FROM o5gc/o5gc-base:jammy

RUN apt-get.sh install libsctp-dev lksctp-tools

ENV UERANSIM_VERSION=3.3.0

RUN git clone --branch v${UERANSIM_VERSION}                                   \
        https://github.com/aligungr/UERANSIM ueransim

WORKDIR /o5gc/ueransim

RUN sync-cache.sh download ueransim ccache                                    \
    && make -j$(nproc)                                                        \
    && rm -rf cmake-build-release                                             \
    && sync-cache.sh upload ueransim ccache

RUN echo ${UERANSIM_VERSION} > /etc/image_version
