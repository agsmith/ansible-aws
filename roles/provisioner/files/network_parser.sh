#!/bin/bash
ANALYSIS_FILE=/home/centos/$2-packet-loss-analysis.txt
SUMMARY_FILE=/home/centos/summary-packet-loss-analysis.txt
LOG_LOCATION=/var/opt/observer/logs/log.txt
RIPPED_LOG_LOCATION=/home/centos/ripped_log
PACKET_LOSS="Dropped packets"
SO_VERSION='Application Lifecycle / Started / Application started'
MIN=1000000000
MAX=0.0
IGNORED_PACKET_LOSS_COUNT=0

function get_ignored_dropped_packet_count {
  ignore_time=$1

  current_time=$(cat $LOG_LOCATION | head -1|awk '{print $1" "$2}')
  #rip all stream start and finish lines into a single flat file
  for ((i = 1 ; i < 11 ; i++ )); do
    ll=$(echo $LOG_LOCATION.$i)
    if [ -f "$ll" ]; then
      current_time=$(cat $ll | head -1|awk '{print $1" "$2}')
    fi
  done

  current_time_epoch=$(date +%s --date="$current_time")
  end_time_epoch=$(date +%s --date="@$((current_time_epoch + ignore_time))")

  while read p; do
    current_time=$(echo $p |awk '{print $1" "$2}')
    current_time_epoch=$(date +%s --date="$current_time")
    skip_version_string=$(echo $p | grep $SO_VERSION)
    if [ -z $skip_version_string ]; then
      if [ "$current_time_epoch" -lt "$end_time_epoch" ]; then
        new_count=$(echo $p | grep "$PACKET_LOSS" |awk '{$1=$2=$3=$4=$5=$6=$7=$8=$9=$10=$11=$12=$13=$14=$15=$16=""; print $0}' |sed -e 's/^[ \t]*//'|sed -e 's/^[ \n]*//'|tr -d '(' | tr -d '|' |tr -d ')')
        echo "NEW COUNT "$new_count
        if [ "$new_count" -gt "$IGNORED_PACKET_LOSS_COUNT" ]; then
          IGNORED_PACKET_LOSS_COUNT=$new_count
        fi
      else
        break
      fi
    fi
  done <$RIPPED_LOG_LOCATION
}

if [ "$1" == "summarize" ]; then
  #get a list of /home/centos/*-packet-loss-analysis.txt files
  FILES=$(ls -tr *packet-loss-analysis.txt)

  FILE=$(ls -tr *-packet-loss-analysis.txt| head -1)
  VERSION=$(cat $FILE | grep "Stream Observer Version")
  echo $VERSION > $SUMMARY_FILE
  echo "runs_per_instance:" $2 >> $SUMMARY_FILE
  echo "instance_type:" $3 >> $SUMMARY_FILE
  echo " " >> $SUMMARY_FILE

  #  grep for "Dropped Packets"
  #  output "<stream name>: Dropped Packets: %d" >> summary-packet-loss-analysis.txt
  for f in $FILES
  do
    line=$(cat $f | grep "Summary Mean Packet Loss")
    echo $f: $line >> $SUMMARY_FILE
  done

elif [ "$1" == "rollup" ]; then

  AVGS_STRING=$(cat $ANALYSIS_FILE | grep "Total Packet Loss:" | awk '{print $4"||"}')
  MINS_STRING=$(cat $ANALYSIS_FILE | grep "Total Packet Loss:" | awk '{print $4"||"}')
  MAXS_STRING=$(cat $ANALYSIS_FILE | grep "Total Packet Loss:" | awk '{print $4"||"}')

  IFS='||' AVGS=($AVGS_STRING)
  IFS='||' MINS=($MINS_STRING)
  IFS='||' MAXS=($MAXS_STRING)

  echo "AVGS" $AVGS
  echo "MINS" $MINS
  echo "MAXS" $MAXS

  NUM_AVGS=${#AVGS[@]}
  TOTAL=0.0
  for ((i = 0 ; i < $NUM_AVGS ; i+=2 )); do
    THIS_AVG=$(echo ${AVGS[i]}| tr -d '\n')
    THIS_MIN=$(echo ${MINS[i]}| tr -d '\n')
    THIS_MAX=$(echo ${MAXS[i]}| tr -d '\n')

    MAX=$(echo $THIS_MAX $MAX | awk '{if ($1>$2) print $1;else print $2}')
    MIN=$(echo $THIS_MIN $MIN | awk '{if ($1<$2) print $1;else print $2}')

    TOTAL=$(echo $TOTAL $THIS_AVG|awk '{print $1 + $2}')
  done
  AVGS_AVG=$(echo $TOTAL $NUM_AVGS | awk '{print $1 / ($2/2)}')
  echo "=================================================" >> $ANALYSIS_FILE
  echo "" >> $ANALYSIS_FILE
  echo "Summary Mean Packet Loss:" $AVGS_AVG >> $ANALYSIS_FILE
  echo "Summary Min Packet Loss: " $MIN >> $ANALYSIS_FILE
  echo "Summary Max Packet Loss: " $MAX >> $ANALYSIS_FILE

else
  cat $LOG_LOCATION | grep "$SO_VERSION" >> $RIPPED_LOG_LOCATION
  cat $LOG_LOCATION | grep "$PACKET_LOSS" >> $RIPPED_LOG_LOCATION

  #rip all stream start and finish lines into a single flat file
  for ((i = 1 ; i < 11 ; i++ )); do
    ll=$(echo $LOG_LOCATION.$i)
    if [ -f "$ll" ]; then
      cat $ll | grep "$SO_VERSION" >> $RIPPED_LOG_LOCATION
      cat $ll | grep "$PACKET_LOSS" >> $RIPPED_LOG_LOCATION
    fi
  done

  #accomodate grepping on stream names 1 & 10 by making them 1| & 10|
  cp $RIPPED_LOG_LOCATION ripped_log.bak

  VERSION_STRING=$(cat $RIPPED_LOG_LOCATION | grep "$SO_VERSION" |awk '{$1=$2=$3=$4=$5=$6=$7=$8=$9=$10=$11=$12=$13=$14=$15=$16=""; print $0}' |sed -e 's/^[ \t]*//'|sed -e 's/^[ \n]*//'|tr -d '(' | tr -d '|' |tr -d ')')

  PACKET_LOSS_STRING=$(cat $RIPPED_LOG_LOCATION | grep "$PACKET_LOSS" |awk '{$1=$2=$3=$4=$5=$6=$7=$8=$9=$10=$11=$12=$13=$14=$15=$16=""; print $0"@@"}' |sed -e 's/^[ \t]*//'|sed -e 's/^[ \n]*//'|tr -d '(' | tr -d '|' |tr -d ')')

  #Convert strings into an array
  IFS='@@' PACKET_LOSS_NUMBERS=($PACKET_LOSS_STRING)

  if [ ! -f $ANALYSIS_FILE ]; then
    echo "Stream Observer Version:" $VERSION_STRING > $ANALYSIS_FILE

  fi

  RUNTIMES_TOTAL=0.0

  echo "Run" $1 >> $ANALYSIS_FILE
  echo ""

  get_ignored_dropped_packet_count $4

  MAX=$(echo "${PACKET_LOSS_NUMBERS[*]}" | sort -nr | head -n1)
  MAX=$(echo $MAX $IGNORED_PACKET_LOSS_COUNT | awk '{print $1 - $2}')

  echo "Total Packet Loss:" $MAX >> $ANALYSIS_FILE
  echo "" >> $ANALYSIS_FILE

  if [ $3 == "True" ]; then
    mkdir -p /home/centos/$2/$1
    mv /var/opt/observer/logs/* /home/centos/$2/$1
    tar cvf $2.tar /home/centos/$2
  fi
fi


