@use "quasar/src/css/variables" as q;

<template>
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

      <q-expansion-item label="Stacks" dense default-opened>
        <q-list>
          <!-- Favourites Section -->
          <q-expansion-item v-if="stackLinks.favourites.length > 0"  label="&nbsp;&nbsp;&nbsp;Favourites" dense default-opened>
            <q-list>
              <q-item clickable :active="$route.path == link.to" v-for="(link, i) in stackLinks.favourites" :key="i" @click="routeTo(link.to);" style="padding-left: 36px;">
                <q-item-section>
                  <q-item-label>{{ link.label }}</q-item-label>
                </q-item-section>
                <q-item-section side>
                  <div class="row no-wrap">
                    <q-btn flat dense round icon="play_arrow" size="sm" :loading="stacks[link.label]?.starting" @click.stop.prevent="startStack(link.label)">
                        <q-tooltip>Start Stack</q-tooltip>
                    </q-btn>
                    <q-btn flat dense round icon="stop" size="sm" :loading="stacks[link.label]?.stopping" @click.stop.prevent="stopStack(link.label)">
                        <q-tooltip>Stop Stack</q-tooltip>
                    </q-btn>
                    <q-btn flat dense round color="grey" size="sm" class="star-swap-btn" @click.stop.prevent="settingsStore.removeFavouriteStack(link.label)">
                        <q-icon name="star" class="icon-normal" />
                        <q-icon :name="symOutlinedStar" class="icon-hover" />
                        <q-tooltip>Remove from Favourites</q-tooltip>
                     </q-btn>
                  </div>
                </q-item-section>
              </q-item>
            </q-list>
          </q-expansion-item>
          <!-- Modules Section (Grouped Non-Favourites) -->
          <div v-for="(links, moduleName) in stackLinks.modules" :key="moduleName">
            <q-expansion-item
              :label="`&nbsp;&nbsp;&nbsp;${moduleName}`"
              dense
              :default-opened="Object.keys(stackLinks.modules).length === 1 || links.some(link => $route.path == link.to)"
            >
              <q-list>
                <q-item clickable :active="$route.path == link.to" v-for="(link, i) in links" :key="i" @click="routeTo(link.to);" style="padding-left: 36px;">
                  <q-item-section>
                    <q-item-label>{{ link.label }}</q-item-label>
                  </q-item-section>
                  <q-item-section side>
                    <div class="row no-wrap">
                      <q-btn flat dense round icon="play_arrow" size="sm" :loading="stacks[link.label]?.starting" @click.stop.prevent="startStack(link.label)">
                          <q-tooltip>Start Stack</q-tooltip>
                      </q-btn>
                      <q-btn flat dense round icon="stop" size="sm" :loading="stacks[link.label]?.stopping" @click.stop.prevent="stopStack(link.label)">
                          <q-tooltip>Stop Stack</q-tooltip>
                      </q-btn>
                      <q-btn flat dense round color="grey" size="sm" class="star-swap-btn non-fav" @click.stop.prevent="settingsStore.addFavouriteStack(link.label)">
                          <q-icon :name="symOutlinedStar" class="icon-normal" />
                          <q-icon name="star" class="icon-hover" />
                          <q-tooltip>Add to Favourites</q-tooltip>
                       </q-btn>
                    </div>
                  </q-item-section>
                </q-item>
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

      <q-expansion-item label="Service Links" dense default-closed>
        <q-list>
          <q-item v-for="(url, title) in externalLinksFromLabels" :key="title" :href="url" style="text-decoration: none" target="_blank">
            <q-item-section avatar>
              <q-icon name="open_in_browser" />
            </q-item-section>
            <q-item-section>
              <q-item-label>{{ title }}</q-item-label>
            </q-item-section>
          </q-item>
          <q-separator inset="item" />
          <q-item href="/doc/" style="text-decoration: none" target="_blank">
            <q-item-section avatar>
              <q-icon name="open_in_browser" />
            </q-item-section>
            <q-item-section>
              <q-item-label>Documentation</q-item-label>
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
    <q-dialog v-model="settingsDialog">
      <SettingsComponent />
    </q-dialog>
</template>

<script>
import { onMounted, onUnmounted, ref } from 'vue';
import { useQuasar, getCssVar } from 'quasar';
import { useServiceStore } from 'src/stores/services';
import { storeToRefs } from 'pinia';
import { symOutlinedStar } from '@quasar/extras/material-symbols-outlined';
import { useStackStore } from 'src/stores/stacks';
import { useSettingsStore } from 'src/stores/settings';
import SettingsComponent from './SettingsComponent.vue';

export default {
  setup() {
    const $q = useQuasar();
    const dark = $q.dark;

    const serviceStore = useServiceStore();
    const { serviceNames, healthStatusForAllServices, externalLinksFromLabels, runningVisibleServiceNames } = storeToRefs(serviceStore);

    const stackStore = useStackStore();
    const { favouriteStackNames, nonFavouriteStackNames, stacks } = storeToRefs(stackStore);
    const { startStack, stopStack } = stackStore;

    const settingsStore = useSettingsStore();
    const { toggleDark } = settingsStore;

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
      serviceNames,
      runningVisibleServiceNames,
      healthStatusForAllServices,
      getCssVar,
      serviceStore,
      settingsStore,
      favouriteStackNames,
      nonFavouriteStackNames,
      stacks,
      startStack,
      stopStack,
      externalLinksFromLabels,
      toggleDark,
      settingsDialog,
      symOutlinedStar,
      title
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
        sortedModules[key] = groupedModules[key];
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
  },
  methods: {
    routeTo(to) {
        this.$router.push(to);
    }
  },
  components: {
    SettingsComponent
  },
}

</script>

<style scoped>
.star-swap-btn .icon-hover {
  display: none;
}
.star-swap-btn:hover .icon-normal {
  display: none;
}
.star-swap-btn:hover .icon-hover {
  display: block;
}
</style>
