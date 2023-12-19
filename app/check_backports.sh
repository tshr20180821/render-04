#!/bin/bash

set +x

echo "check ${1}" | tee -a "${2}"
curl -sS -m 10 "https://packages.debian.org/bookworm-backports/${1}" 2>>"${2}" | grep '<h1>' | grep "${1}" | cut -c 14- | tee -a "${2}"
# grep '<h1>'
# <h1>Package: curl (8.4.0-2~bpo12+1 and others)
sleep 2s
