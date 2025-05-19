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
          <div class="col-xs-12 col-md-4 column q-pr-xs q-py-xs">
            <Suspense>
              <EnvComponent envType="global" :stackName="$route.params.stackName" />
            </Suspense>
          </div>
          <div class="col-xs-12 col-md-4 column q-px-xs q-py-xs">
            <Suspense>
              <EnvComponent envType="stack" :stackName="$route.params.stackName" />
            </Suspense>
          </div>
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

import { ref } from 'vue'

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

    return {
      mainSplitterPercentage
    };
  },
  created() {
    this.$emit('tabs', [])
    this.$emit('toolbarTitleContent', 'STACK: ' + this.$route.params.stackName)

    this.$watch(
      () => this.$route.params,
      (toParams, _previousParams) => {
        this.$emit('toolbarTitleContent', 'STACK: ' + toParams.stackName)
      }
    )
  }
}

</script>
