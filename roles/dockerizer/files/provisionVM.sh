#!/bin/bash

regUser=$1
regPass=$2

# Generic function for running individual commands in virtual machine.
function busyBox {
    docker run --rm \
        -v /etc/docker/certs.d:/etc/docker/certs.d \
        -v $DEV_TOOLS_HOME/tools/boot2docker:/tmp/dev-tools-boot2docker \
        -v /var/lib/boot2docker:/var/lib/boot2docker \
        busybox $1
}

# Sets up environment variables for communication with virtual machine.
$(boot2docker shellinit)

restartVM=0

# Move certificates to virtual machine.
busyBox "diff -r /tmp/dev-tools-boot2docker/private-certs /var/lib/boot2docker/private-certs"
if [ $? != 0 ]; then
    busyBox "rm -Rf /var/lib/boot2docker/private-certs"
    busyBox "cp -r /tmp/dev-tools-boot2docker/private-certs /var/lib/boot2docker/"
    restartVM=1
fi

# Move boot script to virtual machine.  Boot script will install certificates
# and setup DNS entries for acropolis.
busyBox "diff /tmp/dev-tools-boot2docker/bootlocal.sh /var/lib/boot2docker/bootlocal.sh"
if [ $? != 0 ]; then
    busyBox "cp -f /tmp/dev-tools-boot2docker/bootlocal.sh /var/lib/boot2docker/"
    busyBox "chmod u+x /var/lib/boot2docker/bootlocal.sh"
    restartVM=1
fi

# Move profile to virtual machine.  Sets miscellaneous environment variables.
busyBox "diff /tmp/dev-tools-boot2docker/profile /var/lib/boot2docker/profile"
if [ $? != 0 ]; then
    busyBox "cp -f /tmp/dev-tools-boot2docker/profile /var/lib/boot2docker/"
    restartVM=1
fi

# Restart virtual machine if configuration has changed.
if [ $restartVM == 1 ]; then
    boot2docker down
    boot2docker up
fi

# Login to acropolis docker registry.
docker login --username=$regUser --password=$regPass --email=$regUser@ccadllc.us acropolis:5000
