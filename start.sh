#!/bin/sh

PROG=/usr/sbin/sshd
PSHELL=/usr/bin/git-shell
PUSR=git
PHOME=/${PUSR}
PCONFIG=${PHOME}/sshd_config
PKEYSHOST=${PHOME}/keys-host
PKEYS=${PHOME}/keys
PREPOS=${PHOME}/repos

# Print UID and GID for confirmation
echo PUID:${PUID}
echo PGID:${PGID}

# Sanity check on UID/GID
if [ "${PUID}" -lt "1000" ]; then
    echo PUID cannot be \< 1000
    exit 1
fi

if [ "${PGID}" -lt "1000" ]; then
    echo PGID cannot be \< 1000
    exit 1
fi

# Create user with provided UID:GID and git-shell, which provides restricted
# Git access.
# It permits execution only of server-side Git commands implementing the
# pull/push functionality, plus custom commands present in a subdirectory
# named `git-shell-commands` in the user’s home directory.
# [More info](https://git-scm.com/docs/git-shell)
# Set a (dummy) password, otherwise SSH login fails.
addgroup -g ${PGID} ${PUSR}
adduser -D -h ${PHOME}/ -G ${PUSR} -u ${PUID} -s ${PSHELL} ${PUSR}
echo "${PUSR}:dummyPassword" | chpasswd
chown -R ${PUSR}:${PUSR} ${PHOME}/ > /dev/null 2>&1

# If no host keys are present, generate them
if [ -z "$(ls -A ${PKEYSHOST}/)" ]; then
    mkdir -p ${PKEYSHOST}/etc/ssh/ && \
    ssh-keygen -A -f ./keys-host && \
    mv ${PKEYSHOST}/etc/ssh/* ${PKEYSHOST}/ && \
    rm -rf ${PKEYSHOST}/etc/
    chown -R ${PUSR}:${PUSR} ${PKEYSHOST}/
fi

# If public keys are present, copy them into the `authorized_keys` file
if [ -n "$(ls -A ${PKEYS}/)" ]; then
    cat ${PKEYS}/*.pub > ${PHOME}/.ssh/authorized_keys
else
    # If no public SSH keys are present, make the `authorized_keys` file empty.
    # This is important for some corner cases of restarting the Docker
    # container with no public SSH keys present.
    cat '' > ${PHOME}/.ssh/authorized_keys
fi

# Generate an SSH key pair for Docker `HEALTHCHECK`
rm -rf ${PHOME}/.ssh/id_ed25519*
ssh-keygen -q -t ed25519 -N '' -f ${PHOME}/.ssh/id_ed25519
cat ${PHOME}/.ssh/id_ed25519.pub >> ${PHOME}/.ssh/authorized_keys

# Set correct access permissions for the files created in the previous steps
chown -R ${PUSR}:${PUSR} ${PHOME}/.ssh/
chmod 700 ${PHOME}/.ssh/
chmod -R 600 ${PHOME}/.ssh/*

exec ${PROG} -D -f ${PCONFIG}
