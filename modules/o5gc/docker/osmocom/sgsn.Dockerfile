FROM o5gc/osmocom-hlr:latest AS osmo-hlr
FROM o5gc/osmocom-ggsn:latest AS osmo-ggsn

FROM o5gc/osmocom-base:latest
COPY --from=osmo-hlr /usr/local/include/osmocom/gsupclient/* /usr/local/include/osmocom/gsupclient/
COPY --from=osmo-hlr /usr/local/lib/libosmo-gsup-client.* /usr/local/lib/
COPY --from=osmo-hlr /usr/local/lib/pkgconfig/libosmo-gsup-client.pc /usr/local/lib/pkgconfig/
COPY --from=osmo-ggsn /usr/local/include/*.h /usr/local/include/
COPY --from=osmo-ggsn /usr/local/lib/libgtp.* /usr/local/lib/
COPY --from=osmo-ggsn /usr/local/lib/pkgconfig/libgtp.pc /usr/local/lib/pkgconfig/

ARG OSMO_SGSN_VERSION=1.11.0

WORKDIR /o5gc/osmo-sgsn

RUN git clone https://gitea.osmocom.org/cellular-infrastructure/osmo-sgsn .   \
    && git checkout ${OSMO_SGSN_VERSION}                                      \
    && autoreconf -fi                                                         \
    && ./configure --disable-dependency-tracking                              \
    && make -j $(nproc)                                                       \
    && make install                                                           \
    && ldconfig

RUN echo ${OSMO_SGSN_VERSION} > /etc/image_version
