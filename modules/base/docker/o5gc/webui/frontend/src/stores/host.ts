import { defineStore } from 'pinia';
import { api } from 'src/boot/axios';
import { generateErrorNotification } from './common';

/*
 * Format of the host store:
 * {
 *   "hostInfo": {
 *     "docker": {"version": ..., "images": ...} | null,
 *     "os": {"name": ..., "kernel": ..., "arch": ...},
 *     "cpu": {"count": ..., "loadavg": [1.11, 0.73, 0.36], "jiffies": {"total": ..., "idle": ...}},
 *     "memory": {"total_bytes": ..., "available_bytes": ...},
 *     "time": "2026-09-09T17:30:00+00:00"
 *   },
 *   "previousSample": { ... }
 * }
 *
 * The backend only ever returns raw counters, never percentages. The CPU load of the
 * machine is the delta between two consecutive samples and is computed here.
 */

type HostJiffiesType = {
  total: number;
  idle: number;
}

type HostInfoType = {
  docker: {
    version: string;
    images: number;
  }|null;
  os: {
    name: string|null;
    kernel: string|null;
    arch: string|null;
  };
  cpu: {
    count: number|null;
    loadavg: number[];
    jiffies: HostJiffiesType;
  };
  memory: {
    total_bytes: number|null;
    available_bytes: number;
  };
  time: string;
}

type HostSampleType = {
  jiffies: HostJiffiesType;
  time: Date;
}

type ImageUsageType = {
  count: number;
  size_bytes: number;
  // False when layers shared with unrelated images could not be attributed, in which
  // case size_bytes is an upper bound rather than the exact figure.
  exact: boolean;
  store_total_bytes: number;
}

type HostStoreType = {
  hostInfo: HostInfoType|null;
  previousSample: HostSampleType|null;
  reachable: boolean|null;
  imageUsage: ImageUsageType|null;
  imageUsageFetchedAt: number|null;
  imageUsageLoading: boolean;
}

export const useHostStore = defineStore('host', {
  state() : HostStoreType {
    const hostInfo: HostInfoType|null = null;
    const previousSample: HostSampleType|null = null;
    const reachable: boolean|null = null;
    const imageUsage: ImageUsageType|null = null;
    const imageUsageFetchedAt: number|null = null;
    const imageUsageLoading = false;

    return {
      hostInfo, previousSample, reachable, imageUsage, imageUsageFetchedAt, imageUsageLoading
    }
  },
  getters: {
    dockerAvailable: (state) => state.hostInfo !== null && state.hostInfo.docker !== null,
    coreCount: (state) => state.hostInfo ? state.hostInfo.cpu.count : null,
    load1: (state) => state.hostInfo ? state.hostInfo.cpu.loadavg[0] : null,
    loadAverages: (state) => state.hostInfo ? state.hostInfo.cpu.loadavg : null,
    // Load as a percentage of the machine's capacity. Unlike cpu and memory this can exceed 100%.
    loadPercentage: (state): number|null => {
      if(!state.hostInfo || !state.hostInfo.cpu.count) return null;
      return state.hostInfo.cpu.loadavg[0] / state.hostInfo.cpu.count * 100;
    },
    // Needs two samples: the first poll after a page load reports unknown, not 0.
    cpuPercentage: (state): number|null => {
      if(!state.hostInfo || !state.previousSample) return null;

      const totalDelta = state.hostInfo.cpu.jiffies.total - state.previousSample.jiffies.total;
      const idleDelta = state.hostInfo.cpu.jiffies.idle - state.previousSample.jiffies.idle;

      // Counters are cumulative and only ever grow; anything else means we lost track of them.
      if(totalDelta <= 0 || idleDelta < 0) return null;

      return (1 - idleDelta / totalDelta) * 100;
    },
    cpuSampleSeconds: (state): number|null => {
      if(!state.hostInfo || !state.previousSample) return null;
      return (new Date(state.hostInfo.time).getTime() - state.previousSample.time.getTime()) / 1000;
    },
    memoryPercentage: (state): number|null => {
      if(!state.hostInfo || !state.hostInfo.memory.total_bytes) return null;
      const memory = state.hostInfo.memory;
      return (memory.total_bytes - memory.available_bytes) / memory.total_bytes * 100;
    },
    // Rendered next to the image count. Empty until the on-demand fetch returns, so the
    // count is shown immediately and the size fills in.
    imageSizeLabel: (state): string => {
      if(!state.imageUsage) return '';
      const gib = state.imageUsage.size_bytes / (1024 ** 3);
      return `, ${gib.toFixed(1)} GiB${state.imageUsage.exact ? '' : ' or less'}`;
    },
    memoryUsedBytes: (state): number|null => {
      if(!state.hostInfo || !state.hostInfo.memory.total_bytes) return null;
      return state.hostInfo.memory.total_bytes - state.hostInfo.memory.available_bytes;
    }
  },
  actions: {
    // Walks every image's layer chain on the server (~220 ms), so it is fetched when the
    // Docker tooltip opens rather than on the status poll, and cached for a minute.
    async loadImageUsage() {
      const maxAgeMs = 60000;
      if(this.imageUsageLoading) return;
      if(this.imageUsageFetchedAt && Date.now() - this.imageUsageFetchedAt < maxAgeMs) return;

      this.imageUsageLoading = true;
      try {
        this.imageUsage = (await api.get('api/host/images')).data;
        this.imageUsageFetchedAt = Date.now();
      } catch {
        // The count is already on screen; failing to size it is not worth a notification.
        this.imageUsage = null;
      } finally {
        this.imageUsageLoading = false;
      }
    },
    async loadHostInfo() {
      let hostInfo: HostInfoType|null = null;
      try {
        hostInfo = (await api.get('api/host')).data;
      } catch(error: any) {
        // The strip polls continuously, so only report the transition to unreachable
        // instead of raising a notification on every single tick.
        if(this.reachable !== false) {
          if(error.response) {
            generateErrorNotification(`HTTP Error ${error.response.status} on trying to fetch host information.`);
          } else {
            generateErrorNotification('Unknown error on trying to fetch host information.');
          }
        }
        this.reachable = false;
        return;
      }

      if(!hostInfo) return;

      // Keep the previous counters around so the cpu percentage can be a delta of two samples
      if(this.hostInfo) {
        this.previousSample = {
          jiffies: this.hostInfo.cpu.jiffies,
          time: new Date(this.hostInfo.time)
        };
      }

      this.hostInfo = hostInfo;
      this.reachable = true;
    }
  }
});
