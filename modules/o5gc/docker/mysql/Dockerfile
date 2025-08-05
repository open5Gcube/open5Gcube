FROM mysql:8.0-debian

RUN rm /etc/apt/sources.list.d/mysql.list                                        \
    && DEBIAN_FRONTEND=noninteractive apt-get update                             \
    && apt-get --no-install-recommends -y install prips

RUN echo 8.0 > /etc/image_version
