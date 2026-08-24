#!/bin/bash

if [[ "$(lsmod | grep -i wq_wlan)" ]]; then
  echo "wq_wlan module is already loaded. Unloading it first."
  rmmod wq_wlan
fi

if [ -f /lib/modules/$(uname -r)/wq_wlan.ko ]; then
  ko_file=/lib/modules/$(uname -r)/wq_wlan.ko
elif [ -f /lib/modules/$(uname -r)/updates/dkms/wq_wlan.ko ]; then
  ko_file=/lib/modules/$(uname -r)/updates/dkms/wq_wlan.ko
else
  echo "wq_wlan module is not found"
  return 1
fi

echo "Loading ${ko_file} module..."

insmod ${ko_file} \
  fw_dtop_sdio=wq9201_fw_dtop_1_1_mp_sdio.bin \
  fw_bt=wq9201_fw_bt_1_1_mp.bin \
  fw_wifi_sdio=wq9201_fw_wifi_1_1_dtest.bin \
  oem_name=wq9201_oem_1_1_0366.bin \
  wifi_phy_name=wq9201_phy_1_1_4366_0102.bin \
  loadfw_only=1 fw_sys=5 force_reset=1
