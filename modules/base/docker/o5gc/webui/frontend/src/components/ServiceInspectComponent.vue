<template>
  <div class="column col">
    <ServiceTitleBarComponent :service-id="serviceId" :service-title-as-link="false" :autoscroll="false" :loading-history-indicator="false" />
    <q-card flat bordered class="column col">
      <q-input ref="filterRef" v-model="filter" filled label="Filter" class="col-auto">
        <template #append>
          <q-icon v-if="filter !== ''" name="clear" class="cursor-pointer" @click="resetFilter" />
        </template>
      </q-input>
      <!-- no-transition disables animations for tree. Since tree is regularly updated, transitions might affect performance a lot! -->
      <q-scroll-area class="col">
        <q-tree ref="treeRef" :nodes="serviceInspectTree" node-key="label" :filter="filter" no-transition>
          <template #header-keyvalue="prop"><b>{{ prop.node.key }}:&nbsp;</b>{{ prop.node.value }}</template>
          <template #header-key="prop"><b>{{ prop.node.key }}</b></template>
        </q-tree>
      </q-scroll-area>
    </q-card>
  </div>
</template>

<script>
import { onUnmounted, onMounted, ref } from 'vue';
import { useServiceStore } from 'src/stores/services';
import { storeToRefs } from 'pinia';
import ServiceTitleBarComponent from './ServiceTitleBarComponent.vue';

export default {
  components: { ServiceTitleBarComponent },
  props: {
    serviceId: { type: String, required: true }
  },
  setup() {

    const filter = ref('');
    const filterRef = ref(null);
    const treeRef = ref(null);

    const serviceStore = useServiceStore();
    const { services } = storeToRefs(serviceStore);

    let updater = null;

    onMounted(() => {
      serviceStore.loadServiceNamesAndStatus();

      updater = setInterval(async () => {
        serviceStore.loadServiceNamesAndStatus();
      }, 2000);
    });

    onUnmounted(() => {
      clearInterval(updater);
    });

    function resetFilter() {
      filter.value = ''
      filterRef.value.focus()
    }

    return { services, filter, filterRef, treeRef, resetFilter };
  },
  computed: {
    serviceInspectTree() {
      const convertToQuasarTree = (data, label='') => {
        return Object.entries(data).map(([key, value]) => {
          if (Array.isArray(value)) {
            return {
              label: `${label} ${key}`,
              header: 'key',
              key: `${key}`,
              children: convertToQuasarTree(value, `${label} ${key}`)
            };
          } else if (typeof value === 'object' && value != null) {
            return {
              label: `${label} ${key}`,
              header: 'key',
              key: `${key}`,
              children: convertToQuasarTree(value, `${label} ${key}`)
            };
          } else {
            return {
              label: `${label} ${key}: ${value}`,
              header: 'keyvalue',
              key: `${key}`,
              value: `${value}`
            };
          }
        });
      }
      if(!(this.serviceId in this.services) || (typeof this.services[this.serviceId].status != 'object')) return convertToQuasarTree({});

      return convertToQuasarTree(this.services[this.serviceId].status);
    }
  },
  watch: {
    filter(value) {
      if(value.length > 0 && this.treeRef) {
        this.treeRef.expandAll();
      }
    }
  }
}

</script>
