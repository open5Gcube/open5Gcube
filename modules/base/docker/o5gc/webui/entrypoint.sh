#!/bin/bash

set -ex

envsubst.sh /mnt/webui/nginx.conf /etc/nginx/nginx.conf

service nginx configtest
service nginx start

if [ -d /mnt/.ssh/ ]; then
    cp -a /mnt/.ssh/* ~/.ssh
    chown $(id -u):$(id -g) ~/.ssh/*
    echo -e "Host *\n\tUser ${HOST_USER}" >> ~/.ssh/config
fi

export USER=${HOST_USER}
export HOME=${HOST_HOME}

cd /o5gc/webui/backend
FLASK_CONFIG_FILE=$(pwd)/src/config.py gunicorn 'src.app:create_app()' --bind=127.0.0.1:5000 -w 4 --timeout 300
#FLASK_CONFIG_FILE=$(pwd)/config.py python3 -m flask run --port=5000 --debug
