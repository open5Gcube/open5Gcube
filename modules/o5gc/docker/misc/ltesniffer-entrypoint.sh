#!  /bin/bash
set -ex

if [ -z "${SNIFF_FREQ}" ]; then
    cd /o5gc
    mkdir -p scripts/venv/bin/
    ln -sf $(which python3) -t scripts/venv/bin/
    SNIFF_FREQ=$(/o5gc/band_helper.py earfcn_to_freq_dl ${SNIFF_BAND} ${SNIFF_ARFCN})
fi

if [ "${SNIFF_CELL_SEARCH}" == "1" ]; then
    CELL_ARG="-C"
else
    [ -z "${SNIFF_CELL_PCI}" ] && echo "SNIFF_CELL_PCI is missing" && exit 1
    [ -z "${SNIFF_CELL_PRB}" ] && echo "SNIFF_CELL_PRB is missing" && exit 1
    CELL_ARG="-I ${SNIFF_CELL_PCI} -p ${SNIFF_CELL_PRB}"
fi

[ -n "${SNIFF_DEBUG}" ] && DEBUG_ARG="-d"

B210_DETECTED="$(lsusb -d 2500:0020 || true)"
if [ -n "${B210_DETECTED}" ]; then
    USRP_ARGS="type=b200,num_recv_frames=512"  # extends the receiving buffer for USRP B210
    # the B210 must be connected via USB 3
    uhd_find_devices --args type=b200 > /dev/null
    for dev in /sys/bus/usb/devices/*; do
        [ "$(cat ${dev}/id{Vendor,Product} 2>/dev/null)" == $'2500\n0020' ] || continue
        if [ "$(cat ${dev}/speed)" -lt 5000 ]; then
            echo "USRP B210 (${dev##*/}) is connected via USB 2, use a USB 3 port"
            exit 1
        fi
    done
else
    USRP_ARGS="type=x300,addr=192.168.40.2"
fi

cd /mnt/traces

exec /bin/tini -- LTESniffer                                                  \
    -m 0 `# sniffer mode, 0 for downlink and 1 for uplink sniffing`           \
    -a ${USRP_ARGS} `# RF args`                                               \
    -A 2 `# number of antennas`                                               \
    -W 4 `# number of threads`                                                \
    -f ${SNIFF_FREQ} `# frequency`                                            \
    ${CELL_ARG} `# Cell-Search or PCI/PRB of the cell`                        \
    ${DEBUG_ARG} `# Debug Mode`                                               \
    -z ${SNIFF_SECURITY_API} `# Security API`
