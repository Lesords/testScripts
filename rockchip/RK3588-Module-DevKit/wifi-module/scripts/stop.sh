#!/bin/bash

WIFI=$(ls /sys/class/net | grep -E '^wl' | head -1)

rtwpriv $WIFI mp_ctx stop

