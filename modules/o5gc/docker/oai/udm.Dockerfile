ARG OAI_CN5G_VERSION=latest

FROM o5gc/oai-cn5g-base:${OAI_CN5G_VERSION}

RUN git clone --branch v${OAI_CN5G_VERSION} --depth 1                         \
        https://gitlab.eurecom.fr/oai/cn5g/oai-cn5g-udm.git

WORKDIR /o5gc/oai-cn5g-udm

RUN sync-cache.sh download oai-udm ccache                                     \
    && apt-get.sh install libcrypto++-dev libgtest-dev python-setuptools      \
    && cd build/scripts                                                       \
    && ./build_udm --install-deps --force                                     \
    && ./build_udm --clean --Verbose --build-type Release --jobs              \
    && ldconfig                                                               \
    && find ../ \( -name "*.a" -o -name "*.o" \) -type f -delete              \
    && rm -rf /tmp/*                                                          \
    && sync-cache.sh upload oai-udm ccache

HEALTHCHECK --interval=10s --timeout=15s --retries=6                          \
    CMD /o5gc/oai-cn5g-udm/scripts/healthcheck.sh

