#! /bin/bash

set -e

wait-for-it -t 60 ${OPEN5GS_WEBUI_IP_ADDR}:3000
sleep 5

WEBUI_URL=http://${OPEN5GS_WEBUI_IP_ADDR}:3000

add_subscriber () {
    imsi=$1; key=$2; opc=$3
    if [[ ${imsi} != ${MCC}${MNC}* ]]; then
        echo "skip imsi:  ${imsi}"
        return
    fi
    [ "${NSSAI_SD}" != "ffffff" ] && NSSAI_SD=$(printf "%06d" ${NSSAI_SD})
    data='{
        "imsi": "'$imsi'",
        "msisdn": ["'${imsi: -5}'" ],
        "security": {
            "k": "'$key'",
            "amf": "8000",
            "op_type": 0,
            "op_value": "'$opc'",
            "op": null,
            "opc": "'$opc'"
        },
        "ambr": {
            "downlink": { "value": 1, "unit": 3 },
            "uplink": { "value": 1, "unit": 3 }
        },
        "slice": [ {
            "sst": '$NSSAI_SST',
            "sd": "'$NSSAI_SD'",
            "default_indicator": true,
            "session": [ {
                "name": "internet",
                "type": 1,
                "pcc_rule": [],
                "ambr": {
                    "uplink": { "value": 1, "unit": 3 },
                    "downlink": { "value": 1, "unit": 3 }
                },
                "qos": {
                    "index": 9,
                    "arp": {
                        "priority_level": 8,
                        "pre_emption_capability": 1,
                        "pre_emption_vulnerability": 1
                    }
                }
            }, {
                "name": "ims",
                "type": 1,
                "pcc_rule": [
                    {
                        "qos": {
                            "index": 1,
                            "gbr": {
                                "uplink": { "value": 128, "unit": 1 },
                                "downlink": { "value": 128, "unit": 1 }
                            },
                            "mbr": {
                                "uplink": { "value": 128, "unit": 1 },
                                "downlink": { "value": 128, "unit": 1 }
                            },
                            "arp": {
                                "priority_level": 2,
                                "pre_emption_capability": 2,
                                "pre_emption_vulnerability": 2
                            }
                        }
                    }, {
                        "qos": {
                            "index": 2,
                            "gbr": {
                                "uplink": { "value": 128, "unit": 1 },
                                "downlink": { "value": 128, "unit": 1 }
                            },
                            "mbr": {
                                "uplink": { "value": 128, "unit": 1 },
                                "downlink": { "value": 128, "unit": 1 }
                            },
                            "arp": {
                                "priority_level": 4,
                                "pre_emption_capability": 2,
                                "pre_emption_vulnerability": 2
                            }
                        }
                    } ],
                "ambr": {
                    "uplink": { "value": 1530, "unit": 1 },
                    "downlink": { "value": 3850, "unit": 1 }
                },
                "qos": {
                    "index": 5,
                    "arp": {
                        "priority_level": 1,
                        "pre_emption_capability": 1,
                        "pre_emption_vulnerability": 1
                    }
                }
            } ]
        } ]
    }'
    http_code=$(curl -sS                                                      \
        --output /tmp/curl_output --write-out "%{http_code}"                  \
        -X POST                                                               \
        -b /tmp/cookies.txt                                                   \
        -H "Content-Type: application/json"                                   \
        -H "X-CSRF-TOKEN: $(jq -r .csrfToken /tmp/session.json)"              \
        -H "Authorization: Bearer $(jq -r .authToken /tmp/session.json)"      \
        -d "$data"                                                            \
      ${WEBUI_URL}/api/db/Subscriber)
    if [[ ${http_code} -lt 200 || ${http_code} -gt 299 ]]; then
        cat /tmp/curl_output
        exit 1
    fi
    echo "added imsi: $imsi with key: $key opc: $opc"
}

login () {
    curl -sS -c /tmp/cookies.txt ${WEBUI_URL}/api/auth/csrf                   \
        | jq -r '.csrfToken' > /tmp/csrfToken.txt
    curl -sS                                                                  \
        -X POST                                                               \
        -c /tmp/cookies.txt -b /tmp/cookies.txt                               \
        -H "Content-Type: application/json"                                   \
        -H "X-CSRF-TOKEN: $(cat /tmp/csrfToken.txt)"                          \
        -d '{ "username": "o5gc", "password": "o5gc" }'                       \
      ${WEBUI_URL}/api/auth/login
    curl -sS -b /tmp/cookies.txt -o /tmp/session.json ${WEBUI_URL}/api/auth/session
    echo
}

logout () {
    curl -sS                                                                  \
        -X POST                                                               \
        -b /tmp/cookies.txt                                                   \
        -H "X-CSRF-TOKEN: $(jq -r .csrfToken /tmp/session.json)"              \
      ${WEBUI_URL}/api/auth/logout
    echo
    rm /tmp/cookies.txt /tmp/csrfToken.txt /tmp/session.json /tmp/curl_output
}

login

UE_0="${MCC}${MNC}${UE_SOFT_MSIN} ${UE_SOFT_KEY} ${UE_SOFT_OPC}"
for i in $(seq 0 100); do
    ue=UE_$i
    [[ -z "${!ue}" ]] && continue
    read -r imsi key opc <<< "${!ue}"
    add_subscriber $imsi $key $opc $i
done

logout

echo "Finished subscription initialization"
