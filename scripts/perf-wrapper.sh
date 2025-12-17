#!/bin/bash

# Wrapper script to run a command with "performance" CPU governor

restore_gov() {
    echo Restore CPU scaling_governor to ${ORIG_GOV}
    echo "${ORIG_GOV}" | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor >/dev/null
}

shutdown_handler() {
    if [ -n "${CHILD_PID}" ]; then
        kill -TERM "${CHILD_PID}" 2>/dev/null
        wait "${CHILD_PID}"
        EXIT_STATUS=$?
    else
        EXIT_STATUS=1
    fi    
    restore_gov
    exit ${EXIT_STATUS}
}

ORIG_GOV=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor)
echo Set CPU scaling_governor to performance
echo "performance" | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor >/dev/null

trap 'shutdown_handler' SIGTERM SIGINT

# Execute the passed command in the background
echo "$@"
"$@" &
CHILD_PID=$!

wait ${CHILD_PID}
EXIT_STATUS=$?

restore_gov
exit ${EXIT_STATUS}
