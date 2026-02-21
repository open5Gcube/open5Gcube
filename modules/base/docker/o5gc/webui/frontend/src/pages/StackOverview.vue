<template>
  <q-page class="column full-height">

    <q-splitter v-model="mainSplitterPercentage" reverse horizontal unit="px" style="min-height: 100%; height: 100%;" class="column">

      <template v-slot:before>
      <div class="column" style="min-height: 100%;">
        <div class="row col-auto q-pa-xs">
          <div class="col-12">
            <Suspense>
              <StackDescriptionComponent :stackName="$route.params.stackName" />
            </Suspense>
          </div>
        </div>
        <div class="row col q-mx-xs">
          <!-- Column 1: Global Env -->
          <div class="col-xs-12 col-md-4 column q-pr-xs q-py-xs">
            <Suspense>
              <EnvComponent envType="global" :stackName="$route.params.stackName" />
            </Suspense>
          </div>

          <!-- Column 2: Module Env (Top) and Stack Env (Bottom) -->
          <div class="col-xs-12 col-md-4 column q-px-xs q-py-xs">
            <!-- Because EnvComponent has class="col", placing two of them in a flex column makes them share height equally -->
            <Suspense>
              <EnvComponent
                envType="module"
                :moduleName="moduleName"
                class="q-mb-xs"
              />
            </Suspense>
            <Suspense>
              <EnvComponent
                envType="stack"
                :stackName="$route.params.stackName"
              />
            </Suspense>
          </div>

          <!-- Column 3: Overrides -->
          <div class="col-xs-12 col-md-4 column q-pl-xs q-py-xs">
            <Suspense>
              <template #default>
                <EnvOverridesComponent :stackName="$route.params.stackName" />
              </template>
            </Suspense>
          </div>
        </div>
        <div class="row col-auto">
          <div class="col q-pa-xs">
            <Suspense>
              <StackStartStopComponent :stackName="$route.params.stackName" :key="$route.params.stackName" />
            </Suspense>
          </div>
        </div>
      </div>
      </template>

      <template v-slot:separator>
        <q-avatar color="primary" text-color="white" size="40px" icon="drag_indicator" />
      </template>

      <template v-slot:after>
        <EventLogComponent />
      </template>

    </q-splitter>

  </q-page>
</template>
<script>
import StackDescriptionComponent from 'components/StackDescriptionComponent.vue'
import EnvOverridesComponent from 'src/components/EnvOverridesComponent.vue'
import EnvComponent from 'src/components/EnvComponent.vue'
import StackStartStopComponent from 'src/components/StackStartStopComponent.vue'
import EventLogComponent from 'src/components/EventLogComponent.vue'

import { ref, computed } from 'vue'
import { useStackStore } from 'src/stores/stacks'
import { useRoute } from 'vue-router'

export default {

  components: {
    StackDescriptionComponent,
    EnvComponent,
    EnvOverridesComponent,
    StackStartStopComponent,
    EventLogComponent
  },
  setup() {
    const mainSplitterPercentage = ref(226);
    const stackStore = useStackStore();
    const route = useRoute();

    const moduleName = computed(() => {
        const stackName = route.params.stackName;
        // Default to 'General' if stack not yet loaded or module undefined
        if (stackStore.stacks[stackName]) {
            return stackStore.stacks[stackName].module || 'General';
        }
        return 'General';
    });

    return {
      mainSplitterPercentage,
      moduleName
    };
  },
  created() {
    this.$emit('tabs', [])
    this.$emit('toolbarTitleContent', 'Stack: ' + this.$route.params.stackName)

    this.$watch(
      () => this.$route.params,
      (toParams, _previousParams) => {
        this.$emit('toolbarTitleContent', 'Stack: ' + toParams.stackName)
      }
    )
  }
}

</script>
