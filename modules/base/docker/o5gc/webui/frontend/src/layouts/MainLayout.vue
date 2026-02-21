<template>
  <q-layout view="lhh Lpr lFr" class="full-height">

    <q-header reveal elevated class="bg-primary text-white" height-hint="98">
      <q-toolbar>
        <q-btn dense flat round icon="menu" @click="toggleLeftDrawer" />

        <q-toolbar-title>
          <!---<q-icon name="view_in_ar" class="text-h4" />-->
          {{ toolbarTitleContent }}
        </q-toolbar-title>
      </q-toolbar>

      <q-tabs align="left" v-if="tabs.length > 0">
        <q-route-tab v-for="tab in tabs" :key="tab.label" :to="tab.to" :label="tab.label" />
      </q-tabs>
    </q-header>

    <q-drawer show-if-above v-model="leftDrawerOpen" side="left" elevated>
      <DrawerComponent/>
    </q-drawer>

    <q-page-container style="height: 100%;">
      <router-view
        @tabs="(_tabs) => tabs = _tabs"
        @toolbarTitleContent="(_toolbarTitleContent) => toolbarTitleContent = _toolbarTitleContent"
      />
    </q-page-container>

  </q-layout>
</template>

<script>
import { ref } from 'vue'
import DrawerComponent from 'components/DrawerComponent.vue'

export default {

  components: {
    DrawerComponent
  },

  setup () {
    const leftDrawerOpen = ref(false)
    const tabs = ref([]) // [{'label': 'TAB1', 'to': '/page1'}]
    const toolbarTitleContent = ref('open5Gcube')

    return {
      leftDrawerOpen,
      tabs,
      toolbarTitleContent,
      toggleLeftDrawer () {
        leftDrawerOpen.value = !leftDrawerOpen.value
      }
    }
  }
}
</script>
