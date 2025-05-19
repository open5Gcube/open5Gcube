FROM o5gc/o5gc-base:jammy as o5gc-base

RUN git clone --branch Rel-17 https://github.com/jdegre/5GC_APIs.git

FROM swaggerapi/swagger-ui:v5.12.0

COPY --from=o5gc-base /o5gc/5GC_APIs/* /usr/share/nginx/html/5GC_APIs/

RUN apk --no-cache add nghttp2

RUN echo latest > /etc/image_version
