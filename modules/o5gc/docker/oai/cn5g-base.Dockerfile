ARG BASE_IMG
FROM o5gc/o5gc-base:${BASE_IMG:-jammy}

ARG OAI_CN5G_VERSION=2.1.0
ENV OAI_CN5G_VERSION=${OAI_CN5G_VERSION}
ENV IS_DOCKERFILE=1

RUN git config --global --add                                                 \
        url."https://github.com/tatsuhiro-t/".insteadOf https://github.com/tatsuhiro-t/ && \
    git config --global --add                                                 \
        url."https://gitlab.eurecom.fr/oai/cn5g/oai-cn5g-common-src.git".insteadOf https://gitlab.eurecom.fr/oai/cn5g/oai-cn5g-common-src.git

# Hack to install common packages
RUN git clone --branch v${OAI_CN5G_VERSION} --depth 1 --recurse-submodules    \
        https://gitlab.eurecom.fr/oai/cn5g/oai-cn5g-pcf.git tmp               \
    && pushd /usr/local/bin/                                                  \
    && ln -s /usr/bin/false git                                               \
    && popd                                                                   \
    && pushd tmp/build/scripts                                                \
    && ./build_pcf --install-deps --force || true                             \
    && popd                                                                   \
    && rm -rf tmp /usr/local/bin/git

RUN cached-download.sh                                                        \
        https://github.com/mikefarah/yq/releases/download/v4.45.1/yq_linux_amd64 /usr/local/bin/yq && \
    chmod +x /usr/local/bin/yq

RUN echo ${OAI_CN5G_VERSION} > /etc/image_version
