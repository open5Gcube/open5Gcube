#!/bin/bash

set -ux

# Add static route to route traffic back to UE as there is not NATing
ip r add 192.168.101.0/24 via ${UPF_IP_ADDR}

exec rtpengine                                                                \
    --interface=${RTPENGINE_IP_ADDR}                                          \
    --listen-ng=${RTPENGINE_IP_ADDR}:2223                                     \
    --listen-cli=${RTPENGINE_IP_ADDR}:9901                                    \
    --pidfile=/run/ngcp-rtpengine-daemon.pid                                  \
    --port-min=49000 --port-max=50000                                         \
    --table=-1                                                                \
    --tos=184                                                                 \
    --log-stderr --foreground
