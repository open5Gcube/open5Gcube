#! /bin/bash

set -ex

# will be set by base.Dockerfile
USE_BUILD_CACHER=0

[ ${USE_BUILD_CACHER} -ne 0 ] || exit 0

BUILD_HOST=$(cat /etc/build_host)

for cache in "${@:3}"; do
    [ "$cache" == "ccache" ] && dir=/root/.ccache
    [ "$cache" == "sccache" ] && dir=/root/.cache/sccache
    [ "$cache" == "cargo-registry" ] && dir=/root/.cargo/registry
    [ "$cache" == "npm-cache" ] && dir=/root/.npm/_cacache
    [ "$cache" == "go-cache-dl" ] && dir=/root/go/pkg/mod/cache/download
    [ "$cache" == "go-cache-build" ] && dir=/root/.cache/go-build
    case "$1" in
        download)
            mkdir -p ${dir}
            rsync -a rsync://o5gc-build-cacher:40860/${cache}/${BUILD_HOST}/$2/ ${dir}
            ;;
        upload)
            rsync -a -O --no-perms ${dir}/ rsync://o5gc-build-cacher:40860/${cache}/${BUILD_HOST}/$2
            rm -rf ${dir}
            ;;
    esac
done
