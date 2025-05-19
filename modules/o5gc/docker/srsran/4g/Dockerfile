FROM o5gc/o5gc-base:jammy AS proxy

LABEL org.opencontainers.image.title='srsRAN-4G'

RUN echo latest > /etc/image_version

FROM proxy AS develop

# Install dependencies
RUN apt-get.sh install                                                        \
        libfftw3-dev libmbedtls-dev libconfig++-dev                           \
        libboost-system-dev libboost-program-options-dev                      \
        libsctp-dev libzmq3-dev

# Install UHD for USRP support
RUN add-apt-repository -y ppa:ettusresearch/uhd                               \
    && apt-get.sh install libuhd-dev uhd-host                                 \
    && ldconfig                                                               \
    && /usr/lib/uhd/utils/uhd_images_downloader.py -t "x310|b2"

# Clone and build srsGUI
RUN apt-get.sh install                                                        \
        libboost-thread-dev libboost-test-dev libqwt-qt5-dev qtbase5-dev      \
    && git clone https://github.com/srsran/srsGUI                             \
    && mkdir srsGUI/build                                                     \
    && cd srsGUI/build                                                        \
    && sync-cache.sh download srsran-4g ccache                                \
    && cmake ..                                                               \
    && make -j $(nproc)                                                       \
    && make install                                                           \
    && ldconfig                                                               \
    && sync-cache.sh upload srsran-4g ccache

RUN pip3 install --no-cache-dir nrarfcn

RUN echo develop > /etc/image_version

WORKDIR /o5gc/srsRAN_4G

FROM develop

# Clone and build srsRAN
ENV SRSRAN_VERSION=23_11

RUN git clone --branch release_${SRSRAN_VERSION} --depth 1                    \
        https://github.com/srsran/srsRAN_4G .

RUN mkdir build && cd build                                                   \
    && sync-cache.sh download srsran-4g ccache                                \
    && cmake ..                                                               \
    && make -j $(nproc) srsepc srsenb srsue                                   \
    && ldconfig                                                               \
    && find ./ \( -name "*.a" -o -name "*.o" \) -type f -delete               \
    && ./srsran_install_configs.sh                                            \
    && sync-cache.sh upload srsran-4g ccache

# cell_measurement (pdsch_ue + sib1)
COPY cell_measurement.cc lib/examples/cell_measurement.cc
RUN echo -e "add_executable(cell_measurement cell_measurement.cc)\n"          \
            "target_link_libraries(cell_measurement"                          \
            "    srsran_phy srsran_common srsran_rf rrc_asn1 pthread"         \
            "    \${SRSGUI_LIBRARIES})\n"                                     \
        >> lib/examples/CMakeLists.txt                                        \
    && cd build                                                               \
    && sync-cache.sh download srsran-4g ccache                                \
    && cmake ..                                                               \
    && make cell_measurement cell_search                                      \
    && find ./ \( -name "*.a" -o -name "*.o" \) -type f -delete               \
    && sync-cache.sh upload srsran-4g ccache

RUN echo ${SRSRAN_VERSION//_/.} > /etc/image_version
