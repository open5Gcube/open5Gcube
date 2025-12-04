#!/bin/bash

set -eux

cf=$1

envsubst.sh /mnt/volte/kamailio/kamctlrc.cfg /usr/local/etc/kamailio/kamctlrc
envsubst.sh /mnt/volte/kamailio/kamailio.cfg /usr/local/etc/kamailio/kamailio.cfg

wait-for-it -t 30 ${MYSQL_IP_ADDR}:3306

export MYSQL_HOST=mysql
export MYSQL_USER=root
export MYSQL_PWD=${MYSQL_ROOT_PASSWORD}

mysql -e "DROP DATABASE IF EXISTS ${cf}"
mysql -e "CREATE DATABASE ${cf}"

case "${cf}" in
    pcscf)
        cd /o5gc/kamailio/utils/kamctl/mysql
        mysql pcscf < standard-create.sql
        mysql pcscf < presence-create.sql
        mysql pcscf < ims_usrloc_pcscf-create.sql
        mysql pcscf < ims_dialog-create.sql
        # Add static route to route traffic back to UE as there is not NATing
        ip r add 192.168.101.0/24 via ${UPF_IP_ADDR}
        sh -c "echo 1 > /proc/sys/net/ipv4/ip_nonlocal_bind"
        ;;
    scscf)
        cd /o5gc/kamailio/utils/kamctl/mysql
        mysql scscf < standard-create.sql
        mysql scscf < presence-create.sql
        mysql scscf < ims_usrloc_scscf-create.sql
        mysql scscf < ims_dialog-create.sql
        mysql scscf < ims_charging-create.sql
        ;;
    icscf)
        cd /o5gc/kamailio/misc/examples/ims/icscf
        mysql icscf < icscf.sql
        mysql icscf -e "INSERT INTO nds_trusted_domains VALUES (1,'${IMS_DOMAIN}')"
        mysql icscf -e "INSERT INTO s_cscf VALUES (1,'First and only S-CSCF','sip:scscf.${IMS_DOMAIN}:6060')"
        mysql icscf -e "INSERT INTO s_cscf_capabilities VALUES (1,1,0),(2,1,1)"
        ;;
    smsc)
        cd /o5gc/kamailio/utils/kamctl/mysql
        mysql smsc < standard-create.sql
        mysql smsc < dialplan-create.sql
        mysql smsc < presence-create.sql
        mysql smsc < /mnt/volte/kamailio/smsc/smsc-create.sql
        ;;
    *)
        echo unknown function: ${cf} > /dev/stderr
        exit 1
esac

cp -a /mnt/volte/kamailio/${cf} /etc/kamailio_${cf}
cd /etc/kamailio_${cf}
for f in kamailio_${cf}.cfg ${cf}.cfg ${cf}.xml; do
    [ -f $f ] && envsubst.sh $f
done
mkdir /var/run/kamailio

exec kamailio -f /etc/kamailio_${cf}/kamailio_${cf}.cfg -P /kamailio_${cf}.pid -DD -E -e

