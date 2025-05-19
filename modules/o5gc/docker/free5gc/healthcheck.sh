#!/bin/bash

set -e

service=$(hostname)
case "${service}" in
    free5gc-webui)
        wait-for-it -t 30 ${FREE5GC_WEBUI_IP_ADDR}:5000
        ;;
    nrf | amf | ausf | nssf | pcf | smf | udm | udr)
        service_ip=${service^^}_IP_ADDR
        wait-for-it -t 1 ${!service_ip}:7777
        ;;
    upf)
        nc -v -z -u ${UPF_IP_ADDR} 2152
        ;;
    *)
        echo "Error: Invalid SERVICE: ${service}"
        exit 1;
        ;;
esac
