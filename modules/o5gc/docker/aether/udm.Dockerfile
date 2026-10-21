FROM o5gc/aether-core-base:latest

WORKDIR /o5gc/aether-udm

ARG AETHER_CORE_UDM_VERSION=3.1.2

RUN git clone --branch v${AETHER_CORE_UDM_VERSION} --depth 1                  \
        https://github.com/omec-project/udm.git .

RUN sync-cache.sh download aether-udm go-cache-dl go-cache-build              \
    && make all                                                               \
    && sync-cache.sh upload aether-udm go-cache-dl go-cache-build

RUN echo ${AETHER_CORE_UDM_VERSION} > /etc/image_version
