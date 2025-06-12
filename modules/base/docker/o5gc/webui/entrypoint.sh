#!/bin/bash

set -ex

envsubst.sh /mnt/webui/nginx.conf /etc/nginx/nginx.conf

nginx -t
service nginx start

if [ -d /mnt/.ssh/ ]; then
    cp -a /mnt/.ssh/* ~/.ssh
    chown $(id -u):$(id -g) ~/.ssh/*
    rm -f ~/.ssh/known_hosts
    echo -e "Host *\n\tUser ${HOST_USER}" >> ~/.ssh/config
fi
[ "${ENB_HOSTNAME}" != "localhost" ] && ssh-keyscan ${ENB_HOSTNAME} >> ~/.ssh/known_hosts
[ "${GNB_HOSTNAME}" != "localhost" ] && ssh-keyscan ${GNB_HOSTNAME} >> ~/.ssh/known_hosts

export USER=${HOST_USER}
export HOME=${HOST_HOME}

cd /o5gc/webui/backend
FLASK_CONFIG_FILE=$(pwd)/src/config.py gunicorn 'src.app:create_app()' --bind=127.0.0.1:5000
#FLASK_CONFIG_FILE=$(pwd)/config.py python3 -m flask run --port=5000 --debug
