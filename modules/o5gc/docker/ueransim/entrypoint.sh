#!/bin/bash

set -ex

service=$1

if [[ -z "${service}" ]]; then
    echo "Error: first argument SERVICE not set!";
    exit 1;
fi

[[ "${service}" == "gnb" ]] && wait-for-it -t 60 ${AMF_IP_ADDR}:7777
[[ "${service}" == "ue" ]] && retry --until=success --times=10 --delay=5 -- nc -v -z -u ${GNB_RF_IP_ADDR} 4997

# wait until 'init' container is finished
while [[ -n "$(dig +short open5gs-init)" ]]; do sleep 2; done
while [[ -n "$(dig +short li-init)" ]]; do sleep 2; done

[ "${NSSAI_SD}" == "ffffff" ] && export NSSAI_SD=0x${NSSAI_SD}
envsubst.sh /mnt/ueransim/${service}.yaml config/${service}.yaml

exec ./build/nr-${service} -c config/${service}.yaml
