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

wait-for-it ${MYSQL_IP_ADDR}:3306
[[ "${service}" != "nrf" ]] && wait-for-it -t 30 ${NRF_IP_ADDR}:7777
[[ "${service}" == "smf" ]] && retry --until=success --times=10 --delay=1 -- nc -v -z -u  ${UPF_IP_ADDR} 2152

exec /o5gc/oai-cn5g-${service}/build/${service}/build/${service} -c ${config} -o
