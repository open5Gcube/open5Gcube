FROM o5gc/aether-core-base:latest

WORKDIR /o5gc/aether-ausf

ARG AETHER_CORE_AUSF_VERSION=3.1.2

RUN git clone --branch v${AETHER_CORE_AUSF_VERSION} --depth 1                 \
        https://github.com/omec-project/ausf.git .

RUN sync-cache.sh download aether-ausf go-cache-dl go-cache-build             \
    && make all                                                               \
    && sync-cache.sh upload aether-ausf go-cache-dl go-cache-build

RUN echo ${AETHER_CORE_AUSF_VERSION} > /etc/image_version
