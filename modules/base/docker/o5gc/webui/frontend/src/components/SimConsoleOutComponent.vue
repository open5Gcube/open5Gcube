<template>
    <div class="column full-height">
        <q-bar class="bg-primary text-white text-weight-bold">Console Out</q-bar>
        <q-card flat bordered square class="column col q-pa-sm" style="white-space: pre-wrap; font-family: monospace;">
            <q-inner-loading :showing="consoleOutBusy" class="col">
                <q-spinner-gears size="50px" color="primary" />
            </q-inner-loading>
            <q-scroll-area style="overflow: auto; word-break: break-word" class="col">
                {{ consoleOut }}
            </q-scroll-area>
        </q-card>
    </div>
</template>

<script>
import { useSimWriterStore } from 'src/stores/simWriter';
import { storeToRefs } from 'pinia';

export default {
    setup() {
        const simWriterStore = useSimWriterStore();
        const { consoleOut, consoleOutBusy } = storeToRefs(simWriterStore);
        return { consoleOut, consoleOutBusy };
    }
}

</script>
