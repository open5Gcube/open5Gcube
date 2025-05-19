ARG OAI_CN5G_VERSION=latest

FROM o5gc/oai-cn5g-base:${OAI_CN5G_VERSION}

RUN git clone --branch v${OAI_CN5G_VERSION} --depth 1                         \
        https://gitlab.eurecom.fr/oai/cn5g/oai-cn5g-udr.git

WORKDIR /o5gc/oai-cn5g-udr

RUN sync-cache.sh download oai-udr ccache                                     \
    && cd build/scripts                                                       \
    && ./build_udr --install-deps --force                                     \
    && ./build_udr --clean --Verbose --build-type Release --jobs              \
    && ldconfig                                                               \
    && find ../ \( -name "*.a" -o -name "*.o" \) -type f -delete              \
    && rm -rf /tmp/*                                                          \
    && sync-cache.sh upload oai-udr ccache

HEALTHCHECK --interval=10s --timeout=15s --retries=6                          \
    CMD /o5gc/oai-cn5g-udr/scripts/healthcheck.sh

