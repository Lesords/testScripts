# WiFi 模块测试文档

## 固件信息

```bash
# v2.2.1.961
## h4 协议的蓝牙固件
a3e91b3bd74daffb133f5a522391476b  ./wq9201_oem_1_1_0366.bin

## h5 协议的蓝牙固件
b24c25e96e30b1ade844b9393de77543  ./wq9201_oem_1_1_0366.bin

# v2.2.3.94
## h4 协议的蓝牙固件
c12fccf6c377e73801b02b4329d681c0  ./wq9201_oem_1_1_0366.bin

## h5 协议的蓝牙固件
c1cd675e5eb46025eef89862fa8b0f1d  ./wq9201_oem_1_1_0366.bin
```

## 驱动适配

```bash
# 拷贝驱动
scp ./driver/wq_wlan.ko root@10.0.0.154:/lib/modules/6.1.115-vendor-rk35xx

# 进入目标板
depmod -a

# 拷贝固件
scp ./firmwares/wq9201_* root@10.0.0.154:/lib/firmware

# 拷贝配置文件
scp ./configs/wq_wlan_settings.ini root@10.0.0.154:/lib/firmware

# 禁用冲突驱动（否则 wlan 驱动无法加载）
echo "blacklist btsdio" > /etc/modprobe.d/blacklist-aic8800.conf

# 禁用无用驱动（否则可能会导致蓝牙不稳定）
cat > /etc/modprobe.d/aic8800-wireless.conf <<'EOF'
blacklist aic8800_bsp
blacklist aic8800_fdrv
blacklist aic8800_btlpm
blacklist aic8800_bsp_sdio
EOF

# 替换蓝牙启动协议（否则 hci 节点数据有误）
## h5 版本的替换方法（只支持扫描，不支持连接！！！）
sed -i "s/any/3wire/" /usr/bin/aic-bluetooth
## h4 版本的替换方法（新版本，支持连接）
sed -i 's|hciattach[^>]*|btattach -B /dev/ttyS4 -N -P h4 -S 1500000 |g' /usr/bin/aic-bluetooth

## h4 版本手动执行的方法
btattach -B /dev/ttyS4 -N -P h4 -S 1500000 &
```

## 定频测试步骤

环境依赖
```bash
# 拷贝定频固件
scp ./firmwares/定频/wq9201_* root@10.0.0.154:/lib/firmware

# 拷贝工具
scp ./tools/ioctl_app root@10.0.0.154:/usr/bin

# 默认不加载驱动（新版驱动支持重新加载，所以可以不需要禁用）
echo "blacklist wq_wlan" >> /etc/modprobe.d/blacklist.conf

# 拷贝脚本
scp ./scripts/* root@10.0.0.247:/root
```

测试命令

```bash
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

注：切换定频参数的指令可以参考 `WQ-command.txt`

## 定频参数介绍

RX sensitivity

```bash
# ANT1
## 清除RX收包数量
ioctl_app wifi "rxratecnt 0 r"

ioctl_app wifi "set_ch 7 0 0 0"
# 第一位表示设置主20MHz信道
#   20MHz是设置实际中心频率信道号
#   40MHz是设置实际中心频率信道号减2
#   80MHz是设置实际中心频率信道号减6
# 第二位表示信道带宽: 0=20M/1=40M/2=80M

# 设置RX使用天线；1代表天线1；2代表天线2
ioctl_app wifi "rx_ant_cfg 1"

# 仪器发对应速率一定数量的包后，通过下面这个命令获取返回信息
ioctl_app wifi "rxratecnt 0 5 11"
# 第一位表示模式: 0=b/g/a; 2=n; 4=ac; 5=ax
# 第二位表示速率: b/g/a/直接写，如1/2/5.5/11/6/9/ 12/18/24/36/48/54; n=0-7; ac=0-9; ax=0-11

# ANT2
ioctl_app wifi "rxratecnt 0 r"
ioctl_app wifi "set_ch 7 0 0 0"

ioctl_app wifi "rx_ant_cfg 2"
ioctl_app wifi "rxratecnt 0 5 11"
```

TX 相关命令解释

```bash
# 每次下载完固件，需先将RF端口接上仪器，再执行此命令进行内部RF自校准
dstart 15 1 0

set_ch 36 0 0 0
# 第一位表示设置主20MHz信道；20MHz是设置实际中心频率信道号；40MHz是设置实际中心频率信道号减2；80MHz是设置实际中心频率信道号减6
# 第二位表示信道带宽: 0=20M/1=40M/2=80M

force_cca 0 1
force_cca 1 1

set_power 0 19
# 这一位表示设定目标功率：19dBm
set_rate 0 6 20 0 0 0 1
# 第一位表示模式:0=b/g/a；2=n；4=ac；5=ax
# 第二位表示速率：b/g/a/直接写，如
# 1 2 5.5 11 6 9 12 18 24 36 48 54；n=0-7；ac=0-9；ax=0-11
# 第三位表示带宽：20/40/80

tx_ant_cfg 0 1 0
# 这一位表示天线，1表示path 1，2表示path 2

ampdu_prot 0
tx_mpdu 0 1000 0x1 3 2 0 0 50 16 2
# 80M包长设1500；20/40M包长设1000
# 11b后两位设1 1;其它都设16 2

cancel
# 停止发包，需要更改ch、power、rate、ant等发包参数时需先停止发包
```

## FAQ

### 驱动加载失败问题

问题描述

```bash
ERROR: count not insert module /lib/modules/6.1.115-vendor-rk35xx/wq_wlan.ko: Invalid parameters
```

解决方法

```bash
cd /lib/modules/6.1.115-vendor-rk35xx/
objcopy --remove-section=.BTF wq_wlan.ko
```
