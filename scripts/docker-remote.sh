#! /bin/bash

term_handler()
{
    kill $(pgrep -P ${docker_pid})
    wait ${docker_pid}
    exit 0
}

set -ex

trap 'term_handler' SIGTERM

if [ "$1" == "--check" ]; then
    [[ -z "${DOCKER_TARGET_HOSTNAME}" || "${DOCKER_TARGET_HOSTNAME}" == "localhost" ]] && exit 1
    DOCKER_HOSTNAME=$(docker info --format '{{.Name}}')
    [[ "${DOCKER_HOSTNAME}" == "${DOCKER_TARGET_HOSTNAME}" ]] && exit 1 || exit 0
fi

CONTAINER_ID=$(grep "/docker/containers/" /proc/self/mountinfo | head -1 | awk '{print $4}' | sed -E "s|/var/lib/docker/containers/(.*)/resolv.conf|\1|")
CONTAINER_NETWORKS=$(docker inspect ${CONTAINER_ID} --format='{{range $k,$v := .NetworkSettings.Networks}} {{$k}} {{end}}')
for net in ${CONTAINER_NETWORKS}; do
    (set -x
    docker network disconnect ${net} ${CONTAINER_ID} )
done
docker network connect bridge ${CONTAINER_ID}

if [ -d /mnt/.ssh/ ]; then
    cp -a /mnt/.ssh/* ~/.ssh
    chown $(id -u):$(id -g) ~/.ssh/*
    rm ~/.ssh/known_hosts
    echo -e "Host *\n\tUser ${HOST_USER}" >> ~/.ssh/config
fi

unset BASE DOCKER MODULES VAR
export BASE_DIR=/tmp/o5gc
export USER=$(whoami)
export ENV_FILE=${BASE_DIR}/var/etc/${MODULE}/${O5GC_STACK}.env

ssh-keyscan ${DOCKER_TARGET_HOSTNAME} >> ~/.ssh/known_hosts

rsync -a --delete --exclude var/cache ${BASE_DIR}/ ${DOCKER_TARGET_HOSTNAME}:${BASE_DIR}

{ set +x; } 2>/dev/null
echo
echo "-----------------------------------------"
echo "-- Run Docker @ ${DOCKER_TARGET_HOSTNAME}"
echo "-----------------------------------------"
{ set -x; } 2>/dev/null

DOCKER_COMPOSE="docker -H ssh://${DOCKER_TARGET_HOSTNAME} compose             \
    --env-file=${ENV_FILE}                                                    \
    --file docker-compose.yaml --file ${BASE_DIR}/etc/networks.yaml           \
    --profile $1"                                                             \

cd ${BASE_DIR}/modules/${MODULE}/stacks/${O5GC_STACK}
${DOCKER_COMPOSE} up --force-recreate --no-log-prefix &
docker_pid=$!
wait -n ${docker_pid}

exit_code=$(${DOCKER_COMPOSE} ps -a -q                                        \
    | xargs docker -H ssh://${DOCKER_TARGET_HOSTNAME}                         \
        inspect -f '{{ .State.ExitCode }}' | grep -v "^0")
exit ${exit_code}
