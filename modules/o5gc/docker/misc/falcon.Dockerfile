FROM o5gc/o5gc-base:focal

# Install srsRAN dependencies
RUN apt-get.sh install                                                        \
        libfftw3-dev libmbedtls-dev libconfig++-dev                           \
        libboost-system-dev libboost-program-options-dev                      \
        libsctp-dev libzmq3-dev

# Install UHD for USRP support
ARG UHD_VERSION=4.4
RUN sync-cache.sh download misc-falcon ccache                                 \
    && install-uhd.sh ${UHD_VERSION}                                          \
    && sync-cache.sh upload misc-falcon ccache

# Clone and build srsGUI
RUN apt-get.sh install                                                        \
        libboost-thread-dev libboost-test-dev libqwt-qt5-dev qtbase5-dev      \
    && git clone https://github.com/srsran/srsGUI                             \
    && mkdir srsGUI/build                                                     \
    && cd srsGUI/build                                                        \
    && sync-cache.sh download misc-falcon ccache                              \
    && cmake ..                                                               \
    && make -j $(nproc)                                                       \
    && make install clean                                                     \
    && ldconfig                                                               \
    && sync-cache.sh upload misc-falcon ccache

# Install FALCON dependencies
RUN apt-get.sh install                                                        \
        libglib2.0-dev libudev-dev libcurl4-gnutls-dev                        \
        qtdeclarative5-dev libqt5charts5-dev

# Clone and build FALCON
RUN git clone https://github.com/falkenber9/falcon.git                        \
    && mkdir falcon/build                                                     \
    && cd falcon/build                                                        \
    && sync-cache.sh download misc-falcon ccache                              \
    && cmake -DHAVE_AVX512=0 ..                                               \
    && make -j $(nproc)                                                       \
    && make install clean                                                     \
    && ldconfig                                                               \
    && sync-cache.sh upload misc-falcon ccache

RUN echo latest > /etc/image_version
