# WiFi 模块测试文档

## 驱动 适配

```bash
# 拷贝驱动
scp ./driver/wq_wlan.ko root@10.0.0.154:/lib/modules/6.1.115-vendor-rk35xx

# 进入目标板
depmod -a

# 拷贝固件
scp ./* root@10.0.0.154:/lib/firmware

# 拷贝工具
scp ./tools/ioctl_app root@10.0.0.154:/usr/bin
```

## 定频测试步骤

```bash
# 默认不加载驱动
echo "blacklist wq_wlan" >> /etc/modprobe.d/blacklist.conf

# 卸载驱动
rmmod wq_wlan
insmod /lib/modules/$(uname -r)/wq_wlan.ko \
  fw_dtop_sdio=wq9201_fw_dtop_1_1_mp_sdio.bin \
  fw_bt=wq9201_fw_bt_1_1_mp.bin \
  fw_wifi_sdio=wq9201_fw_wifi_1_1_dtest.bin \
  oem_name=wq9201_oem_1_1_0366.bin \
  wifi_phy_name=wq9201_phy_1_1_4366_0102.bin \
  loadfw_only=1 fw_sys=5 force_reset=1

# 进入定频模式
## dtop 切产测
ioctl_app dtop "08 00 00 00 2e 00 00 01"
## WiFi 自校准(上电后仅一次)
ioctl_app wifi "dstart 15 1 0"
## 进 verify 模式
ioctl_app wifi "mp_mode_en 0"
```
