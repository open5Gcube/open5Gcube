FROM o5gc/aether-core-base:latest

WORKDIR /o5gc/aether-nssf

ARG AETHER_CORE_NSSF_VERSION=3.1.2

RUN git clone --branch v${AETHER_CORE_NSSF_VERSION} --depth 1                 \
        https://github.com/omec-project/nssf.git .

RUN sync-cache.sh download aether-nssf go-cache-dl go-cache-build             \
    && make all                                                               \
    && sync-cache.sh upload aether-nssf go-cache-dl go-cache-build

RUN echo ${AETHER_CORE_NSSF_VERSION} > /etc/image_version
