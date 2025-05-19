#!  /bin/bash
set -ex

cd "$(dirname "$0")"
mkdir -p scripts/venv/bin/
ln -sf $(which python3) -t scripts/venv/bin/

EUTRA_FREQ_DL=$(scripts/band_helper.py earfcn_to_freq_dl ${EUTRA_BAND} ${EUTRA_ARFCN_DL})
EUTRA_FREQ_DL_MHZ=$(printf "${EUTRA_FREQ_DL} / 1000000\n" | bc -l | sed '/\./ s/\.\{0,1\}0\{1,\}$//')

NR_FREQ=$(scripts/band_helper.py arfcn_to_freq ${NR_ARFCN})
NR_FREQ_MHZ=$(printf "${NR_FREQ} / 1000000\n" | bc -l | sed '/\./ s/\.\{0,1\}0\{1,\}$//')

mkdir -p /root/.suscan/config
cat > /root/.suscan/config/bookmarks.yaml << EOF
%TAG ! tag:actinid.org,2022:suscan:
---
- name: ${EUTRA_FREQ_DL_MHZ} MHz (EARFCN ${EUTRA_ARFCN_DL})
  frequency: ${EUTRA_FREQ_DL}
  color: '#ffffff'
  low_freq_cut: -16666
  high_freq_cut: 16666
  modulation: AM
- name: ${NR_FREQ_MHZ} MHz (ARFCN ${NR_ARFCN})
  frequency: ${NR_FREQ}
  color: '#ffffff'
  low_freq_cut: -16666
  high_freq_cut: 16666
  modulation: AM
EOF

exec SigDigger
