<template>
    <q-page class="full-height column">
      <div class="column col q-pa-md">
        <q-tabs
          v-model="tab"
          dense
          class="col-auto bg-primary text-white"
          active-color="white"
          indicator-color="white"
          align="center"
        >
          <q-tab name="logs" label="Logs" />
          <q-tab name="inspect" label="Inspect" />
        </q-tabs>

        <q-tab-panels v-model="tab" class="column col">
          <q-tab-panel name="logs" class="column col q-pa-none">
            <ServiceLogComponent :key="`${$route.params.serviceId}-detail`" :service-id="$route.params.serviceId" :service-title-as-link="false" :status-line="true" class="column col" />
          </q-tab-panel>

          <q-tab-panel name="inspect" class="column col q-pa-none">
            <ServiceInspectComponent :service-id="$route.params.serviceId" class="column col" />
          </q-tab-panel>
        </q-tab-panels>
      </div>
  </q-page>
</template>

<script>
import { onMounted, onUnmounted, ref, nextTick } from 'vue';
import ServiceLogComponent from 'src/components/ServiceLogComponent.vue';
import ServiceInspectComponent from 'src/components/ServiceInspectComponent.vue';
import { useServiceStore } from 'src/stores/services';
import { useStackStore } from 'src/stores/stacks';
import { storeToRefs } from 'pinia';
import { _ } from 'lodash';
import { useRoute } from 'vue-router';

export default {
  components: {
    ServiceLogComponent, ServiceInspectComponent
  },
  emits: ['tabs', 'toolbar-title-content'],
  setup(_props, context) {
    const route = useRoute();

    const tab = ref('logs');

    const serviceStore = useServiceStore();
    const stackStore = useStackStore();
    const { services, visibleServiceDetailsSorted } = storeToRefs(serviceStore);

    const tabs = ref([]);
    const inspect = ref('inspect');

    let updater = null;

    function updateTabs() {
      const new_tabs = visibleServiceDetailsSorted.value.map(service => ({
        label: service.containerName,
        to: `/service/${service.containerId}`
      }));
      if(!_.isEqual(new_tabs, tabs.value)) {
        tabs.value = new_tabs;
        context.emit('tabs', tabs.value);
      }
    }

    onMounted(async () => {
      await serviceStore.loadServiceNamesAndStatus();
      await stackStore.loadRunningStacks();
      updateTabs();
      context.emit('toolbar-title-content', 'Service: ' + services.value[route.params.serviceId].containerName);

      nextTick(() => {
        context.emit('tabs', tabs.value);
      });

      updater = serviceStore.addUpdateServicesInterval(() => {
        updateTabs();
        stackStore.loadRunningStacks();
      }, 1);
    });

    onUnmounted(() => {
      if(updater)
        serviceStore.removeUpdateServicesInterval(updater);
    });

    return {
      tab,
      services,
      inspect,
      serviceStore
    };
  },
  created() {
    this.$emit('tabs', [])

    this.$watch(
      () => this.$route.params,
      (toParams) => {
        // this watcher is unnecessarily called one more time when the page is unmounted
        // however this is the officially recommended way to check for param changes
        // see https://router.vuejs.org/guide/essentials/dynamic-matching.html#Reacting-to-Params-Changes
        // hence check whether the params apply to this component
        if('serviceId' in toParams) {
          this.$emit('toolbar-title-content', 'Service: ' + this.services[toParams.serviceId].containerName)
        }
      }
    )
  },
}

</script>
