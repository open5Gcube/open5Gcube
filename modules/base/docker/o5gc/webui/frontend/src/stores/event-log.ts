import { defineStore } from 'pinia';

/*
 * Format of event log store:
 * {
 *   "event_log": {
 *     42: {
 *       "event_id": 42,
 *       "start_timestamp": "2023-12-24T12:34:56",
 *       "end_timestamp": "2023-12-24T12:45:56",
 *       "status": "SUCCESSFUL", // "IN_PROGRESS", "SUCCESSFUL", "FAILED"
 *       "description": "Start stack oai",
 *       "result": "OK",
 *     }
 *   }
 * }
 *
 * Getters:
 * -
 *
 * Actions:
 * - start_event
 * - end_event
 *
 */

type LogEventType = {
    'event_id': number,
    'start_timestamp': string,
    'end_timestamp': string | null,
    'status': 'IN_PROGRESS' | 'SUCCESSFUL' | 'FAILED',
    'description': string,
    'result': string,
    'result_detail': string
}

export const useEventLogStore = defineStore('event-log', {
  state(){
    const eventLog: {[key: number]: LogEventType} = {};
    const nextKey = 0;

    return {
        eventLog, nextKey
    }
  },
  getters: {

  },
  actions: {
    start_event(description: string) {
        const key = this.nextKey;
        this.nextKey++;

        const event: LogEventType = {
            'event_id': key,
            'start_timestamp': new Date().toISOString(),
            'end_timestamp': null,
            'status': 'IN_PROGRESS',
            'description': description,
            'result': '',
            'result_detail': ''
        }

        this.eventLog[key] = event;
        return key;
    },

    end_event(key: number, status: 'SUCCESSFUL' | 'FAILED', result: string, result_detail = '') {
        // Event might have been deleted in the mean time
        if(!(key in this.eventLog)) return;
        this.eventLog[key].end_timestamp = new Date().toISOString();
        this.eventLog[key].status = status;
        this.eventLog[key].result = result;
        this.eventLog[key].result_detail = result_detail;
    },

    delete_event(key: number) {
      delete this.eventLog[key];

      // If store is empty, reset the next id to 0 so ids don't become too large.
      // Theoretically this creates a race condition where old answers can be assigned to younger events.
      // This race condition should not be practically relevant.
      if(Object.keys(this.eventLog).length == 0) this.nextKey = 0;
    },

    clear_log() {
      this.eventLog = {};
      this.nextKey = 0;
    }
  },
  persist: {
    enabled: true,
    strategies: [
      {storage: localStorage}
    ]
  }
});
