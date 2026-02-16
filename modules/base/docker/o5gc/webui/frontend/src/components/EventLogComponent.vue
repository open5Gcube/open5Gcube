<template>
    <q-table
      flat
      bordered
      title="Log Events"
      dense
      class="eventlog-sticky-dynamic full-height"
      :columns="columns"
      :rows="Object.values(eventLog)"
      :filter="filter"
      v-model:pagination="pagination"
      row-key="event_id"
    >
      <template v-slot:top>
          <span class="text-bold text-h6">Event Log</span>
          <q-space />
          <q-btn color="negative" label="Clear Log" class="q-mx-sm" @click="clear_log" />
          <q-input dense outlined debounce="300" color="positive" v-model="filter" input-style="line-height: 10px;" :dark="$q.dark.isActive">
              <template v-slot:append>
                  <q-icon name="search" />
              </template>
          </q-input>
      </template>
      <template v-slot:body-cell-event_id="props">
        <q-td :props="props" @click="resultDetailDialog = true; resultDetailDialogId = props.row.event_id" class="cursor-pointer">
          {{ props.value }}
        </q-td>
      </template>
      <template v-slot:body-cell-start_timestamp="props">
        <q-td :props="props" @click="resultDetailDialog = true; resultDetailDialogId = props.row.event_id" class="cursor-pointer">
          {{ props.value }}
        </q-td>
      </template>
      <template v-slot:body-cell-end_timestamp="props">
        <q-td :props="props" @click="resultDetailDialog = true; resultDetailDialogId = props.row.event_id" class="cursor-pointer">
          {{ props.value }}
        </q-td>
      </template>
      <template v-slot:body-cell-description="props">
        <q-td :props="props" @click="resultDetailDialog = true; resultDetailDialogId = props.row.event_id" class="cursor-pointer">
          {{ props.value }}
        </q-td>
      </template>
      <template v-slot:body-cell-status="props">
        <q-td :props="props" @click="resultDetailDialog = true; resultDetailDialogId = props.row.event_id" class="cursor-pointer">
          {{ props.value }}
        </q-td>
      </template>
      <template v-slot:body-cell-result="props">
        <q-td :props="props" @click="resultDetailDialog = true; resultDetailDialogId = props.row.event_id" class="cursor-pointer">
          {{ props.value }} <q-icon v-if="props.row.result_detail != ''" name="info"></q-icon>
        </q-td>
      </template>
      <template v-slot:body-cell-delete="props">
          <q-td :props="props">
              <div>
                  <q-icon :name="symOutlinedDelete" style="font-size: large;" class="text-negative q-mx-xs cursor-pointer"><q-tooltip>Delete</q-tooltip>
                      <q-menu>
                          <q-list dense>
                              <q-item clickable @click="delete_event(props.row.event_id)" v-close-popup>
                                  <q-item-section avatar><q-icon :name="symOutlinedDelete" class="text-negative" /></q-item-section>
                                  <q-item-section>Delete</q-item-section>
                              </q-item>
                          </q-list>
                      </q-menu>
                  </q-icon>
              </div>
          </q-td>
      </template>
      <template v-slot:bottom><!-- Empty bottom to save space (pagination isn't used anyways) --></template>
    </q-table>
    <q-dialog v-model="resultDetailDialog">
      <q-card style="max-width: 75vw;">
        <q-card-section class="text-white" :class="{'IN_PROGRESS': 'bg-primary', 'SUCCESSFUL': 'bg-positive', 'FAILED': 'bg-negative'}[eventLog[resultDetailDialogId].status]">
          <div class="text-h6">Result Details</div>
        </q-card-section>

        <q-separator />

        <q-card-section>
          <div>
            <b>Start:</b> {{ eventLog[resultDetailDialogId].start_timestamp }}<br />
            <b>End:</b> {{ eventLog[resultDetailDialogId].end_timestamp }}<br />
            <b>Description:</b> {{ eventLog[resultDetailDialogId].description }}<br />
            <b>Result:</b> {{ eventLog[resultDetailDialogId].result }}<br />
            <b>Status:</b> {{ eventLog[resultDetailDialogId].status }}<br />
          </div>
        </q-card-section>

        <q-separator />

        <q-card-section style="max-height: 50vh; white-space: pre; word-break: break-word; font-family: monospace;" class="scroll">
          <div style="word-break: break-word; white-space: pre-wrap;">{{ eventLog[resultDetailDialogId].result_detail }}</div>
        </q-card-section>

        <q-separator />

        <q-card-actions align="right">
          <q-btn label="CLOSE" v-close-popup color="primary" />
        </q-card-actions>
      </q-card>
    </q-dialog>
</template>

<script>

import { useEventLogStore } from 'src/stores/event-log';
import { storeToRefs } from 'pinia'
import { getCssVar, useQuasar } from 'quasar'
import { watch, ref } from 'vue';
import { symOutlinedDelete } from '@quasar/extras/material-symbols-outlined';

function formatDate(date) {
  const today = new Date();
  if(date) {
    const val = new Date(date);
    if(val.getDate() === today.getDate() && val.getMonth() === today.getMonth() && val.getFullYear() === today.getFullYear())
      return val.toLocaleString([], {hour: '2-digit', minute: '2-digit', second: '2-digit'});
    else
      return val.toLocaleString([], {weekday: 'short', day: 'numeric', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit', second: '2-digit'});
  }
  else return '-';
}

export default {

    setup() {
      const $q = useQuasar();

      const eventLogStore = useEventLogStore();
      const { eventLog } = storeToRefs(eventLogStore);
      const { delete_event, clear_log } = eventLogStore;
      const filter = ref('');

      const resultDetailDialog = ref(false);
      const resultDetailDialogId = ref(null);

      const pos_color = getCssVar('positive');
      const neg_color = getCssVar('negative');

/*    // Doesn't work for some reason
      const pos_dark  = getCssVar('positive-dark');
      const neg_dark  = getCssVar('negative-dark');
      const pos_light = getCssVar('positive-light');
      const neg_light = getCssVar('negative-light');
*/
      const pos_dark = '#1E3724';
      const neg_dark = '#38181C';
      const pos_light = '#DAF4E0';
      const neg_light = '#F5D5D8';

      const columns = ref([]);

      const pagination = ref({
        sortBy: 'start_timestamp',
        descending: true,
        rowsPerPage: 0
      })

      function backgroundCss(row) {
        if(row.status != 'SUCCESSFUL' && row.status != 'FAILED') return '';
        if($q.dark.isActive) {
            if(row.status == 'SUCCESSFUL') return `background-color: ${pos_dark};`;
            else return `background-color: ${neg_dark};`;
        }
        else {
            if(row.status == 'SUCCESSFUL') return `background-color: ${pos_light};`;
            else return `background-color: ${neg_light};`;
        }
      };

      // extra function to account for dark / light mode updates
      function set_columns() {
        columns.value = [
            {
                name: 'event_id',
                required: true,
                label: 'ID',
                align: 'left',
                field: 'event_id',
                sortable: true,
                style: row => 'width: 0px; ' + backgroundCss(row) // ensures minimum width
            },
            {
                name: 'start_timestamp',
                label: 'Start',
                align: 'left',
                field: 'start_timestamp',
                format: formatDate,
                sortable: true,
                style: row => 'width: 0px; ' + backgroundCss(row) // ensures minimum width

            },
            {
                name: 'end_timestamp',
                label: 'End',
                align: 'left',
                field: 'end_timestamp',
                format: formatDate,
                sortable: true,
                style: row => 'width: 0px; ' + backgroundCss(row) // ensures minimum width
            },
            {
                name: 'description',
                label: 'Description',
                align: 'left',
                field: 'description',
                sortable: false,
                style: row => backgroundCss(row)
            },
            {
                name: 'result',
                label: 'Result',
                align: 'left',
                field: 'result',
                sortable: false,
                style: row => 'width: 100%; ' + backgroundCss(row) // ensures maximum width
            },
            {
                name: 'status',
                label: 'Status',
                align: 'left',
                field: 'status',
                sortable: true,
                style: row => {return 'width: 0px; ' + (
                    row.status == 'SUCCESSFUL' ? `background-color: ${pos_color}; color: white` :
                    row.status == 'FAILED' ? `background-color: ${neg_color}; color: white` : '')}
            },
            {
                name: 'delete',
                label: 'Delete'
            }
        ]
      }

      set_columns();

      // Whenever dark / light mode changes, update the column background colors accordingly
      watch(
        () => $q.dark.isActive,
        () => set_columns()
      );

      return {
        eventLog, columns, pagination, resultDetailDialog, resultDetailDialogId, symOutlinedDelete, delete_event, clear_log, filter
      };
    }
}
</script>
<style lang="sass">
.eventlog-sticky-dynamic
  /* height or max-height is important */

  .q-table__top,
  .q-table__bottom,
  thead tr:first-child th /* bg color is important for th; just specify one */
    background-color: #fff /* Default to white for light mode */

  // Eliminate table bottom
  .q-table__bottom
    min-height: 0px !important
    margin: 0px !important
    padding: 0px !important

  thead tr th
    position: sticky
    z-index: 1
  /* this will be the loading indicator */
  thead tr:last-child th
    /* height of all previous header rows */
    top: 48px
  thead tr:first-child th
    top: 0

  /* prevent scrolling behind sticky top row on focus */
  tbody
    /* height of all previous header rows */
    scroll-margin-top: 48px

/* Override for Dark Mode using Quasar global body class */
.body--dark .eventlog-sticky-dynamic
  .q-table__top,
  .q-table__bottom,
  thead tr:first-child th
    background-color: $dark

</style>
