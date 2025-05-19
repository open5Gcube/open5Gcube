#!/bin/bash

set -ex

service=$1
mnt=/mnt/free5gc

if [[ -z "${service}" ]]; then
    echo "Error: first argument SERVICE not set!"
    exit 1
fi

export NSSAI_SD=$(printf "%06x" "${NSSAI_SD/#0x}")
envsubst.sh ${mnt}/${service}cfg.yaml /o5gc/free5gc/config/${service}cfg.yaml

if [[ "${service}" == "upf" ]]; then
    if [[ "${INSTALL_GTP5G_MODULE}" == "1" ]]; then
        pushd /o5gc/gtp5g
        make -j $(nproc)
        /lib/modules/$(uname -r)/build/scripts/sign-file sha256               \
            /mnt/o5gc/ssl/MOK.priv /mnt/o5gc/ssl/MOK.der ./gtp5g.ko
        modprobe udp_tunnel
        rmmod gtp5g || true
        insmod ./gtp5g.ko
        popd
    fi
    iptables -t nat -A POSTROUTING -s 192.168.100.0/24 ! -o upfgtp -j MASQUERADE
    service ssh start
fi

wait-for-it -t 30 ${MONGO_IP_ADDR}:27017

case "${service}" in
    webui)
        wait-for-it -t 30 ${NRF_IP_ADDR}:7777
        cd webconsole
        exec ./webconsole -c /o5gc/free5gc/config/webuicfg.yaml
        ;;
    nrf | upf | amf | ausf | nssf | pcf | smf | udm | udr)
        if [[ "${service}" != "nrf" ]]; then
            wait-for-it -t 30 ${NRF_IP_ADDR}:7777
            while [[ -n "$(dig +short free5gc-init)" ]]; do sleep 2; done
            sleep 1
        fi
        exec /o5gc/free5gc/bin/${service} -c /o5gc/free5gc/config/${service}cfg.yaml
        ;;
    *)
        echo "Error: Invalid SERVICE: ${service}"
        exit 1
        ;;
esac
