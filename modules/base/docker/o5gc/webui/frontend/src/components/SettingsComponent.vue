<template>
    <q-card style="min-width: 300px" :dark="darkIsActive()">
        <q-card-section class="bg-primary">
            <div class="text-h6 text-white">Settings</div>
        </q-card-section>

        <q-card-section>
            <q-item-label header :class="darkIsActive() ? 'text-white' : 'text-black'">Dark Mode</q-item-label>
            <q-item dense>
                <q-item-section avatar>
                    <q-icon name="contrast" />
                </q-item-section>
                <q-item-section>
                    <q-btn-toggle
                        v-model="darkMode"
                        toggle-color="primary"
                        :options="[
                            {label: 'Dark', value: true},
                            {label: 'Light', value: false},
                            {label: 'Default', value: 'auto'}
                        ]"
                        @update:model-value="val => setDark(val)"
                    />
                </q-item-section>
            </q-item>

            <q-item-label header :class="darkIsActive() ? 'text-white' : 'text-black'">Log Lines</q-item-label>
            <q-item dense>
                <q-item-section avatar>
                    <q-icon name="receipt_long"><q-tooltip>The number of log lines to load and show for each service.</q-tooltip></q-icon>
                </q-item-section>
                <q-item-section>
                    <q-input
                        v-model.number="logLines"
                        type="number"
                        filled
                        style="max-width: 200px"
                        :rules="[val => {if (val < 0) { logLines=0; return 'Number of lines cannot be negative' } else return true},
                                 val => (val < 10000) || 'Expect performance issues',
                                 val => {if (!/^\d+$/.test(val)) {logLines=0; return 'Number of lines must be numeric.'} else return true}]"
                    />
                </q-item-section>
            </q-item>
        </q-card-section>

        <q-card-actions align="right">
          <q-btn label="OK" v-close-popup color="primary" />
        </q-card-actions>

    </q-card>
</template>

<script>
import { storeToRefs } from 'pinia';
import { useSettingsStore } from 'src/stores/settings';
import { ref } from 'vue';
import { useQuasar } from 'quasar';

export default {
    setup() {
        const settingsStore = useSettingsStore();
        const { logLines, dark } = storeToRefs(settingsStore);
        const { setDark } = settingsStore;

        const darkMode = ref(dark);
        return { darkMode, logLines, setDark };
    },
    methods: {
        darkIsActive() {
            return useQuasar().dark.isActive;
        }
    }
}

</script>
