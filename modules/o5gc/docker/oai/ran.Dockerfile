FROM o5gc/o5gc-base:jammy AS proxy

LABEL org.opencontainers.image.title='OpenAirInterface5G'

ARG VERSION

RUN echo ${VERSION} > /etc/image_version

FROM proxy

RUN OAI_RAN_VERSION=$(echo ${VERSION} | sed "s|\(.*\)-.*|\1|")                \
    && git clone https://gitlab.eurecom.fr/oai/openairinterface5g.git         \
    && cd openairinterface5g                                                  \
    && git checkout ${OAI_RAN_VERSION}

WORKDIR /o5gc/openairinterface5g

COPY 0001-Add-ip-and-port-option-to-gnb-tracer.patch .
COPY 0002-Thin-UHD-compilation*.patch .
RUN sync-cache.sh download oai-ran ccache                                     \
    && git -c user.name='o5gc' -c user.email='o5gc@fkie.fraunhofer.de'        \
        am --3way *.patch                                                     \
    && source ./oaienv                                                        \
    && cd cmake_targets                                                       \
    && export UHD_VERSION=$(echo ${VERSION} | sed "s|.*-\(.*\)|\1|")          \
    && export BUILD_UHD_FROM_SOURCE=True                                      \
    && ./build_oai --ninja -I -w USRP                                         \
    && apt-get.sh purge texlive-base                                          \
    && ./build_oai --ninja -w USRP --eNB --gNB --RU --UE --nrUE               \
    && ldconfig                                                               \
    && cd ..                                                                  \
    && ln -s cmake_targets/ran_build/build/ .                                 \
    && make -j $(nproc) -C common/utils/T/tracer                              \
    && find ./build/ \( -name "*.a" -o -name "*.o" \) -type f -delete         \
    && rm -rf targets/bin /tmp/* /usr/local/share/doc/*                       \
    && sync-cache.sh upload oai-ran ccache

RUN /usr/local/lib/uhd/utils/uhd_images_downloader.py -t "x310|b2"

RUN pip3 install --no-cache-dir nrarfcn
