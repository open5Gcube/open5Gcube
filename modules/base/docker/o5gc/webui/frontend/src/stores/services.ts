import { defineStore, storeToRefs } from 'pinia';
import { api } from 'src/boot/axios';
import { Notify } from 'quasar';
import { Mutex } from 'async-mutex';
import { _ } from 'lodash';
import { parse as ansiParse } from 'ansicolor';
import { generateErrorNotification } from './common';
import { useSettingsStore } from './settings';

/*
 * Format of services store:
 * {
 *   "services": {
 *     "gNodeB": {
 *       "log": {
 *         "stdout": [
 *            {"time": "2022-12-12T12:12:12.121212Z", "log": ..., "stream": ...}}
 *         ],
 *         "stderr": [
 *            {"time": "2022-12-12T12:12:12.121212Z", "log": ..., "stream": ...}}
 *         ]
 *       },
 *       "status": { ... }
 *     }
 *   }
 * }
 *
 */

type ServiceOverviewType = {
  host: string;
  container_id: string;
  container_name: string;
  status: any;
};

type ServiceLogSpanType = {
  text: string;
  css: string;
  reset?: boolean;
  color?: {
    name: string;
    bright?: boolean;
    dim?: boolean;
  };
  bgColor: {
    name: string;
    bright?: boolean;
    dim?: boolean;
  };
  bold: boolean;
  italic: boolean;
  underline: boolean;
  inverted: boolean;
}

type ServiceLogEntryType = {
  time: Date;
  log: string;
  spans: ServiceLogSpanType[];
  stream: 'stdout'|'stderr';
}

type ServicesType = {
  [serviceName: string]: {
    log: {
      logLines: ServiceLogEntryType[];
    };
    host: string;
    containerId: string;
    containerName: string;
    status: any;
  }
}

type ServiceLogApiType = {
  log_lines: {
    time: string|Date;
    log: string;
    stream: 'stdout'|'stderr';
  }[]
}

/*
 * Container resource usage. The backend sends raw cumulative counters only: the CPU
 * percentage and the network and block rates are deltas of two samples, computed here.
 */
type ContainerStatsType = {
  cpu_total: number;
  cpu_system: number|null;
  online_cpus: number|null;
  net_rx: number;
  net_tx: number;
  blk_read: number;
  blk_write: number;
  // Absolute, no delta needed
  mem_usage: number;
  mem_limit: number|null;
  pids: number|null;
}

type ContainerStatsSampleType = {
  stats: {[containerId: string]: ContainerStatsType};
  time: string;
}

// Titles are whatever the host's ps printed for "docker top", not a fixed set of columns.
type ContainerProcessesType = {
  titles: string[];
  processes: string[][];
}

// A pair of byte figures; for block devices "rx" is read and "tx" is write.
type ByteRateType = {
  rx: number;
  tx: number;
}

// Number of CPU samples kept per container: 30 ticks of 2 s = the last minute.
const CPU_HISTORY_LENGTH = 30;

/*
 * Longest distance between two samples that still counts as one uninterrupted series.
 * Only the open detail view polls, so the series pauses whenever that tab is left: a
 * percentage across such a pause would average over minutes, and the trace would draw the
 * samples on either side of it as neighbours.
 */
const MAX_SAMPLE_GAP_SECONDS = 5;

type UpdateServiceNamesAndStatusIntervalInfoType = {
  nextSubscriberId: number,
  subscribers: {
    [subId: number]: {
      intervalPower: number,
      callback: () => null|null,
    }
  },
  intervalId: any,
  currentIntervalPower: number|null
}

export const useServiceStore = defineStore('services', {
  state(){
    const services: ServicesType = {};
    const serviceOrder: string[] = [];
    const containerStats: ContainerStatsSampleType|null = null;
    const previousContainerStats: ContainerStatsSampleType|null = null;
    // Per container ring buffer of cpu percentages, oldest first; a null is a tick whose
    // value is unknown, so the trace breaks instead of dropping to a zero that never was.
    const cpuHistory: {[containerId: string]: (number|null)[]} = {};
    const _statsLoading = false;
    const _statsLoadedAt: number|null = null;
    // Only ever holds the container of the detail view that is open, see loadContainerProcesses()
    const containerProcesses: {[containerId: string]: ContainerProcessesType} = {};
    // Kept apart so a view can tell "not fetched yet" from "cannot be fetched"
    const _processesLoadingFor: string|null = null;
    const _processesFailedFor: string|null = null;
    const _updateMutex = new Mutex();
    const _updateServicesIntervalInfo: UpdateServiceNamesAndStatusIntervalInfoType = {
      nextSubscriberId: 0,
      subscribers: {},
      intervalId: null,
      currentIntervalPower: null
    }

    return {
        services, serviceOrder, containerStats, previousContainerStats, cpuHistory,
        containerProcesses, _statsLoading, _statsLoadedAt,
        _processesLoadingFor, _processesFailedFor,
        _updateMutex, _updateServicesIntervalInfo
    }
  },
  getters: {
    serviceNames: (state) => Object.keys(state.services),
    containerName: (state) => {
      return (id: string) => {
        if(!(id in state.services)) return null;
        return state.services[id].containerName;
      };
    },
    logForService: (state) => {
      return (id: string, stdout: boolean, stderr: boolean) => {
        if(!(id in state.services)) return [];

        // Filter by selected time frame and stdout/stderr
        const filteredLogs = state.services[id].log.logLines.filter((entry) => {
          return ( (stdout && entry.stream === 'stdout') || (stderr && entry.stream === 'stderr') );
        });
        return filteredLogs;
      }
    },
    healthStatus: (state) => {
      return (id: string): 'starting'|'healthy'|'unhealthy'|null => {
        if(!(id in state.services)) return null;
        if(!('State' in state.services[id].status) || !('Health' in state.services[id].status.State) || !('Status' in state.services[id].status.State.Health)) return null;

        return state.services[id].status.State.Health.Status;
      }
    },
    executionStatus: (state) => {
      return (id: string): 'created'|'running'|'restarting'|'removing'|'paused'|'exited'|'exited-successful'|'exited-error'|'dead'|null => {
        if(!(id in state.services)) return null;
        if(!('State' in state.services[id].status) || !('Status' in state.services[id].status.State)) return null;

        if(state.services[id].status.State.Status == 'exited') {
          if(state.exitCode(id) == 0) return 'exited-successful';
          else if(state.exitCode(id) > 0) return 'exited-error';
          else return 'exited';
        }

        return state.services[id].status.State.Status;
      }
    },
    healthExecutionStatus: (state) => {
      return (id: string): 'created'|'running'|'starting'|'healthy'|'unhealthy'|'restarting'|'removing'|'paused'|'exited-successful'|'exited-error'|'dead'|null => {
        if(state.executionStatus(id) == 'running' && state.healthStatus(id)) return state.healthStatus(id);
        return state.executionStatus(id);
      }
    },
    healthStatusForAllServices: (state) => {
      return (): 'healthy'|'unhealthy'|null => {
        let at_least_one_healthy = false;

        for(const serviceId in state.services) {
          if(!state.services.hasOwnProperty(serviceId)) continue;

          const healthStatus = state.healthExecutionStatus(serviceId);
          if(['unhealthy', 'exited-error'].includes(healthStatus)) return 'unhealthy';
          if(['healthy'].includes(healthStatus)) at_least_one_healthy = true;
        }
        if(at_least_one_healthy) return 'healthy';
        return null;
      }
    },
    imageName: (state) => {
      return (id: string): string|null => {
        if(!(id in state.services)) return null;
        if(!('Config' in state.services[id].status) || !('Image' in state.services[id].status.Config)) return null;

        return state.services[id].status.Config.Image;
      }
    },
    // Config.Env holds one "NAME=value" string per entry, and a value may contain "=".
    environment: (state) => {
      return (id: string): {name: string, value: string}[]|null => {
        if(!(id in state.services)) return null;
        if(!('Config' in state.services[id].status) || !('Env' in state.services[id].status.Config)) return null;

        return (state.services[id].status.Config.Env || []).map((entry: string) => {
          const separator = entry.indexOf('=');
          if(separator === -1) return {name: entry, value: ''};
          return {name: entry.slice(0, separator), value: entry.slice(separator + 1)};
        });
      }
    },
    labelValue: (state) => {
      return (id: string, label: string): string|null => {
        if(!(id in state.services)) return null;
        if(!('Config' in state.services[id].status) || !('Labels' in state.services[id].status.Config) ||
        !(label in state.services[id].status.Config.Labels)) return null;

        return state.services[id].status.Config.Labels[label];
      }
    },
    createdDate: (state) => {
      return (id: string): Date|null => {
        if(!(id in state.services)) return null;
        if(!('Created' in state.services[id].status)) return null;

        return new Date(state.services[id].status.Created);
      }
    },
    startedDate: (state) => {
      return (id: string): Date|'not started'|null => {
        if(!(id in state.services)) return null;
        if(!('State' in state.services[id].status) || !('StartedAt' in state.services[id].status.State)) return null;

        const startedAt = state.services[id].status.State.StartedAt;
        if(startedAt == '0001-01-01T00:00:00Z') return 'not started';
        else return new Date(startedAt);
      }
    },
    finishedDate: (state) => {
      return (id: string): Date|'not finished'|null => {
        if(!(id in state.services)) return null;
        if(!('State' in state.services[id].status) || !('FinishedAt' in state.services[id].status.State)) return null;

        const finishedAt = state.services[id].status.State.FinishedAt;
        if(finishedAt == '0001-01-01T00:00:00Z') return 'not finished';
        else return new Date(finishedAt);
      }
    },
    exitCode: (state) => {
      return (id: string): number|null => {
        if(!(id in state.services)) return null;
        if(!('State' in state.services[id].status) || !('ExitCode' in state.services[id].status.State)) return null;

        return Number(state.services[id].status.State.ExitCode);
      }
    },
    restartCount: (state) => {
      return (id: string): number|null => {
        if(!(id in state.services)) return null;
        if(!('RestartCount' in state.services[id].status)) return null;

        return Number(state.services[id].status.RestartCount);
      }
    },
    restartPolicy: (state) => {
      return (id: string): string|null => {
        if(!(id in state.services)) return null;
        if(!('HostConfig' in state.services[id].status) || !('RestartPolicy' in state.services[id].status.HostConfig)) return null;

        return state.services[id].status.HostConfig.RestartPolicy.Name || 'no';
      }
    },
    // Path and Args are the command line the container runs, not the image's default.
    command: (state) => {
      return (id: string): string|null => {
        if(!(id in state.services)) return null;
        if(!('Path' in state.services[id].status)) return null;

        return [state.services[id].status.Path, ...(state.services[id].status.Args || [])].join(' ');
      }
    },
    ipv4Addresses: (state) => {
      return (id: string): {[networkInterface: string]: string}|null => {
        if(!(id in state.services)) return null;
        if(!('NetworkSettings' in state.services[id].status) || !('Networks' in state.services[id].status.NetworkSettings)) return null;

        const networks = state.services[id].status.NetworkSettings.Networks

        const ipAddresses = Object.keys(networks).reduce((acc: {[networkInterface: string]: string}, key) => {
          acc[key] = networks[key].IPAddress;
          return acc;
        }, {});
        return ipAddresses;
      }
    },
    serviceRunningOrStarting: (state) => {
      return (id: string): boolean|null => {
        if(!(id in state.services)) return null;
        return ['running', 'starting', 'restarting'].includes(state.executionStatus(id));
      }
    },
    externalLinksFromLabels: (state) => {
      const containerLinks: { [key: string]: string } = {};

      for (const id in state.services) {
        const executionStatus = state.executionStatus(id);

        if (executionStatus === 'running') {
          const title = state.labelValue(id, 'o5gc.link.title');
          const url = state.labelValue(id, 'o5gc.link.url');

          if (title && url) {
            containerLinks[title] = url.replace('{{host}}', window.location.hostname);
          }
        }
      }

      return containerLinks
    },
    visibleServiceIds: (state) => {
      const visibleServiceIdsUnsorted = Object.keys(state.services).filter((id) => state.labelValue(id, 'o5gc.webui.hide') === null);
      return state.serviceOrder.filter((serviceId: string) => visibleServiceIdsUnsorted.includes(serviceId));
    },
    visibleServiceDetails: (state) => {
      return state.visibleServiceIds.map((serviceId: string) => state.services[serviceId]);
    },
    visibleServiceIdsSorted: (state) => {
      const l = Object.assign([],  state.visibleServiceIds); // clone array
      return l.sort((a: string, b: string) => {
        const statusPriorities: {[healthExecutionStatus: string]: number} = {
          'exited-error': 5,
          'unhealthy': 4,
          'running': 3, 'healthy': 3, 'starting': 3, 'restarting': 3,
          'created': 2, 'paused': 2,
          'exited-successful': 1,
          'removing': 0, 'dead': 0, null: 0
        }

        const statusPrioA: number = statusPriorities[state.healthExecutionStatus(a)];
        const statusPrioB: number = statusPriorities[state.healthExecutionStatus(b)];
        const labelPrioA = state.labelValue(a, 'o5gc.webui.priority') || 0;
        const labelPrioB = state.labelValue(b, 'o5gc.webui.priority') || 0;
        const createdA = state.createdDate(a);
        const createdB = state.createdDate(b);

        // First criterion: execution health status
        if(statusPrioA != statusPrioB)
          return statusPrioB - statusPrioA; // Show the one with the highest prio first

        // Second criterion: priority from label
        if(labelPrioA != labelPrioB) {
          return labelPrioB - labelPrioA; // Show the one with the highest prio first
        }

        // Third criterion: output later created services first
        return createdB - createdA;
      })
    },
    visibleServiceDetailsSorted: (state) => {
      return state.visibleServiceIdsSorted.map((serviceId: string) => state.services[serviceId])
    },
    runningVisibleServiceNames: (state) => state.visibleServiceIds.filter((serviceId: string) => state.executionStatus(serviceId) === 'running'),

    // The window the rates are measured over, from the timestamps the server sent.
    statsSampleSeconds: (state): number|null => {
      if(!state.containerStats || !state.previousContainerStats) return null;
      const seconds = (new Date(state.containerStats.time).getTime()
                       - new Date(state.previousContainerStats.time).getTime()) / 1000;
      return seconds > 0 ? seconds : null;
    },
    // Percentage of one core: a container using four of them reports 400%.
    cpuPercent: (state) => {
      return (id: string): number|null => {
        const current = state.containerStats?.stats[id];
        const previous = state.previousContainerStats?.stats[id];
        if(!current || !previous) return null;
        if(current.cpu_system === null || previous.cpu_system === null) return null;

        const cpuDelta = current.cpu_total - previous.cpu_total;
        const systemDelta = current.cpu_system - previous.cpu_system;

        // A negative delta means the container restarted and the counters were reset
        if(systemDelta <= 0 || cpuDelta < 0) return null;

        return cpuDelta / systemDelta * (current.online_cpus || 1) * 100;
      }
    },
    memoryBytes: (state) => {
      return (id: string): number|null => {
        const current = state.containerStats?.stats[id];
        return current ? current.mem_usage : null;
      }
    },
    // The host's RAM, not a container limit: no stack service sets one.
    memoryLimit: (state) => {
      return (id: string): number|null => {
        const current = state.containerStats?.stats[id];
        return current ? current.mem_limit : null;
      }
    },
    netRate: (state) => {
      return (id: string): ByteRateType|null => {
        const current = state.containerStats?.stats[id];
        const previous = state.previousContainerStats?.stats[id];
        const seconds = state.statsSampleSeconds;
        if(!current || !previous || !seconds) return null;

        const rx = current.net_rx - previous.net_rx;
        const tx = current.net_tx - previous.net_tx;
        if(rx < 0 || tx < 0) return null;

        return {rx: rx / seconds, tx: tx / seconds};
      }
    },
    blockRate: (state) => {
      return (id: string): ByteRateType|null => {
        const current = state.containerStats?.stats[id];
        const previous = state.previousContainerStats?.stats[id];
        const seconds = state.statsSampleSeconds;
        if(!current || !previous || !seconds) return null;

        const read = current.blk_read - previous.blk_read;
        const write = current.blk_write - previous.blk_write;
        if(read < 0 || write < 0) return null;

        return {rx: read / seconds, tx: write / seconds};
      }
    },
    // Counters since the container started, which the rates above are deltas of.
    netTotal: (state) => {
      return (id: string): ByteRateType|null => {
        const current = state.containerStats?.stats[id];
        return current ? {rx: current.net_rx, tx: current.net_tx} : null;
      }
    },
    blockTotal: (state) => {
      return (id: string): ByteRateType|null => {
        const current = state.containerStats?.stats[id];
        return current ? {rx: current.blk_read, tx: current.blk_write} : null;
      }
    },
    processList: (state) => {
      return (id: string): ContainerProcessesType|null => state.containerProcesses[id] || null;
    },
    processListFailed: (state) => {
      return (id: string): boolean => state._processesFailedFor === id;
    },
    // Tasks in the pids cgroup, the PIDS column of "docker stats": every thread counts, so
    // this is well above the number of processes in processList() for a threaded softmodem.
    pidCount: (state) => {
      return (id: string): number|null => {
        const current = state.containerStats?.stats[id];
        return current ? current.pids : null;
      }
    },
    /*
     * The cpu history as plottable points, one segment per uninterrupted run of samples.
     *
     * Newest sample at the right edge, the trace growing leftwards as the buffer fills.
     * The vertical scale is 0..100% (one core) unless a container uses more, in which case
     * it stretches to the peak of the window - so the common case stays comparable between
     * services and a softmodem burning four cores is still on screen.
     */
    cpuSparklineSegments: (state) => {
      return (id: string, width = 60, height = 16): {x: number, y: number}[][] => {
        const samples = state.cpuHistory[id];
        if(!samples) return [];

        const maximum = Math.max(100, ...samples.filter((value: number|null) => value !== null));
        const step = width / (CPU_HISTORY_LENGTH - 1);
        // Leave room for the stroke so a flat 0% line is not clipped at the bottom edge.
        const top = 1;
        const bottom = height - 1;

        const segments: {x: number, y: number}[][] = [];
        let segment: {x: number, y: number}[]|null = null;
        samples.forEach((value: number|null, index: number) => {
          if(value === null) {
            segment = null;
            return;
          }
          if(segment === null) {
            segment = [];
            segments.push(segment);
          }
          segment.push({
            x: width - (samples.length - 1 - index) * step,
            y: bottom - Math.min(value, maximum) / maximum * (bottom - top)
          });
        });
        return segments;
      }
    },
    cpuSparkline: (state) => {
      return (id: string, width = 60, height = 16): string => {
        return state.cpuSparklineSegments(id, width, height).map(
          (segment: {x: number, y: number}[]) => segment.map(
            (point: {x: number, y: number}, index: number) =>
              `${index === 0 ? 'M' : 'L'}${point.x.toFixed(1)} ${point.y.toFixed(1)}`
          ).join('')
        ).join('');
      }
    },
    // The same trace closed down to the baseline, to be filled underneath the stroke.
    cpuSparklineArea: (state) => {
      return (id: string, width = 60, height = 16): string => {
        const bottom = (height - 1).toFixed(1);
        return state.cpuSparklineSegments(id, width, height).filter(
          (segment: {x: number, y: number}[]) => segment.length > 1
        ).map((segment: {x: number, y: number}[]) =>
          `M${segment[0].x.toFixed(1)} ${bottom}`
          + segment.map((point: {x: number, y: number}) => `L${point.x.toFixed(1)} ${point.y.toFixed(1)}`).join('')
          + `L${segment[segment.length - 1].x.toFixed(1)} ${bottom}Z`
        ).join('');
      }
    },
  },
  actions: {
    async loadServiceNamesAndStatus() {
        await this._updateMutex.runExclusive(async () => {
          function syncStatus(status_old: any, status_new: any) {
            for (const key in status_new) {
              if (status_new.hasOwnProperty(key)) {
                if (!status_old.hasOwnProperty(key)) {
                  status_old[key] = status_new[key];
                } else if (typeof status_new[key] === 'object' && typeof status_old[key] === 'object' && status_new[key] != null && status_old[key] != null) {
                  syncStatus(status_old[key], status_new[key]);
                } else if (status_old[key] !== status_new[key]) {
                  status_old[key] = status_new[key];
                }
              }
            }

            for (const key in status_old) {
              if (status_old.hasOwnProperty(key) && !status_new.hasOwnProperty(key)) {
                delete status_old[key];
              }
            }
          }

          // Get stack names from API
          const serviceOverview: ServiceOverviewType[] = (await api.get('api/containers')).data.containers;

          // Get lists of service names in order to sync the service names from internal state with updated service names
          const servicesBefore = new Set(Object.keys(this.services));
          const servicesNew = new Set(serviceOverview.map(l => l.container_id));

          // Delete service names that do not exist on server anymore
          for (const s of servicesBefore) {
              if (!servicesNew.has(s)) {
                  delete this.services[s]
              }
          }

          // Add services that are new on server
          for(const s of serviceOverview) {
              if (!servicesBefore.has(s.container_id)) {
                  this.services[s.container_id] = {
                    log: {
                      logLines: []
                    },
                    host: s.host,
                    containerId: s.container_id,
                    containerName: s.container_name,
                    status: s.status
                  }
              }
              // Just update some information if service is already there
              else {
                this.services[s.container_id].host = s.host;
                this.services[s.container_id].containerName = s.container_name;
                syncStatus(this.services[s.container_id].status, s.status);
              }
            }

            this.serviceOrder = serviceOverview.map(l => l.container_id);
        });
    },
    /*
     * One sample of the resource counters of every running container. The in flight flag
     * and the minimum age collapse the calls of several subscribers into one request.
     */
    async loadContainerStats() {
      const minimumAgeMs = 1000;
      if(this._statsLoading) return;
      if(this._statsLoadedAt && Date.now() - this._statsLoadedAt < minimumAgeMs) return;

      this._statsLoading = true;
      let sample: ContainerStatsSampleType|null = null;
      try {
        sample = (await api.get('api/containers/stats')).data;
      } catch {
        // Polled continuously: a missed sample leaves the previous one on screen
        return;
      } finally {
        this._statsLoading = false;
        this._statsLoadedAt = Date.now();
      }

      if(!sample) return;

      const sampleTime = new Date(sample.time).getTime();
      const previousTime = this.containerStats ? new Date(this.containerStats.time).getTime() : null;
      const continuous = previousTime !== null
                         && (sampleTime - previousTime) / 1000 <= MAX_SAMPLE_GAP_SECONDS;

      this.previousContainerStats = continuous ? this.containerStats : null;
      this.containerStats = sample;

      if(!continuous) this.cpuHistory = {};

      for(const containerId of Object.keys(sample.stats)) {
        const history = this.cpuHistory[containerId] || (this.cpuHistory[containerId] = []);
        history.push(this.cpuPercent(containerId));
        if(history.length > CPU_HISTORY_LENGTH) history.splice(0, history.length - CPU_HISTORY_LENGTH);
      }

      // A restarted container comes back under a new id, so its buffer would linger
      for(const containerId of Object.keys(this.cpuHistory)) {
        if(!(containerId in sample.stats)) delete this.cpuHistory[containerId];
      }
    },
    /*
     * The process list of the container whose detail view is open: "docker top" costs
     * several times a stats sample, so it is not fetched for a whole stack. The sample
     * replaces the whole map, leaving no list behind per service visited.
     */
    async loadContainerProcesses(containerId: string) {
      // Keyed by container rather than a single in flight flag: skipping the request for
      // the service just switched to would leave its view empty until the next tick.
      if(this._processesLoadingFor === containerId) return;

      this._processesLoadingFor = containerId;
      try {
        const processes = (await api.get(`api/containers/${containerId}/processes`)).data;

        // A newer request for another container took over while this one was in flight
        if(this._processesLoadingFor !== containerId) return;

        this.containerProcesses = {[containerId]: processes};
        this._processesFailedFor = null;
      } catch {
        this._processesFailedFor = containerId;
      } finally {
        if(this._processesLoadingFor === containerId) this._processesLoadingFor = null;
      }
    },
    _startUpdateServicesInterval() {
      const intervalPower = Math.min(...Object.values(this._updateServicesIntervalInfo.subscribers).map(sub => sub.intervalPower));

      this._updateServicesIntervalInfo.intervalId = setInterval(async () => {
        await this.loadServiceNamesAndStatus();

        for(const subId in this._updateServicesIntervalInfo.subscribers) {
          const subscriber = this._updateServicesIntervalInfo.subscribers[subId];
          if (subscriber.callback && typeof subscriber.callback === 'function') {
            subscriber.callback();
          }
        }

      }, 1000*Math.pow(2, intervalPower));
      this._updateServicesIntervalInfo.currentIntervalPower = intervalPower;
    },
    addUpdateServicesInterval(callback: () => null|null, intervalPower: number) {

      const subId = this._updateServicesIntervalInfo.nextSubscriberId++;
      this._updateServicesIntervalInfo.subscribers[subId] = {intervalPower, callback};

      if(this._updateServicesIntervalInfo.currentIntervalPower && intervalPower < this._updateServicesIntervalInfo.currentIntervalPower) {
        clearInterval(this._updateServicesIntervalInfo.intervalId);
        this._updateServicesIntervalInfo.intervalId = null;
      }

      if(!this._updateServicesIntervalInfo.intervalId) {
        this._startUpdateServicesInterval();
      }
      return subId;
    },
    removeUpdateServicesInterval(subId: number) {

      const subscriberIntervalPower = this._updateServicesIntervalInfo.subscribers[subId].intervalPower;
      delete this._updateServicesIntervalInfo.subscribers[subId];

      if(subscriberIntervalPower == this._updateServicesIntervalInfo.currentIntervalPower
         && Math.min(...Object.values(this._updateServicesIntervalInfo.subscribers).map(sub => sub.intervalPower)) > subscriberIntervalPower) {
          clearInterval(this._updateServicesIntervalInfo.intervalId);
          this._updateServicesIntervalInfo.intervalId = null;
      }

      if(!this._updateServicesIntervalInfo.intervalId) {
        this._startUpdateServicesInterval();
      }
    },
    async loadServiceLog(id: string) {

      if(!this.ensureServiceIsInStore(id)) return;

      const removeANSIEscapeSequences = (input: string) => {
        /*
         * Remove some relevant terminal escape sequences.
         * See http://rtfm.etla.org/xterm/ctlseq.html
         */
        // Control sequences (except color codes): ESC [ parameter_list character
        const regex_csi = /\x1b\[[?!]?[0-9;]*[a-ln-zA-Z@`]/g;
        // Operating system commands (like terminal title): ESC ] number ; text bell|string_terminator
        const regex_osc = /\x1b\].*?(\x07|\x1b\\)/g;
        return input.replace(regex_csi, '').replace(regex_osc, '');
      };

      await this._updateMutex.runExclusive(async () => {

        const { logLines } = storeToRefs(useSettingsStore());

        const service = this.services[id];

        const timestamps = 'true';
        const tail = `${logLines.value}`;
        const stdout = 'true';
        const stderr = 'true';

        // Get log part
        let logPart: ServiceLogApiType;
        try {
          logPart = (await api.get(`api/container/${service.host}/${service.containerId}/logs`, {
            params: {
              timestamps, tail, stdout, stderr
            }
          })).data;
        } catch (error: any) {
          if(error.response) {
            generateErrorNotification(`HTTP Error ${error.response.status} on trying to fetch service log for service ${service.containerName} from server.`);
          } else {
            generateErrorNotification(`Unknown error on trying to fetch service log for service ${service.containerName} from server.`);
          }
          return;
        }

        const convertedLogPart: ServiceLogEntryType[] = logPart.log_lines.map((entry) => {
          return {
            ...entry,
            log: removeANSIEscapeSequences(entry.log),
            spans: [],
            time: new Date(entry.time)
          }
        });

        let previousSpan: ServiceLogSpanType | undefined = undefined
        for(const logLine of convertedLogPart) {
          const spans = ansiParse(logLine.log, previousSpan);
          logLine.spans = spans.spans;
          previousSpan = logLine.spans[logLine.spans.length - 1];
        }

        this.services[id].log.logLines = convertedLogPart;

      });
    },
    async ensureServiceIsInStore(serviceId: string) {
      if(serviceId in this.services) return true;

      await this.loadServiceNamesAndStatus();
      if(serviceId in this.services) return true;

      Notify.create({
        message: 'Tried to get service information for service ' + serviceId + ' which does not exist.',
        color: 'negative',
        icon: 'announcement'
      })

      return false;
    }
  }
});
