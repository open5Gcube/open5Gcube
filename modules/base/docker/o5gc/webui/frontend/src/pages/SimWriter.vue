<template>
  <q-page class="column full-height">
        <q-resize-observer @resize="onResize" :debounce="0" />
        <q-splitter v-model="splitterPixel" :reverse="true" horizontal unit="px" style="min-height: 100%; height: 100%;" class="column">
          <template v-slot:before>
            <div class="row column q-px-sm q-py-xs full-height">
              <UeDbComponent />
            </div>
          </template>
          <template v-slot:after>
            <div class="row full-height q-mx-xs">
              <div class="col-xs-12 col-md-4">
                <div class="q-pa-xs"><SimReaderComponent /></div>
                <div class="q-pa-xs"><SimWriterComponent /></div>
              </div>
              <div class="col-xs-12 col-md-8 full-height q-pa-xs">
                <SimConsoleOutComponent />
              </div>
            </div>
          </template>
        </q-splitter>
  </q-page>
</template>

<script>
import UeDbComponent from 'src/components/UeDbComponent.vue'
import SimReaderComponent from 'src/components/SimReaderComponent.vue'
import SimWriterComponent from 'src/components/SimWriterComponent.vue'
import SimConsoleOutComponent from 'src/components/SimConsoleOutComponent.vue'
import {ref} from 'vue';

export default {

  setup() {
    const splitterPixel = ref(539);

    // Page resize event handler
    const onResize = (size) => {
      const UE_DB_MIN_HEIGHT = 136;
      const WRITER_HEIGHT = 539;

      // Update splitterPixel value
      // If UE DB and writer both fit, show full writer and whatever space remains for UE DB.
      if(size.height >= UE_DB_MIN_HEIGHT + WRITER_HEIGHT) splitterPixel.value = WRITER_HEIGHT;
      // Else, if only writer fully fits but not UE DB, make sure UE DB is still shown and add a scroll bar to writer
      else if(size.height >= UE_DB_MIN_HEIGHT) splitterPixel.value = size.height - UE_DB_MIN_HEIGHT;
      // Else, if writer doesn't even fully fit, do a best effort solution and just split half and half.
      else splitterPixel.value = size.height / 2;
    };

    return {
      splitterPixel,
      onResize
    };
  },
  created() {
    this.$emit('tabs', [])
    this.$emit('toolbarTitleContent', 'SIM Writer')
  },
  components: { UeDbComponent, SimReaderComponent, SimWriterComponent, SimConsoleOutComponent }

}

</script>
