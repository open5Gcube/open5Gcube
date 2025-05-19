#!/bin/bash
set -x

sleep $1
shift
exec "${@}"
