FROM o5gc/o5gc-base:jammy AS proxy

LABEL org.opencontainers.image.title='OCUDU'

RUN echo latest > /etc/image_version

FROM proxy AS develop

# Install dependencies
RUN apt-get.sh install                                                        \
        cmake make gcc g++ pkg-config libfftw3-dev libmbedtls-dev libsctp-dev \
        libyaml-cpp-dev libgtest-dev libboost-dev libzmq3-dev

# Install UHD for USRP support.
ARG UHD_VERSION=4.6
RUN sync-cache.sh download ocudu ccache                                       \
    && install-uhd.sh ${UHD_VERSION}                                          \
    && sync-cache.sh upload ocudu ccache

RUN pip3 install --no-cache-dir nrarfcn

RUN echo develop > /etc/image_version

WORKDIR /o5gc/ocudu

FROM develop

# Clone and build OCUDU
RUN git clone https://gitlab.com/ocudu/ocudu.git .

ARG OCUDU_VERSION=26_04

RUN if [[ "${OCUDU_VERSION}" == *_* ]]; then                                  \
        OCUDU_VERSION="release_${OCUDU_VERSION}";                             \
    fi                                                                        \
    && git checkout ${OCUDU_VERSION}                                          \
    && mkdir build && cd build                                                \
    && sync-cache.sh download ocudu ccache                                    \
    # https://gitlab.com/ocudu/ocudu/-/merge_requests/322                     \
    && ARCH_FLAG="-DMARCH=native"                                             \
    && if [ "$TARGETARCH" = "arm64" ]; then ARCH_FLAG="-DMCPU=native"; fi     \
    && cmake -DBUILD_TESTING=False -DENABLE_UHD=On -DENABLE_ZEROMQ=ON         \
        ${ARCH_FLAG} ..                                                       \
    && make -j $(nproc)                                                       \
    && ldconfig                                                               \
    && find ./ \( -name "*.a" -o -name "*.o" \) -type f -delete               \
    && sync-cache.sh upload ocudu ccache

RUN echo ${OCUDU_VERSION//_/.} > /etc/image_version
