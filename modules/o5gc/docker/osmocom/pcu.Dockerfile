FROM o5gc/osmocom-base:latest

ARG OSMO_PCU_VERSION=1.3.1

WORKDIR /o5gc/osmo-pcu

RUN git clone https://gitea.osmocom.org/cellular-infrastructure/osmo-pcu .    \
    && git checkout ${OSMO_PCU_VERSION}                                       \
    && autoreconf -fi                                                         \
    && ./configure --disable-dependency-tracking                              \
    && make -j $(nproc)                                                       \
    && make install                                                           \
    && ldconfig

RUN echo ${OSMO_PCU_VERSION} > /etc/image_version
