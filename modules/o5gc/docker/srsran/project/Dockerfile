FROM o5gc/o5gc-base:jammy AS proxy

LABEL org.opencontainers.image.title='srsRAN-Project'

RUN echo latest > /etc/image_version

FROM proxy AS develop

# Install dependencies
RUN apt-get.sh install                                                        \
        cmake make gcc g++ pkg-config libfftw3-dev libmbedtls-dev libsctp-dev \
        libyaml-cpp-dev libgtest-dev libboost-dev libzmq3-dev

# Install UHD for USRP support
RUN add-apt-repository -y ppa:ettusresearch/uhd                               \
    && apt-get.sh install libuhd-dev uhd-host                                 \
    && ldconfig                                                               \
    && /usr/lib/uhd/utils/uhd_images_downloader.py -t "x310|b2"

RUN pip3 install --no-cache-dir nrarfcn

RUN echo develop > /etc/image_version

WORKDIR /o5gc/srsRAN_Project

FROM develop

# Clone and build srsRAN
RUN git clone https://github.com/srsran/srsRAN_Project .

ARG SRSRAN_VERSION=24_10_1

RUN if [[ "${SRSRAN_VERSION}" == *_* ]]; then                                 \
        SRSRAN_VERSION="release_${SRSRAN_VERSION}";                           \
    fi                                                                        \
    && git checkout ${SRSRAN_VERSION}                                         \
    && mkdir build && cd build                                                \
    && sync-cache.sh download srsran-project ccache                           \
    && cmake -DENABLE_EXPORT=ON -DENABLE_ZEROMQ=ON -DBUILD_TESTS=OFF ..       \
    && make -j $(nproc)                                                       \
    && ldconfig                                                               \
    && find ./ \( -name "*.a" -o -name "*.o" \) -type f -delete               \
    && sync-cache.sh upload srsran-project ccache

RUN echo ${SRSRAN_VERSION//_/.} > /etc/image_version
