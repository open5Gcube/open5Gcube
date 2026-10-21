FROM o5gc/o5gc-base:noble

RUN cached-download.sh https://go.dev/dl/go1.26.1.linux-amd64.tar.gz          \
    && tar -C /usr/local -zxvf go1.*.tar.gz                                   \
    && rm go1.*.tar.gz
ENV PATH="$PATH:/usr/local/go/bin"

RUN echo latest > /etc/image_version
