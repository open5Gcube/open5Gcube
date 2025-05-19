<template>
        <div class="q-gutter-sm">

        <q-btn :loading="current_stack.starting" class="bg-positive text-white" style="width: 150px" icon="play_arrow" @click="startStack()">
          Start
          <template v-slot:loading>
            <q-spinner-hourglass class="on-left" />
            Starting...
          </template>
        </q-btn>
        <q-btn :loading="current_stack.stopping" class="bg-negative text-white" style="width: 150px" icon="stop" @click="stopStack()">
          Stop
          <template v-slot:loading>
            <q-spinner-hourglass class="on-left" />
            Stopping...
          </template>
        </q-btn>
        </div>
</template>
<script>
import { useStackStore } from 'src/stores/stacks';
import { toRef } from 'vue';
import { storeToRefs } from 'pinia';

export default {
    props: {
        stackName: String
    },

    async setup(props) {
        const stackStore = useStackStore();
        const { stacks } = storeToRefs(stackStore);
        const stackName = toRef(props, 'stackName');

        const result = await stackStore.ensureStackIsInStore(stackName.value)
        if(!result) return {};

        const current_stack = stacks.value[stackName.value];

        return {
            stackStore, stacks, current_stack
        };
    },
    methods: {
      async startStack() {
        if(this.current_stack.starting || this.current_stack.stopping) {
          this.notifyStackStartingStopping();
          return;
        }
        await this.stackStore.startStack(this.stackName);
      },
      async stopStack() {
        if(this.current_stack.stopping || this.current_stack.starting) {
          this.notifyStackStartingStopping();
          return;
        }
        await this.stackStore.stopStack(this.stackName);
      },
      notifyStackStartingStopping() {
        this.$q.notify({
            message: 'Stack is already starting or stopping. Please wait.',
            color: 'negative',
            icon: 'announcement'
          });
      }
    }
}

</script>
