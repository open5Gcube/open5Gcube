FROM o5gc/o5gc-base:jammy

# Keep Go and Node.js installs identical to ellacore/Dockerfile (shared layers)
RUN cached-download.sh https://go.dev/dl/go1.27.3.linux-amd64.tar.gz          \
    && tar -C /usr/local -zxvf go1.*.tar.gz                                   \
    && rm go1.*.tar.gz
ENV PATH="$PATH:/usr/local/go/bin"

RUN mkdir -p /etc/apt/keyrings                                                \
    && curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key   \
        | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg                   \
    && echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg]"                \
            "https://deb.nodesource.com/node_24.x nodistro main"              \
        > /etc/apt/sources.list.d/nodesource.list                             \
    && apt-get.sh install nodejs nginx

WORKDIR /o5gc/ella-smsc

# Ella SMSC has no release tags yet, so pin a commit
ARG ELLA_SMSC_VERSION=5c094bc
RUN git clone https://github.com/ellanetworks/smsc.git .                      \
    && git checkout ${ELLA_SMSC_VERSION}                                      \
    && REVISION=`git rev-parse HEAD`                                          \
    && sync-cache.sh download ellacore-smsc                                   \
        go-cache-dl go-cache-build npm-cache                                  \
    && npm ci --prefix ui                                                     \
    && npm run build --prefix ui                                              \
    && go build -o smsc -ldflags                                              \
          "-X github.com/ellanetworks/smsc/version.GitCommit=${REVISION}"     \
        ./cmd/smsc                                                            \
    && sync-cache.sh upload ellacore-smsc                                     \
        go-cache-dl go-cache-build npm-cache

RUN echo ${ELLA_SMSC_VERSION} > /etc/image_version
