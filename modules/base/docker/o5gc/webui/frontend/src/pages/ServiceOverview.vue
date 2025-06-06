<template>
    <q-page class="column bg-image">
      <div class="row">
        <div class="col-xs-12 col-md-6 col-lg-6 column" v-for="serviceId in visibleServiceIdsSortedByHealthExecutionStatusAndPriorityLabel" style="height: 250px;" :key="serviceId">
            <ServiceLogComponent :serviceId="serviceId" :serviceTitleAsLink="true" :statusLine="false" :key="`${$route.params.serviceId}-mini`" class="q-pa-xs" />
        </div>
      </div>
  </q-page>
</template>

<script>
import { onMounted, onUnmounted, ref, nextTick } from 'vue';
import ServiceLogComponent from 'src/components/ServiceLogComponent.vue'
import { useServiceStore } from 'src/stores/services';
import { storeToRefs } from 'pinia';
import { _ } from 'lodash';

export default {
    setup(_props, context) {
        const serviceStore = useServiceStore();
        const { services, visibleServiceIdsSortedByHealthExecutionStatusAndPriorityLabel, visibleServiceDetailsSortedByHealthExecutionStatusAndPriorityLabel } = storeToRefs(serviceStore);

        const tabs = ref([]);

        let updater = null;

        function updateTabs() {
          const new_tabs = visibleServiceDetailsSortedByHealthExecutionStatusAndPriorityLabel.value.map(service => ({
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
            updateTabs();

            nextTick(() => {
                context.emit('tabs', tabs.value);
            });

            updater = serviceStore.addUpdateServicesInterval(() => {
                updateTabs();
            }, 1);
        });

        onUnmounted(() => {
          if(updater)
            serviceStore.removeUpdateServicesInterval(updater);
        });

        return {
            services, visibleServiceIdsSortedByHealthExecutionStatusAndPriorityLabel, visibleServiceDetailsSortedByHealthExecutionStatusAndPriorityLabel, serviceStore
        };
    },
    created() {
        this.$emit('toolbarTitleContent', 'Service Overview');
    },
    components: { ServiceLogComponent }
}

</script>
