#!/bin/bash

set -ex

service=$1
mnt=/mnt/oai

if [[ -z "${service}" ]]; then
    echo "Error: first argument SERVICE not set!";
    exit 1;
fi

export NSSAI_SD=$(printf "%06x" "${NSSAI_SD/#0x}")
config=/o5gc/oai-cn5g-${service}/etc/config.yaml
envsubst.sh ${mnt}/cn5g.yaml ${config}

# healthcheck script expects config file in /openair-${service}/etc
mkdir -p /openair-${service}/etc
ln -s ${config} -t /openair-${service}/etc

cat /etc/image_version

exec /o5gc/oai-cn5g-${service}/build/${service}/build/${service} -c ${config} -o
