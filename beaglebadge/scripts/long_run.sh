#!/bin/sh

FILE=long_test.log
CMD="echo test at $(date)"
cnt=1

while true; do
  echo "[$(date '+%F %T')] run #$cnt: running command..."
  result=$(dmesg | grep -i "ready after" | awk '{print $NF}' | awk '{print substr($0, 1, length($0) - 2)}' | tail -1)
  echo "[$(date '+%F %T')] run #$cnt: running command... - result: $result" >> $FILE
  # eval "$CMD"

  cnt=$((cnt + 1))
  # sleep 3600
  sleep 60
done
