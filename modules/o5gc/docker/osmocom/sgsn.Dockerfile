FROM o5gc/osmocom-hlr:latest AS osmo-hlr
FROM o5gc/osmocom-ggsn:latest AS osmo-ggsn

FROM o5gc/osmocom-base:latest
COPY --from=osmo-hlr /usr/local/include/osmocom/gsupclient/* /usr/local/include/osmocom/gsupclient/
COPY --from=osmo-hlr /usr/local/lib/libosmo-gsup-client.* /usr/local/lib/
COPY --from=osmo-hlr /usr/local/lib/pkgconfig/libosmo-gsup-client.pc /usr/local/lib/pkgconfig/
COPY --from=osmo-ggsn /usr/local/include/osmocom/gtp/ /usr/local/include/osmocom/gtp/
COPY --from=osmo-ggsn /usr/local/include/*.h /usr/local/include/
COPY --from=osmo-ggsn /usr/local/lib/libgtp.* /usr/local/lib/
COPY --from=osmo-ggsn /usr/local/lib/pkgconfig/libgtp.pc /usr/local/lib/pkgconfig/

ARG OSMO_SGSN_VERSION=1.13.1

WORKDIR /o5gc/osmo-sgsn

RUN git clone https://gitea.osmocom.org/cellular-infrastructure/osmo-sgsn .   \
    && git checkout ${OSMO_SGSN_VERSION}                                      \
    && autoreconf -fi                                                         \
    && sync-cache.sh download osmocom-sgsn ccache                             \
    && ./configure --disable-dependency-tracking                              \
    && make -j $(nproc) install                                               \
    && make clean                                                             \
    && sync-cache.sh upload osmocom-sgsn ccache                               \
    && ldconfig

RUN echo ${OSMO_SGSN_VERSION} > /etc/image_version
