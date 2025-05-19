#!/bin/sh

set -e

if [ 2 -ne $# ]
then
    echo You must specify output directory and service : ./make_certs.sh ./freeDiameter mme
    exit;
fi

outdir=$(realpath $1)
service=$2

cd /tmp

rm -rf demoCA
mkdir demoCA
echo 01 > demoCA/serial
touch demoCA/index.txt.attr
touch demoCA/index.txt

# Generate .rnd if it does not exist
openssl rand -out /root/.rnd -hex 256

# CA self certificate
openssl req  -new -batch -x509 -days 3650 -nodes -newkey rsa:1024 -out ${outdir}/${service}.cacert.pem -keyout cakey.pem -subj /CN=ca.${EPC_DOMAIN}/C=KO/ST=Seoul/L=Nowon/O=Open5GS/OU=Tests

# Service
openssl genrsa -out ${outdir}/${service}.key.pem 1024
openssl req -new -batch -out csr.pem -key ${outdir}/${service}.key.pem -subj /CN=${service}.${EPC_DOMAIN}/C=KO/ST=Seoul/L=Nowon/O=Open5GS/OU=Tests
openssl ca -cert ${outdir}/${service}.cacert.pem -days 3650 -keyfile cakey.pem -in csr.pem -out ${outdir}/${service}.cert.pem -outdir . -batch

rm -f 01.pem 02.pem 03.pem 04.pem
rm -f cakey.pem
rm -f csr.pem
