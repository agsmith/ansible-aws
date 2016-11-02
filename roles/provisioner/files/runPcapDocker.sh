#!/bin/bash

for ((i = 1 ; i <= $1 ; i++ )); do
  sudo docker run -i -t --name=observer --net=host -v /var/opt/observer/conf:/opt/stream-observer/conf/external -v /var/opt/observer/logs:/opt/stream-observer/logs ccadllc/stream-observer:3.0.0-SNAPSHOT /opt/stream-observer/bin/stream-observer
  sudo /home/centos/pcap_parser.sh $i $2 $4
  sudo docker stop observer
  sudo docker rm observer
  sudo rm -rf /var/opt/observer/logs/* /home/centos/ripped_log
  sudo chmod 777 $2-time-analysis.txt
done
/home/centos/pcap_parser.sh rollup $2
sudo rm -rf /var/opt/observer/conf/*
exit 0
