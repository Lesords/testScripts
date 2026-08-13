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

# 禁用冲突驱动（否则 wlan 驱动无法加载）
echo "blacklist btsdio" > /etc/modprobe.d/blacklist-aic8800.conf

# 替换蓝牙启动协议（否则 hci 节点数据有误）
sed -i "s/any/3wire/" /usr/bin/aic-bluetooth
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
