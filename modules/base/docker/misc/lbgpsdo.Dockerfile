FROM o5gc/o5gc-base:focal

RUN apt-get.sh install libhidapi-hidraw0                                      \
    && pip3 install --no-cache-dir hid==1.0.4                                 \
    && git clone https://github.com/hamarituc/lbgpsdo.git

RUN echo latest > /etc/image_version

ENTRYPOINT ["python3", "/o5gc/lbgpsdo/lbgpsdo.py"]
