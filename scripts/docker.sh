#!/bin/bash

set -euo pipefail

log() { echo "+ $@" ; "$@" ; }

function build() 
{
    declare -A VERSIONS=()
    HOST="localhost"
    BUILD_ARGS=; VERSION_ARG=; TARGET=; IMG=
    args=$(getopt -a -o m:p:i:a:v:h:t: --long module:,project:,image:,arg:,version:,host:,target,version-arg: -- "$@")
    [[ $? -gt 0 ]] && exit 1
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
    if [[ "$HOST" != "localhost" ]]; then
        BUILD_CACHER=$(ip route get $(getent hosts "${HOST}" | awk '{print $1}') | sed -n 's|.* src \([0-9.]*\) .*|\1|p')
        DOCKER="docker -H ssh://${HOST}"
        BUILD_CONTEXT=" < ${BASE_DIR}/var/tmp/${HOST}-${IMAGE}.tar"
        tar -cf "${BASE_DIR}/var/tmp/${HOST}-${IMAGE}.tar" -C "${BASE_DIR}/modules/${MODULE}/docker/${PROJECT}" .
    else
        BUILD_CACHER="$(docker network inspect bridge -f '{{range .IPAM.Config}}{{.Gateway}}{{end}}')"
        DOCKER="docker"
        BUILD_CONTEXT="."
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
            ${BUILD_ARGS} ${VERSION_BUILD_ARG} ${TARGET}                              \
            ${BUILD_CONTEXT}
        )
        VERSION_BUILD_ARG=
        rm -fv "${BASE_DIR}/var/tmp/${HOST}-${IMAGE}.tar"

        VERSION_STRING=$($DOCKER run --rm --entrypoint /bin/cat o5gc/${TAG} /etc/image_version)
        (set -x;
        echo "FROM o5gc/${TAG}" | $DOCKER build                                       \
            --tag o5gc/${TAG}                                                         \
            --label "org.opencontainers.image.version=${VERSION_STRING}" -
        $DOCKER tag o5gc/${TAG} o5gc/${IMAGE}:${VERSION_STRING} )
        $DOCKER image ls o5gc/${IMAGE}
    done
}


[[ $# -lt 1 ]] && exit 1
"$1" "${@:2}"
