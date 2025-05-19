ARG OAI_CN5G_VERSION=latest

FROM o5gc/oai-cn5g-base:${OAI_CN5G_VERSION}

RUN git clone --branch v${OAI_CN5G_VERSION} --depth 1                         \
        https://gitlab.eurecom.fr/oai/cn5g/oai-cn5g-nrf.git

WORKDIR /o5gc/oai-cn5g-nrf

RUN sync-cache.sh download oai-nrf ccache                                     \
    && cd build/scripts                                                       \
    && ./build_nrf --install-deps --force                                     \
    && ./build_nrf --clean --Verbose --build-type Release --jobs              \
    && ldconfig                                                               \
    && find ../ \( -name "*.a" -o -name "*.o" \) -type f -delete              \
    && rm -rf /tmp/*                                                          \
    && sync-cache.sh upload oai-nrf ccache

HEALTHCHECK --interval=10s --timeout=15s --retries=6                          \
    CMD /o5gc/oai-cn5g-nrf/scripts/healthcheck.sh
