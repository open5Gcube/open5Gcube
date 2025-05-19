import { defineStore } from 'pinia';
import { Dark } from 'quasar';
import { generateErrorNotification } from './common';

type SettingsType = {
    dark: boolean|'auto',
    logLines: number,
    favouriteStacks: string[]
};

export const useSettingsStore = defineStore('settings', {
    state: (): SettingsType => {
      return {
        dark: true,
        logLines: 1000,
        favouriteStacks: []
      }
    },
    actions: {
      setDark (value: boolean|'auto') {
        Dark.set(value);
        this.dark = Dark.mode;
      },
      toggleDark () {
        Dark.toggle();
        this.dark = Dark.mode;
      },
      initDark() {
        Dark.set(this.dark);
      },
      addFavouriteStack(stackName: string) {
        if(this.favouriteStacks.indexOf(stackName) == -1)
          this.favouriteStacks.push(stackName);
        else
          generateErrorNotification('Stack ' + stackName + ' is already a favourite.');
      },
      removeFavouriteStack(stackName: string) {
        const idx = this.favouriteStacks.indexOf(stackName);
        if(idx !== -1)
          this.favouriteStacks.splice(idx, 1);
        else
          generateErrorNotification('Stack ' + stackName + ' is not a favourite.');
      }
    },
    persist: {
      enabled: true,
      strategies: [
        {storage: localStorage}
      ]
    }
})
