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
          <q-expansion-item v-if="stackLinks.favourites.length > 0"  label="&nbsp;&nbsp;&nbsp;Favourites" dense default-opened>
            <q-list>
              <q-item clickable :active="$route.path == link.to" v-for="(link, i) in stackLinks.favourites" :key="i" @click="routeTo(link.to);">
                <q-item-section avatar>
                  <div class="icon-container" @click.stop="settingsStore.removeFavouriteStack(link.label);">
                    <q-icon :name="link.icon" size="md" class="default-icon" />
                    <q-icon name="star" size="md" class="hovered-icon" />
                  </div>
                </q-item-section>
                <q-item-section>
                  <q-item-label>{{ link.label }}</q-item-label>
                </q-item-section>
                <q-item-section side>
                  <q-item-label>{{ link.value }}</q-item-label>
                </q-item-section>
              </q-item>
            </q-list>
          </q-expansion-item>
          <q-expansion-item v-if="stackLinks.favourites.length > 0 && stackLinks.nonFavourites.length > 0" label="&nbsp;&nbsp;&nbsp;Others" dense default-opened>
            <q-list>
              <q-item clickable :active="$route.path == link.to" v-for="(link, i) in stackLinks.nonFavourites" :key="i" @click="routeTo(link.to);">
                <q-item-section avatar>
                  <div class="icon-container" @click.stop="settingsStore.addFavouriteStack(link.label);">
                    <q-icon :name="link.icon" size="md" class="default-icon" />
                    <q-icon :name="symOutlinedStar" size="md" class="hovered-icon" />
                  </div>
                </q-item-section>
                <q-item-section>
                  <q-item-label>{{ link.label }}</q-item-label>
                </q-item-section>
                <q-item-section side>
                  <q-item-label>{{ link.value }}</q-item-label>
                </q-item-section>
              </q-item>
            </q-list>
          </q-expansion-item>
          <q-item v-else clickable :active="$route.path == link.to" v-for="(link, i) in stackLinks.nonFavourites" :key="i" @click="routeTo(link.to);">
            <q-item-section avatar>
              <div class="icon-container" @click.stop="settingsStore.addFavouriteStack(link.label);">
                <q-icon :name="link.icon" size="md" class="default-icon" />
                <q-icon :name="symOutlinedStar" size="md" class="hovered-icon" />
              </div>
            </q-item-section>
            <q-item-section>
              <q-item-label>{{ link.label }}</q-item-label>
            </q-item-section>
            <q-item-section side>
              <q-item-label>{{ link.value }}</q-item-label>
            </q-item-section>
          </q-item>
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
    const { favouriteStackNames, nonFavouriteStackNames } = storeToRefs(stackStore);

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
      externalLinksFromLabels,
      toggleDark,
      settingsDialog,
      symOutlinedStar,
      title
    }
  },
  computed: {
    stackLinks() {
      return {
        favourites: this.favouriteStackNames.map((name) => ({
          label: name,
          value: '',
          icon: 'cell_tower',
          to: `/stack/${name}`
        })),
        nonFavourites: this.nonFavouriteStackNames.map((name) => ({
          label: name,
          value: '',
          icon: 'cell_tower',
          to: `/stack/${name}`
        })),
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
.icon-container {
  position: relative;
  display: inline-block;
}

.default-icon {
  display: block;
}

.hovered-icon {
  display: none;
}

.icon-container:hover .hovered-icon {
  display: block;
}

.icon-container:hover .default-icon {
  display: none;
}
</style>
