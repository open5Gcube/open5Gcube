#! /bin/bash

set -e

echo
echo USRP x310 flash helper
echo

BASE_DIR=$(realpath $(dirname "$0")/..)

echo "Available stacks"
RAN_STACKS=$(find etc -name docker-compose.yaml -printf "%h\n" | xargs -L1 basename | grep -E "^oai|srsran" | sort)
i=1; for stack in ${RAN_STACKS}; do
    echo "${i}  ${stack}"
    (( i++ ))
done

read -r -p "Select the stack for which the x310 should be flashed: " 'i'
STACK=$(echo ${RAN_STACKS} | cut -d " " -f ${i});

export O5GC_STACK=${STACK}
export ENV_FILE=${BASE_DIR}/var/etc/${O5GC_STACK}.env
export UHD_IMAGE_LOADER=1
make -s -C ${BASE_DIR} ${ENV_FILE}
DOCKER_COMPOSE="docker compose --env-file=${ENV_FILE}                         \
    --file docker-compose.yaml --file ${BASE_DIR}/etc/networks.yaml"

cd etc/${STACK}

echo
echo "RAN services for ${STACK}"
PROFILES=$(for p in $(${DOCKER_COMPOSE} config --profiles); do echo -n " --profile ${p}"; done)
SERVICES=$(${DOCKER_COMPOSE} ${PROFILES} config --services | grep -E "enb|gnb")
j=1; for srv in ${SERVICES}; do
    echo "${j}  ${srv}"
    (( j++ ))
done
read -r -p "Select the service: " 'j'
SERVICE=$(echo ${SERVICES} | cut -d " " -f ${j});

TARGET_HOSTNAME=$(${DOCKER_COMPOSE} run --rm --entrypoint /bin/bash ${SERVICE} -c "echo \${DOCKER_TARGET_HOSTNAME}")
echo
[[ "$(read -r -e -p "Continue updating USRP connected @ ${TARGET_HOSTNAME} for ${STACK}/${SERVICE} [y/N]> "; echo $REPLY)" == [Yy]* ]] || exit 1
echo

set -x

${DOCKER_COMPOSE} run --rm ${SERVICE}
