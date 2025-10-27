<template>
    <div class="">
        <q-card flat bordered square class="q-pa-sm" style="font-family: monospace;">
            <q-select
                dense
                outlined
                v-model="simScriptFormContent.scriptName"
                :options="scriptNameOptionsRef"
                ref="scriptNameRef"
                :rules="[val => checkScriptNameFormat || '']"
                label="Select Script"
                class="q-pa-xs"
                use-input
                input-debounce="0"
                @filter="filterScriptNames"
                behavior="menu"
            >
                <template v-slot:append>
                    <q-icon v-if="simScriptFormContent.scriptName !== null" name="info" style="cursor: help" @click.stop.prevent>
                        <q-tooltip style="white-space: pre-wrap; font-family: monospace; background-color: #333333; font-size: 15px;">
                            {{ scriptComment }}
                        </q-tooltip>
                    </q-icon>
                    <q-icon v-if="simScriptFormContent.scriptName !== null" name="delete" class="cursor-pointer" color="negative" @click.stop.prevent="">
                        <q-menu>
                          <q-list dense>
                              <q-item clickable @click="deleteScript(); simScriptFormContent.scriptName = null; resetValidation()" v-close-popup>
                                  <q-item-section avatar><q-icon name="delete" class="text-negative" /></q-item-section>
                                  <q-item-section>Delete Script</q-item-section>
                              </q-item>
                          </q-list>
                      </q-menu>
                    </q-icon>
                </template>
                <template v-slot:no-option>
                    <q-item>
                        <q-item-section class="text-italic text-grey">
                            No scripts found - upload your first one today!
                        </q-item-section>
                    </q-item>
                </template>
            </q-select>
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

        const scriptNameOptionsRef = ref([]);
        const scriptNameRef = ref(null);
        const admRef = ref(null);

        async function loadScripts() {
            simWriterStore.loadScripts();
        }

        onMounted(() => {
            loadScripts();
            scriptNameOptionsRef.value = Object.keys(scripts.value);
        });

        function resetValidation() {
            nextTick(() => {
                if(scriptNameRef.value) scriptNameRef.value.resetValidation();
                if(admRef.value) admRef.value.resetValidation();
            });
        }

        function filterScriptNames (val, update) {
            if(val === '') {
                update(() => {
                    scriptNameOptionsRef.value = Object.keys(scripts.value);
                });
                return;
            }

            update(() => {
                const needle = val.toLowerCase();
                scriptNameOptionsRef.value = Object.keys(scripts.value).filter(v => v.toLowerCase().indexOf(needle) > -1);
            });
        }

        return {
            scripts, simScriptFormContent, _busy, consoleOutBusy,
            loadScripts, deleteScript, executeScript,
            scriptDialogActive,
            scriptNameOptionsRef, scriptNameRef, admRef,
            filterScriptNames, resetValidation
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
