#! /bin/bash

set -e

wait-for-it -t 60 ${AETHER_WEBUI_IP_ADDR}:5000
sleep 1

WEBUI_URL=http://${AETHER_WEBUI_IP_ADDR}:5000
# SD as 6 hex digits, e.g. 0x1 -> 000001
NSSAI_SD=$(printf "%06x" $((16#${NSSAI_SD#0x})))

webui_api () {
    # shellcheck disable=SC2068
    http_code=$(curl -sS --output /tmp/curl_output --write-out "%{http_code}" \
        -X POST                                                               \
        -H "Accept: application/json"                                         \
        -H "Content-Type: application/json"                                   \
        -d "$2"                                                               \
      ${WEBUI_URL}/$1)
    if [[ ${http_code} -eq 409 ]]; then
        echo "$1 already exists"
    elif [[ ${http_code} -lt 200 || ${http_code} -gt 299 ]]; then
        cat /tmp/curl_output; echo
        exit 1
    fi
}

IMSI_ARRAY=()

add_subscriber () {
    imsi=$1; key=$2; opc=$3
    # the webui only accepts device groups whose IMSIs belong to the slice's PLMN
    if [[ "${imsi}" != "${MCC}${MNC}"* ]]; then
        echo "skipped subscriber ${imsi} (not in PLMN ${MCC}${MNC})"
        return
    fi
    data='{
        "plmnID": "'${MCC}${MNC}'",
        "opc": "'${opc}'",
        "key": "'${key}'",
        "sequenceNumber": "000000000001"
    }'
    webui_api api/subscriber/imsi-${imsi} "${data}"
    echo "added subscriber ${imsi}"
    IMSI_ARRAY+=(${imsi})
}

configure_device_group() {
    imsis=$(jq --compact-output --null-input '$ARGS.positional' --args -- "${IMSI_ARRAY[@]}")
    data='{
        "imsis": '${imsis}',
        "site-info": "open5Gcube",
        "ip-domain-name": "pool-1",
        "ip-domains": [
            {
                "dnn": "'${APN}'",
                "ue-ip-pool": "'${UE_IP_SUBNET}'",
                "dns-primary": "8.8.8.8",
                "dns-secondary": "8.8.4.4",
                "mtu": 1460,
                "ue-dnn-qos": {
                    "dnn-mbr-uplink": 1000,
                    "dnn-mbr-downlink": 1000,
                    "bitrate-unit": "Mbps",
                    "traffic-class": {
                        "name": "platinum",
                        "qci": 9,
                        "arp": 6,
                        "pdb": 300,
                        "pelr": 6
                    }
                }
            }
        ]
    }'
    webui_api config/v1/device-group/dev-group-1 "${data}"
    echo "added device group"
}

configure_network_slice() {
    data='{
        "slice-id": {
            "sst": "'${NSSAI_SST}'",
            "sd": "'${NSSAI_SD}'"
        },
        "site-device-group": [ "dev-group-1" ],
        "site-info": {
            "site-name": "open5Gcube",
            "plmn": {
                "mcc": "'${MCC}'",
                "mnc": "'${MNC}'"
            },
            "gNodeBs": [
                {
                    "name": "gnb1",
                    "tac": '${TAC}'
                }
            ],
            "upf": {
                "upf-name": "upf",
                "upf-port": 8805
            }
        }
    }'
    webui_api config/v1/network-slice/slice-1 "${data}"
    echo "added network slice"
}

source /mnt/o5gc/core-init.sh
call_for_each_subscriber add_subscriber

configure_device_group
configure_network_slice

echo "Finished Core initialization"
