<template>
    <div class="col column">
        <q-card flat bordered square class="column col q-pa-sm" style="font-family: monospace;">
            <q-select ref="typeRef" v-model="simWriterContent.type" dense outlined :options="types" :rules="[val => checkTypeFormat || '']" label="Type" class="q-pa-xs" />
            <div class="row">
                <q-input ref="mccRef" v-model="simWriterContent.mcc" dense outlined :rules="[val => checkMccFormat || '']" label="MCC" maxlength="3" class="col-md-3 col-xs-6 q-pa-xs" @update:model-value="simWriterContent.imsi && imsiRef.validate()" />
                <q-input ref="mncRef" v-model="simWriterContent.mnc" dense outlined :rules="[val => checkMncFormat || '']" label="MNC" maxlength="3" class="col-md-3 col-xs-6 q-pa-xs" @update:model-value="simWriterContent.imsi && imsiRef.validate()" />
                <q-input ref="imsiRef" v-model="simWriterContent.imsi" dense outlined :rules="[val => checkImsiFormat || '']" label="IMSI (incl. MCC + MNC)" maxlength="15" class="col-md-6 col-xs-12 q-pa-xs"/>
            </div>
            <div class="row">
                <div class="col-10 row">
                    <q-input ref="kiRef" v-model="simWriterContent.ki" dense outlined :rules="[val => checkKiFormat || '']" label="KEY" class="col-12 q-pa-xs" />
                    <q-input ref="opcRef" v-model="simWriterContent.opc" dense outlined :rules="[val => checkOpcFormat || '']" label="OPC" class="col-12 q-pa-xs" />
                </div>
                <div class="col-2 row"><q-btn :loading="_busy.autogen" color="primary" class="col-11 q-ma-xs" @click="autogenKeyOpc()">Autogen</q-btn></div>
            </div>
            <div class="row">
                <q-input ref="admRef" v-model="simWriterContent.adm" dense outlined :rules="[val => checkAdmFormat || '']" label="ADM" class="q-pa-xs col-md-9 col-xs-12" />
                <div class="col-3 row"><q-btn color="primary" class="col-11 q-ma-xs" @click="clearWriterContent(); resetValidation();">Clear&nbsp;Form</q-btn></div>
            </div>
            <div class="row">
                <q-btn :loading="_busy.writeCard" :disable="!writeButtonActive" size="lg" color="negative" class="q-pa-xs col-12" @click="writeDialogActive = true">Write to Card</q-btn>
            </div>
        </q-card>
    </div>
    <q-dialog v-model="writeDialogActive" persistent>
      <q-card>
        <q-card-section class="row items-center">
          <q-avatar icon="warning" color="warning" text-color="black" />
          <span class="q-ml-sm">
            Are you sure you want to write the following data to the SIM Card?<br /><br />
            <b>Type:</b> {{ simWriterContent.type }}<br />
            <b>MCC:</b> {{ simWriterContent.mcc }}<br />
            <b>MNC:</b> {{ simWriterContent.mnc }}<br />
            <b>IMSI:</b> {{ simWriterContent.imsi }}<br />
            <b>KEY:</b> {{ simWriterContent.ki }}<br />
            <b>OPC:</b> {{ simWriterContent.opc }}<br />
            <b>ADM:</b> {{ simWriterContent.adm }}<br />
          </span>
        </q-card-section>

        <q-card-actions align="right">
          <q-btn v-close-popup flat label="Okay" icon="check" color="positive" @click="writeCard()" />
          <q-btn v-close-popup flat label="Cancel" icon="close" color="negative" />
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
        const { types, simWriterContent, _busy, consoleOutBusy } = storeToRefs(simWriterStore);

        const { clearWriterContent, autogenKeyOpc, writeCard } = simWriterStore;

        const writeDialogActive = ref(false);

        const typeRef = ref(null);
        const mccRef = ref(null);
        const mncRef = ref(null);
        const imsiRef = ref(null);
        const kiRef = ref(null);
        const opcRef = ref(null);
        const admRef = ref(null);

        async function loadData() {
            simWriterStore.loadTypes();
        }

        onMounted(() => loadData());

        function resetValidation() {
            nextTick(() => {
                if(typeRef.value) typeRef.value.resetValidation();
                if(mccRef.value) mccRef.value.resetValidation();
                if(mncRef.value) mncRef.value.resetValidation();
                if(imsiRef.value) imsiRef.value.resetValidation();
                if(kiRef.value) kiRef.value.resetValidation();
                if(opcRef.value) opcRef.value.resetValidation();
                if(admRef.value) admRef.value.resetValidation();
            });
        }

        return {
            types, simWriterContent, autogenKeyOpc, clearWriterContent, writeCard, _busy, consoleOutBusy, writeDialogActive,
            typeRef, mccRef, mncRef, imsiRef, kiRef, opcRef, admRef,
            resetValidation

        };
    },
    computed: {
        checkTypeFormat: (state) => state.simWriterContent.type.length > 0 && state.types.includes(state.simWriterContent.type),
        checkMccFormat: (state) => /^\d{3}$/.test(state.simWriterContent.mcc),
        checkMncFormat: (state) => /^\d{2,3}$/.test(state.simWriterContent.mnc),
        checkImsiFormat: (state) => /^\d{5,15}$/.test(state.simWriterContent.imsi) && state.simWriterContent.imsi.startsWith(`${state.simWriterContent.mcc}${state.simWriterContent.mnc}`),
        checkKiFormat: (state) => /^[0-9A-Fa-f]{32}$/.test(state.simWriterContent.ki),
        checkOpcFormat: (state) => /^[0-9A-Fa-f]{32}$/.test(state.simWriterContent.opc),
        checkAdmFormat: (state) => /^[0-9]+$/.test(state.simWriterContent.adm),
        writeButtonActive: (state) => (
            state.checkTypeFormat &&
            state.checkMccFormat &&
            state.checkMncFormat &&
            state.checkImsiFormat &&
            state.checkKiFormat &&
            state.checkOpcFormat &&
            !state.consoleOutBusy
        )
    }
}
</script>
