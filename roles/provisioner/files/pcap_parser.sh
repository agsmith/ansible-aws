#!/bin/bash
ANALYSIS_FILE=/home/centos/$2-time-analysis.txt
SUMMARY_FILE=/home/centos/summary-time-analysis.txt
LOG_LOCATION=/var/opt/observer/logs/log
RIPPED_LOG_LOCATION=/home/centos/ripped_log
STREAM_STARTED='Starting processing of stream'
STREAM_FINISHED='Finished processing of stream'
SO_VERSION='Application Lifecycle / Started / Application started'
MIN=100000
MAX=0.0

function calculate_runtime {
  AMILLIS=$(date -u -d $1 +"%3N")
  AEPOCH=$(date -u -d $1 +"%s")
  BMILLIS=$(date -u -d $2 +"%3N")
  BEPOCH=$(date -u -d $2 +"%s")
  #if BMILLIS > AMILLIS then add 1 to BEPOCH and set DIFFMILLIS = BMILLIS-AMILLIS
  #else set DIFFMILLIS = AMILLIS-BMILLIS
  if [ "$BMILLIS" -gt "$AMILLIS" ]; then
    ((BEPOCH+=1))
    DIFFMILLIS=`expr $BMILLIS - $AMILLIS`
  else
    DIFFMILLIS=`expr $AMILLIS - $BMILLIS`
  fi
  if [ "$AEPOCH" -gt "$BEPOCH" ]; then
    ((BEPOCH+=86400))
  fi
  EPOCH_DIFF=`expr $BEPOCH - $AEPOCH`
  RUNTIME=$EPOCH_DIFF.$DIFFMILLIS
}

if [ "$1" == "summarize" ]; then
  #get a list of /home/centos/*-time-analysis.txt files
  FILES=$(ls -tr *-time-analysis.txt)
  NT_FILES=$(ls -tr *-nt-time-analysis.txt)
  FILE_FOUND=0
  FILE=$(ls -tr *-time-analysis.txt| head -1)
  VERSION=$(cat $FILE | grep "Stream Observer Version")
  echo $VERSION > $SUMMARY_FILE
  echo "runs_per_instance:" $2 >> $SUMMARY_FILE
  echo "instance_type:" $3 >> $SUMMARY_FILE
  echo " " >> $SUMMARY_FILE

  #For each txt file,
  #  get filename or stream name
  #  grep for "Summary Mean Runtime"
  #  output "<stream name>: Mean Runtime: %d" >> summary-time-analysis.txt

  if [ "$NT_FILES" == "$FILES" ]; then
    echo -e "PROFILE-TYPE\tNT"| expand -t 11 >> $SUMMARY_FILE
    echo -e "------------------------------------------------------------------">> $SUMMARY_FILE
    for g in $NT_FILES; do
      gline=$(cat $g | grep "Summary Mean Runtime:"|awk '{print $4}')
      t=$(echo "$g" | rev | cut -c 19- | rev)
      echo -e $t:"\t" $gline| expand -t 11 >> $SUMMARY_FILE
    done
  elif [ "$NT_FILES" == "" ]; then
    echo -e "PROFILE-TYPE\tT"| expand -t 11 >> $SUMMARY_FILE
    echo -e "------------------------------------------------------------------">> $SUMMARY_FILE
    for g in $FILES; do
      gline=$(cat $g | grep "Summary Mean Runtime:"|awk '{print $4}')
      t=$(echo "$g" | rev | cut -c 19- | rev)
      echo -e $t:"\t" $gline| expand -t 11 >> $SUMMARY_FILE
    done
  else
    echo -e "PROFILE-TYPE\tT\tNT"| expand -t 11 >> $SUMMARY_FILE
    echo -e "------------------------------------------------------------------">> $SUMMARY_FILE
    for f in $FILES
    do
      if [[ $f != *"-nt-"* ]]; then
        stem=${f%%"-time-analysis.txt"}
        for g in $NT_FILES; do
          if [ "$g" == $stem"-nt-time-analysis.txt" ]; then
            FILE_FOUND=1
            fline=$(cat $f | grep "Summary Mean Runtime:"|awk '{print $4}')
            gline=$(cat $g | grep "Summary Mean Runtime:"|awk '{print $4}')
            t=$(echo "$f" | rev | cut -c 19- | rev)
            echo -e $t:"\t" $fline"\t" $gline| expand -t 11 >> $SUMMARY_FILE
          fi
        done
        if [ $FILE_FOUND == "0" ]; then
            fline=$(cat $f | grep "Summary Mean Runtime:"|awk '{print $4}')
            t=$(echo "$f" | rev | cut -c 19- | rev)
            echo -e $t:"\t" $fline| expand -t 11 >> $SUMMARY_FILE
        fi
        FILE_FOUND=0
      fi
    done
    for g in $NT_FILES; do
      stem=${g%%"-nt-time-analysis.txt"}
      for f in $FILES; do
        if [ "$f" == $stem"-time-analysis.txt" ]; then
          FILE_FOUND=1
        fi
      done
      if [ $FILE_FOUND == "0" ]; then
        gline=$(cat $g | grep "Summary Mean Runtime:"|awk '{print $4}')
        t=$(echo "$g" | rev | cut -c 19- | rev)
        echo -e $t:"\t\t" $gline| expand -t 11 >> $SUMMARY_FILE
      fi
      FILE_FOUND=0
    done
  fi

elif [ "$1" == "rollup" ]; then

  AVGS_STRING=$(cat $ANALYSIS_FILE | grep "Stream Mean Runtime:" | awk '{print $4"||"}')
  MINS_STRING=$(cat $ANALYSIS_FILE | grep "Stream Min Runtime:" | awk '{print $4"||"}')
  MAXS_STRING=$(cat $ANALYSIS_FILE | grep "Stream Max Runtime:" | awk '{print $4"||"}')

  IFS='||' AVGS=($AVGS_STRING)
  IFS='||' MINS=($MINS_STRING)
  IFS='||' MAXS=($MAXS_STRING)

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
  echo "Summary Mean Runtime:" $AVGS_AVG >> $ANALYSIS_FILE
  echo "Summary Min Runtime: " $MIN >> $ANALYSIS_FILE
  echo "Summary Max Runtime: " $MAX >> $ANALYSIS_FILE

else

  #rip all stream start and finish lines into a single flat file
  for ((i = 10 ; i > 0 ; i-- )); do
    LL=$(echo $LOG_LOCATION.$i.txt)
    if [ -f "$LL" ]; then
      cat $LL | grep "$SO_VERSION" >> $RIPPED_LOG_LOCATION
      cat $LL | grep "$STREAM_STARTED" >> $RIPPED_LOG_LOCATION
      cat $LL | grep "$STREAM_FINISHED" >> $RIPPED_LOG_LOCATION
    fi
  done

  cat $LOG_LOCATION.txt | grep "$SO_VERSION" >> $RIPPED_LOG_LOCATION
  cat $LOG_LOCATION.txt | grep "$STREAM_STARTED" >> $RIPPED_LOG_LOCATION
  cat $LOG_LOCATION.txt | grep "$STREAM_FINISHED" >> $RIPPED_LOG_LOCATION

  #accomodate grepping on stream names 1 & 10 by making them 1| & 10|
  sed 's/$/|/g' $RIPPED_LOG_LOCATION >> ./.tmp
  mv ./.tmp $RIPPED_LOG_LOCATION

  cp $RIPPED_LOG_LOCATION ripped_log.bak
  #Read in all Stream Names from ripped log file
  STREAM_STRING=$(cat $RIPPED_LOG_LOCATION | grep "$STREAM_FINISHED" |awk '{$1=$2=$3=$4=$5=$6=$7=$8=$9=$10=$11=""; print $0"@@"}' |sed -e 's/^[ \t]*//'|sed -e 's/^[ \n]*//'|tr -d '\n')
  VERSION_STRING=$(cat $RIPPED_LOG_LOCATION | grep "$SO_VERSION" |awk '{$1=$2=$3=$4=$5=$6=$7=$8=$9=$10=$11=$12=$13=$14=$15=$16=""; print $0}' |sed -e 's/^[ \t]*//'|sed -e 's/^[ \n]*//'|tr -d '(' | tr -d '|' |tr -d ')')

  #Convert strings into an array
  IFS='@@' STREAM_NAMES=($STREAM_STRING)
  RUNTIMES_TOTAL=0.0

  if [ ! -f $ANALYSIS_FILE ]; then
    echo "Stream Observer Version:" $VERSION_STRING > $ANALYSIS_FILE

  fi

  echo "Run" $1 >> $ANALYSIS_FILE
  NUM_STREAMS=${#STREAM_NAMES[@]}
  for ((i = 0 ; i < $NUM_STREAMS ; i+=2 )); do
    STREAM_NAME=$(echo ${STREAM_NAMES[i]} | tr -d '\n')
    START_STRING=$(cat $RIPPED_LOG_LOCATION | grep "$STREAM_STARTED" |grep "$STREAM_NAME" |awk '{print $2}'|sed -e 's/^[ \t]*//'|sed -e 's/^[ \n]*//'|tr '\n' ' ')
    END_STRING=$(cat $RIPPED_LOG_LOCATION | grep "$STREAM_FINISHED"|grep "$STREAM_NAME" |awk '{print $2}'|sed -e 's/^[ \t]*//'|sed -e 's/^[ \n]*//'|tr '\n' ' ')

    calculate_runtime $START_STRING $END_STRING

    THIS_RUN=$(echo $RUNTIME | tr -d '\n')
    MAX=$(echo $THIS_RUN $MAX | awk '{if ($1>$2) print $1;else print $2}')
    MIN=$(echo $THIS_RUN $MIN | awk '{if ($1<$2) print $1;else print $2}')

    RUNTIMES_TOTAL=$(echo $RUNTIMES_TOTAL $THIS_RUN | awk '{print $1 + $2}')
    echo " " ${STREAM_NAMES[$i]}": "$RUNTIME | tr -d '\n' >> $ANALYSIS_FILE
    echo "" >> $ANALYSIS_FILE
  done
  AVG=$(echo $RUNTIMES_TOTAL $NUM_STREAMS | awk '{print $1 / ($2/2)}')
  echo "  Stream Mean Runtime:" $AVG >> $ANALYSIS_FILE
  echo "  Stream Min Runtime: " $MIN >> $ANALYSIS_FILE
  echo "  Stream Max Runtime: " $MAX >> $ANALYSIS_FILE
  echo "" >> $ANALYSIS_FILE
  if [ $3 == "True" ]; then
    mkdir -p /home/centos/$2/$1
    mv /var/opt/observer/logs/* /home/centos/$2/$1
    tar cvf $2.tar /home/centos/$2
  fi
fi
