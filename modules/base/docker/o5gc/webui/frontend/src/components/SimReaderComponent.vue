<template>
    <div class="col column">
        <q-card flat bordered square class="column col q-pa-sm" style="font-family: monospace;">
            <q-btn icon="search" :loading="_busy.detectReader" :disable="consoleOutBusy" color="primary" label="Detect Reader" @click="detectReader()" class="q-ma-xs" />
            <q-btn :icon="symOutlinedSimCard" :loading="_busy.detectCard" :disable="consoleOutBusy" color="primary" label="Detect Card" @click="detectCard()" class="q-ma-xs" />
            <q-btn :icon="symOutlinedSimCardDownload" :loading="_busy.readCard" :disable="consoleOutBusy" color="primary" label="Read Card" @click="readCard()" class="q-ma-xs" />
        </q-card>
    </div>
</template>

<script>
import { symOutlinedSimCard, symOutlinedSimCardDownload } from '@quasar/extras/material-symbols-outlined'
import { storeToRefs } from 'pinia';
import { useSimWriterStore } from 'src/stores/simWriter';

export default {
    setup() {
        const simWriterStore = useSimWriterStore();
        const { _busy, consoleOutBusy } = storeToRefs(simWriterStore);
        const detectReader = simWriterStore.detectReader;
        const detectCard = simWriterStore.detectCard;
        const readCard = simWriterStore.readCard;

        return {
            symOutlinedSimCard, symOutlinedSimCardDownload, detectReader, detectCard, readCard, _busy, consoleOutBusy
        }
    }
}

</script>
