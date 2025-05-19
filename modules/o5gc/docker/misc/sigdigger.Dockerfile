FROM o5gc/o5gc-base:jammy

RUN apt-get.sh install libsndfile-dev libfftw3-dev libvolk2-dev               \
    && git clone --recurse-submodules --progress                              \
        https://github.com/BatchDrake/sigutils.git                            \
    && cd sigutils                                                            \
    && git checkout 'master@{2024-02-01}'                                     \
    && cmake -B build .                                                       \
    && make -C build -j $(nproc)                                              \
    && make -C build install clean

RUN apt-get.sh install libsoapysdr-dev soapysdr-module-uhd uhd-host           \
    && git clone --branch develop --recurse-submodules --progress             \
        https://github.com/BatchDrake/suscan.git                              \
    && cd suscan                                                              \
    && git checkout 'develop@{2024-02-01}'                                    \
    && cmake -B build .                                                       \
    && make -C build -j $(nproc)                                              \
    && make -C build install clean                                            \
    && uhd_images_downloader -t "x310|b2"

RUN apt-get.sh install qttools5-dev libqt5opengl5 libqt5opengl5-dev           \
    && git clone --branch develop --recurse-submodules --progress             \
        https://github.com/BatchDrake/SuWidgets.git                           \
    && cd SuWidgets                                                           \
    && git checkout 'develop@{2024-02-01}'                                    \
    && qmake SuWidgetsLib.pro                                                 \
    && make -j $(nproc)                                                       \
    && make install clean

RUN git clone --branch develop --recurse-submodules --progress                \
        https://github.com/BatchDrake/SigDigger                               \
    && cd SigDigger                                                           \
    && git checkout 'develop@{2024-02-01}'                                    \
    && qmake SigDigger.pro                                                    \
    && make -j $(nproc)                                                       \
    && make install clean

RUN pip3 install --no-cache-dir nrarfcn

RUN echo latest > /etc/image_version

ENTRYPOINT ["/o5gc/SigDigger/entrypoint.sh"]
