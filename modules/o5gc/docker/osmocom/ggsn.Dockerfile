FROM o5gc/osmocom-base:latest

ARG OSMO_GGSN_VERSION=1.10.2

WORKDIR /o5gc/osmo-ggsn

RUN git clone https://gitea.osmocom.org/cellular-infrastructure/osmo-ggsn .   \
    && git checkout ${OSMO_GGSN_VERSION}                                      \
    && autoreconf -fi                                                         \
    && ./configure --disable-dependency-tracking                              \
    && make -j $(nproc)                                                       \
    && make install                                                           \
    && ldconfig

RUN echo ${OSMO_GGSN_VERSION} > /etc/image_version
