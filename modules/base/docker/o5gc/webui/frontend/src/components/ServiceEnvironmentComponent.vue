<!--
  Environment tab of the service detail view. The list is long for a stack service - the
  whole settings.env ends up in it - so it is filtered, the same way the Inspect tab is.
-->
<template>
  <div class="column col">
    <ServiceTitleBarComponent :service-id="serviceId" :service-title-as-link="false" :autoscroll="false" />
    <q-card flat bordered square class="column col">
      <q-input ref="filterRef" v-model="filter" filled label="Filter" class="col-auto">
        <template #append>
          <q-icon v-if="filter !== ''" name="clear" class="cursor-pointer" @click="resetFilter" />
        </template>
      </q-input>

      <q-scroll-area class="col">
        <div
          v-for="(variable, index) in filteredEnvironment"
          :key="variable.name"
          class="row items-baseline q-px-sm q-py-xs"
          :class="index % 2 === 0 ? 'bg-grey-10' : ''"
          style="font-family: monospace; word-break: break-all;"
        >
          <span class="col-auto text-grey-5 q-mr-sm">{{ variable.name }}&nbsp;=</span>
          <span class="col">{{ variable.value }}</span>
        </div>
        <div v-if="filteredEnvironment.length === 0" class="q-pa-sm text-grey-5">{{ emptyMessage }}</div>
      </q-scroll-area>

      <q-bar class="bg-grey text-black col-auto q-ma-none" style="line-height: 1.2;">
        <div class="text-caption">
          {{ environmentSorted.length }} variable{{ environmentSorted.length === 1 ? '' : 's' }}
          <template v-if="filter !== ''">&mdash; {{ filteredEnvironment.length }} shown</template>
        </div>
      </q-bar>
    </q-card>
  </div>
</template>

<script>
import { onMounted, ref, watch } from 'vue';
import { useServiceStore } from 'src/stores/services';
import { storeToRefs } from 'pinia';
import ServiceTitleBarComponent from './ServiceTitleBarComponent.vue';

export default {
  components: { ServiceTitleBarComponent },
  props: {
    serviceId: { type: String, required: true }
  },
  setup(props) {
    const filter = ref('');
    const filterRef = ref(null);

    const serviceStore = useServiceStore();
    const { environment } = storeToRefs(serviceStore);

    // No interval: the environment of a container is fixed for its lifetime
    onMounted(() => serviceStore.loadServiceNamesAndStatus());
    watch(() => props.serviceId, () => serviceStore.loadServiceNamesAndStatus());

    return {
      environment, filter, filterRef,
      resetFilter() {
        filter.value = '';
        filterRef.value.focus();
      }
    };
  },
  computed: {
    environmentSorted() {
      const variables = this.environment(this.serviceId) || [];
      return [...variables].sort((a, b) => a.name.localeCompare(b.name));
    },
    filteredEnvironment() {
      const filter = this.filter.toLowerCase();
      if(filter === '') return this.environmentSorted;

      // Values are matched too: looking up which service got a given IP address
      return this.environmentSorted.filter(variable =>
        variable.name.toLowerCase().includes(filter) || variable.value.toLowerCase().includes(filter)
      );
    },
    emptyMessage() {
      if(this.environment(this.serviceId) === null) return 'Reading the environment…';
      if(this.environmentSorted.length === 0) return 'This container has no environment variables.';
      return 'No variable matches the filter.';
    }
  }
}

</script>
