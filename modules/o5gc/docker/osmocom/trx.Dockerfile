FROM o5gc/osmocom-base:latest AS proxy

RUN echo latest > /etc/image_version

FROM proxy

RUN apt-get.sh install libfftw3-dev libboost-system-dev

# Install UHD for USRP support
ARG UHD_VERSION=4.4
RUN sync-cache.sh download osmocom-trx ccache                                 \
    && install-uhd.sh ${UHD_VERSION}                                          \
    && sync-cache.sh upload osmocom-trx ccache

ARG OSMO_TRX_VERSION=1.6.1

WORKDIR /o5gc/osmo-trx

RUN git clone https://gitea.osmocom.org/cellular-infrastructure/osmo-trx .    \
    && git checkout ${OSMO_TRX_VERSION}                                       \
    && autoreconf -fi                                                         \
    && CFLAGS="-march=native -O3 -flto=auto" CXXFLAGS=${CFLAGS}               \
        ./configure --disable-dependency-tracking --with-uhd                  \
    && make -j $(nproc)                                                       \
    && make install                                                           \
    && ldconfig

RUN echo ${OSMO_TRX_VERSION} > /etc/image_version
