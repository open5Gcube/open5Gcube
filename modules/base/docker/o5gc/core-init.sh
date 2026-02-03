#!/usr/bin/env bash

function load_env {
    source <(grep -Ev '^[[:space:]]*#|^[[:space:]]*$' ${1})
}

load_env /mnt/o5gc/etc/uedb.env
if [ -d "/mnt/o5gc/etc/uedb.d/" ]; then
    for envfile in /mnt/o5gc/etc/uedb.d/*.env; do
        load_env "${envfile}"
    done
fi

function call_for_each_subscriber {
    i=1
    while IFS= read -r subscriber ; do
        [[ -z "${subscriber}" ]] && continue
        read -r imsi key opc <<< "${subscriber}"
        ${1} ${imsi} ${key} ${opc} ${i}
        i=$((i + 1))
    done <<< "${UE_DB}"
    ${1} ${MCC}${MNC}${UE_SOFT_MSIN} ${UE_SOFT_KEY} ${UE_SOFT_OPC} ${i}
    for j in $(seq 0 100); do
        i=$((i + 1))
        msin=UE_SOFT_MSIN_$j
        key=UE_SOFT_KEY_$j
        opc=UE_SOFT_OPC_$j
        [[ -z "${!msin}" ]] && continue
        ${1} ${MCC}${MNC}${!msin} ${!key} ${!opc} ${i}
    done
}
