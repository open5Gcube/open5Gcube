#!/bin/bash

set -euo pipefail

log() { echo "+ $*" ; "$@" ; }

function build()
{
    declare -A VERSIONS=()
    HOST="localhost"
    BUILD_ARGS=; VERSION_ARG=; TARGET=; IMG=; VERSION_BUILD_ARG=
    args=$(getopt -a -o m:p:i:a:v:h:t: --long module:,project:,image:,arg:,version:,host:,target:,version-arg: -- "$@") || exit 1
    eval set -- ${args}
    while true; do
    case "$1" in
        -m|--module) MODULE=$2; shift 2 ;;
        -p|--project) PROJECT=${2#"docker-build-"}; shift 2 ;;
        -i|--image) IMG=$2; shift 2 ;;
        -a|--arg) BUILD_ARGS+=" --build-arg $2"; shift 2 ;;
        -v|--version) VERSIONS["$2"]=1; shift 2 ;;
        -h|--host) HOST=$2; shift 2 ;;
        -t|--target) TARGET="--target $2"; shift 2 ;;
        --version-arg) VERSION_ARG=$2; shift 2;;
        --) shift; break ;;
        *) echo "Unsupported option: $1" >&2; exit 3 ;;
    esac
    done
    IMG=${IMG#"docker-build-${PROJECT}-"}
    IMAGE="${PROJECT//\//-}${IMG:+-$IMG}"
    PROXY_ARGS=
    [[ -n "${http_proxy:-}" ]] && PROXY_ARGS+=" --build-arg http_proxy=${http_proxy}"
    [[ -n "${https_proxy:-}" ]] && PROXY_ARGS+=" --build-arg https_proxy=${https_proxy}"
    CONTEXT_TAR=
    if [[ "$HOST" != "localhost" ]]; then
        BUILD_CACHER=$(ip route get $(getent hosts "${HOST}" | awk '{print $1}') | sed -n 's|.* src \([0-9.]*\) .*|\1|p')
        DOCKER="docker -H ssh://${HOST}"
        # Remote builds read the context tarball from stdin (docker build -)
        CONTEXT_TAR="${BASE_DIR}/var/tmp/${HOST}-${IMAGE}.tar"
        BUILD_CONTEXT="-"
        STDIN_SRC="${CONTEXT_TAR}"
        tar -cf "${CONTEXT_TAR}" -C "${BASE_DIR}/modules/${MODULE}/docker/${PROJECT}" .
    else
        BUILD_CACHER="$(docker network inspect bridge -f '{{range .IPAM.Config}}{{.Gateway}}{{end}}')"
        DOCKER="docker"
        BUILD_CONTEXT="."
        STDIN_SRC="/dev/null"
    fi
    [ ${#VERSIONS[@]} -eq 0 ] && VERSIONS["latest"]="default"
    for version in "${!VERSIONS[@]}"; do
        TAG="${IMAGE}:${version}"
        log mkdir -p $(echo -n "${SYNC_CACHES}" | xargs  -d " " -I "%" echo var/cache/%/${HOST}/${IMAGE})
        DATE=$(date --rfc-3339=seconds)
        [[ ${VERSIONS["$version"]} == 1 && -n "$VERSION_ARG" ]] && VERSION_BUILD_ARG="--build-arg $VERSION_ARG=$version"
        (set -x;
        cd "modules/${MODULE}/docker/${PROJECT}"
        DOCKER_BUILDKIT=1 $DOCKER build                                               \
            --tag o5gc/${TAG}                                                         \
            --label "org.opencontainers.image.created=${DATE}"                        \
            --secret id=id_ed25519,src=${BASE_DIR}/var/ssh/id_ed25519                 \
            --secret id=id_ed25519.pub,src=${BASE_DIR}/var/ssh/id_ed25519.pub         \
            --add-host o5gc-build-cacher:${BUILD_CACHER}                              \
            --file "${IMG:+$IMG.}Dockerfile"                                          \
            ${BUILD_ARGS} ${PROXY_ARGS} ${VERSION_BUILD_ARG} ${TARGET}                \
            ${BUILD_CONTEXT} < "${STDIN_SRC}"
        )
        VERSION_BUILD_ARG=
        VERSION_STRING=$($DOCKER run --rm --entrypoint /bin/cat o5gc/${TAG} /etc/image_version)
        (set -x;
        echo "FROM o5gc/${TAG}" | $DOCKER build                                       \
            --tag o5gc/${TAG}                                                         \
            --label "org.opencontainers.image.version=${VERSION_STRING}" -
        $DOCKER tag o5gc/${TAG} o5gc/${IMAGE}:${VERSION_STRING} )
        $DOCKER image ls o5gc/${IMAGE}
    done
    if [[ -n "${CONTEXT_TAR}" ]]; then rm -fv "${CONTEXT_TAR}"; fi
}

function purge-old-images()
{
    local images img img_created age old_images=
    images=$(docker images 'o5gc/*' --format '{{.Repository}}:{{.Tag}}'      \
        | grep -v build-cacher | sort || true)
    echo "Old images:"
    for img in ${images}; do
        img_created=$(docker inspect --format                                \
            '{{index .Config.Labels "org.opencontainers.image.created"}}' "${img}")
        age=$(( ($(date +%s) - $(date +%s -d "${img_created}")) / (60*60*24) ))
        if [[ ${age} -gt 0 ]]; then
            echo "${img} build ${age} days ago"
            old_images+=" ${img}"
        fi
    done
    [[ -z "${old_images}" ]] && return 0
    read -r -p 'Purge? [y/n] ' x
    [[ "${x}" == "y" ]] || return 1
    docker image rm --force ${old_images}
}

function purge-all-images()
{
    local images
    read -r -p 'Purge all o5gc images? [y/n] ' x
    [[ "${x}" == "y" ]] || return 1
    images=$(docker images 'o5gc/*' -q | sort -u)
    [[ -z "${images}" ]] || docker image rm --force ${images}
}


[[ $# -lt 1 ]] && exit 1
"$1" "${@:2}"
