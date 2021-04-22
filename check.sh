#!/bin/sh

PUSR=git

su -l ${PUSR} -c \
    "ssh -q \
    -o \"UserKnownHostsFile=/dev/null\" \
    -o \"StrictHostKeyChecking=no\" \
    ${PUSR}@localhost 2>&1 > /dev/null"

if [ "$?" -eq "128" ]; then
    exit 0
else
    exit 1
fi
