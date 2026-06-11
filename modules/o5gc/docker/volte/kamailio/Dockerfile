FROM o5gc/o5gc-base:jammy

# https://open5gs.org/open5gs/docs/tutorial/02-VoLTE-setup/index.html
# https://github.com/herlesupreeth/docker_open5gs/blob/master/ims_base

RUN apt-get.sh install                                                        \
        libcurl4-openssl-dev rtpproxy libmnl-dev libradcli-dev libjson-c-dev  \
        libpcre2-dev libgcrypt20-dev libnghttp2-dev uuid-dev rsyslog bsdextrautils

#ENV KAMAILIO_VERSION=5.3

RUN git clone https://github.com/kamailio/kamailio                            \
    && cd kamailio                                                            \
    && git checkout ce087ee796a3b1a6751a8286018cb2e5601d8fac

WORKDIR /o5gc/kamailio

RUN make cfg
COPY modules.lst src/modules.lst

RUN sync-cache.sh download volte-kamailio ccache                              \
    && export RADCLI=1                                                        \
    && make -j$(nproc) Q=0 all | tee make_all.log                             \
    && make install clean | tee make_install.log                              \
    && ldconfig                                                               \
    && sync-cache.sh upload volte-kamailio ccache

#RUN echo ${KAMAILIO_VERSION} > /etc/image_version
RUN git rev-parse --short HEAD > /etc/image_version
