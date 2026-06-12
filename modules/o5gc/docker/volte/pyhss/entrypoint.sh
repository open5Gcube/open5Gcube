#!/bin/bash

set -ex

add_subscriber () {
    imsi=$1; key=$2; opc=$3; id=$4
    msisdn=${imsi: -5}
    /mnt/volte/pyhss/pyhss-tool.py subscriber-create                          \
        --imsi ${imsi} --msisdn ${msisdn} --k ${key} --opc ${opc}
    echo "added imsi: $imsi with key: $key opc: $opc"
}

cd /o5gc/pyhss
envsubst.sh /mnt/volte/pyhss/config.yaml ./config.yaml
cp /mnt/volte/pyhss/*.xml ./

wait-for-it -t 60 ${MYSQL_IP_ADDR}:3306
sleep 1

/usr/bin/redis-server /etc/redis/redis.conf --daemonize yes

cd /o5gc/pyhss/services

mkdir -p /var/log/pyhss
export PYTHONUNBUFFERED=1

python3 apiService.py >/var/log/pyhss/api.log 2>&1 &
sleep 5
python3 diameterService.py >/var/log/pyhss/diameter.log 2>&1 &
sleep 5
python3 hssService.py >/var/log/pyhss/hss.log 2>&1 &

wait-for-it 127.0.0.1:8080
sleep 1

{ set +x; } 2>/dev/null
source /mnt/o5gc/core-init.sh
call_for_each_subscriber add_subscriber
set -x

tail -f /var/log/pyhss/*.log
