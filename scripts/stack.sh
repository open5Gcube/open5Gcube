#!/bin/bash
# Run docker compose stacks from modules/*/stacks/.
#
# Usage:
#   stack.sh up <stack> [profile...]
#   stack.sh down <stack> [profile...]
#   stack.sh config <stack> [profile...]
#   stack.sh list
#
# The stack name may carry a trailing profile suffix, e.g. 'oai-5g-basic-core'
# selects stack 'oai-5g-basic' with only the profile 'core'.  Without profile
# arguments, the stack's default profiles are taken from the top-level
# 'x-o5gc-profiles:' key in its docker-compose.yaml.
# Set DETACHED=1 to run 'up' in detached mode.

set -euo pipefail

BASE_DIR=$(realpath "$(dirname "$(realpath "$0")")/..")
ENV_DIR="${BASE_DIR}/var/etc"

usage() { sed -n '2,/^$/s/^# \?//p' "$0"; }

default_profiles() {  # <stack-dir>
    sed -n 's/^x-o5gc-profiles: *//p' "$1/docker-compose.yaml" 2>/dev/null    \
        | tr '[],"' ' ' | xargs
}

list() {
    local dir stack module
    printf "%-32s %-8s %s\n" "STACK" "MODULE" "DEFAULT PROFILES"
    for dir in "${BASE_DIR}"/modules/*/stacks/*/; do
        dir=${dir%/}
        stack=$(basename "${dir}")
        module=$(basename "$(dirname "$(dirname "${dir}")")")
        printf "%-32s %-8s %s\n" "${stack}" "${module}" "$(default_profiles "${dir}")"
    done
}

find_stack_dir() {  # <stack>
    local dir
    for dir in "${BASE_DIR}"/modules/*/stacks/"$1"; do
        [ -d "${dir}" ] && { echo "${dir}"; return 0; }
    done
    return 1
}

# Resolve <name> to STACK/STACK_DIR/PROFILES.  If no stack dir matches the
# full name, trailing '-<segment>'s are stripped and used as a single profile
# (so 'ocudu-split-open5gs-5g-cu-cp' -> stack 'ocudu-split-open5gs-5g',
# profile 'cu-cp').
resolve_stack() {  # <name>
    local name=$1 suffix=
    while ! STACK_DIR=$(find_stack_dir "${name}"); do
        case "${name}" in
        *-*) suffix="${name##*-}${suffix:+-${suffix}}"; name="${name%-*}" ;;
        *)   echo "Unknown stack '$1', available stacks:" >&2
             list >&2
             exit 1 ;;
        esac
    done
    STACK=${name}
    SUFFIX_PROFILE=${suffix}
    PROFILES=${suffix:-$(default_profiles "${STACK_DIR}")}
}

# The develop image of a project is mounted over /o5gc/ as long as its
# develop and latest tags point to the same image (see 'develop-*-*' targets).
export_develop_volumes() {
    local img id_latest id_develop v
    for img in $(docker images 'o5gc/*:develop' --format '{{.Repository}}'); do
        id_latest=$(docker images --format '{{.ID}}' "${img}:latest")
        id_develop=$(docker images --format '{{.ID}}' "${img}:develop")
        [ -n "${id_latest}" ] && [ "${id_latest}" = "${id_develop}" ] || continue
        v=${img#o5gc/}; v=${v//-/_}
        export "DEVELOP_VOLUME_${v^^}=develop:/o5gc/"
    done
}

setup_env() {
    MODULE=${STACK_DIR#"${BASE_DIR}"/modules/}; MODULE=${MODULE%%/*}
    O5GC_STACK=${STACK}
    ENV_FILE="${ENV_DIR}/${MODULE}/${O5GC_STACK}.env"
    DOCKER_HOST_BRIDGE=$(docker network inspect bridge                        \
        -f '{{range .IPAM.Config}}{{.Gateway}}{{end}}')
    HOST_USER_GROUP_ID="$(id -u):$(id -g)"
    export BASE_DIR MODULE O5GC_STACK ENV_FILE DOCKER_HOST_BRIDGE HOST_USER_GROUP_ID
    export_develop_volumes
    MAKEFLAGS='' make --no-print-directory -s -C "${BASE_DIR}" "${ENV_FILE}"
}

compose() {  # <compose sub-command and args...>
    local profile file=docker-compose.yaml cmd=(docker compose "--env-file=${ENV_FILE}")
    cd "${STACK_DIR}"
    [ -f "${file}" ] || file=services.yaml
    cmd+=(--file "${file}" --file "${BASE_DIR}/etc/networks.yaml")
    for profile in ${PROFILES}; do cmd+=(--profile "${profile}"); done
    "${cmd[@]}" "$@"
}

# Guard against a mistyped stack name being misinterpreted as
# stack + profile suffix.
validate_suffix_profile() {
    [ -z "${SUFFIX_PROFILE}" ] && return 0
    PROFILES="" compose config --profiles | grep -Fxq "${SUFFIX_PROFILE}" && return 0
    echo "Stack '${STACK}' has no profile '${SUFFIX_PROFILE}', available profiles:" >&2
    PROFILES="" compose config --profiles >&2
    exit 1
}

ACTION=${1:-}
case "${ACTION}" in
up|down|config)
    [ $# -ge 2 ] || { usage >&2; exit 1; }
    resolve_stack "$2"
    if [ $# -gt 2 ]; then
        PROFILES="${*:3}"
        SUFFIX_PROFILE=
    fi
    setup_env
    validate_suffix_profile
    echo "+ stack: ${STACK} (module: ${MODULE}, profiles: ${PROFILES:-<none>})"
    case "${ACTION}" in
    up)     compose up ${DETACHED:+--detach} ;;
    down)   compose down ;;
    config) compose config ;;
    esac ;;
list)
    list ;;
*)
    usage >&2; exit 1 ;;
esac
