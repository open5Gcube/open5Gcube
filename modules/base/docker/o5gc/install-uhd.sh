#! /bin/bash

set -ex

UHD_VERSION=$1

apt-get.sh install                                                            \
    libboost-chrono-dev libboost-date-time-dev libboost-filesystem-dev        \
    libboost-program-options-dev libboost-thread-dev libboost-test-dev        \

cd /o5gc
git clone --branch UHD-${UHD_VERSION} --depth 1                               \
    https://github.com/EttusResearch/uhd.git
mkdir uhd/host/build
cd uhd/host/build
cmake -DENABLE_TESTS=OFF -DENABLE_EXAMPLES=OFF -DENABLE_B100=OFF              \
      -DENABLE_DOXYGEN=OFF -DENABLE_MANUAL=OFF -DENABLE_MAN_PAGES=OFF         \
      -DENABLE_MAN_PAGE_COMPRESSION=OFF -DENABLE_OCTOCLOCK=ON                 \
      -DENABLE_X400=OFF -DENABLE_USRP1=OFF -DENABLE_USRP2=OFF                 \
      -DCMAKE_CXX_FLAGS="-march=native"                                       \
    ../
make -j $(nproc)
make install
make clean
ldconfig

uhd_images_downloader -t "x310|b2"
