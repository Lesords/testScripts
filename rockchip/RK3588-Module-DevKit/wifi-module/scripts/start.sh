#!/bin/bash

WIFI=$(ls /sys/class/net | grep -E '^wl' | head -1)

rtwpriv $WIFI mp_txpower patha=0,pathb=100
rtwpriv $WIFI mp_channel 1 
rtwpriv $WIFI mp_bandwidth 40M=0,shortGI=0
rtwpriv $WIFI mp_ant_tx b
rtwpriv $WIFI mp_rate 22
rtwpriv $WIFI mp_ctx count=%100,pkt
