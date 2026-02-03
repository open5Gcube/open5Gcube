FROM o5gc/o5gc-base:jammy

RUN mkdir -p /etc/apt/keyrings                                                \
    && curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key   \
        | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg                   \
    && echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg]"                \
            "https://deb.nodesource.com/node_20.x nodistro main"              \
        > /etc/apt/sources.list.d/nodesource.list                             \
    && apt-get.sh install nodejs nginx

RUN apt-get.sh install kmod mokutil                                           \
    && npm install --global yarn@1.22.21

RUN cached-download.sh https://dl.google.com/go/go1.21.8.linux-amd64.tar.gz   \
    && tar -C /usr/local -zxvf go1.*.tar.gz                                   \
    && rm go1.*.tar.gz
ENV PATH="$PATH:/usr/local/go/bin"

ARG GTP5G_VERSION=0.9.11
RUN git clone https://github.com/free5gc/gtp5g.git                            \
    && cd gtp5g                                                               \
    && git checkout v${GTP5G_VERSION}

WORKDIR /o5gc/free5gc

ARG FREE5GC_VERSION=3.4.4
RUN git clone --branch v${FREE5GC_VERSION} --depth 1 --recurse-submodules     \
        -j $(nproc) https://github.com/free5gc/free5gc.git .                  \
    && sync-cache.sh download free5gc go-cache-dl go-cache-build npm-cache    \
    && make -j $(nproc) nfs                                                   \
    && apt-get.sh install sudo                                                \
    && make -j $(nproc) webconsole                                            \
    && apt-get.sh purge sudo                                                  \
    && ln -t webconsole/ -s bin/webconsole                                    \
    && sync-cache.sh upload free5gc go-cache-dl go-cache-build npm-cache      \
    && rm -rf webconsole/frontend/node_modules /root/go/pkg/mod/*

RUN echo ${FREE5GC_VERSION} > /etc/image_version
