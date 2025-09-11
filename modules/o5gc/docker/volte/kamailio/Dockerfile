FROM o5gc/o5gc-base:focal

# https://open5gs.org/open5gs/docs/tutorial/02-VoLTE-setup/index.html
# https://github.com/herlesupreeth/docker_open5gs/blob/master/ims_base

RUN apt-get.sh install                                                        \
        libcurl4-openssl-dev rtpproxy libmnl-dev libradcli-dev libjson-c-dev  \
        libpcre2-dev libgcrypt20-dev libnghttp2-dev uuid-dev rsyslog

#ENV KAMAILIO_VERSION=5.3

#RUN git clone --branch ${KAMAILIO_VERSION} --depth 1                          \
#    https://github.com/herlesupreeth/kamailio
RUN git clone https://github.com/kamailio/kamailio                            \
    && cd kamailio                                                            \
    && git checkout 0da3eb3f94c087b272ebbe19c42fd9331

WORKDIR /o5gc/kamailio

RUN make cfg
COPY modules.lst src/modules.lst

RUN sync-cache.sh download volte-kamailio ccache                              \
    && export RADCLI=1                                                        \
    && make -j$(nproc) all | tee make_all.log                                 \
    && make install clean | tee make_install.log                              \
    && ldconfig                                                               \
    && sync-cache.sh upload volte-kamailio ccache

#RUN echo ${KAMAILIO_VERSION} > /etc/image_version
RUN git rev-parse --short HEAD > /etc/image_version
