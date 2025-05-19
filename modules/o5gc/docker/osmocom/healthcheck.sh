#!/bin/bash

set -e

service=$(hostname)
case "${service}" in
    osmo-hlr)
        wait-for-it -t 1 ${OSMO_HLR_IP_ADDR}:${OSMO_HLR_VTY_PORT}
        ;;
    osmo-stp)
        wait-for-it -t 1 ${OSMO_STP_IP_ADDR}:${OSMO_STP_VTY_PORT}
        ;;
    osmo-msc)
        wait-for-it -t 1 ${OSMO_MSC_IP_ADDR}:${OSMO_MSC_VTY_PORT}
        ;;
    osmo-mgw)
        wait-for-it -t 1 ${OSMO_MGW_IP_ADDR}:${OSMO_MGW_VTY_PORT}
        ;;
    osmo-trx)
        wait-for-it -t 1 ${OSMO_TRX_IP_ADDR}:${OSMO_TRX_VTY_PORT}
        ;;
    osmo-sgsn)
        wait-for-it -t 1 ${OSMO_SGSN_IP_ADDR}:${OSMO_SGSN_VTY_PORT}
        ;;
    osmo-ggsn)
        wait-for-it -t 1 ${OSMO_GGSN_IP_ADDR}:${OSMO_GGSN_VTY_PORT}
        ;;
    osmo-bsc)
        wait-for-it -t 1 ${OSMO_BSC_IP_ADDR}:${OSMO_BSC_VTY_PORT}
        ;;
    osmo-bts)
        wait-for-it -t 1 ${OSMO_BTS_IP_ADDR}:${OSMO_BTS_VTY_PORT}
        ;;
    osmo-pcu)
        wait-for-it -t 1 ${OSMO_PCU_IP_ADDR}:${OSMO_PCU_VTY_PORT}
        ;;
    osmo-cbc)
        wait-for-it -t 1 ${OSMO_CBC_IP_ADDR}:${OSMO_CBC_VTY_PORT}
        ;;
    *)
        echo "Error: Invalid SERVICE: ${service}"
        exit 1;
        ;;
esac
