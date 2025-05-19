FROM o5gc/osmocom-mgw:latest AS osmo-mgw
FROM o5gc/osmocom-hlr:latest AS osmo-hlr
FROM o5gc/osmocom-stp:latest AS osmo-stp

FROM o5gc/osmocom-base:latest
COPY --from=osmo-mgw /usr/local/include/osmocom/mgcp_client/* /usr/local/include/osmocom/mgcp_client/
COPY --from=osmo-mgw /usr/local/lib/libosmo-mgcp-client.* /usr/local/lib/
COPY --from=osmo-mgw /usr/local/lib/pkgconfig/libosmo-mgcp-client.pc /usr/local/lib/pkgconfig/
COPY --from=osmo-hlr /usr/local/include/osmocom/gsupclient/* /usr/local/include/osmocom/gsupclient/
COPY --from=osmo-hlr /usr/local/lib/libosmo-gsup-client.* /usr/local/lib/
COPY --from=osmo-hlr /usr/local/lib/pkgconfig/libosmo-gsup-client.pc /usr/local/lib/pkgconfig/
COPY --from=osmo-stp /usr/local/include/osmocom/sigtran/* /usr/local/include/osmocom/sigtran/
COPY --from=osmo-stp /usr/local/include/osmocom/sccp/* /usr/local/include/osmocom/sccp/
COPY --from=osmo-stp /usr/local/lib/libosmo-sccp.* /usr/local/lib/libosmo-sigtran.* /usr/local/lib/
COPY --from=osmo-stp /usr/local/lib/pkgconfig/libosmo-sccp.pc /usr/local/lib/pkgconfig/libosmo-sigtran.pc /usr/local/lib/pkgconfig/

ARG LIBSMPP34_VERSION=1.14.3
RUN git clone https://gitea.osmocom.org/cellular-infrastructure/libsmpp34     \
    && cd libsmpp34                                                           \
    && git checkout ${LIBASN1C_VERSION}                                       \
    && autoreconf -i                                                          \
    && ./configure --disable-dependency-tracking                              \
    && make -j $(nproc)                                                       \
    && make install                                                           \
    && ldconfig

ARG OSMO_MSC_VERSION=1.11.1

WORKDIR /o5gc/osmo-msc

RUN git clone https://gitea.osmocom.org/cellular-infrastructure/osmo-msc .    \
    && git checkout ${OSMO_MSC_VERSION}                                       \
    && autoreconf -i                                                          \
    && ./configure --enable-smpp --disable-dependency-tracking                \
    && make -j $(nproc)                                                       \
    && make install                                                           \
    && ldconfig

RUN echo ${OSMO_MSC_VERSION} > /etc/image_version
