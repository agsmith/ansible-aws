#!/bin/bash

function is_steady_state() {
  grep "org/pcap4j/pcap4j.properties" /var/opt/observer/logs/log.txt > /dev/null 2>&1
  [ $? -eq 0 ]
}

function wait_for_steady_state() {
  while !is_steady_state; do
    sleep 1
  done
}

ip=$(/sbin/ip -o -4 addr list eth0 | awk '{print $4}' | cut -d/ -f1)
sed -i "s/0.0.0.0/${ip}/g" /var/opt/observer-netproducer/conf/app.conf

for ((i = 1 ; i <= $1 ; i++ )); do
  sudo docker run -d --name=observer-netconsumer -p 6705:6705/udp -v /var/opt/observer/conf:/opt/stream-observer/conf/external -v /var/opt/observer/logs:/opt/stream-observer/logs ccadllc/stream-observer:3.0.0-SNAPSHOT /opt/stream-observer/bin/stream-observer
  wait_for_steady_state
  sudo docker run -i -t --name=observer-netproducer -v /var/opt/observer-netproducer/conf:/opt/stream-observer/conf/external -v /var/opt/observer-netproducer/logs:/opt/stream-observer/logs ccadllc/stream-observer:3.0.0-SNAPSHOT /opt/stream-observer/bin/stream-observer
  sudo /home/centos/network_parser.sh $i $2 $4 $5
  sudo docker stop observer-netconsumer
  sudo docker rm observer-netconsumer
  sudo docker stop observer-netproducer
  sudo docker rm observer-netproducer
  sudo rm -f /var/opt/observer-netproducer/logs/* /var/opt/observer/logs/* /home/centos/ripped_log
  sudo chmod 777 $2-packet-loss-analysis.txt
done
/home/centos/network_parser.sh rollup $2
sudo rm -rf /var/opt/observer/conf/*
exit 0
