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

exec /bin/tini -- LTESniffer                                                  \
    -m 0 `# sniffer mode, 0 for downlink and 1 for uplink sniffing`           \
    -a "num_recv_frames=512" `# extends the receiving buffer for USRP B210`   \
    -A 2 `# number of antennas`                                               \
    -W 4 `# number of threads`                                                \
    -f ${SNIFF_FREQ} `# frequency`                                            \
    ${CELL_ARG} `# Cell-Search or PCI/PRB of the cell`                        \
    ${DEBUG_ARG} `# Debug Mode`                                               \
    -z ${SNIFF_SECURITY_API} `# Security API`
