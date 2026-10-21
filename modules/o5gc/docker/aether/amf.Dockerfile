FROM o5gc/aether-core-base:latest

WORKDIR /o5gc/aether-amf

ARG AETHER_CORE_AMF_VERSION=3.3.2

RUN git clone --branch v${AETHER_CORE_AMF_VERSION} --depth 1                  \
        https://github.com/omec-project/amf.git .

RUN sync-cache.sh download aether-amf go-cache-dl go-cache-build              \
    && make all                                                               \
    && sync-cache.sh upload aether-amf go-cache-dl go-cache-build

RUN echo ${AETHER_CORE_AMF_VERSION} > /etc/image_version
