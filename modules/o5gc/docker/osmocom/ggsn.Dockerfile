FROM o5gc/osmocom-base:latest

ARG OSMO_GGSN_VERSION=1.14.0

WORKDIR /o5gc/osmo-ggsn

RUN git clone https://gitea.osmocom.org/cellular-infrastructure/osmo-ggsn .   \
    && git checkout ${OSMO_GGSN_VERSION}                                      \
    && autoreconf -fi                                                         \
    && sync-cache.sh download osmocom-ggsn ccache                             \
    && ./configure --disable-dependency-tracking                              \
    && make -j $(nproc)                                                       \
    && make install                                                           \
    && sync-cache.sh upload osmocom-ggsn ccache                               \
    && ldconfig

RUN echo ${OSMO_GGSN_VERSION} > /etc/image_version
