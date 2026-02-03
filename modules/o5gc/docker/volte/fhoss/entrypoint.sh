#!/bin/bash

set -ex

cd /o5gc/FHoSS

adjust_conf_files () {
    sed -i 's|^host=127.0.0.1$|host=0.0.0.0|' deploy/hss.properties
    sed -i 's|open-ims.org|'${IMS_DOMAIN}'|g' deploy/webapps/hss.web.console/WEB-INF/web.xml
    sed -i 's|open-ims.org|'${IMS_DOMAIN}'|g' src-web/WEB-INF/web.xml
    sed -i 's|open-ims.test|'${IMS_DOMAIN}'|g' scripts/userdata.sql

    envsubst.sh /mnt/volte/fhoss/hibernate.properties deploy/hibernate.properties
    envsubst.sh /mnt/volte/fhoss/DiameterPeerHSS.xml deploy/DiameterPeerHSS.xml
    cp deploy/DiameterPeerHSS.xml deploy/hibernate.properties config/
}

init_database () {
    export MYSQL_HOST=localhost
    export MYSQL_USER=root
    export MYSQL_PWD=

    service mysql start
    wait-for-it 127.0.01:3306
    sleep 1

    mysql -e "create database hss_db;"
    mysql hss_db < scripts/hss_db.sql
    mysql -e "CREATE USER 'hss'@'%' IDENTIFIED WITH mysql_native_password BY 'hss'";
    mysql -e "CREATE USER 'hss'@'${VOLTE_HSS_IP_ADDR}' IDENTIFIED WITH mysql_native_password BY 'hss'";
    mysql -e "GRANT ALL ON hss_db.* TO 'hss'@'%'";
    mysql -e "GRANT ALL ON hss_db.* TO 'hss'@'${VOLTE_HSS_IP_ADDR}'";
    mysql -e "FLUSH PRIVILEGES;"
    mysql hss_db < scripts/userdata.sql
}

FHOSS_URI=http://hssAdmin:hss@127.0.0.1:8080/hss.web.console
fhoss_web_conolse () {
    action="$1"; shift
    # shellcheck disable=SC2068
    http_code=$(curl -sS --output /tmp/curl_output --write-out "%{http_code}" \
            ${@/#/--data } ${FHOSS_URI}/${action})
    if [[ ${http_code} -lt 200 || ${http_code} -gt 299 ]]; then
        cat /tmp/curl_output
        exit 1
    fi
}
create_imsu () {
    imsi=$1
    fhoss_web_conolse IMSU_Submit.do                                          \
            id=-1 id_capabilities_set=1 id_preferred_scscf=1 name=${imsi}     \
            nextAction=save
}
create_impi () {
    imsu_id=$1; identity=$2
    fhoss_web_conolse IMPI_Submit.do                                          \
            id_imsu=-1 already_assigned_imsu_id=${imsu_id}                    \
            secretKey=${key} all=on default_auth_scheme=1 amf=8000            \
            op=00000000000000000000000000000000 opc=${opc} sqn=000000021090   \
            identity=${identity} id=-1 ip= line_identifier= nextAction=save
}
create_impu () {
    impi_id=$1; identity=$2; barring=$3; id_sp=$4
    fhoss_web_conolse IMPU_Submit.do                                          \
            already_assigned_impi_id=${impi_id} id=-1 identity=${identity}    \
            id_charging_info=1 associated_ID=-1 ${barring} id_sp=${id_sp}     \
            id_impu_implicitset=-1 can_register=on type=0 wildcard_psi=       \
            display_name= user_state=0 nextAction=save
}
set_visited_network_to_impu () {
    impu_id=$1; identity=$2; id_sp=$3
    fhoss_web_conolse IMPU_Submit.do                                          \
            associated_ID=-1 already_assigned_impi_id=-1 id=${impu_id}        \
            identity=${identity} id_sp=${id_sp} can_register=on               \
            id_impu_implicitset=${impu_id} id_charging_info=-1 type=0         \
            wildcard_psi= display_name= user_state=0 ppr_apply_for=0 vn_id=1  \
            impu_implicitset_identity= impi_identity= nextAction=add_vn
}
set_impu_to_implicitset () {
    impu_id=$1; impu_identity=$2; impu_implicitset_identity=$3; id_sp=$4
    fhoss_web_conolse IMPU_Submit.do                                          \
            associated_ID=-1 already_assigned_impi_id=0 id=${impu_id}         \
            identity=${impu_identity} barring=off id_sp=${id_sp}              \
            id_impu_implicitset=${impu_id} id_charging_info=1 can_register=on \
            type=0 wildcard_psi= display_name= user_state=0                   \
            impu_implicitset_identity=${impu_implicitset_identity} vn_id=-1   \
            impi_identity= ppr_apply_for=0 nextAction=add_impu_to_implicitset
}
add_impu () {
    impi_id=$1; identity=$2; barring=$3; id_sp=$4
    create_impu ${impi_id} ${identity} ${barring} ${id_sp}
    impu_id=$(sed -nr "s|.*IMPU_Load.do\?id=([0-9]+).*|\1|p" /tmp/curl_output)
    set_visited_network_to_impu ${impu_id} ${identity} ${id_sp}
}
add_subscriber () {
    imsi=$1; key=$2; opc=$3; id=$4
    msisdn=${imsi: -5}
    if [[ "${SMS_DOMAIN}" == "SMS-over-SGs" ]]; then
        id_sp=1 # Default Service Point
    else
        id_sp=2 # SMS Service Point
    fi
    # IMS Subscription / Create
    create_imsu ${imsi}
    imsu_id=$(sed -nr "s|.*already_assigned_imsu_id=([0-9]+).*|\1|p" /tmp/curl_output)
    # Create & Bind new IMPI
    create_impi ${imsu_id} ${imsi}%40${IMS_DOMAIN}
    impi_id=$(sed -nr "s|.*already_assigned_impi_id=([0-9]+).*|\1|p" /tmp/curl_output)
    # Create & Bind new IMPU
    add_impu ${impi_id} sip%3A${imsi}%40${IMS_DOMAIN} barring=on ${id_sp}
    imsi_impu_id=$(sed -nr "s|.*IMPU_Load.do\?id=([0-9]+).*|\1|p" /tmp/curl_output)
    add_impu ${impi_id} tel%3A${msisdn} barring=off ${id_sp}
    set_impu_to_implicitset ${imsi_impu_id} sip%3A${imsi}%40${IMS_DOMAIN} tel%3A${msisdn} ${id_sp}
    add_impu ${impi_id} sip%3A${msisdn}%40${IMS_DOMAIN} barring=off ${id_sp}
    set_impu_to_implicitset ${imsi_impu_id} sip%3A${imsi}%40${IMS_DOMAIN} sip%3A${msisdn}%40${IMS_DOMAIN} ${id_sp}

    echo "added subscriber #${id} imsi: $imsi with tel:${msisdn} (key: $key opc: $opc)"
}
add_subscriptions () {
    source /mnt/o5gc/core-init.sh
    call_for_each_subscriber add_subscriber
}

adjust_conf_files

init_database

cd deploy
./startup.sh &
fhoss_pid=$!

wait-for-it 127.0.0.1:8080
sleep 1

{ set +x; } 2>/dev/null
add_subscriptions

wait -n ${fhoss_pid}
