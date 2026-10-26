#! /bin/bash

set -e

for i in $(seq 1 60); do
    if curl -sSf http://${AMF_IP_ADDR}:5002/api/v1/status | grep -q '"ready":true'; then
        break
    fi
    sleep 1
done

WEBUI_URL=http://${AMF_IP_ADDR}:5002
IMS_URL=http://${PCSCF_IP_ADDR}:5020
SMSC_URL=http://${SMSC_IP_ADDR}:5010
# E.164 numbers of Ella SMSC (the SMSC number for SIM cards) and Ella Core
SMSC_NUMBER=+${MSISDN_COUNTRY_CODE}1000
CORE_SMS_NUMBER=+${MSISDN_COUNTRY_CODE}1001

# API of Ella IMS and SMSC, which need no authentication
nf_api () {
    url=$1; shift
    echo "curl -d "$3" -X $1 ${url}/api/v1/$2)"
    http_code=$(curl -sS --output /tmp/curl_output --write-out "%{http_code}" \
        -X $1                                                                 \
        -H "Content-Type: application/json"                                   \
        -d "$3"                                                               \
      ${url}/api/v1/$2)
    cat /tmp/curl_output; echo
    if [[ ${http_code} -lt 200 || ${http_code} -gt 299 ]]; then
        exit 1
    fi
}

ims_api () {
    nf_api ${IMS_URL} "$@"
}

smsc_api () {
    nf_api ${SMSC_URL} "$@"
}

# wait until the API of Ella IMS or SMSC ($1) is up
wait_for_api () {
    for i in $(seq 1 60); do
        if curl -sSf $1/api/v1/status > /dev/null; then
            return
        fi
        sleep 1
    done
    echo "Error: API $1 is not up"
    exit 1
}

# wait until the Diameter peer of Ella IMS or SMSC (API $1, path $2) is open
# (Ella Core starts its Diameter node only once the operator is set up)
wait_for_diameter () {
    for i in $(seq 1 120); do
        if curl -sSf $1/api/v1/$2 | grep -q '"state":"open"'; then
            echo "Diameter connection to Ella Core is open"
            return
        fi
        sleep 1
    done
    echo "Error: Diameter connection to Ella Core did not open"
    exit 1
}

ella_api () {
    echo "curl -d "$3" -X $1 /api/v1/$2)"
    # shellcheck disable=SC2068
    http_code=$(curl -sS --output /tmp/curl_output --write-out "%{http_code}" \
        -X $1                                                                 \
        -H "Authorization: Bearer $(cat /tmp/access_token)"                   \
        -H "Content-Type: application/json"                                   \
        -d "$3"                                                               \
      ${WEBUI_URL}/api/v1/$2)
    cat /tmp/curl_output; echo
    if [[ ${http_code} -lt 200 || ${http_code} -gt 299 ]]; then
        exit 1
    fi
}

add_subscriber () {
    imsi=$1; key=$2; opc=$3
    if [[ ${imsi} != ${MCC}${MNC}* ]]; then
        return
    fi
    data='{
        "imsi": "'${imsi}'",
        "key": "'${key}'",
        "opc": "'${opc}'",
        "msisdn": "+'${MSISDN_COUNTRY_CODE}${imsi#${MCC}${MNC}}'",
        "sequenceNumber": "000000000022",
        "profile_name": "default"
    }'
    ella_api POST subscribers "${data}"
    echo "added imsi: $imsi with key: $key opc: $opc"
}

init() {
    curl -sS                                                                  \
        -X POST                                                               \
        -H "Content-Type: application/json"                                   \
        -d '{"email": "o5gc@open5gcube.de", "password": "o5gc"}'              \
      ${WEBUI_URL}/api/v1/init | jq -r '.result.token' > /tmp/access_token
}

setup () {
    data='{"supportedTacs": ["'$(printf "%06x" "${TAC}")'"]}'
    ella_api PUT operator/tracking "${data}"
    data='{"fullName": "'${NETWORK_NAME}'", "shortName": "'${NETWORK_NAME}'"}'
    ella_api PUT operator/spn "${data}"
    data='{"sd": "'${NSSAI_SD}'", "sst": '${NSSAI_SST}'}'
    ella_api PUT slices/default "${data}"
    # replace the initial internet data network and its default policy by
    # one for the APN in the UE subnet, with Ella Core's initial values
    ella_api DELETE policies/default
    ella_api DELETE networking/data-networks/internet
    data='{"name": "'${APN}'", "ipv4_pool": "'${UE_IP_SUBNET}'", "dns": "8.8.8.8", "mtu": 1400}'
    ella_api POST networking/data-networks "${data}"
    data='{
        "name": "default",
        "profile_name": "default",
        "slice_name": "default",
        "data_network_name": "'${APN}'",
        "session_ambr_uplink": "200 Mbps",
        "session_ambr_downlink": "200 Mbps",
        "var5qi": 9,
        "arp": 1
    }'
    ella_api POST policies "${data}"
    data='{"keyIdentifier":1, "scheme": "A", "privateKey": "c53c22208b61860b06c62e5406a7b330c2b577aa5558981510d128247d38bd1d"}'
    ella_api POST operator/home-network-keys "${data}"
    data='{"keyIdentifier":2, "scheme": "B", "privateKey": "F1AB1074477EBCC7F554EA1C5FC368B1616730155E0041AC447D6301975FECDA"}'
    ella_api POST operator/home-network-keys "${data}"
}

setup_ims () {
    wait_for_api ${IMS_URL}

    # Ella Core: ims data network for SIP signalling and media, its policy in
    # the default profile, and the P-CSCF given to UEs on it
    data='{"name": "ims", "ipv4_pool": "'${UE_IMS_IP_SUBNET}'", "dns": "8.8.8.8", "mtu": 1400}'
    ella_api POST networking/data-networks "${data}"
    data='{
        "name": "ims",
        "profile_name": "default",
        "slice_name": "default",
        "data_network_name": "ims",
        "session_ambr_uplink": "100 Mbps",
        "session_ambr_downlink": "100 Mbps",
        "var5qi": 5,
        "arp": 15
    }'
    ella_api POST policies "${data}"
    data='{"pcscfAddresses": ["'${PCSCF_EXT_IP_ADDR}'"]}'
    ella_api PUT operator/ims "${data}"

    # Ella IMS: operator, numbering plan, and Ella Core as HSS (Cx) and PCRF (Rx)
    data='{
        "mcc": "'${MCC}'",
        "mnc": "'${MNC}'",
        "numbering": {
            "country_code": "'${MSISDN_COUNTRY_CODE}'",
            "national_prefix": "0",
            "international_prefix": "00"
        }
    }'
    ims_api PUT operator "${data}"
    data='{"address": "'${AMF_IP_ADDR}'", "port": 3868, "transport": "sctp", "applications": ["cx", "rx"]}'
    ims_api POST diameter/peers "${data}"
    realm=epc.mnc${MNC03}.mcc${MCC}.3gppnetwork.org
    ims_api PUT diameter/routes/cx '{"realm": "'${realm}'"}'
    ims_api PUT diameter/routes/rx '{"realm": "'${realm}'"}'
    ims_api PUT policy '{"interface": "rx"}'

    wait_for_diameter ${IMS_URL} diameter/peers
}

setup_smsc () {
    wait_for_api ${SMSC_URL}

    # Ella SMSC: operator, which also sets its Diameter identity
    # smsc.node.<realm>, numbering plan, and its service centre number
    data='{
        "mcc": "'${MCC}'",
        "mnc": "'${MNC}'",
        "service_centre_address": "'${SMSC_NUMBER}'",
        "numbering": {
            "country_code": "'${MSISDN_COUNTRY_CODE}'",
            "national_prefix": "0",
            "international_prefix": "00"
        }
    }'
    smsc_api PUT operator "${data}"

    # Ella Core: its own SMS number, and the SMSC it connects to (SGd/S6c)
    ella_api PUT operator/sms '{"smsNumber": "'${CORE_SMS_NUMBER}'"}'
    data='{"address": "'${SMSC_IP_ADDR}'", "port": 3868, "serviceCentres": ["'${SMSC_NUMBER}'"]}'
    ella_api POST operator/sms/smsc-peers "${data}"

    wait_for_diameter ${SMSC_URL} diameter
}

init

setup

source /mnt/o5gc/core-init.sh
call_for_each_subscriber add_subscriber

# only if the stack runs Ella IMS / SMSC
if [[ -n "$(dig +short ellacore-ims)" ]]; then
    setup_ims
fi
if [[ -n "$(dig +short ellacore-smsc)" ]]; then
    setup_smsc
fi

echo "Finished subscription initialization"
