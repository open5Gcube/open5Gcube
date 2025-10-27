import { defineStore } from 'pinia';
import { api } from 'src/boot/axios';
import { generateErrorNotification } from './common';

const SIM_DEFAULT_TYPE = 'sysmoISIM-SJA2';

/*
 * Format of SIM Writer store:
 * {
 *   "ueDb": {
 *     {
 *       "id": 1,
 *       "imsi": "262 01 9876543210",
 *       "key": "F18E5DB0A8B5B8A0304E9113D644DFE3",
 *       "opc": "E83C9CF3683B9E82EBC005A696E86AD8"
 *     },
 *     ...
 *   },
 *   "types": ["type1", "type2", ...],
 *   "simWriterContent": {
 *     "type": "type1",
 *     "mcc": "262",
 *     "mnc": "02",
 *     "imsi": "262029876543210",
 *     "key": "DEADCAFE..",
 *     "opc": "12345678..",
 *     "adm": "..."
 *   }
 *   "consoleOut": "...",
 * }
 *
 * Getters:
 * -
 *
 * Actions:
 * - loadUeDb
 * - loadTypes
 * - detectReader
 * - detectCard
 * - readCard
 * - copyUeDataToWriterContent
 * - autogenKeyOpc
 * - addUe
 * - removeUe
 * - updateUe
 */

type UeType = {
    id: number,
    imsi: `${number}`,
    key: string,
    opc: string
}

type UeDbType = UeType[];

type SimWriterContentType = {
    type: string,
    mcc: string,
    mnc: string,
    imsi: string,
    ki: string,
    opc: string,
    adm: string
}

type SimWriterBusyType = {
    loadUeDb: boolean,
    loadTypes: boolean,
    loadScripts: boolean,
    uploadScript: boolean,
    deleteScript: boolean,
    detectReader: boolean,
    detectCard: boolean,
    readCard: boolean,
    writeCard: boolean,
    autogen: boolean,
    executeScript: boolean
}

type SimWriterStoreType = {
    ueDb: UeDbType,
    types: string[],
    scripts: {[scriptName: string]: SimScriptType},
    simWriterContent: SimWriterContentType,
    simScriptFormContent: {scriptName: string|null, adm: string},
    consoleOut: string,
    _busy: SimWriterBusyType
};

type SimScriptType = {
    comment: string[],
    content: string,
    error: string
};

export const useSimWriterStore = defineStore('simWriter', {
    state() : SimWriterStoreType {
      const ueDb: UeDbType = [];
      const types: string[] = [];
      const scripts: {[scriptName: string]: SimScriptType} = {};
      const simWriterContent: SimWriterContentType = {type: '', mcc: '', mnc: '', imsi: '', ki: '', opc: '', adm: ''};
      const simScriptFormContent = {scriptName: null, adm: ''};
      const consoleOut = '';
      const _busy: SimWriterBusyType = {
        loadUeDb: false,
        loadTypes: false,
        loadScripts: false,
        uploadScript: false,
        deleteScript: false,
        detectReader: false,
        detectCard: false,
        readCard: false,
        writeCard: false,
        autogen: false,
        executeScript: false
    };

      return {
        ueDb, types, scripts, simWriterContent, simScriptFormContent, consoleOut, _busy
      }
    },
    getters: {
        consoleOutBusy: (state) => (state._busy.detectReader || state._busy.detectCard || state._busy.readCard || state._busy.writeCard || state._busy.deleteScript || state._busy.executeScript)
    },
    actions: {
        async _httpRequestWithErrorReporting(requestCb: () => Promise<any>, errorMessageTemplate: string) {
            try {
                return await requestCb();
            } catch(error: any) {
                const error_msg = errorMessageTemplate.replace('{{ error_detail }}', error.response ? `HTTP Error ${error.response.status}` : 'Unknown error');
                generateErrorNotification(error_msg);
                if(error.response) {
                    this.consoleOut = error.response.data;
                }
                throw error;
            }
        },
        async _getDataWithErrorReporting(url: string, errorMessageTemplate: string) {
            try {
                return await this._httpRequestWithErrorReporting(async () => (await api.get(url)).data, errorMessageTemplate);
            } catch {};
        },
        async loadUeDb() {
            this._busy.loadUeDb = true;
            try {
                this.ueDb = (await this._getDataWithErrorReporting('/api/uedb', 'Error: {{ error_detail }} when trying to fetch UE DB'));
            } catch {};
            this._busy.loadUeDb = false;
        },
        async loadTypes() {
            this._busy.loadTypes = true;
            try {
                this.types = (await this._getDataWithErrorReporting('/api/pysim/prog_types', 'Error: {{ error_detail }} when trying to fetch pysim prog types'));
                if(!this.simWriterContent.type && this.types.includes(SIM_DEFAULT_TYPE))
                    this.simWriterContent.type = SIM_DEFAULT_TYPE;
            } catch {};
            this._busy.loadTypes = false;
        },
        async loadScripts() {
            this._busy.loadScripts = true;
            try {
                this.scripts = (await this._getDataWithErrorReporting('http://localhost/api/pysim/scripts', 'Error: {{ error_detail }} when trying to fetch pysim scripts.'));
            } catch {};
            this._busy.loadScripts = false;
        },
        async detectReader() {
            this._busy.detectReader = true;
            try {
                this.consoleOut = (await this._getDataWithErrorReporting('/api/pcsc_scan/readers', 'Error: {{ error_detail }} when trying to get card reader state'));
            } catch {}
            this._busy.detectReader = false;
        },
        async detectCard() {
            this._busy.detectCard = true;
            try {
                this.consoleOut = (await this._getDataWithErrorReporting('/api/pcsc_scan/cards', 'Error: {{ error_detail }} when trying to get card state'));
            } catch {}
            this._busy.detectCard = false;
        },
        async readCard() {
            this._busy.readCard = true;
            try {
                this.consoleOut = (await this._getDataWithErrorReporting('/api/pysim/read', 'Error: {{ error_detail }} when trying to get card content'));
            } catch {}
            this._busy.readCard = false;
        },
        async writeCard() {
            this._busy.writeCard = true;
            try {
                this.consoleOut = (await this._httpRequestWithErrorReporting(async () => (await api.post('/api/pysim/prog', this.simWriterContent)).data, 'Error: {{ error_detail }} when trying to write to SIM.'));
            } catch {}
            this._busy.writeCard = false;
        },
        copyUeDataToWriterContent(imsi: string, key: string, opc: string) {
            this.simWriterContent.mcc = '';
            this.simWriterContent.mnc = '';
            this.simWriterContent.imsi = imsi;
            this.simWriterContent.ki = key;
            this.simWriterContent.opc = opc;
            this.simWriterContent.adm = '';
        },
        async autogenKeyOpc() {
            this._busy.autogen = true;
            try {
                const {ki, opc} = (await this._getDataWithErrorReporting('/api/kiopcgen', 'Error: {{ error_detail }} when trying to generate Key and OPC'));
                this.simWriterContent.ki = ki;
                this.simWriterContent.opc = opc;
            } catch {}
            this._busy.autogen = false;
        },
        async deleteScript() {
            this._busy.deleteScript = true;
            try {
                this.consoleOut = (await this._httpRequestWithErrorReporting(async () => (await api.delete(`http://localhost/api/pysim/script/${this.simScriptFormContent.scriptName}`)).data, 'Error: {{ error_detail }} when trying to delete script.'));
            } catch {};
            this._busy.deleteScript = false;
            this.loadScripts();
        },
        async executeScript() {
            this._busy.executeScript = true;
            try {
                this.consoleOut = (await this._httpRequestWithErrorReporting(async () => (await api.post(`http://localhost/api/pysim/run_script/${this.simScriptFormContent.scriptName}`, {adm: this.simScriptFormContent.adm})).data, 'Error: {{ error_detail }} when trying to write to SIM.'));
            } catch {}
            this._busy.executeScript = false;
        },
        clearWriterContent() {
            if(this.types.includes(SIM_DEFAULT_TYPE)) this.simWriterContent.type = SIM_DEFAULT_TYPE;
            this.simWriterContent.mcc = '';
            this.simWriterContent.mnc = '';
            this.simWriterContent.imsi = '';
            this.simWriterContent.ki = '';
            this.simWriterContent.opc = '';
            this.simWriterContent.adm = '';
        }
    }
});
