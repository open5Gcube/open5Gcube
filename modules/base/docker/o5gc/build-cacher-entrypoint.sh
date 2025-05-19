#!/bin/bash
term_handler()
{
    /etc/init.d/apt-cacher-ng stop
    pids="$(pgrep node) $(pgrep rsync)"
    kill ${pids}
    sleep .5
    exit 0
}

set -ex

trap 'term_handler' SIGTERM

# run apt-cacher-ng as non-root
cat << EOT >> /etc/default/apt-cacher-ng
USER=$(id -u)
GROUP=$(id -g)
EOT

/etc/init.d/apt-cacher-ng start

rsync --config=/etc/rsyncd.conf --daemon

git-cache-http-server --port 8123 --cache-dir /var/cache/git &
wait -n $1
