#!/bin/bash

set -ex

if [[ "${INSTALL_GTP5G_MODULE}" == "1" ]]; then
    pushd lib/gtp5g
    make -j $(nproc)
    /lib/modules/$(uname -r)/build/scripts/sign-file sha256                   \
        /mnt/o5gc/ssl/MOK.priv /mnt/o5gc/ssl/MOK.der ./gtp5g.ko
    modprobe udp_tunnel
    rmmod gtp5g || true
    insmod ./gtp5g.ko
    popd
fi

if [[ "${OPEN5GS_ROAMING}" == "1" ]]; then
    var="${OPEN5GS_ROAMING_NETWORK}_CORENET_HOST_IP_ADDR"
    export GNB_IP_ADDR=$(ip route get ${!var} | sed -n 's|.* src \([0-9.]*\) .*|\1|p')
fi

wait-for-it -t 30 ${AMF_IP_ADDR}:7777

# wait until all initialisation containers are completed
{ set +x; } 2>/dev/null
while sleep 1; do
    init_containers=$(docker container ls --filter label=o5gc.initialisation --format '{{.Names}}' | tr '\n' ' ')
    if [[ -n "${init_containers}" ]]; then echo "Waiting for completion of initialisation containers: ${init_containers}";
    else break; fi
done
# wait until all core network functions are healthy
while sleep 1; do
    nonhealthy_containers=$(docker container ls --filter label=o5gc.corenetwork-function --filter health=unhealthy --filter health=starting --format '{{.Names}}' | tr '\n' ' ')
    if [[ -n "${nonhealthy_containers}" ]]; then echo "Wait until the core network containers are healthy: ${nonhealthy_containers}";
    else break; fi
done
set -x

[ "${NSSAI_SD}" != "ffffff" ] && NSSAI_SD=$(printf "%06d" ${NSSAI_SD})
NSSAI_SST=$(printf "%02d" ${NSSAI_SST})
TAC=$(printf "%06d" ${TAC})
envsubst.sh /mnt/packetrusher/config.yaml config/config.yml

exec ./packetrusher ue
