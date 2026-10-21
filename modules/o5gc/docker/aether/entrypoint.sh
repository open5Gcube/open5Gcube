#!/bin/bash

set -ex

service=$1
mnt=/mnt/aether

if [[ -z "${service}" ]]; then
    echo "Error: first argument SERVICE not set!"
    exit 1
fi

# SD as 6 hex digits (e.g. 0x1 -> 000001), as it is provisioned by init-core.sh
export NSSAI_SD=$(printf "%06x" $((16#${NSSAI_SD#0x})))

if [[ "${service}" == "upf" ]]; then
    envsubst.sh ${mnt}/upf.jsonc /upf.jsonc
else
    envsubst.sh ${mnt}/${service}cfg.yaml /${service}cfg.yaml
    wait-for-it -t 60 ${MONGO_IP_ADDR}:27017
fi

case "${service}" in
    upf)
        # In af_packet mode the kernel also sees the N3/N6 packets that BESS
        # handles: it must neither answer GTP-U with ICMP port unreachable nor
        # reset the (masqueraded) N6 connections.
        iptables -I OUTPUT -p icmp --icmp-type port-unreachable -j DROP
        iptables -I INPUT -i core -j DROP
        # route_control.py only programs routes with a gateway into BESS, so
        # add one for the directly attached gNB
        ip route replace ${GNB_IP_ADDR}/32 via ${GNB_IP_ADDR} dev access onlink
        export CONF_FILE=/upf.jsonc
        # bessd dumps one line per 4k memory segment (~130k lines) to stdout,
        # which blocks it when an attached 'docker compose up' reads slowly;
        # its log goes to stderr
        bess/core/bessd -f -m 0 --iova=va --grpc_url=127.0.0.1:10514 >/dev/null &
        retry --until=success --times=30 --delay=2 --                         \
            bash -c "bessctl daemon reset && bessctl run up4"
        conf/route_control.py -i access core &
        bin/pfcpiface -config /upf.jsonc &
        wait -n
        exit $?
        ;;
    webui)
        #exec ./webconsole -cfg /${service}cfg.yaml
        exec ./bin/webconsole-ui -cfg /${service}cfg.yaml
        ;;
    nrf | amf | ausf | nssf | pcf | smf | udm | udr)
        if [[ "${service}" != "nrf" ]]; then
            wait-for-it -t 60 ${NRF_IP_ADDR}:7777
        fi
        if [[ "${service}" == "smf" ]]; then
            exec bin/${service} -cfg /${service}cfg.yaml -uerouting ${mnt}/uerouting.yaml
        else
            exec bin/${service} -cfg /${service}cfg.yaml
        fi
        ;;
    *)
        echo "Error: Invalid SERVICE: ${service}"
        exit 1
        ;;
esac
