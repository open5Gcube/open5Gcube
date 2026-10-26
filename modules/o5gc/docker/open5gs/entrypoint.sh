#!/bin/bash

set -ex

export LC_ALL=C.UTF-8
export LANG=C.UTF-8

service=$1
mnt=/mnt/open5gs

if [[ -z "${service}" ]]; then
    echo "Error: first argument SERVICE not set!";
    exit 1;
fi

# the gateway of a UE subnet is its first host address
first_host () { prips ${1} | sed "2q;d"; }
export UE_IP_GATEWAY=$(first_host ${UE_IP_SUBNET})
export UE_IMS_IP_GATEWAY=$(first_host ${UE_IMS_IP_SUBNET})

if [[ -f ${mnt}/${service}.yaml ]]; then
    envsubst.sh ${mnt}/${service}.yaml install/etc/open5gs/${service}.yaml
    cat install/etc/open5gs/${service}.yaml
fi
if [[ -f ${mnt}/${service}.conf ]]; then
    envsubst.sh ${mnt}/${service}.conf install/etc/freeDiameter/${service}.conf
    ${mnt}/make-certs.sh install/etc/freeDiameter ${service}
fi

case "${service}" in
    upf)
        python3 ${mnt}/tun_if.py --tun_ifname ogstun  --ipv4_range ${UE_IP_SUBNET} --ipv6_range 2001:230:cafe::/48
        python3 ${mnt}/tun_if.py --tun_ifname ogstun2 --ipv4_range ${UE_IMS_IP_SUBNET} --ipv6_range 2001:230:babe::/48 --nat_rule 'no'
        service ssh start
        ;;
    mme)
        if [[ "${SMS_DOMAIN}" == "SMS-over-SGs" ]]; then
            envsubst.sh ${mnt}/mme-sgsap.yaml install/etc/open5gs/mme-sgsap.yaml
            awk 1 install/etc/open5gs/mme.yaml install/etc/open5gs/mme-sgsap.yaml | sponge install/etc/open5gs/mme.yaml
        fi
        ;;
esac

cat /etc/image_version
wait-for-it -t 60 ${MONGO_IP_ADDR}:27017
case "${service}" in
    webui)
        cd webui && HOSTNAME=0.0.0.0 PORT=3000 npm run dev
        ;;
#    upf)
#        gdb -batch -ex "run" -ex "bt" install/bin/open5gs-${service}d 2>&1 | grep --line-buffered -v ^"No stack."$
#        ;;
    nrf | ausf | udr | udm | pcf | bsf | nssf | hss | sgwc | sgwu | smf | amf | mme | pcrf | upf | scp | sepp)
        while [[ -n "$(dig +short ${OPEN5GS_INIT_HOST:-open5gs-init})" ]]; do sleep 2; done
        exec install/bin/open5gs-${service}d
        ;;
    *)
        echo "Error: Invalid SERVICE: ${service}"
        exit 1;
        ;;
esac
