FROM o5gc/osmocom-base:latest

ARG OSMO_MGW_VERSION=1.12.1

WORKDIR /o5gc/osmo-mgw

RUN git clone https://gitea.osmocom.org/cellular-infrastructure/osmo-mgw .    \
    && git checkout ${OSMO_MGW_VERSION}                                       \
    && autoreconf -i                                                          \
    && ./configure --disable-dependency-tracking                              \
    && make -j $(nproc)                                                       \
    && make install                                                           \
    && ldconfig

RUN echo ${OSMO_MGW_VERSION} > /etc/image_version
