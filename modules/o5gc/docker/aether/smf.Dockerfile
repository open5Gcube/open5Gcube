FROM o5gc/aether-core-base:latest

WORKDIR /o5gc/aether-smf

ARG AETHER_CORE_SMF_VERSION=4.3.3

RUN git clone --branch v${AETHER_CORE_SMF_VERSION} --depth 1                  \
        https://github.com/omec-project/smf.git .

RUN sync-cache.sh download aether-smf go-cache-dl go-cache-build              \
    && make all                                                               \
    && sync-cache.sh upload aether-smf go-cache-dl go-cache-build

RUN echo ${AETHER_CORE_SMF_VERSION} > /etc/image_version
