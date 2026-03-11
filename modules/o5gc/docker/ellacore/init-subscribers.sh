#! /bin/bash

set -e

wait-for-it -t 60 ${AMF_IP_ADDR}:5002
sleep 1

WEBUI_URL=http://${AMF_IP_ADDR}:5002

ella_api () {
    #echo "curl -d "$3" -X $1 /api/v1/$2)"
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
    data='{
        "imsi": "'${imsi}'",
        "key": "'${key}'",
        "opc": "'${opc}'",
        "sequenceNumber": "000000000022",
        "policyName": "default"
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
    data='{"sd": "'$(printf "%06x" "${NSSAI_SD/#0x}")'", "sst": '${NSSAI_SST}'}'
    ella_api PUT operator/slice "${data}"
    data='{"privateKey": "c53c22208b61860b06c62e5406a7b330c2b577aa5558981510d128247d38bd1d"}'
    ella_api PUT operator/home-network "${data}"
}

init

setup

source /mnt/o5gc/core-init.sh
call_for_each_subscriber add_subscriber

echo "Finished subscription initialization"
