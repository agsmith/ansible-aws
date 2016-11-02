#!/bin/bash
[ -f /var/opt/stream-observer-netproducer/logs/log.txt ] && /home/centos/network_parser.sh $* || /home/centos/pcap_parser.sh $*
