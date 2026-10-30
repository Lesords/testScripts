#!/bin/bash

systemctl stop NetworkManager
modprobe -r 88x2ce 2>/dev/null
modprobe -r rtw88_8822ce 2>/dev/null
modprobe 88x2ce
sleep 3

WIFI=$(ls /sys/class/net | grep -E '^wl' | head -1)
[ -n "$WIFI" ] || echo "未发现无线网卡! 查: dmesg | grep -i 88x2ce | tail -5"
ifconfig $WIFI up
rtwpriv $WIFI mp_start
