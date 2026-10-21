FROM o5gc/aether-core-base:latest

WORKDIR /o5gc/aether-pcf

ARG AETHER_CORE_PCF_VERSION=3.2.2

RUN git clone --branch v${AETHER_CORE_PCF_VERSION} --depth 1                  \
        https://github.com/omec-project/pcf.git .

RUN sync-cache.sh download aether-pcf go-cache-dl go-cache-build              \
    && make all                                                               \
    && sync-cache.sh upload aether-pcf go-cache-dl go-cache-build

RUN echo ${AETHER_CORE_PCF_VERSION} > /etc/image_version
