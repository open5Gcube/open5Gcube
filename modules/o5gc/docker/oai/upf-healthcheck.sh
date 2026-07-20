#!/bin/bash
# SPDX-License-Identifier: MIT
set -eo pipefail

CONFIG=/openair-upf/etc/*.yaml
BPFTOOL=/openair-upf/bin/bpftool

# Read a single yes/no flag value from the config YAML.
config_flag() { grep "${1}:" $CONFIG | awk 'NR==1{print $2}'; }

check_configuration_file() {
  local n
  n=$(grep -v contact@openairinterface.org $CONFIG | grep -c @ || true)
  if [ "$n" -ne 0 ]; then
    echo "UNHEALTHY: configuration file has unreplaced template placeholders"
    return 1
  fi
}

get_interface_name() {
  local ref=$1
  local name
  name=$(grep -A 16 "upf:" $CONFIG | awk -v r="${ref}:" '$0~r{f=1} f && /interface_name:/{print $2; exit}')
  if [[ -z "$name" ]]; then
    echo "Error: interface_name not found for $ref" >&2
    return 1
  fi
  echo "$name"
}

# Verify that the named XDP program is attached to an interface.
# Usage: check_xdp_program <iface> <expected-prog-name>
check_xdp_program() {
  local iface=$1 expected=$2
  local prog_id prog_name

  prog_id=$(ip link show dev "$iface" | grep -oP 'prog/xdp id \K\d+')
  if [[ -z "$prog_id" ]]; then
    echo "UNHEALTHY: no XDP program attached to $iface"
    return 1
  fi

  prog_name=$($BPFTOOL prog list | grep -w "$prog_id" | awk '{print $4}')
  if [[ -z "$prog_name" ]]; then
    echo "UNHEALTHY: cannot resolve XDP program name for id $prog_id on $iface"
    return 1
  fi

  if [[ "$prog_name" == "$expected" ]]; then
    echo "OK: $expected attached to $iface"
  else
    echo "UNHEALTHY: expected $expected on $iface, found $prog_name"
    return 1
  fi
}

check_port_status() {
  local iface=$1 port=$2
  local ip
  ip=$(ifconfig "$iface" | awk '/inet /{print $2; exit}')
  if [[ -z "$ip" ]]; then
    echo "Error: no IPv4 address on $iface" >&2
    return 1
  fi
  if ss -uln | grep -qE "(${ip}|0\.0\.0\.0|\*):${port}[^0-9]"; then
    echo "OK: port $port listening on $ip"
  else
    echo "UNHEALTHY: port $port not listening on $ip"
    return 1
  fi
}

main() {
  local status=0
  local N4_PORT=8805

  check_configuration_file || { echo "Config check failed."; exit 1; }

  local N3 N4 N6
  N3=$(get_interface_name n3)
  N4=$(get_interface_name n4)
  N6=$(get_interface_name n6)
  echo "N3=$N3  N4=$N4  N6=$N6"

  if [[ "$(config_flag enable_bpf_datapath)" == "yes" ]]; then
    echo "BPF datapath enabled — checking XDP programs"

    # Select entry program names based on PDU session type.
    #   IP mode  (default):  xdp_n3_entry  /  xdp_n6_entry
    #   ETH mode:            xdp_n3_eth_entry / xdp_n6_eth_entry
    local n3_prog n6_prog
    if [[ "$(config_flag enable_eth_pdu)" == "yes" ]]; then
      n3_prog=xdp_n3_eth_entry
      n6_prog=xdp_n6_eth_entry
    else
      n3_prog=xdp_n3_entry
      n6_prog=xdp_n6_entry
    fi
  else
    echo "BPF datapath disabled — skipping XDP checks"
    check_port_status "$N4" "$N4_PORT" || status=1
  fi

  exit $status
}

main
