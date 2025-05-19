#! /bin/bash

set -e

export MYSQL_PWD=${MYSQL_PASSWORD}

function edq () { printf "%s" ${1//'"'/'\"'}; }  # escape double-quotes

ue_ip () { prips ${UE_IP_ADDR_POOL_BEGIN} ${UE_IP_ADDR_POOL_END} | sed "$((${1}+1))q;d"; }

exec_sql () {
    echo "$1"
    mysql --user ${MYSQL_USER} oai_db -e "$1"
}

add_user () {
    imsi=$1; key=$2; opc=$3; id=$4
    [ "${NSSAI_SD^^}" == "FFFFFF" ] && NSSAI_SD=0xffffff
    case "${OAI_CN5G_TYPE}" in
    minimalist)
        exec_sql 'INSERT INTO `users` VALUES (
                "'${imsi}'",            # IMSI
                "00000001",             # MSISDN
                "55000000000001",       # IMEI
                NULL, "PURGED", 50,     # imei_sv, ms_ps_status, rau_tau_timer
                40000000,               # Maximum Aggregated uplink MBRs
                100000000,              # Maximum Aggregated downlink MBRs
                47,                     # access_restriction
                0000000000, 1,          # mme_cap, mmeidentity_idmmeidentity
                0x'${key}',             # UE security key
                0, 0,                   # RFSP-Index, urrp_mme
                0x40,                   # sqn
                "ebd07771ace8677a",     # rand
                0x'${opc}'              # OPc
            );'
        exec_sql 'INSERT INTO `pdn` VALUES (
                '${id}',                # id
                "'${APN}'",             # apn
                "IPv4",                 # pdn_type (IPv4, IPv6, IPv4v6, IPv4_or_IPv6)
                "0.0.0.0",              # pdn_ipv4
                "0:0:0:0:0:0:0:0",      # pdn_ipv6
                50000000,               # aggregate_ambr_ul
                100000000,              # aggregate_ambr_dl
                3,                      # pgw_id
                "'${imsi}'",            # users_imsi
                9, 15,                  # qci, priority_level
                "DISABLED", "ENABLED",  # pre_emp_cap, pre_emp_vul
                "LIPA-only"             # LIPA-Permissions (LIPA-prohibited, LIPA-only, LIPA-conditional)
            );'
        ;;
    basic)
        exec_sql 'INSERT INTO `AuthenticationSubscription` VALUES (
                "'${imsi}'",            # ueid
                "5G_AKA",               # authenticationMethod
                "'${key}'",             # encPermanentKey
                "'${key}'",             # protectionParameterId
                "'$(edq '{
                    "sqn":
                        "000000000020",
                    "sqnScheme":
                        "NON_TIME_BASED",
                    "lastIndexes":
                        {"ausf": 0}}' )'",# sequenceNumber
                "8000",                 # authenticationManagementField
                "milenage",             # algorithmId
                "'${opc}'",             # encOpcKey
                NULL, NULL,             # encTopcKey, vectorGenerationInHss
                NULL, NULL,             # n5gcAuthMethod, rgAuthenticationInd
                "'${imsi}'"             # supi
            );'
        exec_sql 'INSERT INTO `SessionManagementSubscriptionData`
            (`ueid`, `servingPlmnid`, `singleNssai`, `dnnConfigurations`) VALUES (
                "'${imsi}'",
                "'${imsi:0:5}'",
                "'$(edq '{
                    "sst": '${NSSAI_SST}',
                    "sd": "'${NSSAI_SD}'" }' )'",
                "'$(edq '{
                    "'${APN}'": {
                        "pduSessionTypes": {
                            "defaultSessionType": "IPV4" },
                        "sscModes": {
                            "defaultSscMode": "SSC_MODE_1" },
                        "5gQosProfile": {
                            "5qi": 6,
                            "arp": {
                                "priorityLevel": 1,
                                "preemptCap": "NOT_PREEMPT",
                                "preemptVuln": "NOT_PREEMPTABLE" },
                            "priorityLevel": 1 },
                        "sessionAmbr": {
                            "uplink": "100Mbps",
                            "downlink": "100Mbps" },
                        "staticIpAddress": [{
                            "ipv4Addr": "'$(ue_ip $id)'" }]
                    }}' )'"
            );'
        exec_sql 'INSERT INTO `AccessAndMobilitySubscriptionData`
            (`ueid`, `servingPlmnid`, `nssai`) VALUES (
                "'${imsi}'",
                "'${MCC}${MNC}'",
                "'$(edq '{
                    "defaultSingleNssais": [ {"sst": '${NSSAI_SST}', "sd": "'${NSSAI_SD}'"} ] }' )'"
            );'
        ;;
    *)
        exit 0
        ;;
    esac
}

UE_0="${MCC}${MNC}${UE_SOFT_MSIN} ${UE_SOFT_KEY} ${UE_SOFT_OPC}"
for i in $(seq 0 100); do
    ue=UE_$i
    [[ -z "${!ue}" ]] && continue
    read -r imsi key opc <<< "${!ue}"
    add_user ${imsi} ${key} ${opc} $i
done
