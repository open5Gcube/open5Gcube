<template>
  <div class="column col">
    <ServiceTitleBarComponent :serviceId="serviceId" :serviceTitleAsLink="serviceTitleAsLink" :autoscroll="autoscroll" />
    <q-card flat bordered square class="column col">
      <q-scroll-area visible="visible" @scroll="onScroll" ref="scrollArea" :bar-style="autoscroll ? {background: getCssVar('info')} : {}" class="col bg-grey-10 text-white">
        <div>
          <div v-for="(logLine, lineIndex) in log" :key="lineIndex" style="font-family: monospace; margin-left: 1.5em; text-indent: -1em; margin-top: 0.5em; margin-bottom: 0.5em; margin-right: 0.5em; line-height: 1.0; white-space: pre-wrap; word-break: break-word">
            <span v-for="(logSpan, spanIndex) in logLine.spans" :key="spanIndex" :style="logSpan.css">
              {{ logSpan.text }}
            </span>
          </div>
        </div>
      </q-scroll-area>
    </q-card>
    <q-bar v-if="statusLine" class="bg-grey text-black col-auto row q-ma-none" style="line-height: 1.2; flex-wrap: wrap !important;">
      <div class="col-auto q-mx-sm"><q-icon :name="symOutlinedDeployedCode" style="font-weight: bold; font-size: 20px;"><q-tooltip>Image</q-tooltip></q-icon> {{ imageName(serviceId) }}</div>
      <q-separator vertical color="black" />
      <div class="col-auto q-mx-sm"><q-icon name="commit" style="font-weight: bold; font-size: 20px;"><q-tooltip>Version</q-tooltip></q-icon> {{ labelValue(serviceId, 'org.opencontainers.image.version') }}</div>
      <q-separator vertical color="black" />
      <div class="col-auto q-mx-sm"><q-icon :name="symOutlinedUnarchive" style="font-weight: bold; font-size: 20px;"><q-tooltip>Created</q-tooltip></q-icon> {{ createdDate(serviceId) == null ? '-' : createdDate(serviceId).toLocaleString('de-DE') || '' }}</div>
      <q-separator vertical color="black" />
      <div class="col-auto q-mx-sm"><q-icon :name="symOutlinedPlayArrow" style="font-weight: bold; font-size: 20px;"><q-tooltip>Started</q-tooltip></q-icon> {{ startedDate(serviceId) == null ? '-' : startedDate(serviceId) == 'not started' ? 'not started' : startedDate(serviceId).toLocaleString('de-DE') || '' }}</div>
      <q-separator vertical color="black" />
      <div class="col-auto row q-mx-sm">
        <q-icon :name="symOutlinedStop" style="font-weight: bold; font-size: 20px;">
          <q-tooltip>Finished</q-tooltip>
        </q-icon>
        <div>{{ finishedDate(serviceId) == null ? '-' : finishedDate(serviceId) == 'not finished' ? 'not finished' : `${finishedDate(serviceId).toLocaleString('de-DE')}` || '' }}</div>&nbsp;
        <q-badge v-if="finishedDate(serviceId) != null && finishedDate(serviceId) != 'not finished'" :class="exitCode(serviceId) > 0 ? 'bg-negative' : 'bg-positive'" style="font-weight: bold;">{{ exitCode(serviceId) }}</q-badge>
      </div>
      <q-separator vertical color="black" />
      <div class="col-auto row"><q-icon :name="symOutlinedLan" style="font-weight: bold; font-size: 20px;"><q-tooltip>IP Addresses</q-tooltip></q-icon> <div v-for="(ipAddress, networkName, i) in ipv4Addresses(serviceId) || {}" :key="networkName" class="col-auto"> {{ ipAddress || "-" }} ({{ networkName }}){{(i < Object.keys(ipv4Addresses(serviceId)).length-1) ? '&nbsp;|&nbsp;': ''}}</div> </div>
    </q-bar>
  </div>
</template>

<script>
import { onUnmounted, onMounted, ref } from 'vue';
import { useServiceStore } from 'src/stores/services';
import { storeToRefs } from 'pinia';
import { getCssVar } from 'quasar';
import { symOutlinedDeployedCode, symOutlinedUnarchive, symOutlinedLan, symOutlinedPlayArrow, symOutlinedStop } from '@quasar/extras/material-symbols-outlined'
import ServiceTitleBarComponent from './ServiceTitleBarComponent.vue';

export default {
  props: {
    serviceId: String,
    serviceTitleAsLink: {
      type: Boolean,
      default: () => true
    },
    statusLine: Boolean
  },
  setup(props) {
    const log = ref([]);
    const scrollArea = ref(null);
    const autoscroll = ref(true);
    const updating = ref(false);

    // Once a service stops, we need to update the log once more to get the final log content.
    // This ref indicates whether this update has already been done.
    const lastUpdateForStoppedServiceDone = ref(false);

    const serviceStore = useServiceStore();
    const {
      logForService,
      imageName,
      labelValue,
      createdDate,
      startedDate,
      finishedDate,
      exitCode,
      ipv4Addresses,
      serviceRunningOrStarting
    } = storeToRefs(serviceStore);

    let servicesUpdater = null;
    let updater = null;
    let scrollInfoBefore = null;
    let syncInProgress = false;

    onMounted(async () => {
      await serviceStore.loadServiceNamesAndStatus();
      servicesUpdater = serviceStore.addUpdateServicesInterval(null, 1);

      log.value = serviceStore.logForService(props.serviceId, true, true);
      autoscroll.value = true;

      updater = setInterval(async () => {

        // Check whether the service is stopped and the last update after stopping was already done. In this case skip update.
        const serviceStopped = !serviceRunningOrStarting.value(props.serviceId);
        if(serviceStopped && lastUpdateForStoppedServiceDone.value) return;

        // In case of an overload, if an earlier update is still in queue, skip this one.
        // With a certain number of containers this case is realistic, e.g. if a request takes ~50ms, starting from ~20 containers.
        if(updating.value) return;
        updating.value = true;

        // Only update if autoscroll is on. This way users can scroll in the history without log lines jumping around.
        if(!autoscroll.value) return;

        // The actual update
        await serviceStore.loadServiceLog(props.serviceId);
        syncInProgress = true;
        log.value = serviceStore.logForService(props.serviceId, true, true);

        // If service is stopped, indicate that update is done. If service is running, last update is not done (still needs to be done once stopped).
        lastUpdateForStoppedServiceDone.value = serviceStopped;

        // Indicate that we are not updating anymore so next update can start.
        updating.value = false;
      }, 1000);
    });

    onUnmounted(() => {
      if(servicesUpdater)
        serviceStore.removeUpdateServicesInterval(servicesUpdater);
      clearInterval(updater);
    });

    function onScroll(info) {
      // Set initial scrollInfo
      if(!scrollInfoBefore) scrollInfoBefore = info;

      // Check whether user scrolled all the way to the bottom and in this case activate autoscroll
      // Exclude cases where "scroll" was triggered from an update of the content or container size
      if (scrollInfoBefore.verticalSize == info.verticalSize && scrollInfoBefore.verticalContainerSize == info.verticalContainerSize && !syncInProgress) {
        autoscroll.value = (Math.ceil(info.verticalPosition+info.verticalContainerSize) >= info.verticalSize) || (info.verticalSize <= info.verticalContainerSize);
      }

      // Perform autoscroll if it is enabled
      if(autoscroll.value) {
        scrollArea.value.setScrollPosition('vertical', info.verticalSize-info.verticalContainerSize, 0);
      }

      if(syncInProgress) syncInProgress = false;

      scrollInfoBefore = info;
    }

    return {
      onScroll, serviceStore, logForService, log, scrollArea, autoscroll, getCssVar,
      symOutlinedDeployedCode, symOutlinedUnarchive, symOutlinedLan, symOutlinedPlayArrow, symOutlinedStop,
      imageName,
      labelValue,
      createdDate,
      startedDate,
      finishedDate,
      exitCode,
      ipv4Addresses,
      serviceRunningOrStarting
    }
  },
  components: { ServiceTitleBarComponent }
}

</script>
