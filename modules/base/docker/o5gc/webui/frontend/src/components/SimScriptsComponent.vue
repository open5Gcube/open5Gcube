<template>
    <div class="">
        <q-card flat bordered square class="q-pa-sm" style="font-family: monospace;">
            <q-select dense outlined v-model="simScriptFormContent.scriptName" :options="scriptNames" ref="scriptNameRef" :rules="[val => checkScriptNameFormat || '']" label="Select Script" class="q-pa-xs" />
            <q-card flat bordered square class="q-pa-sm" style="white-space: pre; font-family: monospace">
                <q-scroll-area style="height: 150px"><div style="height: 100%">
                    {{ scriptContent }}
                </div></q-scroll-area>
            </q-card>
            <div class="row">
                <q-input dense outlined v-model="simScriptFormContent.adm" ref="admRef" :rules="[val => checkAdmFormat || '']" label="ADM" class="q-pa-xs col-md-9 col-xs-12" />
            </div>
            <div class="row">
                <q-btn :loading="_busy.writeCard" :disable="!executeButtonActive" @click="scriptDialogActive = true" size="lg" color="negative" class="q-pa-xs col-12">Execute Script</q-btn>
            </div>
        </q-card>
    </div>
    <q-dialog v-model="scriptDialogActive" persistent>
      <q-card>
        <q-card-section class="row items-center">
          <q-avatar icon="warning" color="warning" text-color="black" />
          <span class="q-ml-sm">
            Are you sure you want to execute the following script on the SIM Card?<br /><br />
            <b>Script Name:</b> {{ simScriptFormContent.scriptName }}<br />
            <b>ADM:</b> {{ simScriptFormContent.adm }}<br />
          </span>
        </q-card-section>

        <q-card-actions align="right">
          <q-btn flat label="Okay" @click="executeScript()" icon="check" color="positive" v-close-popup />
          <q-btn flat label="Cancel" icon="close" color="negative" v-close-popup />
        </q-card-actions>
      </q-card>
    </q-dialog>
</template>

<script>
import { useSimWriterStore } from 'src/stores/simWriter';
import { storeToRefs } from 'pinia';
import { nextTick, onMounted, ref } from 'vue';

export default {
    setup() {
        const simWriterStore = useSimWriterStore();
        const { scripts, simScriptFormContent, _busy, consoleOutBusy } = storeToRefs(simWriterStore);

        const { deleteScript, executeScript } = simWriterStore;

        const scriptDialogActive = ref(false);

        const scriptNameRef = ref(null);
        const admRef = ref(null);

        async function loadScripts() {
            simWriterStore.loadScripts();
        }

        onMounted(() => loadScripts());

        function resetValidation() {
            nextTick(() => {
                if(admRef.value) admRef.value.resetValidation();
            });
        }

        return {
            scripts, simScriptFormContent, _busy, consoleOutBusy,
            loadScripts, deleteScript, executeScript,
            scriptDialogActive,
            scriptNameRef, admRef,
            resetValidation
        };
    },
    computed: {
        checkScriptNameFormat: (state) => state.simScriptFormContent.scriptName?.length > 0 && state.simScriptFormContent.scriptName in state.scripts,
        checkAdmFormat: (state) => /^[0-9A-Fa-f]{1,32}$/.test(state.simScriptFormContent.adm),
        executeButtonActive: (state) => (
            state.checkScriptNameFormat &&
            state.checkAdmFormat &&
            !state.consoleOutBusy
        ),
        scriptNames: (state) => Object.keys(state.scripts),
        scriptContent: (state) => state.scripts[state.simScriptFormContent.scriptName]?.content,
        scriptComment: (state) => state.scripts[state.simScriptFormContent.scriptName]?.comment?.join('')
    }
}
</script>
