#!/bin/bash
[ "$3" = "network" ] && /home/centos/runNetworkDocker.sh $* || /home/centos/runPcapDocker.sh $*
exit 0
