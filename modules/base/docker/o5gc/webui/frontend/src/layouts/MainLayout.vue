<template>
  <q-layout view="lhh Lpr lFr" class="full-height">

    <q-header reveal elevated class="bg-primary text-white" height-hint="98">
      <q-toolbar>
        <q-btn dense flat round icon="menu" @click="toggleLeftDrawer" />

        <q-toolbar-title>
          <!---<q-icon name="view_in_ar" class="text-h4" />-->
          {{ toolbarTitleContent }}
        </q-toolbar-title>
        <div v-if="$route.path.startsWith('/service')" class="row items-center">
          <span class="text-subtitle2 q-mr-sm">Running Stacks:</span>
          <div v-if="runningStacks && runningStacks.length > 0" class="row items-center q-gutter-x-sm">
            <q-chip
              v-for="stack in runningStacks"
              :key="stack"
              color="positive"
              text-color="white"
              dense
              clickable
              @click="$router.push(`/stack/${stack}`)"
            >
              {{ stack }}
            </q-chip>
            <!-- Layout Toggle Button -->
            <q-btn v-if="$route.path === '/serviceOverview'" flat round dense :icon="settingsStore.oneColumnLogLayout ? 'grid_view' : 'view_agenda'" class="q-ml-md" @click="settingsStore.oneColumnLogLayout = !settingsStore.oneColumnLogLayout">
              <q-tooltip>{{ settingsStore.oneColumnLogLayout ? 'Two Columns Layout' : 'One Column Layout' }}</q-tooltip>
            </q-btn>
          </div>
          <div v-else class="text-subtitle2 text-italic q-mr-sm">None</div>
        </div>
      </q-toolbar>

      <q-tabs v-if="tabs.length > 0" align="left">
        <q-route-tab v-for="tab in tabs" :key="tab.label" :to="tab.to" :label="tab.label" />
      </q-tabs>
    </q-header>

    <q-drawer v-model="leftDrawerOpen" show-if-above side="left" elevated>
      <DrawerComponent/>
    </q-drawer>

    <q-page-container style="height: 100%;">
      <router-view
        @tabs="tabs = $event"
        @toolbar-title-content="toolbarTitleContent = $event"
      />
    </q-page-container>

  </q-layout>
</template>

<script>
import { ref } from 'vue'
import DrawerComponent from 'components/DrawerComponent.vue'
import { useStackStore } from 'src/stores/stacks'
import { useSettingsStore } from 'src/stores/settings'
import { storeToRefs } from 'pinia'

export default {

  components: {
    DrawerComponent
  },

  setup () {
    const leftDrawerOpen = ref(false)
    const tabs = ref([])
    const toolbarTitleContent = ref('open5Gcube')
    const stackStore = useStackStore()
    const { runningStacks } = storeToRefs(stackStore)
    const settingsStore = useSettingsStore()

    return {
      leftDrawerOpen,
      tabs,
      toolbarTitleContent,
      runningStacks,
      settingsStore,
      toggleLeftDrawer () {
        leftDrawerOpen.value = !leftDrawerOpen.value
      }
    }
  }
}
</script>
