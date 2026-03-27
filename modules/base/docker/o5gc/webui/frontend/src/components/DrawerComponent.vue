@use "quasar/src/css/variables" as q;

<template>
  <q-scroll-area
    class="fit"
    visible
    :thumb-style="{ background: '#777', opacity: 1 }"
    :bar-style="{ background: dark.isActive ? '#1D1D1D' : '#ffffff', opacity: 1 }"
  >
    <img src="~assets/logo.png" style="max-width: 70%; margin-left: auto; margin-right: auto; margin-top: 10px; display: block;" />
    <q-list>
      <q-item-label header class="text-bold text-h3" style="text-align: center; padding-top: 0px !important; font-family: SourceSans3;">
        {{ title }}
      </q-item-label>

      <q-item clickable to="/serviceOverview">
        <q-item-section avatar>
          <q-icon name="monitor_heart" />
        </q-item-section>
        <q-item-section>
          <q-item-label>Service Overview</q-item-label>
        </q-item-section>
        <q-item-section side>
          <q-item-label><q-chip dense :class="serviceOverviewBackgroundColor" style="color: white;">{{ runningVisibleServiceNames.length }} running</q-chip></q-item-label>
        </q-item-section>
      </q-item>

      <q-separator />

      <q-expansion-item icon="layers" label="Stacks" default-opened>
        <q-list>
          <!-- Favourites Section -->
          <q-expansion-item v-if="stackLinks.favourites.length > 0"  label="&nbsp;&nbsp;&nbsp;Favourites" dense default-opened>
            <q-list>
              <DrawerStackItem v-for="(link, i) in stackLinks.favourites" :key="i" :link="link" :is-fav="true" padding-left="2.5em" />
            </q-list>
          </q-expansion-item>

          <!-- Modules Section (Grouped Non-Favourites) -->
          <div v-for="(moduleData, moduleName) in stackLinks.modules" :key="moduleName">
            <q-expansion-item
              :label="`&nbsp;&nbsp;&nbsp;${moduleName}`"
              dense
              :default-opened="Object.keys(stackLinks.modules).length === 1 || moduleData.allLinks.some(link => $route.path == link.to)"
            >
              <q-list v-if="!moduleData.isGrouped">
                <DrawerStackItem v-for="(link, i) in moduleData.items" :key="i" :link="link" :is-fav="false" padding-left="2.5em" />
              </q-list>
              <q-list v-else>
                <q-expansion-item
                  v-for="(groupLinks, groupName) in moduleData.items"
                  :key="groupName"
                  :label="`&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;${groupName}`"
                  dense
                  :default-opened="groupLinks.some(link => $route.path == link.to)"
                >
                  <q-list>
                    <DrawerStackItem v-for="(link, i) in groupLinks" :key="i" :link="link" :is-fav="false" padding-left="3em" />
                  </q-list>
                </q-expansion-item>
              </q-list>
            </q-expansion-item>
          </div>
        </q-list>
      </q-expansion-item>

      <q-separator />

      <q-item clickable to="/simWriter">
        <q-item-section avatar>
          <q-icon name="sim_card_download" />
        </q-item-section>
        <q-item-section>
          <q-item-label>SIM Writer</q-item-label>
        </q-item-section>
      </q-item>

      <q-separator />

      <q-expansion-item icon="open_in_browser" label="Service Links" default-closed>
        <q-list>
          <q-item v-for="(url, label) in externalLinksFromLabels" :key="label" :href="url" style="text-decoration: none; padding-left: 2em;" target="_blank" dense>
            <q-item-section>
              <q-item-label>{{ label }}</q-item-label>
            </q-item-section>
          </q-item>
          <q-item href="/doc/" style="text-decoration: none; padding-left: 2em;" target="_blank" dense>
            <q-item-section>
              <q-item-label>open5Gcube Documentation</q-item-label>
            </q-item-section>
          </q-item>
        </q-list>
      </q-expansion-item>

      <q-separator />

      <q-item clickable @click="settingsDialog = true">
        <q-item-section avatar>
          <q-icon name="settings" />
        </q-item-section>
        <q-item-section>
          <q-item-label>Settings</q-item-label>
        </q-item-section>
      </q-item>

    </q-list>
    <q-space />
  </q-scroll-area>
  <q-dialog v-model="settingsDialog">
    <SettingsComponent />
  </q-dialog>
</template>

<script>
import { onMounted, onUnmounted, ref } from 'vue';
import { useQuasar } from 'quasar';
import { useServiceStore } from 'src/stores/services';
import { storeToRefs } from 'pinia';
import { useStackStore } from 'src/stores/stacks';
import SettingsComponent from './SettingsComponent.vue';
import DrawerStackItem from './DrawerStackItem.vue';

export default {
  components: {
    SettingsComponent,
    DrawerStackItem
  },
  setup() {
    const $q = useQuasar();
    const dark = $q.dark;

    const serviceStore = useServiceStore();
    const { runningVisibleServiceNames, healthStatusForAllServices, externalLinksFromLabels } = storeToRefs(serviceStore);

    const stackStore = useStackStore();
    const { favouriteStackNames, nonFavouriteStackNames, stacks } = storeToRefs(stackStore);

    const settingsDialog = ref(false);
    const title = process.env.TITLE;
    let updater = null;

    onMounted(async () => {
      await stackStore.loadStackNames();
      await serviceStore.loadServiceNamesAndStatus();

      updater = serviceStore.addUpdateServicesInterval(null, 2);
    });

    onUnmounted(() => {
        if(updater)
          serviceStore.removeUpdateServicesInterval(updater);
    });

    return {
      dark,
      runningVisibleServiceNames,
      healthStatusForAllServices,
      externalLinksFromLabels,
      settingsDialog,
      title,
      favouriteStackNames,
      nonFavouriteStackNames,
      stacks
    }
  },
  computed: {
    stackLinks() {
      const createLink = (name) => ({
        label: name,
        value: '',
        icon: 'cell_tower',
        to: `/stack/${name}`
      });
      const groupedModules = {};

      this.nonFavouriteStackNames.forEach((name) => {
        const moduleName = this.stacks[name].module;
        if (!groupedModules[moduleName]) {
          groupedModules[moduleName] = [];
        }
        groupedModules[moduleName].push(createLink(name));
      });

      const sortedModules = {};
      Object.keys(groupedModules).sort().forEach(key => {
        const links = groupedModules[key];
        let isGrouped = false;
        let items = links;

        if (links.length > 10) {
          const initialSubGroups = {};

          links.forEach(link => {
            const firstWord = link.label.split('-')[0];
            if (!initialSubGroups[firstWord]) {
              initialSubGroups[firstWord] = [];
            }
            initialSubGroups[firstWord].push(link);
          });

          const finalSubGroups = {};
          const others = [];

          // Separate out groups with only a single item
          Object.keys(initialSubGroups).forEach(subKey => {
            if (initialSubGroups[subKey].length === 1) {
              others.push(initialSubGroups[subKey][0]);
            } else {
              finalSubGroups[subKey] = initialSubGroups[subKey];
            }
          });

          // Move the singles to "Others"
          if (others.length > 0) {
            if (finalSubGroups['Others']) {
              finalSubGroups['Others'].push(...others);
            } else {
              finalSubGroups['Others'] = others;
            }
          }

          // Verify if at least two groups are present
          if (Object.keys(finalSubGroups).length >= 2) {
            isGrouped = true;
            const sortedSubGroups = {};

            Object.keys(finalSubGroups)
              .filter(k => k !== 'Others')
              .sort()
              .forEach(subKey => {
                sortedSubGroups[subKey] = finalSubGroups[subKey];
              });

            if (finalSubGroups['Others']) {
              sortedSubGroups['Others'] = finalSubGroups['Others'].sort((a, b) => a.label.localeCompare(b.label));
            }

            items = sortedSubGroups;
          }
        }

        sortedModules[key] = {
          isGrouped,
          items,
          allLinks: links
        };
      });

      return {
        favourites: this.favouriteStackNames.map(createLink),
        modules: sortedModules,
      }
    },
    serviceOverviewBackgroundColor() {
      const hs = this.healthStatusForAllServices();
      if(hs == 'healthy') return 'bg-positive';
      else if(hs == 'unhealthy') return 'bg-negative';
      else return 'bg-primary';
    }
  }
}
</script>
