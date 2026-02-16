<template>
    <div class="col column">
        <q-bar class="bg-primary text-white text-weight-bold">Environment Overrides&nbsp;<q-icon name="info"><q-tooltip>The environment overrides are saved on the server when the stack is started.<br />Until that point, your overrides are only stored temporarily in your browser.</q-tooltip></q-icon></q-bar>
        <q-card flat bordered square class="column col q-pa-sm env-overrides-textarea" style="min-height: 100px;">
            <q-input v-model="envOverrides" filled square type="textarea" class="column col" style="white-space: pre; font-family: monospace;" dense input-class="col full-height" input-style="" />
            <q-btn @click="reload()" label="Reload from server" icon="update" class="bg-primary text-white" />
        </q-card>
    </div>
</template>

<script>
import { storeToRefs } from 'pinia';
import { useStackStore } from 'src/stores/stacks';
import { ref, onMounted, watch } from 'vue';

export default {
    props: {
        stackName: String
    },

    async setup(props) {
        const stackStore = useStackStore();
        const envOverrides = ref('');

        async function ensureStackIsInStore() {
            const result = await stackStore.ensureStackIsInStore(props.stackName)
            if(!result) return {};
        }

        async function loadData() {
            await ensureStackIsInStore();

            if(storeToRefs(stackStore).stacks.value[props.stackName].envOverrides === null)
                await stackStore.loadStackEnvOverrides(props.stackName);
            envOverrides.value = storeToRefs(stackStore).stacks.value[props.stackName].envOverrides;
        }

        async function saveData() {
            await ensureStackIsInStore();

            storeToRefs(stackStore).stacks.value[props.stackName].envOverrides = envOverrides.value;
        }

        async function reload() {
            await ensureStackIsInStore();

            storeToRefs(stackStore).stacks.value[props.stackName].envOverrides = null;
            await loadData();
        }

        onMounted(() => loadData());

        watch(
            () => props.stackName,
            () => loadData()
        );

        watch(envOverrides, () => saveData());

        return {
            stackStore, envOverrides, reload
        };
    }
}
</script>
<style lang="sass">
.env-overrides-textarea
  /* height or max-height is important */

  .q-filed__inner,
  .q-field__control,
  .q-field__control-container
    height: 100%
</style>
