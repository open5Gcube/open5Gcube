FROM o5gc/osmocom-base:latest

ARG OSMO_BTS_VERSION=1.7.1

WORKDIR /o5gc/osmo-bts

RUN git clone https://gitea.osmocom.org/cellular-infrastructure/osmo-bts .    \
    && git checkout ${OSMO_BTS_VERSION}                                       \
    && autoreconf -fi                                                         \
    && ./configure --disable-dependency-tracking --enable-trx                 \
    && make -j $(nproc)                                                       \
    && make install                                                           \
    && ldconfig

RUN echo ${OSMO_BTS_VERSION} > /etc/image_version
