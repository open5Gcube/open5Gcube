#!/bin/bash

set -e

# redis
redis-cli ping
# api
nc -z ${VOLTE_HSS_IP_ADDR} 8080
# diameter
nc -z ${VOLTE_HSS_IP_ADDR} 3868
