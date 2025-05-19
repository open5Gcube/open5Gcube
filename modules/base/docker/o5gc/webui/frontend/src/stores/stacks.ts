import { defineStore } from 'pinia';
import { api } from 'src/boot/axios';
import { generateErrorNotification } from './common';
import { useEventLogStore } from './event-log';
import { useSettingsStore } from './settings';

/*
 * Format of stack store:
 * {
 *   "global_env": "ENV1=VAL1\nENV2=VAL2\n...",
 *   "stacks": {
 *     "stack_name1": {
 *       "description": "Description of Stack 1",
 *       "stackEnv": "ENV1=VAL1_modified\nENV3=VAL3\n...",
 *       "envOverrides": "ENV4=VAL4\n...",
 *       "starting": true,
 *       "stopping": false
 *     }
 *   }
 * }
 *
 * Getters:
 * - stackNames
 *
 * Actions:
 * - loadGlobalEnv
 * - loadStackNames
 * - ensureStackIsInStore
 * - loadStackDescription
 * - loadStackEnv
 * - startStack
 * - stopStack
 *
 */

type StackStoreType = {
  globalEnv: string|null,
  stacks: {[key: string]: {[key:string]: any}},
  eventLogStore: any,
  settingsStore: any
}

function handleEnvApiError(error: any, fetchType: string, stackName: string|null = null) {
  let errorMessage = '';
  if(error.response) {
    if(error.response.status == 404) {
      errorMessage = `Tried to fetch ${fetchType} ${stackName ? 'for stack ' + stackName : ' '} from server which does not exist on server.`;
    } else {
      errorMessage = `Tried to fetch ${fetchType} ${stackName ? 'for stack ' + stackName : ' '} from server and got HTTP error ${error.response.status}.`;
    }
  }
  else {
    errorMessage = `Tried to fetch ${fetchType} ${stackName ? 'for stack ' + stackName : ' '} from server which failed with an unknown error.`;
  }
  generateErrorNotification(errorMessage);
}

export const useStackStore = defineStore('stacks', {
  state() : StackStoreType {
    const globalEnv: string|null = '';
    const stacks: {[key: string]: {[key:string]: any}} = {};
    const eventLogStore = useEventLogStore();
    const settingsStore = useSettingsStore();

    return {
        globalEnv, stacks, eventLogStore, settingsStore
    }
  },
  getters: {
    stackNames: (state) => Object.keys(state.stacks),
    stackEnv: (state) => {
      return (stackName: string) => {
        if(!(stackName in state.stacks)) return undefined;
        return state.stacks[stackName].stackEnv;
      }
    },
    favouriteStackNames: (state) => Object.keys(state.stacks).filter(stackName => state.settingsStore.favouriteStacks.includes(stackName)),
    nonFavouriteStackNames: (state) => Object.keys(state.stacks).filter(stackName => !state.settingsStore.favouriteStacks.includes(stackName))
  },
  actions: {
    async loadGlobalEnv() {
        try {
            this.globalEnv = (await api.get('api/global_env')).data
        } catch(error: any) {
          if(error.response && error.response.status == 404) {
            this.globalEnv = null;
          } else {
            handleEnvApiError(error, 'global environment');
          }
        }
    },
    async loadStackNames() {
        // Get stack names from API
        let stackNames: {stacks: [{stack_name: string}]}|null = null;
        try {
          stackNames = (await api.get('api/stacks')).data
        } catch(error: any) {
          if(error.response) {
            generateErrorNotification(`HTTP Error ${error.response.status} on trying to fetch stack names from server.`);
          } else {
            generateErrorNotification('Unknown error on trying to fetch stack names from server.');
          }
        }

        if(!stackNames) return;

        // Get lists of stack names in order to sync the stack names from internal state with updated stack names
        const stacksBefore = new Set(Object.keys(this.stacks))
        const stacksNew = new Set(stackNames.stacks.map(l => l['stack_name']))

        // Delete stack names that do not exist on server anymore
        for (const s of stacksBefore) {
            if (!stacksNew.has(s)) {
                delete this.stacks[s]
            }
        }

        // Add stacks that are new on server
        for(const s of stacksNew) {
            if (!stacksBefore.has(s)) {
                this.stacks[s] = {'description': null, 'stackEnv': null, 'envOverrides': null, 'starting': false, 'stopping': false}
            }
        }
    },
    async ensureStackIsInStore(stackName: string) {
      if(stackName in this.stacks) return true;

      await this.loadStackNames();
      if(stackName in this.stacks) return true;

      generateErrorNotification('Tried to get stack environment for stack ' + stackName + ' which does not exist.');

      return false;
    },
    async loadStackEnv(stackName: string) {
      if(!this.ensureStackIsInStore(stackName)) return;

      // This code is only reached when the stack exists on the server
      try {
        this.stacks[stackName].stackEnv = (await api.get('api/stack/' + stackName + '/env')).data
      } catch(error: any) {
        if(error.response && error.response.status == 404) {
          this.stacks[stackName].stackEnv = null;
        } else {
          handleEnvApiError(error, 'stack environment', stackName);
        }
      }
    },
    async loadStackEnvOverrides(stackName: string) {
      if(!this.ensureStackIsInStore(stackName)) return;

      // This code is only reached when the stack exists on the server
      try {
        this.stacks[stackName].envOverrides = (await api.get('api/stack/' + stackName + '/env_overrides')).data
      } catch(error: any) {
        if(error.response && error.response.status == 404) {
          this.stacks[stackName].envOverrides = null;
        } else {
          handleEnvApiError(error, 'environment overrides', stackName);
        }
      }
    },
    async loadStackDescription(stackName: string) {
      if(!this.ensureStackIsInStore(stackName)) return;

      // This code is only reached when the stack exists on the server
      try {
        this.stacks[stackName].description = (await api.get('api/stack/' + stackName + '/description')).data;
      } catch(error: any) {
        if(error.response && error.response.status == 404) {
          this.stacks[stackName].description = null;
        } else {
          handleEnvApiError(error, 'stack description', stackName);
        }
      }
    },
    async startStack(stackName: string) {
      if(!this.ensureStackIsInStore(stackName)) return;

      // This code is only reached when the stack exists on the server
      const event_id = this.eventLogStore.start_event(`Starting stack ${stackName}`);

      this.stacks[stackName].starting = true;

      const envOverrides = this.stacks[stackName].envOverrides ? this.stacks[stackName].envOverrides.toString() : '';

      try {
        const result = (await api.post('api/stack/' + stackName, {
          // Transform [{"name": "ENV_VAR", "value": "env_value"}, ...] into {"ENV_VAR": "env_value", ...} and add to request
          //'env': this.stacks[stackName].envOverrides.reduce((obj: { [key: string]: string }, item: {'name': string, 'value': string}) => { obj[item.name] = item.value; return obj }, {})
          'env_file': envOverrides.endsWith('\n') ? envOverrides : envOverrides + '\n'
        })).data;
        this.eventLogStore.end_event(event_id, 'SUCCESSFUL', 'Stack started successfully.', result);
      }
      catch (error: any) {
        if (error.response) {
          this.eventLogStore.end_event(event_id, 'FAILED', `HTTP ERROR ${error.response.status}`, error.response.data);
        }
        else if (error.request) {
          this.eventLogStore.end_event(event_id, 'FAILED', `Request error: ${error.request}`);
        }
        else {
          this.eventLogStore.end_event(event_id, 'FAILED', `Unknown error: ${error.message}`);
        }
      }
      this.stacks[stackName].starting = false;
    },
    async stopStack(stackName: string) {
      if(!this.ensureStackIsInStore(stackName)) return;

      const event_id = this.eventLogStore.start_event(`Stopping stack ${stackName}`);

      this.stacks[stackName].stopping = true;

      // Test
      //await new Promise(resolve => setTimeout(resolve, 1000000));

      // This code is only reached when the stack exists on the server
      try {
        const result = (await api.delete('api/stack/' + stackName)).data;
        this.eventLogStore.end_event(event_id, 'SUCCESSFUL', 'Stack stopped successfully.', result);
      }
      catch(error: any) {
        if (error.response) {
          this.eventLogStore.end_event(event_id, 'FAILED', `HTTP ERROR ${error.response.status}`, error.response.data);
        }
        else if (error.request) {
          this.eventLogStore.end_event(event_id, 'FAILED', `Request error: ${error.request}`);
        }
        else {
          this.eventLogStore.end_event(event_id, 'FAILED', `Unknown error: ${error.message}`);
        }
      }

      this.stacks[stackName].stopping = false;
    }
  }
});
