#!  /bin/sh
set -ex

cd /usr/share/nginx/html/5GC_APIs

for spec in *_Nnrf_*.yaml; do
    sed -i "s|https://example.com|http://${HOST_DEFAULT_ROUTE_IFACE_IP}:${SWAGGER_UI_HOST_PORT}|g" ${spec}
done

nghttpx --daemon                                                              \
    --frontend="*,8288;no-tls"                                                \
    --backend="${NRF_IP_ADDR},7777;/nnrf-nfm/;proto=h2;no-tls"                \
    --backend="127.0.0.1,8080"
