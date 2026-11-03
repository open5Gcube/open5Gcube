FROM o5gc/osmocom-base:latest

ARG OSMO_CBC_VERSION=0.5.0

WORKDIR /o5gc/osmo-cbc

RUN git clone https://gitea.osmocom.org/cellular-infrastructure/osmo-cbc .    \
    && git checkout ${OSMO_CBC_VERSION}                                       \
    && autoreconf -i                                                          \
    && sync-cache.sh download osmocom-cbc ccache                              \
    && ./configure --disable-dependency-tracking                              \
    && make -j $(nproc)                                                       \
    && make install                                                           \
    && sync-cache.sh upload osmocom-cbc ccache                                \
    && ldconfig

RUN echo ${OSMO_CBC_VERSION} > /etc/image_version
