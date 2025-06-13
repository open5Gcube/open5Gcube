#! /bin/bash

set -e

[[ $EUID -ne 0 ]] && echo "This script must be run as root." && exit 1

BASE_DIR=$(realpath $(dirname "$0")/..)

make -s -C ${BASE_DIR} ENV_DIR=/tmp /tmp/o5gc.env
source /tmp/o5gc.env
rm /tmp/o5gc.env

echo "Configure Network Kernel Settings"
(set -x
sysctl -q -w net.core.rmem_max=33554432
sysctl -q -w net.core.wmem_max=33554432 )

if [ ! -d /sys/class/net/${USRP_IFACE} ]; then
    echo "Create dummy USRP Interface '${USRP_IFACE}'"
    (set -x
    ip link add ${USRP_IFACE} type dummy )
fi

echo "Configure USRP Interface '${USRP_IFACE}'"
(set -x
ifconfig ${USRP_IFACE} 192.168.40.1/24 up
ifconfig ${USRP_IFACE} mtu 9000 )

if [ -d /sys/class/net/corenet ]; then
    (set -x
    ip link delete corenet )
fi
if [ "${CORENET_DRIVER}" == "macvlan" ]; then
    echo "Create macvlan interface 'corenet' @ ${CORENET_MACVLAN_IFACE}"
    (set -x
    ip link add corenet link ${CORENET_MACVLAN_IFACE} type macvlan mode bridge
    ip addr add ${CORENET_HOST_IP_ADDR}/${CORENET_SUBNET_SUFFIX} dev corenet
    ip link set dev corenet up )
fi

docker network inspect o5gc &>/dev/null || (
    echo "Create custom Docker bridge 'o5gc'"
    set -x
    docker network create --driver bridge --label o5gc-bridge o5gc )

echo Start /etc/hosts updater
make -s -C ${BASE_DIR} USER=root HOME=/root docker-etc-hosts-updater-restart
