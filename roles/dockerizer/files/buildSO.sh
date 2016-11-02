#!/bin/bash

soProjectDir=$1

# Sets up environment variables for communication with virtual machine.
$(boot2docker shellinit)

# Clean out current and old Stream Observer images from the virtual
# machine's docker image cache in preparation for building a new image.
docker images \
    | grep -e "stream-observer" -e "<none>" \
    | awk '{ print $3 }' \
    | xargs docker rmi -f

# Change to Stream Observer's project directory.
cd $soProjectDir

# Dockerize Stream Observer.
dockerize build
if [ $? != 0 ]; then
    echo "Failed to dockerize stream observer"
    exit 1
fi

# Generate a tarball of Stream Observer's docker image in the virtual
# machine's docker image cache.
dockerize save
if [ $? != 0 ]; then
    echo "Failed to generate stream observer docker image tarball"
    exit 1
fi
