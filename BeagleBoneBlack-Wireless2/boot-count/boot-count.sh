#!/bin/bash
F=/var/lib/boot-count
n=$(cat $F 2>/dev/null || echo 0)
n=$((n+1))
echo $n > $F
echo "$(date +%s) boot#$n" >> /var/lib/boot-log   # 带时间戳，能看出哪次断了
sync                                             # 关键：循环断电测试必须落盘
logger -t boot-count "boot #$n"
