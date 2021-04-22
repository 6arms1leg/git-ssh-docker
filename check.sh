#!/bin/sh

PUSR=git

su -l ${PUSR} -s /bin/sh -c \
    "ssh -q \
    -o \"UserKnownHostsFile=/dev/null\" \
    -o \"StrictHostKeyChecking=no\" \
    ${PUSR}@localhost > /dev/null 2>&1"

if [ "$?" -eq "128" ]; then
    exit 0
else
    exit 1
fi
