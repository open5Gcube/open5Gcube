<template>
  <div class="row items-center no-wrap q-gutter-x-md text-caption">

    <!-- Load: percentage of the machine's capacity, followed by the raw 1/5/15 minute averages -->
    <div class="row items-center no-wrap">
      <span class="q-mr-xs">Load</span>
      <q-icon v-if="levelStyle('load').iconName" :name="levelStyle('load').iconName" :class="`text-${levelStyle('load').textColor} q-mr-xs`" />
      <span :class="`text-${levelStyle('load').textColor} text-weight-medium`">{{ formatPercentage(loadPercentage) }}</span>
      <span v-if="loadAverages" class="q-ml-xs">({{ loadAverages[0].toFixed(2) }}/{{ loadAverages[1].toFixed(2) }}/{{ loadAverages[2].toFixed(2) }})</span>
      <q-tooltip>
        <div v-if="loadAverages">Load average: {{ loadAverages[0].toFixed(2) }} (1 min) / {{ loadAverages[1].toFixed(2) }} (5 min) / {{ loadAverages[2].toFixed(2) }} (15 min)</div>
        <div v-else>Load average unknown</div>
        <div>{{ coreCount !== null ? `${coreCount} CPU cores` : 'Core count unknown (Docker unavailable)' }}</div>
      </q-tooltip>
    </div>

    <!-- CPU -->
    <div class="row items-center no-wrap">
      <span class="q-mr-xs">CPU</span>
      <q-icon v-if="levelStyle('cpu').iconName" :name="levelStyle('cpu').iconName" :class="`text-${levelStyle('cpu').textColor} q-mr-xs`" />
      <span :class="`text-${levelStyle('cpu').textColor} text-weight-medium`">{{ formatPercentage(cpuPercentage) }}</span>
      <q-tooltip>
        <div v-if="cpuPercentage !== null">Busy over the last {{ cpuSampleSeconds !== null ? cpuSampleSeconds.toFixed(1) : '?' }} s</div>
        <div v-else>Waiting for a second sample &mdash; the CPU load is measured between two polls</div>
      </q-tooltip>
    </div>

    <!-- Memory -->
    <div class="row items-center no-wrap">
      <span class="q-mr-xs">Mem</span>
      <q-icon v-if="levelStyle('memory').iconName" :name="levelStyle('memory').iconName" :class="`text-${levelStyle('memory').textColor} q-mr-xs`" />
      <span :class="`text-${levelStyle('memory').textColor} text-weight-medium`">{{ formatPercentage(memoryPercentage) }}</span>
      <q-tooltip>
        <div v-if="hostInfo">{{ formatBytes(memoryUsedBytes) }} used of {{ formatBytes(hostInfo.memory.total_bytes) }}</div>
        <div v-if="hostInfo">{{ formatBytes(hostInfo.memory.available_bytes) }} available</div>
        <div v-if="!hostInfo">Memory usage unknown</div>
      </q-tooltip>
    </div>

    <!-- Docker version + liveness dot -->
    <div class="row items-center no-wrap">
      <span class="q-mr-xs">Docker</span>
      <span class="text-weight-medium">{{ dockerAvailable ? hostInfo.docker.version : 'n/a' }}</span>
      <q-icon :name="reachable === false ? 'cloud_off' : 'circle'" :class="`text-${livenessColor} q-ml-sm`" :style="reachable === false ? '' : 'font-size: 10px;'" />
      <q-tooltip @show="loadImageUsage">
        <div v-if="reachable === false">Host information could not be fetched from the backend</div>
        <div v-else-if="!hostInfo">Waiting for host information</div>
        <template v-else>
          <div v-if="dockerAvailable">Docker {{ hostInfo.docker.version }}</div>
          <div v-if="dockerAvailable">{{ hostInfo.docker.images }} open5Gcube images{{ imageSizeLabel }}</div>
          <div v-else>Docker socket unavailable</div>
          <div v-if="hostInfo.os.name">{{ hostInfo.os.name }} &mdash; kernel {{ hostInfo.os.kernel }} ({{ hostInfo.os.arch }})</div>
          <div>Updated {{ new Date(hostInfo.time).toLocaleTimeString() }}</div>
        </template>
      </q-tooltip>
    </div>

  </div>
</template>

<script>
import { onUnmounted, onMounted, computed } from 'vue';
import { storeToRefs } from 'pinia';
import { useHostStore } from 'src/stores/host';
import { useServiceStore } from 'src/stores/services';
import { hostThresholdLevel, hostThresholdLevelToStyleMap } from './hostThresholdConfiguration';

export default {
  setup() {
    const hostStore = useHostStore();
    const {
      hostInfo,
      reachable,
      dockerAvailable,
      coreCount,
      loadAverages,
      loadPercentage,
      cpuPercentage,
      cpuSampleSeconds,
      memoryPercentage,
      memoryUsedBytes,
      imageSizeLabel
    } = storeToRefs(hostStore);

    // No own setInterval: the host info is refreshed on the shared services tick (power 2 = 4 s)
    const serviceStore = useServiceStore();
    let updater = null;

    onMounted(async () => {
      await hostStore.loadHostInfo();
      updater = serviceStore.addUpdateServicesInterval(() => { hostStore.loadHostInfo(); }, 2);
    });

    onUnmounted(() => {
      if(updater)
        serviceStore.removeUpdateServicesInterval(updater);
    });

    const livenessColor = computed(() => {
      if(reachable.value === false) return 'negative';
      if(reachable.value === null) return 'grey-5';
      return dockerAvailable.value ? 'positive' : 'orange-10';
    });

    return {
      hostInfo, reachable, dockerAvailable, coreCount, loadAverages,
      loadPercentage, cpuPercentage, cpuSampleSeconds, memoryPercentage, memoryUsedBytes,
      imageSizeLabel, livenessColor,
      loadImageUsage: () => hostStore.loadImageUsage(),
      levelStyle(metric) {
        const percentages = {
          'load': loadPercentage.value,
          'cpu': cpuPercentage.value,
          'memory': memoryPercentage.value
        };
        return hostThresholdLevelToStyleMap[hostThresholdLevel(metric, percentages[metric])];
      },
      formatPercentage(percentage) {
        if(percentage === null || !isFinite(percentage)) return '–';
        return `${percentage.toFixed(0)}%`;
      },
      formatBytes(bytes) {
        if(bytes === null || bytes === undefined) return 'unknown';
        return `${(bytes / (1024 ** 3)).toFixed(1)} GiB`;
      }
    }
  }
}

</script>
