#!/bin/bash

set -ex

service=$1
mnt=/mnt/ellacore

if [[ -z "${service}" ]]; then
    echo "Error: first argument SERVICE not set!"
    exit 1
fi

envsubst.sh ${mnt}/${service}.yaml ${service}.yaml
cat ${service}.yaml

cat /etc/image_version
case "${service}" in
    core)
        exec ./main --config core.yaml
        ;;
    ims)
        # reach the UEs of the ims data network via Ella Core's N6 interface
        ip route replace ${UE_IMS_IP_SUBNET} via ${UPF_EXT_IP_ADDR}
        # Ella Core's UPF forwards the packets as they are, so the UEs would
        # drop UDP and TCP with checksums left to the (veth) offloading
        ethtool -K eth0 tx off
        exec ./ims --config ims.yaml
        ;;
    smsc)
        exec ./smsc --config smsc.yaml
        ;;
    *)
        echo "Error: Invalid SERVICE: ${service}"
        exit 1
        ;;
esac
