#!/bin/bash

set -o pipefail

input=${1}
output=${2:-$1}
[ -n "${3}" ] && varprefix="-p ${3}"

cat ${input} | genvsub -u ${varprefix} | sponge ${output}
