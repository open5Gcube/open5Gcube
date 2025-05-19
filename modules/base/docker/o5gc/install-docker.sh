#! /bin/bash

set -e

[[ $EUID -ne 0 ]] && echo "This script must be run as root." && exit 1

apt_get_install() {
    if grep -sq 'docker' /proc/1/cgroup; then
        apt-get.sh install "$@"
    else (
        set -x
        apt-get update
        apt-get install -y --allow-downgrades --allow-change-held-packages "$@" )
    fi
}

install_preliminaries() {
    apt_get_install ca-certificates curl gnupg lsb-release

    KEYRING=/etc/apt/keyrings/docker.gpg
    rm -f ${KEYRING}
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg |                 \
        gpg --dearmor -o ${KEYRING}
    chmod a+r ${KEYRING}

    echo "deb [arch=$(dpkg --print-architecture) signed-by=${KEYRING}]"       \
            "https://download.docker.com/linux/ubuntu"                        \
            "$(lsb_release -cs) stable"                                       \
        > /etc/apt/sources.list.d/docker.list
}

install_docker_cli() {
    [ "$(lsb_release -cs)" == "focal" ] &&                                   \
        apt_get_install docker-ce-cli=5:24.* docker-compose-plugin=2.18.* docker-buildx-plugin=0.10.*
    [ "$(lsb_release -cs)" == "jammy" ] &&                                    \
        apt_get_install docker-ce-cli=5:24.* docker-compose-plugin=2.21.* docker-buildx-plugin=0.12.*
    apt-mark hold docker-ce-cli docker-compose-plugin docker-buildx-plugin
}

install_docker_ce() {
    apt_get_install docker-ce=5:24.* docker-ce-rootless-extras=5:24.* containerd.io=1.6.*
    apt-mark hold docker-ce docker-ce-rootless-extras containerd.io
}

install_preliminaries

case "$1" in
    cli-only)
        install_docker_cli
        ;;
    all)
        install_docker_cli
        install_docker_ce
        ;;
    *)
        exit 1
        ;;
esac
