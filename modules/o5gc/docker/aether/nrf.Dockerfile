FROM o5gc/aether-core-base:latest

WORKDIR /o5gc/aether-nrf

ARG AETHER_CORE_NRF_VERSION=3.1.3

RUN git clone --branch v${AETHER_CORE_NRF_VERSION} --depth 1                  \
        https://github.com/omec-project/nrf.git .

RUN sync-cache.sh download aether-nrf go-cache-dl go-cache-build              \
    && make all                                                               \
    && sync-cache.sh upload aether-nrf go-cache-dl go-cache-build

RUN echo ${AETHER_CORE_NRF_VERSION} > /etc/image_version
