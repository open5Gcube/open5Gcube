<template>
  <q-item clickable :active="$route.path == link.to" :style="{ paddingLeft: paddingLeft }" dense @click="$router.push(link.to)">
    <q-item-section>
      <q-item-label>{{ link.label }}</q-item-label>
    </q-item-section>
    <q-item-section side>
      <div class="row no-wrap">
        <q-btn flat dense round icon="play_arrow" size="sm" :loading="stackStore.stacks[link.label]?.starting" @click.stop.prevent="stackStore.startStack(link.label)">
            <q-tooltip>Start Stack</q-tooltip>
        </q-btn>
        <q-btn flat dense round icon="stop" size="sm" :loading="stackStore.stacks[link.label]?.stopping" @click.stop.prevent="stackStore.stopStack(link.label)">
            <q-tooltip>Stop Stack</q-tooltip>
        </q-btn>
        <q-btn flat dense round color="grey" size="sm" class="star-swap-btn" @click.stop.prevent="toggleFavourite">
            <q-icon :name="isFav ? 'star' : symOutlinedStar" class="icon-normal" />
            <q-icon :name="isFav ? symOutlinedStar : 'star'" class="icon-hover" />
            <q-tooltip>{{ isFav ? 'Remove from Favourites' : 'Add to Favourites' }}</q-tooltip>
          </q-btn>
      </div>
    </q-item-section>
  </q-item>
</template>

<script>
import { symOutlinedStar } from '@quasar/extras/material-symbols-outlined';
import { useStackStore } from 'src/stores/stacks';
import { useSettingsStore } from 'src/stores/settings';

export default {
  name: 'DrawerStackItem',
  props: {
    link: { type: Object, required: true },
    isFav: { type: Boolean, default: false },
    paddingLeft: { type: String, default: '36px' }
  },
  setup(props) {
    const stackStore = useStackStore();
    const settingsStore = useSettingsStore();

    const toggleFavourite = () => {
      if (props.isFav) {
        settingsStore.removeFavouriteStack(props.link.label);
      } else {
        settingsStore.addFavouriteStack(props.link.label);
      }
    };

    return {
      stackStore,
      toggleFavourite,
      symOutlinedStar
    };
  }
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
