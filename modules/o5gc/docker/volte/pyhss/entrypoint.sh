#!/bin/bash

set -ex

add_subscriber () {
    imsi=$1; key=$2; opc=$3; id=$4
    msisdn=${imsi: -5}
    /mnt/volte/pyhss/pyhss-tool.py subscriber-create                          \
        --imsi ${imsi} --msisdn ${msisdn} --k ${key} --opc ${opc}
}

cd /o5gc/pyhss
envsubst.sh /mnt/volte/pyhss/config.yaml ./config.yaml

wait-for-it -t 60 ${MYSQL_IP_ADDR}:3306
sleep 1

/usr/bin/redis-server /etc/redis/redis.conf &

cd /o5gc/pyhss/services

python3 hssService.py &
sleep 5
python3 diameterService.py &
sleep 5
python3 apiService.py &
sleep 5

wait-for-it 127.0.0.1:8080
sleep 1

{ set +x; } 2>/dev/null
source /mnt/o5gc/core-init.sh
call_for_each_subscriber add_subscriber
set -x

mkdir -p /var/log/pyhss
cd /var/log/pyhss
touch hss.log diameter.log geored.log metrics.log
tail -f ./*
