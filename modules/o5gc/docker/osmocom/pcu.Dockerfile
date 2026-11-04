FROM o5gc/osmocom-base:latest

ARG OSMO_PCU_VERSION=1.5.2

WORKDIR /o5gc/osmo-pcu

RUN git clone https://gitea.osmocom.org/cellular-infrastructure/osmo-pcu .    \
    && git checkout ${OSMO_PCU_VERSION}                                       \
    && autoreconf -fi                                                         \
    && sync-cache.sh download osmocom-pcu ccache                              \
    && ./configure --disable-dependency-tracking                              \
    && make -j $(nproc) install                                               \
    && make clean                                                             \
    && sync-cache.sh upload osmocom-pcu ccache                                \
    && ldconfig

RUN echo ${OSMO_PCU_VERSION} > /etc/image_version
