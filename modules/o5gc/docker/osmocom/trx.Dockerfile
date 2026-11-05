FROM o5gc/osmocom-base:latest AS osmo-base

FROM o5gc/o5gc-base:jammy AS proxy

# same first steps as srsran and ocudu, so the UHD layer is shared
RUN echo latest > /etc/image_version

FROM proxy

# Install UHD first, so images with the same UHD version share the layer
ARG UHD_VERSION=4.6
RUN sync-cache.sh download uhd ccache                                         \
    && install-uhd.sh ${UHD_VERSION}                                          \
    && sync-cache.sh upload uhd ccache

COPY --from=osmo-base /usr/local/include/osmocom/ /usr/local/include/osmocom/
COPY --from=osmo-base /usr/local/lib/ /usr/local/lib/

RUN apt-get.sh install                                                        \
        libfftw3-dev libboost-system-dev libtalloc-dev libmnl-dev liburing-dev

ARG OSMO_TRX_VERSION=1.7.2

WORKDIR /o5gc/osmo-trx

RUN git clone https://gitea.osmocom.org/cellular-infrastructure/osmo-trx .    \
    && git checkout ${OSMO_TRX_VERSION}                                       \
    && autoreconf -fi                                                         \
    && sync-cache.sh download osmocom-trx ccache                              \
    && CFLAGS="-march=native -O3 -flto=auto" CXXFLAGS=${CFLAGS}               \
        ./configure --disable-dependency-tracking --with-uhd                  \
    && make -j $(nproc) install                                               \
    && make clean                                                             \
    && sync-cache.sh upload osmocom-trx ccache                                \
    && ldconfig

RUN echo ${OSMO_TRX_VERSION} > /etc/image_version
