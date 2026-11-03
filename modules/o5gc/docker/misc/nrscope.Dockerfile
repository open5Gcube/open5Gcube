FROM o5gc/srsran-4g:develop

RUN git clone https://github.com/jbeder/yaml-cpp.git                          \
    && mkdir yaml-cpp/build                                                   \
    && pushd yaml-cpp/build                                                   \
    && sync-cache.sh download misc-nrscope ccache                             \
    && cmake ..                                                               \
    && make -j $(nproc) all install                                           \
    && sync-cache.sh upload misc-nrscope ccache                               \
    && popd                                                                   \
    && rm -r yaml-cpp

RUN git clone https://github.com/jgaeddert/liquid-dsp.git                     \
    && pushd liquid-dsp                                                       \
    && ./bootstrap.sh                                                         \
    && sync-cache.sh download misc-nrscope ccache                             \
    && ./configure                                                            \
    && make -j $(nproc) all install                                           \
    && sync-cache.sh upload misc-nrscope ccache                               \
    && popd                                                                   \
    && rm -r liquid-dsp                                                       \
    && ldconfig

WORKDIR /o5gc/NR-Scope
RUN git clone  https://github.com/PrincetonUniversity/NR-Scope.git .          \
    && mkdir build                                                            \
    && cd build                                                               \
    && sync-cache.sh download misc-nrscope ccache                             \
    && cmake ..                                                               \
    && make -j $(nproc) nrscan nrscope                                        \
    && find ./ \( -name "*.a" -o -name "*.o" \) -type f -delete               \
    && sync-cache.sh upload misc-nrscope ccache

RUN echo latest > /etc/image_version
