#! /bin/bash

set -e

wait-for-it -t 60 ${FREE5GC_WEBUI_IP_ADDR}:5000
sleep 1

WEBUI_URL=http://${FREE5GC_WEBUI_IP_ADDR}:5000
NSSAI_SD=$(printf "%06x" "${NSSAI_SD/#0x}")

add_subscriber () {
    imsi=$1; key=$2; opc=$3
    data='{
        "userNumber": 1,
        "plmnID": "'${imsi::5}'",
        "ueId": "imsi-'${imsi}'",
        "AuthenticationSubscription": {
            "authenticationManagementField": "8000",
            "authenticationMethod": "5G_AKA",
            "milenage": { "op": {"encryptionAlgorithm": 0, "encryptionKey": 0, "opValue": ""} },
            "opc": {
                "encryptionAlgorithm": 0,
                "encryptionKey": 0,
                "opcValue": "'${opc}'"
            },
            "permanentKey": {
                "encryptionAlgorithm": 0,
                "encryptionKey": 0,
                "permanentKeyValue": "'${key}'"
            },
            "sequenceNumber": "16f3b3f70fc2"
        },
        "AccessAndMobilitySubscriptionData": {
            "gpsis": ["msisdn-'${imsi: -5}'"],
            "nssai": {
                "defaultSingleNssais": [ {
                    "sst": '${NSSAI_SST}',
                    "sd": "'${NSSAI_SD}'",
                    "isDefault": true
                } ],
                "singleNssais": []
            },
            "subscribedUeAmbr": {"downlink": "2 Gbps", "uplink": "1 Gbps"}
        },
        "SessionManagementSubscriptionData": [ {
            "singleNssai": {
                "sst": '${NSSAI_SST}',
                "sd": "'${NSSAI_SD}'"
            },
            "dnnConfigurations": {
                "'${APN}'": {
                    "sscModes": {
                        "defaultSscMode": "SSC_MODE_1",
                        "allowedSscModes": ["SSC_MODE_2", "SSC_MODE_3"]
                    },
                    "pduSessionTypes": {
                        "defaultSessionType": "IPV4",
                        "allowedSessionTypes": ["IPV4"]
                    },
                    "sessionAmbr": {"uplink": "200 Mbps", "downlink": "100 Mbps"},
                    "5gQosProfile": { "5qi": 9, "arp": {"priorityLevel": 8}, "priorityLevel": 8 }
                }
            }
        } ],
        "SmfSelectionSubscriptionData": {
            "subscribedSnssaiInfos": {
                "01'${NSSAI_SD}'": {
                    "dnnInfos": [ {"dnn": "'${APN}'"} ]
                }
            }
        },
        "AmPolicyData": { "subscCats": ["free5gc"] },
        "SmPolicyData": {
            "smPolicySnssaiData": {
                "01'${NSSAI_SD}'": {
                    "snssai": {
                        "sst": '${NSSAI_SST}',
                        "sd": "'${NSSAI_SD}'"
                    },
                    "smPolicyDnnData": {
                        "'${APN}'" : {"dnn": "'${APN}'" }
                    }
                }
            }
        },
        "FlowRules": [],
        "QosFlows": []
    }'
    http_code=$(curl -sS                                                      \
        --output /tmp/curl_output --write-out "%{http_code}"                  \
        -X POST                                                               \
        -H "Token: $(cat /tmp/access_token)"                                  \
        -H "Content-Type: application/json"                                   \
        -d "$data"                                                            \
      ${WEBUI_URL}/api/subscriber/imsi-${imsi}/${imsi::5}/1)
    if [[ ${http_code} -lt 200 || ${http_code} -gt 299 ]]; then
        cat /tmp/curl_output
        exit 1
    fi
    echo "added imsi: $imsi with key: $key opc: $opc"
}

login () {
    curl -sS                                                                  \
        -X POST                                                               \
        -H "Content-Type: application/json"                                   \
        -d '{"username": "admin","password": "free5gc"}'                      \
      ${WEBUI_URL}/api/login | jq -r '.access_token' > /tmp/access_token
    curl -sS                                                                  \
        -X GET                                                                \
        -H "Token: $(cat /tmp/access_token)"                                  \
      ${WEBUI_URL}/api/registered-ue-context
}

login

UE_0="${MCC}${MNC}${UE_SOFT_MSIN} ${UE_SOFT_KEY} ${UE_SOFT_OPC}"
count=0
for i in $(seq 0 100); do
    ue=UE_$i
    [[ -z "${!ue}" ]] && continue
    read -r imsi key opc <<< "${!ue}"
    add_subscriber $imsi $key $opc
    count=$((count+1))
done

echo "Finished initialization of ${count} subscriptions"
