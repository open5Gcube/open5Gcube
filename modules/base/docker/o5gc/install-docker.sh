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
    case "$OS_DISTRO $OS_RELEASE" in
        "ubuntu 20.04" | "ubuntu 22.04" | "ubuntu 24.04")
            apt_get_install docker-ce-cli=5:28.* docker-compose-plugin=2.35.* docker-buildx-plugin=0.23.*
            ;;
        *)
            exit 1
    esac
    apt-mark hold docker-ce-cli docker-compose-plugin docker-buildx-plugin
}

install_docker_ce() {
    case "$OS_DISTRO $OS_RELEASE" in
        "ubuntu 20.04" | "ubuntu 22.04" | "ubuntu 24.04")
            apt_get_install docker-ce=5:28.* docker-ce-rootless-extras=5:28.* containerd.io=1.7.*
            ;;
        *)
            exit 1
    esac
    apt-mark hold docker-ce docker-ce-rootless-extras containerd.io
    systemctl restart docker
}

check_supported_distribution() {
    case "$OS_DISTRO $OS_RELEASE" in
        "ubuntu 20.04") return 0 ;;
        "ubuntu 22.04") return 0 ;;
        "ubuntu 24.04") return 0 ;;
    esac
    echo "You're using an unsupported distro: $OS_DISTRO $OS_RELEASE"
    exit 1
}

if [ ! -f /etc/os-release ]; then
    echo "No /etc/os-release file found. You're using an unsupported distro."
    exit 1
fi
OS_DISTRO=$(grep "^ID=" /etc/os-release | sed "s/ID=//" | sed "s/\"//g")
OS_RELEASE=$(grep "^VERSION_ID=" /etc/os-release | sed "s/VERSION_ID=//" | sed "s/\"//g")

check_supported_distribution

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
