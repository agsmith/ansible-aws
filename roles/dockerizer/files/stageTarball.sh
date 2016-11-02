#!/bin/bash

soProjectDir=$1
soTarball=$2

# Sets up environment variables for communication with virtual machine.
$(boot2docker shellinit)

# Locate the docker image tarball in Stream Observer's project directory.
soTarballAbsPath=`find $soProjectDir -name $soTarball`
if [ $? != 0 ]; then
    echo "Stream observer docker image tarball does not exist"
    exit 1
fi

# Move the docker image tarball to the staging directory for uploading to
# AWS instances.  The staging directory is the directory from which the
# Ansible script was executed.
cp -f $soTarballAbsPath .
if [ $? != 0 ]; then
    echo "Unable to move Stream Observer docker image tarball to staging dir"
    exit 1
fi
