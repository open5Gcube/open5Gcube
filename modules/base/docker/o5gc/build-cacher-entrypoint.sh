#!/bin/bash

term_handler()
{
    /etc/init.d/apt-cacher-ng stop
    pids="$(pgrep node) $(pgrep rsync)"
    kill ${pids}
    sleep .5
    exit 0
}

set -e

trap 'term_handler' SIGTERM

# run apt-cacher-ng as non-root
cat << EOT >> /etc/default/apt-cacher-ng
USER=$(id -u)
GROUP=$(id -g)
EOT
# configure http prxy
[ -n "${http_proxy}" ] && echo "Proxy: ${http_proxy}" >> /etc/apt-cacher-ng/acng.conf

set -x

/etc/init.d/apt-cacher-ng start

rsync --config=/etc/rsyncd.conf --daemon

git-cache-http-server --port 8123 --cache-dir /var/cache/git &
wait -n $1
