#!  /bin/bash
set -e

srv=$1
[ "${UHD_IMAGE_LOADER}" == "1" ] && srv=uhd_image_loader

case "${srv}" in
    gnb | enb | nr-ue | lte-ue)
        sleep 1
        # wait until all initialisation containers are completed
        while sleep 1; do
            init_containers=$(docker container ls --filter label=o5gc.initialisation --format '{{.Names}}' | tr '\n' ' ')
            if [[ -n "${init_containers}" ]]; then echo "Waiting for completion of initialisation containers: ${init_containers}";
            else break; fi
        done
        # wait until all core network functions are healthy
        while sleep 1; do
            nonhealthy_containers=$(docker container ls --filter label=o5gc.corenetwork-function --filter health=unhealthy --filter health=starting --format '{{.Names}}' | tr '\n' ' ')
            created_containers=$(docker container ls --filter label=o5gc.corenetwork-function --filter status=created --format '{{.Names}}' | tr '\n' ' ')
            if [[ -n "${nonhealthy_containers}${created_containers}" ]]; then echo "Wait until the core network containers are healthy: ${nonhealthy_containers} ${created_containers}";
            else break; fi
        done
        if [ "${srv}" == "gnb" ] && [ -n "$(dig +short enb)" ]; then
            retry --until=success --times=10 --delay=5 -- ncat -v -z --sctp ${ENB_IP_ADDR} 36422
            sleep 1
        fi
        ;;
esac

set -x

if /docker-remote.sh --check; then
    exec /docker-remote.sh ${1}
fi

SOFTMODEM_ARGS=
B210_DETECTED="$(lsusb -d 2500:0020 || true)"

[ -n "${OAI_RFSIM_ENABLE}" ] && SOFTMODEM_ARGS+=" --rfsim"

if [ -n "${B210_DETECTED}" ]; then
    export USRP_ARGS="type=b200"
else
    export USRP_ARGS="type=x300,addr=192.168.40.2"
fi

mkdir -p scripts/venv/bin/
ln -sf $(which python3) -t scripts/venv/bin/
[ -z "${NR_ABS_FREQ_POINT_A_ARFCN}" ] &&                                      \
    export NR_ABS_FREQ_POINT_A_ARFCN=$(scripts/band_helper.py abs_freq_point_a_arfcn ${NR_ARFCN})
export EUTRA_FREQ_DL=$(scripts/band_helper.py earfcn_to_freq_dl ${EUTRA_BAND} ${EUTRA_ARFCN_DL})
export EUTRA_FREQ_OFFSET_UL=$(scripts/band_helper.py earfcn_to_freq_offset_ul ${EUTRA_BAND} ${EUTRA_ARFCN_DL})

case "${srv}" in
    gnb | enb | nr-ue | lte-ue)
        cfg_file=etc/${srv}.conf
        if [ -n "${B210_DETECTED}" ]; then
            [ -f etc/${srv}.b210.conf ] && cfg_file=etc/${srv}.b210.conf
        else
            [ -f etc/${srv}.x310.conf ] && cfg_file=etc/${srv}.x310.conf
        fi
        export FIVEG_INTEGRITY_ORDER="$(echo \"${FIVEG_INTEGRITY_ORDER//, /\", \"}\" | tr '[:upper:]' '[:lower:]')"
        export FIVEG_CIPHERING_ORDER="$(echo \"${FIVEG_CIPHERING_ORDER//, /\", \"}\" | tr '[:upper:]' '[:lower:]')"
        envsubst.sh ${cfg_file} ${cfg_file%.*}.run.${cfg_file##*.}
        cfg_file=${cfg_file%.*}.run.${cfg_file##*.}
        cat ${cfg_file}
        ;;
esac

cat /etc/image_version

case "${srv}" in
    gnb)
        [ -n "${OAI_TRACER_ENABLE}" ] && SOFTMODEM_ARGS+=" --T_stdout 2 --T_nowait"
        SOFTMODEM_ARGS+=" -E --continuous-tx"
        build/nr-softmodem                                                    \
            -O ${cfg_file} ${SOFTMODEM_ARGS} "${@:2}"
        exit 1
        ;;
    enb)
        [ -n "${OAI_RFSIM_ENABLE}" ] && sleep 50
        [ -n "${OAI_TRACER_ENABLE}" ] && SOFTMODEM_ARGS+=" --T_stdout 2 --T_nowait"
        build/lte-softmodem                                                   \
            -O ${cfg_file} ${SOFTMODEM_ARGS} --T_stdout 2 --T_nowait "${@:2}"
        exit 1
        ;;
    nr-ue)
        if [ -n "${OAI_RFSIM_ENABLE}" ]; then
            sleep 10
            SOFTMODEM_ARGS+=" --rfsimulator.serveraddr ${OAI_RFSIM_SERVERADDR}"
            SOFTMODEM_ARGS+=" -E"
        fi
        [ -n "${B210_DETECTED}" ] && SOFTMODEM_ARGS+=" -E"
        args=$(eval echo ${@:2})
        build/nr-uesoftmodem --sa --nokrnmod                                  \
            --usrp-args ${USRP_ARGS} --clock-source 1 ${SOFTMODEM_ARGS}       \
            -O ${cfg_file} ${args}
        wait_pid=$!
        ;;
    lte-ue)
        [ -n "${OAI_RFSIM_ENABLE}" ] && sleep 80
        [ -n "${OAI_RFSIM_ENABLE}" ] && SOFTMODEM_ARGS+=" --rfsimulator.serveraddr ${OAI_RFSIM_SERVERADDR}"
        targets/bin/conf2uedata -c ${cfg_file} -o .
        build/lte-uesoftmodem --nokrnmod 1                                    \
            --usrp-args ${USRP_ARGS} --clock-source 1 ${SOFTMODEM_ARGS}       \
            "${@:2}" &
        wait_pid=$!
        ;;
    tracer)
        tracee=$2
        tracee_ip=${tracee^^}_IP_ADDR
        cd common/utils/T/
        tracer/${tracee} -d ./T_messages.txt -ip ${!tracee_ip}
        ;;
    macpdu2wireshark)
        tracee=$2
        tracee_ip=${tracee^^}_IP_ADDR
        cd common/utils/T/
        tracer/macpdu2wireshark -d ./T_messages.txt                           \
            -live -live-ip ${!tracee_ip} -ip ${TARGET_IP_ADDR}                \
            -no-bind -no-mib -no-sib
        ;;
    uhd_image_loader)
        (set +x;
        for i in $(seq 10 -1 1); do echo "USRP will be flashed now. Press CTRL-C to abort. ($i)"; sleep 1s; done
        ) 2>/dev/null
        uhd_image_loader --args type=x300,addr=192.168.40.2
        exit 0
        ;;
    *)
        echo unknown service ${srv}
        exit 1
esac

case "${srv}" in
    nr-ue|lte-ue)
        while [ ! -d /sys/class/net/oaitun_ue1 ]; do
            echo "Waiting for 'oaitun_ue1' to come up"
            sleep 1
        done
        sleep 5
        ifconfig
#        ip route del 0/0
#        ip route add default via $(prips ${UE_IP_SUBNET} | sed "2q;d") dev oaitun_ue1
        route -n
        ;;
esac

[ -n "${wait_pid}" ] && wait -n ${wait_pid}
