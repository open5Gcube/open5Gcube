FROM o5gc/o5gc-base:focal

# https://open5gs.org/open5gs/docs/tutorial/02-VoLTE-setup/index.html

RUN apt-get.sh install dkms nfs-common module-assistant dpkg-dev rsyslog      \
         libavcodec-extra

ENV RTPENGINE_VERSION=9.4.1

RUN mkdir /o5gc/rtpengine && cd /o5gc/rtpengine                           \
    && git clone https://github.com/sipwise/rtpengine build                   \
    && cd build                                                               \
    && git checkout mr${RTPENGINE_VERSION}                                    \
    && export DEB_BUILD_PROFILES="pkg.ngcp-rtpengine.nobcg729"                \
    && apt-get.sh install libconfig-tiny-perl libxtables-dev                  \
    && apt-get.sh install `dpkg-checkbuilddeps 2>&1                           \
        | sed 's|dpkg-checkbuilddeps:\serror:\sUnmet build dependencies: ||g' \
        | sed 's|[\(][^)]*[\)] ||g'`                                          \
    && dpkg-checkbuilddeps                                                    \
    && sync-cache.sh download volte-rtpengine ccache                          \
    && dpkg-buildpackage --jobs=$(nproc) -uc -us                              \
    && sync-cache.sh upload volte-rtpengine ccache                            \
    && dpkg -i ../*.deb                                                       \
    && make clean                                                             \
    && ldconfig

RUN echo ${RTPENGINE_VERSION} > /etc/image_version
