FROM o5gc/o5gc-base:jammy

# same first steps as srsran and ocudu, so the UHD layer is shared
RUN echo latest > /etc/image_version

# Install UHD first, so images with the same UHD version share the layer
ARG UHD_VERSION=4.6
RUN sync-cache.sh download uhd ccache                                         \
    && install-uhd.sh ${UHD_VERSION}                                          \
    && sync-cache.sh upload uhd ccache

ARG LTESNIFFER_VERSION=2.1.0

RUN apt-get.sh install                                                        \
        libudev-dev libfftw3-dev libmbedtls-dev libconfig++-dev libglib2.0-dev

WORKDIR /o5gc/LTESniffer

RUN git clone --branch LTESniffer-v${LTESNIFFER_VERSION} --depth 1            \
        https://github.com/SysSec-KAIST/LTESniffer.git .                      \
    && mkdir build                                                            \
    && cd build                                                               \
    && sync-cache.sh download misc-ltesniffer ccache                          \
    && cmake ..                                                               \
    && make -j $(nproc)                                                       \
    && make install clean                                                     \
    && ldconfig                                                               \
    && sync-cache.sh upload misc-ltesniffer ccache

RUN pip3 install --no-cache-dir nrarfcn

RUN echo ${LTESNIFFER_VERSION} > /etc/image_version

