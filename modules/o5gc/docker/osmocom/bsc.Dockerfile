FROM o5gc/osmocom-mgw:latest AS osmo-mgw
FROM o5gc/osmocom-stp:latest AS osmo-stp

FROM o5gc/osmocom-base:latest
COPY --from=osmo-mgw /usr/local/include/osmocom/mgcp_client/* /usr/local/include/osmocom/mgcp_client/
COPY --from=osmo-mgw /usr/local/lib/libosmo-mgcp-client.* /usr/local/lib/
COPY --from=osmo-mgw /usr/local/lib/pkgconfig/libosmo-mgcp-client.pc /usr/local/lib/pkgconfig/
COPY --from=osmo-stp /usr/local/include/osmocom/sigtran/* /usr/local/include/osmocom/sigtran/
COPY --from=osmo-stp /usr/local/include/osmocom/sigtran/protocol/* /usr/local/include/osmocom/sigtran/protocol/
COPY --from=osmo-stp /usr/local/include/osmocom/sccp/* /usr/local/include/osmocom/sccp/
COPY --from=osmo-stp /usr/local/lib/libosmo-sccp.* /usr/local/lib/libosmo-sigtran.* /usr/local/lib/
COPY --from=osmo-stp /usr/local/lib/pkgconfig/libosmo-*.pc /usr/local/lib/pkgconfig/libosmo-sigtran.pc /usr/local/lib/pkgconfig/

ARG OSMO_BSC_VERSION=1.7.1

WORKDIR /o5gc/osmo-bsc

RUN git clone https://gitea.osmocom.org/cellular-infrastructure/osmo-bsc .    \
    && git checkout ${OSMO_BSC_VERSION}                                       \
    && autoreconf -fi                                                         \
    && ./configure --disable-dependency-tracking --enable-trx                 \
    && make -j $(nproc)                                                       \
    && make install                                                           \
    && ldconfig

RUN echo ${OSMO_BSC_VERSION} > /etc/image_version
