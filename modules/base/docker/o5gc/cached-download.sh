#! /bin/bash

set -ex

# will be set by base.Dockerfile
USE_BUILD_CACHER=0

p=$(dirname "${1}" | md5sum | awk '{print $1}')
f=$(basename "${1}")

WGET_ARGS=(
  "--user-agent='Mozilla/5.0 (X11; Fedora; Linux x86_64; rv:52.0) Gecko/20100101 Firefox/52.0'"
)
if [ ${USE_BUILD_CACHER} -eq 1 ]; then
    rsync -az rsync://o5gc-build-cacher:40860/downloads/$p/$f . || true
    if [ ! -f $f ]; then
        wget "${WGET_ARGS[@]}" $1
        # trick 17 to create remote target directory
        rsync /dev/null rsync://o5gc-build-cacher:40860/downloads/$p/
        rsync -az -O --no-perms $f rsync://o5gc-build-cacher:40860/downloads/$p/$f
    fi
else
    wget "${WGET_ARGS[@]}" $1
fi

[ -z "$2" ] || mv $f $2
