ARG BASE_IMG=jammy
FROM ubuntu:${BASE_IMG}
ARG BASE_IMG
ARG BUILD_HOST
ARG USE_BUILD_CACHER=1

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

COPY base-packages.${BASE_IMG}.txt /tmp/base.packages.txt
COPY dpkg-excludes.cfg /etc/dpkg/dpkg.cfg.d/excludes
RUN sed -i 's|http://archive.ubuntu.com|http://de.archive.ubuntu.com|g'       \
        /etc/apt/sources.list                                                 \
    && apt-get update                                                         \
    && echo 'Acquire::http { Proxy "http://o5gc-build-cacher:40861"; };'      \
        > /etc/apt/apt.conf.d/01proxy                                         \
    && ([ ${USE_BUILD_CACHER} -ne 0 ] || :> /etc/apt/apt.conf.d/01proxy)      \
    && DEBIAN_FRONTEND=noninteractive                                         \
       xargs -a /tmp/base.packages.txt apt-get install --no-install-recommends -y

# make /bin/sh symlink to bash instead of dash
RUN echo "dash dash/sh boolean false" | debconf-set-selections                \
    && DEBIAN_FRONTEND=noninteractive dpkg-reconfigure dash
# set timezone
ARG TZ
ENV TZ=${TZ}
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime                            \
    && ln -fs /usr/share/zoneinfo/$TZ /etc/timezone                           \
    && DEBIAN_FRONTEND=noninteractive dpkg-reconfigure -f noninteractive tzdata
# setup ccache
RUN /usr/sbin/update-ccache-symlinks
ENV PATH="/usr/lib/ccache:${PATH}"
# setup git caching
RUN [ ${USE_BUILD_CACHER} -eq 0 ] ||                                          \
git config --global url."http://o5gc-build-cacher:40862/".insteadOf https://
# At login
# - run updatedb
# - disable apt proxy
# - disable git caching
# - enable bash-completion
RUN echo -e "updatedb\n"                                                      \
            "rm -f /etc/apt/apt.conf.d/01proxy\n"                             \
            "git config --global --get-regex url >/dev/null &&"               \
                "git config --global --unset                                  \
                    $(git config --global --get-regex url)\n"                 \
            "source /etc/bash_completion\n"                                   \
            "PATH=/usr/lib/ccache:${PATH}\n"                                  \
        >> ~/.bashrc

# helper scripts
COPY runWithDelay.sh sync-cache.sh cached-download.sh envsubst.sh             \
     apt-get.sh  /usr/local/bin/
RUN sed -i -E "s|^(USE_BUILD_CACHER)=.*|\1=${USE_BUILD_CACHER}|" /usr/local/bin/*.sh

# install recent version of tshark (5G support)
RUN add-apt-repository --yes --update ppa:wireshark-dev/stable                \
    && apt-get.sh install tshark

# install ripgrep
RUN cached-download.sh                                                        \
        https://github.com/BurntSushi/ripgrep/releases/download/13.0.0/ripgrep_13.0.0_amd64.deb \
    && dpkg -i ripgrep_13.0.0_amd64.deb                                       \
    && rm ripgrep_13.0.0_amd64.deb

# install alternative envsubst
RUN cd /usr/local/bin/ && cached-download.sh                                  \
        https://github.com/icy/genvsub/releases/download/v1.2.3/genvsub_1.2.3_Linux_x86_64.tar.gz \
    && tar -zxvf genvsub_*.tar.gz genvsub && chmod +x genvsub                 \
    && rm genvsub_*.tar.gz

# install Docker CLI
COPY install-docker.sh /usr/local/bin/
RUN install-docker.sh cli-only

RUN --mount=type=secret,id=id_ed25519 --mount=type=secret,id=id_ed25519.pub   \
    mkdir -m 0700 /root/.ssh && cd /root/.ssh                                 \
    && cp /run/secrets/id_ed25519* .                                          \
    && chmod +r id_ed25519.pub                                                \
    && cp id_ed25519.pub authorized_keys

RUN echo ${BASE_IMG} > /etc/image_version                                     \
    && echo ${BUILD_HOST} > /etc/build_host

WORKDIR /o5gc
