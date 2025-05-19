#!/bin/bash

set -eux

envsubst.sh /mnt/volte/dns/zone.epc.conf /etc/bind/epc.mnc${MNC03}.mcc${MCC}.3gppnetwork.org
envsubst.sh /mnt/volte/dns/zone.ims.conf /etc/bind/ims.mnc${MNC03}.mcc${MCC}.3gppnetwork.org
envsubst.sh /mnt/volte/dns/named.conf.local /etc/bind/named.conf.local
envsubst.sh /mnt/volte/dns/named.conf.options /etc/bind/named.conf.options
envsubst.sh /mnt/volte/dns/e164.arpa /etc/bind/e164.arpa

/usr/sbin/named -c /etc/bind/named.conf -g -u bind

{ set +x; } 2>/dev/null
pid=$(cat /run/named/named.pid)
while kill -0 $pid 2>/dev/null; do sleep 1; done

exit 1
