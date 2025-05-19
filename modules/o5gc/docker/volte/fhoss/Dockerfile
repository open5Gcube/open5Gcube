FROM o5gc/o5gc-base:focal

# Install Oracle Java 7 SE JDK
RUN cached-download.sh                                                        \
        https://repo.huaweicloud.com/java/jdk/7u80-b15/jdk-7u80-linux-x64.tar.gz \
    && echo "6152f8a7561acf795ca4701daa10a965 jdk-7u80-linux-x64.tar.gz" > md5\
    && md5sum -c md5                                                          \
    && mkdir -p /usr/lib/jvm/                                                 \
    && tar -xzf jdk-7u80-linux-x64.tar.gz -C /usr/lib/jvm/                    \
    && rm jdk-7u80-linux-x64.tar.gz md5                                       \
    && update-alternatives                                                    \
        --install /usr/bin/java java /usr/lib/jvm/jdk1.7.0_80/bin/java 100    \
    && update-alternatives                                                    \
        --install /usr/bin/javac javac /usr/lib/jvm/jdk1.7.0_80/bin/javac 100
ENV JAVA_HOME="/usr/lib/jvm/jdk1.7.0_80"
ENV CLASSPATH="/usr/lib/jvm/jdk1.7.0_80/jre/lib/"

# Install Ant
RUN cached-download.sh                                                        \
        http://archive.apache.org/dist/ant/binaries/apache-ant-1.9.14-bin.tar.gz \
    && tar -xzf apache-ant-1.9.14-bin.tar.gz -C /usr/local                    \
    && rm apache-ant-1.9.14-bin.tar.gz                                        \
    && ln -s /usr/local/apache-ant-1.9.14/bin/ant /usr/bin/ant
ENV ANT_HOME="/usr/local/apache-ant-1.9.14"

# Install FHoSS
ENV FHOSS_REVERSION=4ffa54b

RUN git clone https://github.com/herlesupreeth/FHoSS                          \
    && cd FHoSS                                                               \
    && git checkout ${FHOSS_REVERSION}                                        \
    && LC_ALL=C.UTF-8 ant compile deploy

RUN echo ${FHOSS_REVERSION} > /etc/image_version
