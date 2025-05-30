FROM o5gc/o5gc-base:jammy

LABEL org.opencontainers.image.title='Open5GS'

RUN mv /etc/apt/apt.conf.d/01proxy /tmp                                       \
    && mkdir -p /etc/apt/keyrings                                             \
    && curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key   \
        | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg                   \
    && echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg]"                \
            "https://deb.nodesource.com/node_16.x nodistro main"              \
        > /etc/apt/sources.list.d/nodesource.list                             \
    && apt-get.sh install nodejs                                              \
    && mv /tmp/01proxy /etc/apt/apt.conf.d/

RUN apt-get.sh install                                                        \
        python3-pip python3-setuptools python3-wheel ninja-build              \
        build-essential flex bison git libsctp-dev libgnutls28-dev            \
        libgcrypt-dev libssl-dev libidn11-dev libmongoc-dev libbson-dev       \
        libyaml-dev libnghttp2-dev libmicrohttpd-dev libcurl4-gnutls-dev      \
        libtins-dev libtalloc-dev meson jq

RUN pip3 install --upgrade --no-cache-dir pip                                 \
    && pip3 install --no-cache-dir click==8.0.4                               \
    && ln -s /o5gc/open5gs/ -t /

WORKDIR /o5gc/open5gs

ARG OPEN5GS_VERSION=2.7.2
RUN git clone --branch v${OPEN5GS_VERSION} --depth 1                          \
        https://github.com/open5gs/open5gs .

COPY *.patch .
RUN git -c user.name='o5gc' -c user.email='o5gc@fkie.fraunhofer.de'           \
        am ./*.patch                                                          \
    && sync-cache.sh download open5gs ccache                                  \
    && meson build --prefix=/o5gc/open5gs/install                             \
    && ninja -C build install                                                 \
    && ninja -C build clean                                                   \
    && mkdir /var/log/open5gs                                                 \
    && sync-cache.sh upload open5gs ccache

# Building WebUI of open5gs
RUN cd webui                                                                  \
    && npm ci --no-optional                                                   \
    && npm cache clean --force                                                \
    && sed -i server/index.js                                                 \
        -e "s|newAccount.username = 'admin'|newAccount.username = 'o5gc'|"    \
        -e "s|register(newAccount, '1423'|register(newAccount, 'o5gc'|"

RUN echo ${OPEN5GS_VERSION} > /etc/image_version
