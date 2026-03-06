<template>
    <q-card v-if="stackDesc" square flat bordered>
        <q-scroll-area style="height: 150px;" visible>
            <q-markdown :src="stackDesc" no-heading-anchor-links class="q-ma-md" />
        </q-scroll-area>
    </q-card>
</template>

<script>
import { storeToRefs } from 'pinia';
import { useStackStore } from 'src/stores/stacks';
import { toRef, ref, watch, onMounted } from 'vue';

export default {
    props: {
        stackName: { type: String, required: true }
    },

    async setup(props) {
        const stackStore = useStackStore();

        const stackDesc = ref('');

        async function loadData(props) {
            const stackName = toRef(props, 'stackName');
            const result = await stackStore.ensureStackIsInStore(stackName.value)
            if(!result) return {};

            await stackStore.loadStackDescription(stackName.value)
            const { stacks } = storeToRefs(stackStore);
            const stack = stacks.value[stackName.value]
            stackDesc.value = stack['description']
        }

        onMounted(() => loadData(props));

        watch(
            () => props.stackName,
            () => loadData(props)
        );

        return {
            stackDesc
        };
    },
}
</script>

<style>
.q-markdown--image {
    max-width: 100%;
    height: 130px;
}
</style>
