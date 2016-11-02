#!/bin/bash

# Ensure the Boot2Docker virtual machine is up and running.
b2dStatus=`boot2docker status 2> /dev/null`
b2dRC=$?
if [ $b2dRC == 1 ]; then
    boot2docker init
    boot2docker up
elif [ $b2dRC == 0 ] && [ $b2dStatus != "running" ]; then
    boot2docker up
elif [ $b2dRC == 127 ]; then
    echo "boot2docker command not found"
    exit 1
elif [ $b2dRC != 0 ]; then
    echo "boot2docker virtual machine failed to initialize"
    exit 1
fi

exit 0
