FROM o5gc/o5gc-base:jammy

# Install dependencies
RUN apt-get.sh install libsctp-dev lksctp-tools

# Install up-to-date cmake
RUN pip3 install --upgrade --no-cache-dir pip                                 \
    && pip3 install --upgrade --no-cache-dir cmake

# Clone and build UERANSIM
ENV UERANSIM_VERSION=3.2.6

RUN git clone --branch v${UERANSIM_VERSION} --progress                        \
    https://github.com/aligungr/UERANSIM ueransim

WORKDIR /o5gc/ueransim

RUN sync-cache.sh download ueransim ccache                                    \
    && make -j$(nproc)                                                        \
    && sync-cache.sh upload ueransim ccache

RUN echo ${UERANSIM_VERSION} > /etc/image_version
