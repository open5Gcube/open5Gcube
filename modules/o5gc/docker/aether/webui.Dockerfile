FROM o5gc/aether-core-base:latest

WORKDIR /o5gc/aether-webui

ARG AETHER_WEBUI_VERSION=3.1.4

RUN git clone --branch v${AETHER_WEBUI_VERSION} --depth 1                     \
        https://github.com/omec-project/webconsole.git .

RUN sync-cache.sh download aether-webui go-cache-dl go-cache-build            \
    && make webconsole-ui \
    && sync-cache.sh upload aether-webui go-cache-dl go-cache-build

RUN echo ${AETHER_WEBUI_VERSION} > /etc/image_version
