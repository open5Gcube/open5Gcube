#!/bin/bash

# Wrapper script to run a command with "high performance"

declare ORIG_CPU_GOVERNOR
save_cpu_scaling_governor() {
    ORIG_CPU_GOVERNOR=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor)
}
set_cpu_scaling_governor() {
    echo Set CPU scaling_governor to ${1}
    echo "${1}" | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor >/dev/null
}

declare -A CPU_IDLE_STATES
save_cpu_idle_state() {
    for file in /sys/devices/system/cpu/cpu*/cpuidle/state*/disable; do
        CPU_IDLE_STATES[${file}]=$(cat ${file})
    done
}
disable_cpu_idle_state() {
    echo Disable CPU idle states
    for file in "${!CPU_IDLE_STATES[@]}"; do
        echo 1 > ${file}
    done
}
restore_cpu_idle_state() {
    echo Restore CPU idle states
    for file in "${!CPU_IDLE_STATES[@]}"; do
        echo ${CPU_IDLE_STATES[$file]} > ${file}
    done
}

save_state() {
    save_cpu_scaling_governor
    save_cpu_idle_state
}
set_performance_state() {
    set_cpu_scaling_governor performance
    disable_cpu_idle_state
}
restore_state() {
    set_cpu_scaling_governor ${ORIG_CPU_GOVERNOR}
    restore_cpu_idle_state
}

shutdown_handler() {
    if [ -n "${CHILD_PID}" ]; then
        kill -TERM "${CHILD_PID}" 2>/dev/null
        wait "${CHILD_PID}"
        EXIT_STATUS=$?
    else
        EXIT_STATUS=1
    fi
    restore_state
    exit ${EXIT_STATUS}
}

save_state
trap 'shutdown_handler' SIGTERM SIGINT
set_performance_state

# Execute the passed command in the background
echo "$@"
nice -n -20 "$@" &
CHILD_PID=$!
ps -eo pid,comm,ni,cls,rtprio -f ${CHILD_PID}

wait ${CHILD_PID}
EXIT_STATUS=$?

restore_state
exit ${EXIT_STATUS}
