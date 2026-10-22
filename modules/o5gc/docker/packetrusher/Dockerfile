FROM o5gc/o5gc-base:jammy

# Keep identical to the Go install in ellacore/Dockerfile to share the layer
RUN cached-download.sh https://go.dev/dl/go1.27.3.linux-amd64.tar.gz          \
    && tar -C /usr/local -zxvf go1.*.tar.gz                                   \
    && rm go1.*.tar.gz
ENV PATH="$PATH:/usr/local/go/bin"

RUN apt-get.sh install kmod mokutil

WORKDIR /o5gc/PacketRusher

ARG PACKETRUSHER_VERSION=v2.0.0
RUN git clone https://github.com/HewlettPackard/PacketRusher .                \
    && git checkout ${PACKETRUSHER_VERSION}                                   \
    && go mod download                                                        \
    && go build -o packetrusher                                               \
        -ldflags "-X main.version=${PACKETRUSHER_VERSION}" ./cmd

RUN echo ${PACKETRUSHER_VERSION} > /etc/image_version
