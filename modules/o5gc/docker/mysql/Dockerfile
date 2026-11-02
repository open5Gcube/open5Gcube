FROM mysql:8.0-debian

COPY --from=o5gc/o5gc-base:jammy /usr/local/bin/apt-get.sh /usr/local/bin/
RUN rm /etc/apt/sources.list.d/mysql.list                                        \
    && apt-get.sh install prips

RUN echo 8.0 > /etc/image_version
