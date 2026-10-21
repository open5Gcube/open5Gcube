FROM o5gc/aether-core-base:latest

RUN apt-get.sh install                                                        \
        libbenchmark-dev libbsd-dev libdpdk-dev libfdt-dev libgflags-dev      \
        libgoogle-glog-dev libgraph-easy-perl libgrpc++-dev libgtest-dev      \
        libipsec-mb-dev liblzma-dev libnuma-dev libpcap-dev libprotobuf-dev   \
        libunwind-dev meson protobuf-compiler protobuf-compiler-grpc          \
        python3-pyelftools zlib1g-dev

WORKDIR /o5gc/aether-upf

ARG AETHER_CORE_UPF_VERSION=2.6.3

RUN git clone --branch v${AETHER_CORE_UPF_VERSION} --depth 1                  \
        https://github.com/omec-project/upf.git .

RUN pip install --no-cache-dir --break-system-packages --ignore-installed     \
        --require-hashes -r requirements.txt

# BESS data plane (bessd) and the PFCP agent (pfcpiface)
ARG CPU=haswell
RUN sync-cache.sh download aether-upf ccache go-cache-dl go-cache-build       \
    && cd bess                                                                \
    && BESS_LINK_DYNAMIC=1 CPU=${CPU} ./build.py bess                         \
    && cd ..                                                                  \
    && CGO_ENABLED=0 go build -o bin/pfcpiface ./cmd/pfcpiface                \
    && sync-cache.sh upload aether-upf ccache go-cache-dl go-cache-build

# bessctl loads its pipeline scripts (up4.bess, route_control.py) from conf/
RUN rm -rf bess/bessctl/conf                                                  \
    && ln -s ../../conf bess/bessctl/conf                                     \
    && ln -s /o5gc/aether-upf/bess/bessctl/bessctl /usr/local/bin/
ENV PYTHONPATH="/o5gc/aether-upf/bess"

RUN echo ${AETHER_CORE_UPF_VERSION} > /etc/image_version
