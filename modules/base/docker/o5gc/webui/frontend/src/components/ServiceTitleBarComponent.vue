<template>
  <q-bar :class="`bg-${healthExecutionStatus(serviceId) != null ? healthExecutionStatusToBarColor[healthExecutionStatus(serviceId)].barColor : 'grey-9'} text-white col-auto row`" style="flex-wrap: wrap !important;">
    <div v-if="healthExecutionStatus(serviceId) != null" style="margin-right: 5px;" class="col-auto">
      <q-icon :name="healthExecutionStatusToBarColor[healthExecutionStatus(serviceId)].iconName" style="font-size: 35px;">
        <q-tooltip>{{ healthExecutionStatusToBarColor[healthExecutionStatus(serviceId)].tooltip }}</q-tooltip>
      </q-icon>
    </div>
    <div class="col row items-center" style="line-height: 1.0;">
      <router-link v-if="serviceTitleAsLink" :to="`/service/${serviceId}`" class="text-white col-auto q-mr-sm" style="font-size: 18px; font-weight: bold;">{{ containerName(serviceId) }}</router-link>
      <div v-else style="font-size: 18px; font-weight: bold;" class="col-auto q-mr-sm">{{ containerName(serviceId) }}</div>
      <i class="text-body2 col-auto">
        {{ imageName(serviceId) }}
      </i>
    </div>
    <q-space />
    <div v-if="autoscroll && serviceRunningOrStarting(serviceId)" class="col-auto">
      <q-icon name="keyboard_double_arrow_down" class="text-white" style="font-size: 35px;">
        <q-tooltip>Autoscroll active</q-tooltip>
      </q-icon>
    </div>
  </q-bar>
</template>

<script>
import { onUnmounted, onMounted, ref } from 'vue';
import { useServiceStore } from 'src/stores/services';
import { storeToRefs } from 'pinia';
import { healthExecutionStatusToBarColorMap } from './serviceStatusConfiguration';

export default {
  props: {
    serviceId: { type: String, required: true },
    serviceTitleAsLink: {
      type: Boolean,
      default: () => true
    },
    autoscroll: Boolean
  },
  setup() {
    const healthExecutionStatusToBarColor = ref(healthExecutionStatusToBarColorMap);

    let servicesUpdater = null;

    const serviceStore = useServiceStore();
    const {
      containerName,
      healthExecutionStatus,
      imageName,
      serviceRunningOrStarting
    } = storeToRefs(serviceStore);

    onMounted(async () => {
      await serviceStore.loadServiceNamesAndStatus();
      servicesUpdater = serviceStore.addUpdateServicesInterval(null, 1);
    });

    onUnmounted(() => {
      if(servicesUpdater)
        serviceStore.removeUpdateServicesInterval(servicesUpdater);
    });

    return {
      healthExecutionStatus, containerName, healthExecutionStatusToBarColor, imageName, serviceRunningOrStarting
    }
  }
}

</script>
