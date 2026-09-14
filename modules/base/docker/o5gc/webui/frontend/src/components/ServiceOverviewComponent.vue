<!--
  Overview tab of the service detail view. Not to be confused with pages/ServiceOverview.vue,
  which is the grid of log panels of all services.

  The only component that samples the container stats, so the polling stops with the tab:
  an inactive tab panel is destroyed.
-->
<template>
  <div class="column col">
    <ServiceTitleBarComponent :service-id="serviceId" :service-title-as-link="false" :autoscroll="false" />
    <q-card flat bordered square class="column col">
      <q-scroll-area class="col">
        <div class="q-pa-md">

          <!-- No threshold colouring: 100% CPU is one full core, the normal working point of
               a softmodem rather than a problem, and no stack service sets a memory limit. -->
          <div class="row q-col-gutter-md">

            <div class="col-12 col-sm-6 col-lg-3">
              <q-card flat bordered class="q-pa-sm full-height">
                <div class="row items-center no-wrap">
                  <q-icon :name="symOutlinedMemory" size="20px" class="q-mr-xs" />
                  <span class="text-body2">CPU</span>
                  <q-space />
                  <span class="text-h6">{{ formatPercent(cpuPercent(serviceId)) }}</span>
                </div>
                <!-- preserveAspectRatio none stretches the trace to the card width; the stroke
                     is kept at its nominal width by vector-effect. -->
                <svg
                  class="text-primary"
                  :viewBox="`0 0 ${sparklineWidth} ${sparklineHeight}`"
                  preserveAspectRatio="none"
                  style="display: block; width: 100%; height: 60px;"
                >
                  <line
                    x1="0" :y1="sparklineHeight - 1" :x2="sparklineWidth" :y2="sparklineHeight - 1"
                    stroke="currentColor" stroke-width="1" opacity="0.3" vector-effect="non-scaling-stroke"
                  />
                  <path :d="cpuSparklineArea(serviceId, sparklineWidth, sparklineHeight)" fill="currentColor" opacity="0.2" />
                  <path
                    :d="cpuSparkline(serviceId, sparklineWidth, sparklineHeight)"
                    fill="none"
                    stroke="currentColor"
                    stroke-width="1.5"
                    stroke-linejoin="round"
                    vector-effect="non-scaling-stroke"
                  />
                </svg>
                <div class="text-caption text-grey-5">
                  {{ cpuPercent(serviceId) === null ? 'Waiting for a second sample' : 'of one core' }}
                </div>
                <q-tooltip>
                  <div>Percent of one core: a service using four cores reports 400%</div>
                  <div>Measured between two polls, {{ statsSampleSeconds === null ? '?' : statsSampleSeconds.toFixed(1) }} s apart</div>
                  <div>The trace scales to 100% unless the peak of the window is higher</div>
                </q-tooltip>
              </q-card>
            </div>

            <div class="col-12 col-sm-6 col-lg-3">
              <q-card flat bordered class="q-pa-sm full-height">
                <div class="row items-center no-wrap">
                  <q-icon :name="symOutlinedMemoryAlt" size="20px" class="q-mr-xs" />
                  <span class="text-body2">Memory</span>
                  <q-space />
                  <span class="text-h6">{{ formatBytes(memoryBytes(serviceId)) }}</span>
                </div>
                <div style="height: 60px;" class="column justify-center">
                  <q-linear-progress :value="memoryFraction || 0" color="positive" track-color="grey-9" size="6px" rounded />
                </div>
                <div class="text-caption text-grey-5">
                  {{ formatPercent(memoryFraction === null ? null : memoryFraction * 100, 1) }} of {{ formatBytes(memoryLimit(serviceId)) }} host RAM (no limit set)
                </div>
                <q-tooltip>
                  <div>Resident memory without the page cache, the figure "docker stats" shows</div>
                  <div>No stack service sets a memory limit, so the bar is filled against the host's RAM</div>
                </q-tooltip>
              </q-card>
            </div>

            <div class="col-12 col-sm-6 col-lg-3">
              <q-card flat bordered class="q-pa-sm full-height">
                <div class="row items-center no-wrap">
                  <q-icon :name="symOutlinedSwapVert" size="20px" class="q-mr-xs" />
                  <span class="text-body2">Network I/O</span>
                </div>
                <div style="height: 60px;" class="column justify-center">
                  <div v-for="direction in ['rx', 'tx']" :key="direction" class="row items-baseline no-wrap">
                    <span class="text-grey-5">{{ direction === 'rx' ? 'RX' : 'TX' }}</span>
                    <q-space />
                    <span class="text-body1">{{ formatRate(netRate(serviceId), direction) }}</span>
                  </div>
                </div>
                <div class="text-caption text-grey-5">
                  {{ formatBytes(netTotal(serviceId)?.rx) }} / {{ formatBytes(netTotal(serviceId)?.tx) }} total
                </div>
                <q-tooltip>
                  <div>Received and transmitted over all of the container's networks</div>
                  <div>Rate between the last two polls, totals since the container started</div>
                </q-tooltip>
              </q-card>
            </div>

            <div class="col-12 col-sm-6 col-lg-3">
              <q-card flat bordered class="q-pa-sm full-height">
                <div class="row items-center no-wrap">
                  <q-icon :name="symOutlinedStorage" size="20px" class="q-mr-xs" />
                  <span class="text-body2">Block I/O</span>
                </div>
                <div style="height: 60px;" class="column justify-center">
                  <div v-for="direction in ['rx', 'tx']" :key="direction" class="row items-baseline no-wrap">
                    <span class="text-grey-5">{{ direction === 'rx' ? 'Read' : 'Write' }}</span>
                    <q-space />
                    <span class="text-body1">{{ formatRate(blockRate(serviceId), direction) }}</span>
                  </div>
                </div>
                <div class="text-caption text-grey-5">
                  {{ formatBytes(blockTotal(serviceId)?.rx) }} / {{ formatBytes(blockTotal(serviceId)?.tx) }} total
                </div>
                <q-tooltip>
                  <div>Read from and written to block devices, page cache hits excluded</div>
                  <div>Rate between the last two polls, totals since the container started</div>
                </q-tooltip>
              </q-card>
            </div>

          </div>

          <div class="row q-col-gutter-md q-mt-none">
            <div v-for="section in sections" :key="section.title" class="col-12 col-md-6">
              <q-card flat bordered class="q-pa-sm">
                <div class="row items-center no-wrap q-mb-sm">
                  <q-icon :name="section.icon" size="20px" class="q-mr-xs" />
                  <span class="text-subtitle2">{{ section.title }}</span>
                </div>
                <div class="row q-col-gutter-sm">
                  <div v-for="field in section.fields" :key="field.label" class="col-12 col-sm-6">
                    <div class="text-caption text-grey-5">{{ field.label }}</div>
                    <q-badge v-if="field.color" :color="field.color" class="text-weight-bold">{{ field.value }}</q-badge>
                    <div v-else style="word-break: break-word;">{{ field.value }}</div>
                    <q-tooltip v-if="field.tooltip">{{ field.tooltip }}</q-tooltip>
                  </div>
                </div>
              </q-card>
            </div>
          </div>

          <div class="row q-col-gutter-md q-mt-none">
            <div class="col-12">
              <q-card flat bordered class="q-pa-sm">
                <div class="text-caption text-grey-5">Command</div>
                <div style="font-family: monospace; word-break: break-all;">{{ command }}</div>
              </q-card>
            </div>
          </div>

          <div class="row q-col-gutter-md q-mt-none">
            <div class="col-12">
              <q-card flat bordered class="q-pa-sm">
                <!-- Tooltip on the header, not the card: over a table of rows it would
                     otherwise pop up wherever the pointer rests. -->
                <div class="row items-center no-wrap q-mb-sm">
                  <q-icon :name="symOutlinedListAlt" size="20px" class="q-mr-xs" />
                  <span class="text-subtitle2">Processes</span>
                  <q-tooltip>
                    <div>The output of ps for the processes of this container, busiest first</div>
                    <div>%CPU is the average since a process started, not the current load of the card above</div>
                    <div>PIDs are the host's, the way "docker top" reports them</div>
                  </q-tooltip>
                </div>

                <q-markup-table v-if="processes" flat dense square class="bg-transparent">
                  <thead>
                    <tr>
                      <th class="text-left text-grey-5">#</th>
                      <th v-for="title in processes.titles" :key="title" class="text-left">{{ title }}</th>
                    </tr>
                  </thead>
                  <tbody>
                    <tr v-for="(process, index) in processes.processes" :key="index">
                      <td class="text-grey-5">{{ index + 1 }}</td>
                      <td v-for="(cell, column) in process" :key="column" style="font-family: monospace;">{{ cell }}</td>
                    </tr>
                  </tbody>
                </q-markup-table>
                <div v-else class="text-caption text-grey-5">
                  {{ processListFailed(serviceId) ? 'Process list could not be fetched' : 'Reading the process list…' }}
                </div>

                <div v-if="processes" class="text-caption text-grey-5 q-mt-sm">
                  {{ processes.processes.length }} process{{ processes.processes.length === 1 ? '' : 'es' }}
                  &mdash; {{ pidCount(serviceId) === null ? 'thread count unknown' : `${pidCount(serviceId)} threads in total` }}
                </div>
              </q-card>
            </div>
          </div>

        </div>
      </q-scroll-area>
    </q-card>
  </div>
</template>

<script>
import { onUnmounted, onMounted, computed, watch } from 'vue';
import { useServiceStore } from 'src/stores/services';
import { storeToRefs } from 'pinia';
import { symOutlinedMemory, symOutlinedMemoryAlt, symOutlinedSwapVert, symOutlinedStorage,
         symOutlinedDeployedCode, symOutlinedMonitorHeart, symOutlinedListAlt } from '@quasar/extras/material-symbols-outlined';
import { healthExecutionStatusToBarColorMap } from './serviceStatusConfiguration';
import ServiceTitleBarComponent from './ServiceTitleBarComponent.vue';

// Only an aspect ratio: the svg is stretched to the width of the card.
const SPARKLINE_WIDTH = 300;
const SPARKLINE_HEIGHT = 60;

function formatBytes(bytes) {
  if(bytes === null || bytes === undefined) return '–';
  const mib = bytes / (1024 ** 2);
  if(mib >= 1024) return `${(mib / 1024).toFixed(1)} GiB`;
  if(mib >= 1) return `${mib.toFixed(0)} MiB`;
  return `${(bytes / 1024).toFixed(0)} KiB`;
}

function formatDate(date) {
  if(date === null) return '–';
  if(typeof date === 'string') return date;   // 'not started' / 'not finished'
  return date.toLocaleString('de-DE');
}

export default {
  components: { ServiceTitleBarComponent },
  props: {
    serviceId: { type: String, required: true }
  },
  setup(props) {
    const serviceStore = useServiceStore();
    const {
      cpuPercent,
      cpuSparkline,
      cpuSparklineArea,
      memoryBytes,
      memoryLimit,
      netRate,
      netTotal,
      blockRate,
      blockTotal,
      pidCount,
      processList,
      processListFailed,
      statsSampleSeconds
    } = storeToRefs(serviceStore);

    let servicesUpdater = null;

    onMounted(async () => {
      await serviceStore.loadServiceNamesAndStatus();
      await serviceStore.loadContainerStats();
      await serviceStore.loadContainerProcesses(props.serviceId);
      // No own setInterval: the shared services tick (power 1 = 2 s) drives both the stats
      // and the inspect data the sections below are built from.
      servicesUpdater = serviceStore.addUpdateServicesInterval(() => {
        serviceStore.loadContainerStats();
        serviceStore.loadContainerProcesses(props.serviceId);
      }, 1);
    });

    // The component stays mounted when another service is picked from the tabs above
    watch(() => props.serviceId, (serviceId) => serviceStore.loadContainerProcesses(serviceId));

    onUnmounted(() => {
      if(servicesUpdater)
        serviceStore.removeUpdateServicesInterval(servicesUpdater);
    });

    const memoryFraction = computed(() => {
      const used = memoryBytes.value(props.serviceId);
      const limit = memoryLimit.value(props.serviceId);
      if(used === null || !limit) return null;
      return used / limit;
    });

    return {
      serviceStore, statsSampleSeconds,
      cpuPercent, cpuSparkline, cpuSparklineArea, memoryBytes, memoryLimit,
      netRate, netTotal, blockRate, blockTotal, pidCount, processList, processListFailed, memoryFraction,
      symOutlinedMemory, symOutlinedMemoryAlt, symOutlinedSwapVert, symOutlinedStorage,
      symOutlinedDeployedCode, symOutlinedMonitorHeart, symOutlinedListAlt,
      sparklineWidth: SPARKLINE_WIDTH,
      sparklineHeight: SPARKLINE_HEIGHT,
      formatBytes,
      // Below 10% a whole number hides the difference between an idle and a working service
      formatPercent(percentage, digits = null) {
        if(percentage === null || percentage === undefined || !isFinite(percentage)) return '–';
        return `${percentage.toFixed(digits === null ? (percentage < 10 ? 1 : 0) : digits)}%`;
      },
      formatRate(rate, direction) {
        if(!rate) return '–';
        const bytesPerSecond = rate[direction];
        if(bytesPerSecond >= 1024 ** 2) return `${(bytesPerSecond / (1024 ** 2)).toFixed(1)} MiB/s`;
        if(bytesPerSecond >= 1024) return `${(bytesPerSecond / 1024).toFixed(1)} KiB/s`;
        return `${bytesPerSecond.toFixed(0)} B/s`;
      }
    };
  },
  computed: {
    sections() {
      const store = this.serviceStore;
      const id = this.serviceId;
      const status = store.healthExecutionStatus(id);
      const networks = store.ipv4Addresses(id) || {};

      // ExitCode is the code of the last run and reads 0 for a container that never exited,
      // so only a finished one gets a number - as the status line under the log does it.
      const finished = store.finishedDate(id);
      const hasFinished = finished !== null && finished !== 'not finished';
      const exitCode = hasFinished && store.exitCode(id) !== null ? store.exitCode(id) : '–';
      const exitCodeColor = exitCode > 0 ? 'negative' : null;

      // The count only grows through the restart policy, so under the "no" every stack
      // service runs with it is structurally zero: it is shown only when it is not.
      const restartCount = store.restartCount(id);
      const restartPolicy = store.restartPolicy(id) || 'unknown';
      const restarts = restartCount
        ? `${restartPolicy} (${restartCount} restart${restartCount === 1 ? '' : 's'})`
        : restartPolicy;

      return [
        {
          title: 'Status',
          icon: symOutlinedMonitorHeart,
          fields: [
            {
              label: 'State',
              value: status || 'unknown',
              color: status ? healthExecutionStatusToBarColorMap[status].barColor : 'grey-9'
            },
            { label: 'Started', value: formatDate(store.startedDate(id)) },
            { label: 'Health Check', value: store.healthStatus(id) || 'none' },
            { label: 'Finished', value: formatDate(finished) },
            { label: 'Restart Policy', value: restarts },
            { label: 'Exit Code', value: exitCode, color: exitCodeColor }
          ]
        },
        {
          title: 'Basic information',
          icon: symOutlinedDeployedCode,
          fields: [
            { label: 'Container ID', value: id.slice(0, 12) },
            { label: 'Stack', value: store.labelValue(id, 'o5gc.stack') || '–' },
            { label: 'Image', value: store.imageName(id) || '–' },
            { label: 'Image Version', value: store.labelValue(id, 'org.opencontainers.image.version') || '–' },
            ...Object.entries(networks).map(([networkName, ipAddress]) => (
              { label: `IP (${networkName})`, value: ipAddress || '–' }
            ))
          ]
        }
      ];
    },
    processes() {
      return this.processList(this.serviceId);
    },
    command() {
      return this.serviceStore.command(this.serviceId) || '–';
    }
  }
}

</script>
