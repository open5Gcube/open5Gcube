<template>
    <div class="full-height">
        <q-table
          class="my-sticky-dynamic full-height"
          title="UE Database"
          :rows="ueDb"
          :columns="columns"
          :pagination="pagination"
          :filter="filter"
          :loading="_busy.loadUeDb"
          row-key="id"
          dense square>
            <template v-slot:top>
                <span class="text-bold text-h6 text-white">UE Database</span>
                <q-space />
                <q-btn color="positive" :disable="true" label="Add UE" class="q-mx-sm" @click="addRow" />
                <q-input dense outlined debounce="300" color="positive" v-model="filter" input-style="line-height: 10px;" :dark="true">
                    <template v-slot:append>
                        <q-icon name="search" />
                    </template>
                </q-input>
            </template>
            <template v-slot:body-cell-imsi="props">
                <q-td :props="props">
                    <span style="font-family: monospace;">{{ props.value }}</span>
                </q-td>
            </template>
            <template v-slot:body-cell-key="props">
                <q-td :props="props">
                    <span style="font-family: monospace;">{{ props.value }}</span>
                </q-td>
            </template>
            <template v-slot:body-cell-opc="props">
                <q-td :props="props">
                    <span style="font-family: monospace;">{{ props.value }}</span>
                </q-td>
            </template>
            <template v-slot:body-cell-functions="props">
                <q-td :props="props">
                    <div>
                        <q-icon name="edit" style="font-size: large;" class="q-mx-xs cursor-not-allowed"><q-tooltip>Edit</q-tooltip></q-icon>
                        <q-icon name="keyboard_double_arrow_down" @click="copyUeDataToWriterContent(props.row.imsi, props.row.key, props.row.opc)" style="font-size: large;" class="q-mx-xs cursor-pointer"><q-tooltip>Copy to SIM Writer</q-tooltip></q-icon>
                        <q-icon :name="symOutlinedDelete" style="font-size: large;" class="text-negative q-mx-xs cursor-not-allowed"><q-tooltip>Delete</q-tooltip>
                            <q-menu>
                                <q-list dense>
                                    <q-item clickable :disable="true" v-close-popup>
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
    </div>
</template>

<script>
import { symOutlinedDelete } from '@quasar/extras/material-symbols-outlined'
import { useSimWriterStore } from 'src/stores/simWriter';
import { storeToRefs } from 'pinia';
import { onMounted, ref } from 'vue';


const columns = [
    {
        name: 'id',
        required: true,
        label: 'ID',
        align: 'left',
        field: 'id',
        sortable: true
    },
    {
        name: 'imsi',
        label: 'IMSI',
        field: 'imsi',
        sortable: true
    },
    {
        name: 'key',
        label: 'Key',
        field: 'key',
        sortable: false
    },
    {
        name: 'opc',
        label: 'OPC',
        field: 'opc',
        sortable: false
    },
    {
        name: 'functions',
        label: 'Functions'
    }
]

export default {
    setup() {
        const simWriterStore = useSimWriterStore();
        const { ueDb, _busy } = storeToRefs(simWriterStore);
        const copyUeDataToWriterContent = simWriterStore.copyUeDataToWriterContent

        const filter = ref('');

        const pagination = ref({
            rowsPerPage: 0
        });

        async function loadData() {
            simWriterStore.loadUeDb();
        }

        onMounted(() => loadData());

        return {
            columns, symOutlinedDelete, ueDb, pagination, filter, copyUeDataToWriterContent, _busy
        }
    }
}

</script>
<style lang="sass">
.my-sticky-dynamic
  /* height or max-height is important */

  .q-table__top,
  .q-table__bottom,
  thead tr:first-child th /* bg color is important for th; just specify one */
    background-color: $primary

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

  th
    color: white
</style>
