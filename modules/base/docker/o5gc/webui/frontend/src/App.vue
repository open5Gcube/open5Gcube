<template>
  <router-view />
</template>

<script lang="ts">
import { useSettingsStore } from 'src/stores/settings';

export default {
  setup() {
    const settingsStore = useSettingsStore();
    settingsStore.initDark();
  }
}

</script>
