<template>
<div class="col column">
    <q-bar class="bg-primary text-white text-weight-bold">{{ title }}</q-bar>
    <q-card flat bordered square class="column col q-pa-sm" style="white-space: pre; font-family: monospace; min-height: 100px;">
        <q-scroll-area v-if="env !== null" class="col">
            {{ env }}
        </q-scroll-area>
        <span style="font-style: italic;" v-if="env === null">No environment defined.</span>
    </q-card>
</div>
</template>

<script>
import { storeToRefs } from 'pinia';
import { useStackStore } from 'src/stores/stacks';
import { onMounted, watch, computed } from 'vue';

export default {
    props: {
        stackName: String,
        moduleName: String, // Added prop
        envType: String // 'global'|'stack'|'module'
    },

    setup(props) {
        const stackStore = useStackStore();
        const { globalEnv, stackEnv, moduleEnvs } = storeToRefs(stackStore);

        async function loadData() {
            switch(props.envType) {
                case 'global':
                    await stackStore.loadGlobalEnv();
                    break;
                case 'module':
                    if (props.moduleName) {
                        await stackStore.loadModuleEnv(props.moduleName);
                    }
                    break;
                case 'stack':
                default:
                    if(await stackStore.ensureStackIsInStore(props.stackName)) {
                        await stackStore.loadStackEnv(props.stackName);
                    }
            }
        }

        onMounted(() => loadData());

        watch(
            () => [props.stackName, props.moduleName],
            () => loadData()
        );

        const env = computed(() => {
            if(props.envType == 'global') return globalEnv.value;
            else if(props.envType == 'module') return moduleEnvs.value[props.moduleName] || null;
            else return stackEnv.value(props.stackName);
        });

        const title = computed(() => {
            if(props.envType == 'global') return 'Global Environment';
            else if(props.envType == 'module') return 'Module Environment';
            else return 'Stack Environment';
        });

        return {
            env, title
        };
    },
}
</script>
