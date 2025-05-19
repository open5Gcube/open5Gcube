#!/bin/bash

set -ex

add_subscriber () {
    imsi=$1; key=$2; opc=$3; id=$4
    msisdn=${imsi: -5}
    /mnt/volte/pyhss/pyhss-tool.py subscriber-create                          \
        --imsi ${imsi} --msisdn ${msisdn} --k ${key} --opc ${opc}
}
add_subscriptions () {
#    { set +x; } 2>/dev/null
    count=0
    for i in $(seq 0 100); do
        ue=UE_$i
        [[ -z "${!ue}" ]] && continue
        read -r imsi key opc <<< "${!ue}"
        add_subscriber $imsi $key $opc $i
        count=$((count+1))
    done
#    { set -x; } 2>/dev/null
}

cd /o5gc/pyhss
envsubst.sh /mnt/volte/pyhss/config.yaml ./config.yaml

wait-for-it ${MYSQL_IP_ADDR}:3306
sleep 1

/etc/init.d/redis-server start

mkdir /var/log/pyhss
cd /var/log/pyhss
touch hss.log diameter.log geored.log metrics.log

cd /o5gc/pyhss/services

python3 hssService.py &
sleep 1
python3 diameterService.py &
sleep 1
python3 apiService.py &
sleep 1

wait-for-it 127.0.0.1:8080
sleep 1

add_subscriptions

tail -f /var/log/pyhss/*
