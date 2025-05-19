FROM o5gc/o5gc-base:jammy

WORKDIR /o5gc/gr-osmosdr

RUN apt-get.sh install                                                        \
        gnuradio-dev gr-iqbal libasound2-dev libgmp-dev libhackrf-dev         \
        libhidapi-dev libjack-jackd2-dev liblog4cpp5-dev libpulse-dev         \
        librtlsdr-dev libsndfile1-dev libsoapysdr-dev portaudio19-dev         \
        python3-dev python3-numpy python3-six

RUN apt-get.sh install                                                        \
        libuhd-dev uhd-host                                                   \
    && /usr/lib/uhd/utils/uhd_images_downloader.py -t "x310|b2"

ARG GR_OSMOSDR_VERSION=0.2.5

RUN git clone https://gitea.osmocom.org/sdr/gr-osmosdr .                      \
    && git checkout v${GR_OSMOSDR_VERSION}                                    \
    && mkdir build && cd build                                                \
    && cmake ..                                                               \
    && make -j8 install                                                       \
    && ldconfig
