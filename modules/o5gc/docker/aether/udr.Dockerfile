FROM o5gc/aether-core-base:latest

WORKDIR /o5gc/aether-udr

ARG AETHER_CORE_UDR_VERSION=3.1.2

RUN git clone --branch v${AETHER_CORE_UDR_VERSION} --depth 1                  \
        https://github.com/omec-project/udr.git .

RUN sync-cache.sh download aether-udr go-cache-dl go-cache-build              \
    && make all                                                               \
    && sync-cache.sh upload aether-udr go-cache-dl go-cache-build

RUN echo ${AETHER_CORE_UDR_VERSION} > /etc/image_version
