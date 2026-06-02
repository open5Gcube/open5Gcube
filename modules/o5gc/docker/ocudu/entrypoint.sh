#!/bin/bash

set -ex

srv=$1
[ "${UHD_IMAGE_LOADER}" == "1" ] && srv=uhd_image_loader

case "${srv}" in
    gnb | cu | cu-cp | cu-up | du | uhd_image_loader)
    if /docker-remote.sh --check; then
        exec /docker-remote.sh $1
    fi
esac

cd /o5gc/ocudu
envsubst.sh /mnt/ocudu/${srv}.yaml ./${srv}.yaml

case "${srv}" in
    gnb)
        wait-for-it -t 60 ${AMF_IP_ADDR}:7777
        exec /perf-wrapper.sh ./build/apps/gnb/gnb -c gnb.yaml
        ;;
    cu)
        wait-for-it -t 60 ${AMF_IP_ADDR}:7777
        exec /perf-wrapper.sh ./build/apps/cu/ocu -c cu.yaml
        ;;
    cu_cp)
	    wait-for-it -t 60 ${AMF_IP_ADDR}:7777
        exec /perf-wrapper.sh ./build/apps/cu_cp/ocucp -c cu_cp.yaml
        ;;
    cu_up)
        retry --until=success --times=10 --delay=5 -- ncat -z --sctp ${CU_CP_RAN_IP_ADDR} 38472
        exec /perf-wrapper.sh ./build/apps/cu_up/ocuup -c cu_up.yaml
        ;;
    du)
        retry --until=success --times=10 --delay=5 -- ncat -z --sctp ${CU_CP_RAN_IP_ADDR} 38472
        exec /perf-wrapper.sh ./build/apps/du/odu -c du.yaml
        ;;
    uhd_image_loader)
        (set +x;
        for i in $(seq 10 -1 1); do
            echo "USRP will be flashed now. Press CTRL-C to abort. ($i)"
            sleep 1s
        done) 2>/dev/null
        uhd_image_loader --args type=x300,addr=192.168.40.2
        ;;
esac
