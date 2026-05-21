FROM o5gc/osmocom-base:latest

ARG OSMO_STP_VERSION=2.2.1

WORKDIR /o5gc/osmo-stp

RUN git clone https://gitea.osmocom.org/osmocom/libosmo-sigtran .                \
    && git checkout ${OSMO_STP_VERSION}                                       \
    && autoreconf -i                                                          \
    && ./configure --disable-dependency-tracking --disable-doxygen            \
    && make -j $(nproc)                                                       \
    && make install                                                           \
    && ldconfig

RUN echo ${OSMO_STP_VERSION} > /etc/image_version
