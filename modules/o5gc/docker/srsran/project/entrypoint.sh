#!  /bin/bash

set -ex

srv=$1
[ "${UHD_IMAGE_LOADER}" == "1" ] && srv=uhd_image_loader

case "${srv}" in
    enb | gnb | uhd_image_loader)
    if /docker-remote.sh --check; then
        exec /docker-remote.sh $1
    fi
esac

case "${srv}" in
    gnb)
        envsubst.sh /mnt/srsran/gnb.yaml gnb.yaml
        wait-for-it -t 30 ${AMF_IP_ADDR}:7777
        exec ./build/apps/gnb/gnb -c gnb.yaml -c /mnt/srsran/qos.yaml
        ;;
    uhd_image_loader)
        (set +x;
        for i in $(seq 10 -1 1); do echo "USRP will be flashed now. Press CTRL-C to abort. ($i)"; sleep 1s; done
        ) 2>/dev/null
        uhd_image_loader --args type=x300,addr=192.168.40.2
        ;;
esac
