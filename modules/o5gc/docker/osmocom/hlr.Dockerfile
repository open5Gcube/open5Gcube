FROM o5gc/osmocom-base:latest

ARG OSMO_HLR_VERSION=1.9.2

WORKDIR /o5gc/osmo-hlr

RUN git clone https://gitea.osmocom.org/cellular-infrastructure/osmo-hlr .    \
    && git checkout ${OSMO_HLR_VERSION}                                       \
    && autoreconf -fi                                                         \
    && sync-cache.sh download osmocom-hlr ccache                              \
    && ./configure --disable-dependency-tracking                              \
    && make -j $(nproc) install                                               \
    && make clean                                                             \
    && sync-cache.sh upload osmocom-hlr ccache                                \
    && ldconfig

RUN pip --no-cache-dir install sqlite-web

RUN echo ${OSMO_HLR_VERSION} > /etc/image_version
