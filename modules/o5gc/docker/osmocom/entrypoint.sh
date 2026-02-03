#!/bin/bash

set -ex

service=$1

[ "${UHD_IMAGE_LOADER}" == "1" ] && service=uhd_image_loader

case "${service}" in
    osmo-trx-uhd | uhd_image_loader)
        if /docker-remote.sh --check; then
            exec /docker-remote.sh $1
        fi
        B200_DETECTED="$(lsusb -d 2500:0020 || lsusb -d 2500:0022 || true)"
        if [ -n "${B200_DETECTED}" ]; then
            export USRP_ARGS="type=b200"
        else
            export USRP_ARGS="type=x300,addr=192.168.40.2"
        fi
esac

HLR_DB=/o5gc/osmo-hlr/hlr.db

function add_subscriber () {
    imsi=$1; key=$2; opc=$3; i=$4
    msisdn=${imsi: -5}
    sqlite3 -echo ${HLR_DB} "INSERT INTO subscriber (id, imsi, msisdn) VALUES (${i}, '${imsi}', '${msisdn}');"
    sqlite3 -echo ${HLR_DB} "INSERT INTO auc_2g (subscriber_id, algo_id_2g, ki) VALUES(${i}, 1, '${key}');"
    sqlite3 -echo ${HLR_DB} "INSERT INTO auc_3g (subscriber_id, algo_id_3g, k, op, opc) VALUES(${i}, 5, '${key}', NULL, '${opc}');"
}

function init_hlr () {
    osmo-hlr-db-tool -l ${HLR_DB} create
    { set +x; } 2>/dev/null
    source /mnt/o5gc/core-init.sh
    call_for_each_subscriber add_subscriber
    { set -x; } 2>/dev/null
}

mnt=/mnt/osmocom

if [[ -z "${service}" ]]; then
    echo "Error: first argument SERVICE not set!";
    exit 1;
fi

mkdir -p /etc/osmocom
envsubst.sh ${mnt}/${service}.cfg /etc/osmocom/${service}.cfg

cat /etc/image_version

case "${service}" in
    osmo-hlr)
        init_hlr
        sqlite_web -H 0.0.0.0 -p 8080 -x ${HLR_DB} &> /dev/null &
        osmo-hlr -c /etc/osmocom/osmo-hlr.cfg --database ${HLR_DB}
        ;;
    osmo-stp)
        osmo-stp -c /etc/osmocom/osmo-stp.cfg
        ;;
    osmo-msc)
        wait-for-it ${OSMO_HLR_IP_ADDR}:${OSMO_HLR_GSUP_PORT}
        osmo-msc -c /etc/osmocom/osmo-msc.cfg
        ;;
    osmo-mgw)
        osmo-mgw -c /etc/osmocom/osmo-mgw.cfg
        ;;
    osmo-trx-uhd)
        osmo-trx-uhd -C /etc/osmocom/osmo-trx-uhd.cfg
        ;;
    osmo-bsc)
        wait-for-it ${OSMO_STP_IP_ADDR}:${OSMO_STP_VTY_PORT}
        osmo-bsc -c /etc/osmocom/osmo-bsc.cfg
        ;;
    osmo-bts-trx)
        wait-for-it ${OSMO_BSC_IP_ADDR}:${OSMO_BSC_OML_PORT}
        osmo-bts-trx -c /etc/osmocom/osmo-bts-trx.cfg
        ;;
    osmo-pcu)
        wait-for-it ${OSMO_BTS_IP_ADDR}:${OSMO_BTS_VTY_PORT}
        osmo-pcu -c /etc/osmocom/osmo-pcu.cfg
        ;;
    osmo-cbc)
        wait-for-it ${OSMO_BSC_IP_ADDR}:${OSMO_BSC_OML_PORT}
        osmo-cbc -c /etc/osmocom/osmo-cbc.cfg
        ;;
    osmo-sgsn)
        wait-for-it ${OSMO_HLR_IP_ADDR}:${OSMO_HLR_GSUP_PORT}
        osmo-sgsn -c /etc/osmocom/osmo-sgsn.cfg
        ;;
    osmo-ggsn)
        iptables -t nat -A POSTROUTING -o $(route | grep '^default' | grep -o '[^ ]*$') -j MASQUERADE
        osmo-ggsn -c /etc/osmocom/osmo-ggsn.cfg
        ;;
    *)
        echo "Error: Invalid service: ${service}"
        exit 1;
        ;;
esac
