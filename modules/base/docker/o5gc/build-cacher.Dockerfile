FROM node:16-bullseye

RUN git clone https://github.com/jonasmalacofilho/git-cache-http-server       \
    && cd git-cache-http-server                                               \
    && npm install                                                            \
    && npm install --global

RUN apt-get update                                                            \
&& DEBIAN_FRONTEND=noninteractive                                             \
    apt-get install --no-install-recommends -y apt-cacher-ng rsync

# make /bin/sh symlink to bash instead of dash
RUN echo "dash dash/sh boolean false" | debconf-set-selections                \
    && DEBIAN_FRONTEND=noninteractive dpkg-reconfigure dash

ARG SYNC_CACHES
RUN for cache in ${SYNC_CACHES} downloads; do                                 \
        echo -e "[$cache]\n"                                                  \
            "path = /var/cache/$cache\n"                                      \
            "read only = no\n"                                                \
            "use chroot = false\n"                                            \
          >> /etc/rsyncd.conf;                                                \
        done

RUN chmod 666 /etc/default/apt-cacher-ng /etc/apt-cacher-ng/*                 \
    && sed -i 's|^\(RUNDIR=\).*|\1"/tmp/apt-cacher-ng"|'                      \
        /etc/init.d/apt-cacher-ng                                             \
    && echo -e "SocketPath: /tmp/apt-cacher-ng/socket\n"                      \
               "PidFile: /tmp/apt-cacher-ng/pid\n"                            \
               "PassThroughPattern: .*\n"                                     \
               "LogDir:\n"                                                    \
        >> /etc/apt-cacher-ng/acng.conf

COPY build-cacher-entrypoint.sh /
CMD ["/build-cacher-entrypoint.sh"]
