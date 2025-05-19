FROM o5gc/o5gc-base:jammy

RUN apt-get.sh install                                                        \
        libpcsclite-dev libtalloc-dev libortp-dev libsctp-dev libmnl-dev      \
        libdbi-dev libdbd-sqlite3 libsqlite3-dev sqlite3 libc-ares-dev        \
        liburing-dev libulfius-dev telnet

ARG LIBOSMO_CORE_VERSION=1.9.0
RUN git clone https://gitea.osmocom.org/osmocom/libosmocore                   \
    && cd libosmocore                                                         \
    && git checkout ${LIBOSMO_CORE_VERSION}                                   \
    && autoreconf -i                                                          \
    && ./configure --disable-dependency-tracking --disable-doxygen            \
    && make -j $(nproc)                                                       \
    && make install                                                           \
    && ldconfig

ARG LIBOSMO_ABIS_VERSION=1.5.0
RUN git clone https://gitea.osmocom.org/osmocom/libosmo-abis                  \
    && cd libosmo-abis                                                        \
    && git checkout ${LIBOSMO_ABIS_VERSION}                                   \
    && autoreconf -i                                                          \
    && ./configure --disable-dependency-tracking --disable-dahdi              \
    && make -j $(nproc)                                                       \
    && make install                                                           \
    && ldconfig

ARG LIBOSMO_NETIF_VERSION=1.4.0
RUN git clone https://gitea.osmocom.org/osmocom/libosmo-netif                 \
    && cd libosmo-netif                                                       \
    && git checkout ${LIBOSMO_NETIF_VERSION}                                  \
    && autoreconf -i                                                          \
    && ./configure --disable-dependency-tracking --disable-dahdi              \
    && make -j $(nproc)                                                       \
    && make install                                                           \
    && ldconfig

RUN echo latest > /etc/image_version
