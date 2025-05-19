<template>
<div class="col column">
    <q-bar class="bg-primary text-white text-weight-bold">{{ envType == 'global' ? 'Global ' : 'Stack ' }} Environment</q-bar>
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
import { onMounted, watch } from 'vue';

export default {
    props: {
        stackName: String,
        envType: String // 'global'|'stack'
    },

    async setup(props) {
        const stackStore = useStackStore();
        const { globalEnv, stackEnv } = storeToRefs(stackStore);

        async function loadData() {
            switch(props.envType) {
                case 'global':
                    await stackStore.loadGlobalEnv();
                    break;
                default:
                    if(await stackStore.ensureStackIsInStore(props.stackName)) {
                        await stackStore.loadStackEnv(props.stackName);
                    }
            }
        }

        onMounted(() => loadData());

        watch(
            () => props.stackName,
            () => loadData()
        );

        return {
            globalEnv, stackEnv
        };
    },

    computed: {
        env() {
            if(this.envType == 'global') return this.globalEnv;
            else return this.stackEnv(this.stackName);
        }
    }
}
</script>
