#! /bin/bash

set -e

service pcscd start
sleep .5

if [ -n "$*" ]; then
    exec /bin/bash -c "$*"
else
    exec /bin/bash
fi
