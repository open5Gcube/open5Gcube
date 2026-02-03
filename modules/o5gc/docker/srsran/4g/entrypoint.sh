#!  /bin/bash

term_handler()
{
    if [[ -n "${srsue_pid}" ]]; then
        kill ${srsue_pid}
        wait ${srsue_pid}
    fi
    exit 0
}

trap 'term_handler' SIGTERM

set -ex

srv=$1
[ "${UHD_IMAGE_LOADER}" == "1" ] && srv=uhd_image_loader

case "${srv}" in
    enb | gnb | uhd_image_loader)
    if /docker-remote.sh --check; then
        exec /docker-remote.sh $1
    fi
esac

[ -f /mnt/srsran/${srv}.conf ] && envsubst.sh /mnt/srsran/${srv}.conf ${srv}.conf

add_user () {
    imsi=$1; key=$2; opc=$3; id=$4
    # Format: Name,Auth,IMSI,Key,OP_Type,OP/OPc,AMF,SQN,QCI,IP_alloc
    echo ue${i},mil,${imsi},${key},opc,${opc},8000,000000001234,7,dynamic >> user_db.csv
}

case "${srv}" in
    enb | gnb)
        envsubst.sh /mnt/srsran/rr_${srv}.conf rr_${srv}.conf
        envsubst.sh /mnt/srsran/rb.conf rb.conf
        envsubst.sh /mnt/srsran/sib.conf sib.conf
        exec build/srsenb/src/srsenb ${srv}.conf
        ;;
    epc)
        { set +x; } 2>/dev/null
        source /mnt/o5gc/core-init.sh
        call_for_each_subscriber add_user
        { set -x; } 2>/dev/null
        iptables -t nat -A POSTROUTING -o $(route | grep '^default' | grep -o '[^ ]*$') -j MASQUERADE
        exec build/srsepc/src/srsepc ${srv}.conf
        ;;
    ue)
        build/srsue/src/srsue ${srv}.conf &
        srsue_pid=$!
        { set +x; } 2>/dev/null
        while [ ! -d /sys/class/net/tun_srsue ]; do
            echo "Waiting for 'tun_srsue' to come up"
            sleep 1
        done
        set -x
        ip route del default
        ip route add default dev tun_srsue
        route -n
        wait -n $srsue_pid
        ;;
    uhd_image_loader)
        (set +x;
        for i in $(seq 10 -1 1); do echo "USRP will be flashed now. Press CTRL-C to abort. ($i)"; sleep 1s; done
        ) 2>/dev/null
        uhd_image_loader --args type=x300,addr=192.168.40.2
        ;;
esac
