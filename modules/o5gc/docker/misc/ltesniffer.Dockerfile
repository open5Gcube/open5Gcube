FROM o5gc/o5gc-base:jammy

RUN apt-get.sh install                                                        \
        libboost-dev libboost-chrono-dev libboost-date-time-dev               \
        libboost-filesystem-dev libboost-program-options-dev                  \
        libboost-thread-dev libboost-test-dev libncurses5-dev

ARG UHD_VERSION=4.6

RUN git clone --branch UHD-${UHD_VERSION} --depth 1 --progress                \
        https://github.com/EttusResearch/uhd.git                              \
    && mkdir uhd/host/build                                                   \
    && cd uhd/host/build                                                      \
    && cmake .. -DENABLE_USRP1=OFF -DENABLE_USRP2=OFF                         \
        -DENABLE_MAN_PAGES=OFF -DENABLE_MANUAL=OFF -DENABLE_EXAMPLES=OFF ..   \
    && sync-cache.sh download misc-ltesniffer ccache                          \
    && make -j $(nproc)                                                       \
    && make test install clean                                                \
    && ldconfig                                                               \
    && sync-cache.sh upload misc-ltesniffer ccache                            \
    && uhd_images_downloader -t "x310|b2"

ARG LTESNIFFER_VERSION=2.1.0

RUN apt-get.sh install                                                        \
        libudev-dev libfftw3-dev libmbedtls-dev libconfig++-dev

WORKDIR /o5gc/LTESniffer

RUN git clone --branch LTESniffer-v${LTESNIFFER_VERSION} --depth 1 --progress \
        https://github.com/SysSec-KAIST/LTESniffer.git .                      \
    && mkdir build                                                            \
    && cd build                                                               \
    && cmake ..                                                               \
    && sync-cache.sh download misc-ltesniffer ccache                          \
    && make -j $(nproc)                                                       \
    && make install clean                                                     \
    && ldconfig                                                               \
    && sync-cache.sh upload misc-ltesniffer ccache

RUN pip3 install --no-cache-dir nrarfcn

RUN echo ${LTESNIFFER_VERSION} > /etc/image_version

