#! /bin/bash

set -e

HOST_DISTRI=$(lsb_release -sc)
RESTRICT_DISTRI=$HOST_DISTRI

while [[ $# -gt 0 ]]; do
  case $1 in
    --only-for)
      RESTRICT_DISTRI="$2"
      shift; shift
      ;;
    --not-for)
      EXCLUDE_DISTRI="$2"
      shift; shift
      ;;
    *)
      break
      ;;
  esac
done

[[ "${HOST_DISTRI}" != "${RESTRICT_DISTRI}" ]] && exit 0
[[ "${HOST_DISTRI}" == "${EXCLUDE_DISTRI}" ]] && exit 0

case $1 in
  install)
    (set -x
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y "${@:2}" )
    apt-get clean
    rm -rf /var/lib/apt/lists/*
    ;;
  purge)
    (set -x
    DEBIAN_FRONTEND=noninteractive SUDO_FORCE_REMOVE=yes apt-get -y purge "${@:2}"
    DEBIAN_FRONTEND=noninteractive apt-get -y autoremove --purge )
    ;;
  *)
    exit 1
    ;;
esac
