FROM o5gc/o5gc-base:jammy

RUN apt-get.sh install kmod mokutil

RUN cached-download.sh https://go.dev/dl/go1.21.3.linux-amd64.tar.gz          \
    && tar -C /usr/local -zxvf go1.*.tar.gz                                   \
    && rm go1.*.tar.gz
ENV PATH="$PATH:/usr/local/go/bin"

WORKDIR /o5gc/PacketRusher

ARG PACKETRUSHER_VERSION=20240521
RUN git clone --branch ${PACKETRUSHER_VERSION} --depth 1                      \
        https://github.com/HewlettPackard/PacketRusher .                      \
    && go mod download                                                        \
    && go build cmd/packetrusher.go

RUN echo ${PACKETRUSHER_VERSION} > /etc/image_version
