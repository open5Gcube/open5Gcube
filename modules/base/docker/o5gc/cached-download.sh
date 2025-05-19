#! /bin/bash

set -ex

# will be set by base.Dockerfile
USE_BUILD_CACHER=0

p=$(dirname "${1}" | md5sum | awk '{print $1}')
f=$(basename "${1}")

if [ ${USE_BUILD_CACHER} -eq 1 ]; then
    rsync -az rsync://o5gc-build-cacher:40860/downloads/$p/$f . || true
    if [ ! -f $f ]; then
        wget $1
        # trick 17 to create remote target directory
        rsync /dev/null rsync://o5gc-build-cacher:40860/downloads/$p/
        rsync -az -O --no-perms $f rsync://o5gc-build-cacher:40860/downloads/$p/$f
    fi
else
    wget $1
fi

[ -z "$2" ] || mv $f $2
