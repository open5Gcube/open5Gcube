FROM o5gc/o5gc-base:jammy

WORKDIR /o5gc/pyhss

RUN mkdir -p /etc/apt/keyrings                                                \
    && curl -fsSL https://packages.redis.io/gpg                               \
        | gpg --dearmor -o /etc/apt/keyrings/redis-archive.gpg                \
    && echo "deb [signed-by=/etc/apt/keyrings/redis-archive.gpg]"             \
            "https://packages.redis.io/deb $(lsb_release -cs) main"           \
        > /etc/apt/sources.list.d/redis.list                                  \
    && apt-get.sh install redis

ARG PYHSS_VERSION=1.0.2
RUN git clone --branch ${PYHSS_VERSION} --depth 1                             \
        https://github.com/nickvsnetworking/pyhss.git .                       \
    && pip3 install --no-cache-dir -r requirements.txt                        \
    && mkdir /var/log/pyhss/

RUN echo ${PYHSS_VERSION} > /etc/image_version
