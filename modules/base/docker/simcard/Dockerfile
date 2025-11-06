FROM o5gc/o5gc-base:jammy

RUN apt-get.sh install                                                        \
        libpcsclite-dev python3-pyscard python3-serial python3-yaml           \
        python3-wheel pcscd pcsc-tools

#RUN git clone https://github.com/LudovicRousseau/pcsc-tools                   \
#    && cd pcsc-tools                                                          \
#    && git checkout 1.6.0                                                     \
#    && ./bootstrap                                                            \
#    && ./configure --prefix=/usr                                              \
#    && make install

WORKDIR /o5gc/pysim
RUN git clone https://gitea.osmocom.org/sim-card/pysim.git .                  \
    && git checkout 6bfa8a8533                                                \
    && pip3 install --no-cache-dir wheel                                      \
    && pip3 install --no-cache-dir -r requirements.txt

#RUN git clone https://github.com/sysmocom/sysmo-usim-tool.git

RUN echo latest > /etc/image_version

COPY entrypoint.sh /o5gc/
ENTRYPOINT ["/o5gc/entrypoint.sh"]
