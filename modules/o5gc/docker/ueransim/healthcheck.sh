#!/bin/bash
set -eo pipefail

check_ue_status () {
	status=$(/o5gc/ueransim/build/nr-cli imsi-${MCC}${MNC}${UE_SOFT_MSIN} -e status | grep $1 | awk '{print $2}')
	[ "${status}" == "$2" ] || (echo $1: ${status} != $2 && false)
}

check_gnb_status () {
	node_name=$(/o5gc/ueransim/build/nr-cli --dump)
	status=$(/o5gc/ueransim/build/nr-cli ${node_name} -e status | grep $1 | awk '{print $2}')
	[ "${status}" == "$2" ] || (echo $1: ${status} != $2 && false)
}

case "$1" in
	ue)
		check_ue_status cm-state CM-CONNECTED
		check_ue_status rm-state RM-REGISTERED
		check_ue_status mm-state MM-REGISTERED/NORMAL-SERVICE
		check_ue_status selected-plmn ${MCC}/${MNC}
		check_ue_status current-plmn ${MCC}/${MNC}
		;;
	gnb)
		check_gnb_status is-ngap-up true
		;;
esac
