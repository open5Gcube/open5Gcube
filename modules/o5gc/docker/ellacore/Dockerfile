FROM o5gc/o5gc-base:jammy

RUN mkdir -p /etc/apt/keyrings                                                \
    && curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key   \
        | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg                   \
    && echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg]"                \
            "https://deb.nodesource.com/node_20.x nodistro main"              \
        > /etc/apt/sources.list.d/nodesource.list                             \
    && apt-get.sh install nodejs nginx

RUN cached-download.sh https://go.dev/dl/go1.21.3.linux-amd64.tar.gz          \
    && tar -C /usr/local -zxvf go1.*.tar.gz                                   \
    && rm go1.*.tar.gz
ENV PATH="$PATH:/usr/local/go/bin"

WORKDIR /o5gc/ellacore

ARG ELLACORE_VERSION=1.5.0
RUN git clone --branch v${ELLACORE_VERSION} --depth 1                         \
        https://github.com/ellanetworks/core.git .                            \
    && REVISION=`git rev-parse HEAD`                                          \
    && sync-cache.sh download ellacore go-cache-dl go-cache-build npm-cache   \
    && npm install --prefix ui                                                \
    && npm run build --prefix ui                                              \
    && go build -ldflags                                                      \
          "-X github.com/ellanetworks/core/version.GitCommit=${REVISION}"     \
        ./cmd/core/main.go                                                    \
    && sync-cache.sh upload ellacore go-cache-dl go-cache-build npm-cache

RUN echo ${ELLACORE_VERSION} > /etc/image_version
