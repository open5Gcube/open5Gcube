FROM mysql:5.7-debian

RUN rm /etc/apt/sources.list.d/mysql.list                                        \
    && DEBIAN_FRONTEND=noninteractive apt-get update                             \
    && apt-get --no-install-recommends -y install prips

RUN echo 5.7 > /etc/image_version
