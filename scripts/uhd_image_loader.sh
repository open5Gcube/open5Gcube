#! /bin/bash
#
# Flash the firmware of an USRP X310 from a RAN container, so that it matches
# the UHD version of that container. The script is agnostic of the RAN
# projects: every service passing UHD_IMAGE_LOADER into its container is
# expected to run uhd_image_loader instead of its regular command, when set.

set -e

TITLE="USRP X310 flash helper"
# use whiptail when available and running interactively, else plain bash
TUI=$(command -v whiptail >/dev/null && [ -t 0 ] && echo 1 || true)

# menu <text> <items...>: prints the selected item, fails on cancel
menu() {
    local text=$1 item; shift
    if [[ -n "${TUI}" ]]; then
        local args=()
        for item in "$@"; do args+=("${item}" ""); done
        whiptail --title "${TITLE}" --menu "${text}" 0 0 0                    \
            "${args[@]}" 3>&1 1>&2 2>&3
    else
        echo -e "\n${text}" >&2
        PS3="> "
        select item in "$@"; do
            [[ -n "${item}" ]] && echo "${item}" && return
        done
        return 1
    fi
}
# confirm <text>: fails unless confirmed
confirm() {
    if [[ -n "${TUI}" ]]; then
        whiptail --title "${TITLE}" --defaultno --yesno "$1" 10 70
    else
        local reply
        read -r -e -p "$1 [y/N]> " reply
        [[ "${reply}" == [Yy]* ]]
    fi
}

echo -e "\n${TITLE}\n"

BASE_DIR=$(realpath "$(dirname "$0")/..")
cd "${BASE_DIR}"

export BASE_DIR
export DOCKER_HOST_BRIDGE=$(docker network inspect bridge -f '{{range .IPAM.Config}}{{.Gateway}}{{end}}')
export HOST_USER_GROUP_ID=$(id -u):$(id -g)
export UHD_IMAGE_LOADER=1

env_file() { echo "${BASE_DIR}/var/etc/${1}.env"; }

# prints the resolved compose config of the stack <module>/<stack>
compose_config() {
    local MODULE=${1%/*} O5GC_STACK=${1#*/}
    local ENV_FILE=$(env_file "$1")
    export MODULE O5GC_STACK ENV_FILE
    cd "${BASE_DIR}/modules/${MODULE}/stacks/${O5GC_STACK}"
    docker compose --env-file="${ENV_FILE}"                                   \
        --file docker-compose.yaml --file "${BASE_DIR}/etc/networks.yaml"     \
        --profile '*' config --format json
}
# prints the stack name, if it contains a service supporting UHD_IMAGE_LOADER
uhd_stack() {
    compose_config "$1" 2>/dev/null | jq -e '[.services[]
        | select(.environment | has("UHD_IMAGE_LOADER"))] | length > 0'      \
        &>/dev/null && echo "$1"
    return 0
}
export -f env_file compose_config uhd_stack

mapfile -t ALL_STACKS < <(printf '%s\n' modules/*/stacks/*/ | cut -d / -f2,4)
# create the env files in one make run, git-localenv-ignore can't run parallel
MAKEFLAGS='' make --no-print-directory -s -k                                  \
    $(for s in "${ALL_STACKS[@]}"; do env_file "${s}"; done) 2>/dev/null || true
mapfile -t RAN_STACKS < <(printf "%s\n" "${ALL_STACKS[@]}"                     \
    | xargs -P "$(nproc)" -I{} bash -c 'uhd_stack {}' | sort)

STACK=$(menu "Select the stack for which the X310 should be flashed"         \
    "${RAN_STACKS[@]}") || exit 1

export MODULE=${STACK%/*}
export O5GC_STACK=${STACK#*/}
export ENV_FILE=$(env_file "${STACK}")
MAKEFLAGS='' make --no-print-directory -s "${ENV_FILE}"

CONFIG=$(compose_config "${STACK}")
mapfile -t SERVICES < <(echo "${CONFIG}" | jq -r '.services | to_entries[]
    | select(.value.environment | has("UHD_IMAGE_LOADER")) | .key' | sort)

if [[ ${#SERVICES[@]} -eq 1 ]]; then
    SERVICE=${SERVICES[0]}
else
    SERVICE=$(menu "Select the RAN service of ${O5GC_STACK}"                  \
        "${SERVICES[@]}") || exit 1
fi

TARGET_HOSTNAME=$(echo "${CONFIG}" | jq -r --arg s "${SERVICE}"               \
    '.services[$s].environment.DOCKER_TARGET_HOSTNAME // "localhost"')
IMAGE=$(echo "${CONFIG}" | jq -r --arg s "${SERVICE}" '.services[$s].image')

# UHD version of the image on the host the USRP is connected to, as done by
# docker-remote.sh, it determines the firmware version flashed to the USRP
DOCKER=(docker)
if [[ "${TARGET_HOSTNAME}" != "localhost"                                     \
      && "${TARGET_HOSTNAME}" != "$(docker info --format '{{.Name}}')" ]]; then
    DOCKER+=(-H "ssh://${TARGET_HOSTNAME}")
fi
UHD_VERSION=$("${DOCKER[@]}" run --rm --pull never --entrypoint uhd_config_info \
    "${IMAGE}" --version 2>/dev/null </dev/null | sed -n 's/^UHD //p') || true

confirm "Flash the USRP connected @ ${TARGET_HOSTNAME} from ${O5GC_STACK}/${SERVICE} with UHD ${UHD_VERSION:-unknown} (${IMAGE})?" || exit 1
echo

set -x

cd "modules/${MODULE}/stacks/${O5GC_STACK}"
docker compose --env-file="${ENV_FILE}"                                       \
    --file docker-compose.yaml --file "${BASE_DIR}/etc/networks.yaml"         \
    run --rm --no-deps "${SERVICE}"
