FROM o5gc/osmocom-base:latest

ARG OSMO_BTS_VERSION=1.10.0

WORKDIR /o5gc/osmo-bts

RUN git clone https://gitea.osmocom.org/cellular-infrastructure/osmo-bts .    \
    && git checkout ${OSMO_BTS_VERSION}                                       \
    && autoreconf -fi                                                         \
    && sync-cache.sh download osmocom-bts ccache                              \
    && ./configure --disable-dependency-tracking --enable-trx                 \
    && make -j $(nproc)                                                       \
    && make install                                                           \
    && sync-cache.sh upload osmocom-bts ccache                                \
    && ldconfig

RUN echo ${OSMO_BTS_VERSION} > /etc/image_version
