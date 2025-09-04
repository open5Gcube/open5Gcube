FROM o5gc/srsran-4g:develop

RUN git clone https://github.com/jbeder/yaml-cpp.git                          \
    && mkdir yaml-cpp/build                                                   \
    && pushd yaml-cpp/build                                                   \
    && cmake ..                                                               \
    && make -j $(nproc) all install                                           \
    && popd                                                                   \
    && rm -r yaml-cpp

RUN git clone https://github.com/jgaeddert/liquid-dsp.git                     \
    && pushd liquid-dsp                                                       \
    && ./bootstrap.sh                                                         \
    && ./configure                                                            \
    && make -j $(nproc) all install                                           \
    && popd                                                                   \
    && rm -r liquid-dsp                                                       \
    && ldconfig

WORKDIR /o5gc/NR-Scope
RUN git clone  https://github.com/PrincetonUniversity/NR-Scope.git .          \
    && mkdir build                                                            \
    && cd build                                                               \
    && cmake ..                                                               \
    && sync-cache.sh download misc-nrscope ccache                             \
    && make -j $(nproc) nrscan nrscope                                        \
    && find ./ \( -name "*.a" -o -name "*.o" \) -type f -delete               \
    && sync-cache.sh upload misc-nrscope ccache

RUN echo latest > /etc/image_version
