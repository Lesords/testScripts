# RK3588-Module-DevKit (reComputer Industrial RK3588)

> 板卡:RK3588J SoM + 工业 EVT 载板。
> 固件:armbian vendor 内核 6.1.172,板型 `Recomputer-rk3588-industrial`(GNOME 桌面)。

## 目录

- [EMMC 刷入步骤](#emmc-刷入步骤)
- [SSH 服务](SSH-服务)
- [设备状态](#设备状态)
- [双网口测试](#双网口测试)
- [音频测试 (ES8311)](#音频测试-es8311)
- [风扇](#风扇)
- [蜂鸣器](#蜂鸣器)
- [LED 灯](#led-灯)
- [GPIO 扩展 PCA9535](#gpio-扩展-pca9535)
- [eeprom](#eeprom)
- [双 RTC 测试](#双-rtc-测试)
- [USB 测试](#usb-测试)
- [M.2 NVMe 测试 (PCIe3x4)](#m2-nvme-测试-pcie3x4)
- [M.2 / mini-PCIe 其它插槽](#m2--mini-pcie-其它插槽)
- [WiFi 测试 (M.2 E-key)](#wifi-测试-m2-e-key)
- [蓝牙测试 (M.2 E-key)](#蓝牙测试-m2-e-key)
- [LoRa 测试 (WM1302, mini-PCIe)](#lora-测试-wm1302-mini-pcie)
- [HDMI / DP 显示](#hdmi--dp-显示)
- [GPU 测试 (Mali G610)](#gpu-测试-mali-g610)
- [NPU 测试](#npu-测试)
- [eMMC 健康状态](#emmc-健康状态)
- [压力测试](#压力测试)
- [通讯口](#通讯口)
    - [DI](#di)
    - [DO](#do)
    - [RS485 / RS232 测试 (CH344L)](#rs485--rs232-测试-ch344l)

## EMMC 刷入步骤

```bash
# linux
upgrade_tool db rk3588_spl_loader_v1.16.113.bin
upgrade_tool wl 0 Armbian-unofficial_26.11.0-trunk_Recomputer-rk3588-industrial_resolute_vendor_6.1.172_gnome_desktop.img
upgrade_tool rd
```

## SSH 服务

默认 SSH 在第二次启动后关闭，所以需要手动打开，步骤如下：

```bash
# 通过串口进入设备，然后执行以下命令开启 SSH 服务
sudo systemctl enable ssh && systemctl start ssh
```

## 设备状态

```bash
# 电源域状态
cat /sys/kernel/debug/pm_genpd/pm_genpd_summary

# SoC 温度(风扇温控基于 soc_thermal,38°C 起步调速;zone 编号动态,先看 type)
cat /sys/class/thermal/thermal_zone*/type
cat /sys/class/thermal/thermal_zone*/temp

# CPU 频率
cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq

# CPU 节点
cd /sys/devices/system/cpu
```

## 双网口测试

| 接口 | 对应 | 硬件 | 驱动 |
| ---- | ---- | ---- | ---- |
| end0 | RJ45#2 | RTL8111H(载板,PCIe2.0) | **r8168** |
| end1 | RJ45#1(带 PoE) | MAE0621A PHY(SoM 焊死,RGMII→GMAC0) | **st_gmac** |

```bash
# 驱动归属确认(实测:end0=r8168 / end1=st_gmac)
ethtool -i end0 | grep driver
ethtool -i end1 | grep driver
lspci | grep -i net
# RTL8111

# 链路与连通(end1 已实测 1000Mb/s + DHCP)
ip link set end0 up
ethtool end0 | grep -E 'Speed|Link detected'
ethtool end1 | grep -E 'Speed|Link detected'
```

## 音频测试 (ES8311)

```bash
# 声卡确认
cat /proc/asound/cards

# 找 es8311 卡号(N 以实测为准)
aplay -l | grep -i es8311

# 安装工具
sudo apt install mpg123
# 播放(耳机口)
mpg123 -a hw:N,0 ./test.mp3
# 或
aplay -D plughw:N,0 ./test.wav
# 例子
mpg123 -a hw:2,0 ./test.mp3

# 录音回环(耳机麦克风采→耳机放)
arecord -D hw:N,0 -f cd | aplay -D hw:N,0 -f cd
# 例子
arecord -D hw:2,0 -f cd | aplay -D hw:2,0 -f cd

# 耳机插拔检测
cat /sys/kernel/debug/gpio | grep -i hp_DET
```

音频配置（没有声音时）
```bash
amixer -c 2 cset name='Headphone'         1   > /dev/null 2>&1
amixer -c 2 cset name='hp switch'         1   > /dev/null 2>&1
amixer -c 2 cset name='DAC SDP MUTE'      0   > /dev/null 2>&1
amixer -c 2 cset name='DAC DSM MUTE'      0   > /dev/null 2>&1
amixer -c 2 cset name='DAC DEM MUTE'      0   > /dev/null 2>&1
amixer -c 2 cset name='DAC INVERT'        0   > /dev/null 2>&1
amixer -c 2 cset name='DAC RAM CLR'       0   > /dev/null 2>&1
amixer -c 2 cset name='DAC RAMP RATE'     0   > /dev/null 2>&1
amixer -c 2 cset name='DAC VOLUME'        120 > /dev/null 2>&1
amixer -c 2 cset name='DAC OFFSET'        0   > /dev/null 2>&1
amixer -c 2 cset name='DAC SDP SRC MUX'   0   > /dev/null 2>&1

# 存住,下次开机免跑
alsactl store
```

## 风扇

温控 38-80°C 八档自动调速

```bash
# 按名字定位 hwmon(编号动态分配)
H=$(for d in /sys/class/hwmon/hwmon*; do [ "$(cat $d/name 2>/dev/null)" = pwmfan ] && echo $d && break; done)

# 读转速(RPM)
cat $H/fan1_input

# 手动控制(占空比 0~255;改回请设非零值,勿 unbind)
## 全速
echo 255 > $H/pwm1
## 低速
echo 100 > $H/pwm1
```

### 手动控制(fan-manual overlay)

```bash
# 部署 overlay
scp fan-manual/output/fan-manual.dtbo \
    root@<IP_ADDRESS>:/boot/dtb/rockchip/overlay/rk3588-fan-manual.dtbo

# 启用(overlays= 行存在则追加,不存在则新建)并重启
ssh root@<IP_ADDRESS> "grep -q '^overlays=' /boot/armbianEnv.txt \
    && sed -i 's/^overlays=\(.*\)/overlays=\1 rk3588-fan-manual/' /boot/armbianEnv.txt \
    || echo 'overlays=rk3588-fan-manual' >> /boot/armbianEnv.txt; reboot"

# 重启后手动控制(按名字定位 hwmon)
H=$(for d in /sys/class/hwmon/hwmon*; do [ "$(cat $d/name 2>/dev/null)" = pwmfan ] && echo $d && break; done)

# 占空比 0~255,立即生效,不会被温控抢回
echo 200 > $H/pwm1

# 转速 RPM
cat $H/fan1_input

# 回滚:overlays= 行删掉 fan-manual 重启,恢复自动温控
```

## 蜂鸣器

BUZZER = GPIO3_D0(gpiochip3 line 24,纯 GPIO 无硬件 PWM)。

```bash
# libgpiod v2(gpioset --version 区分:1.6.x=v1,2.x=v2)
# 打开
gpioset -c gpiochip3 24=1
# 关闭
gpioset -c gpiochip3 24=0
```

## LED 灯

```bash
# 节点确认(ACT 在跳 = 心跳活着)
ls /sys/class/leds/

# 手动控制 RGB 灯
## 点亮
echo 255 > /sys/class/leds/led-user-r/brightness
echo 255 > /sys/class/leds/led-user-g/brightness
echo 255 > /sys/class/leds/led-user-b/brightness

echo 0   > /sys/class/leds/led-user-r/brightness
echo 0   > /sys/class/leds/led-user-g/brightness
echo 0   > /sys/class/leds/led-user-b/brightness

# 手动控制 ACT 灯
echo none        > /sys/class/leds/led-act/trigger
echo 255         > /sys/class/leds/led-act/brightness
# 改回心跳
echo heartbeat   > /sys/class/leds/led-act/trigger
```

## GPIO 扩展 PCA9535

I2C0 @0x21,16 路,INT = GPIO1_D5(I2C0_INT)。全部线名(= 功能):

| 线 | 名称 | 功能 | 线 | 名称 | 功能 |
| ---- | ---- | ---- | ---- | ---- | ---- |
| P00 | USER_LED_R | 红 LED | P10 | CH344L_RST | CH344L 复位 |
| P01 | USER_LED_G | 绿 LED | P11 | USB_HUB_Reset | USB hub 复位 |
| P02 | USER_LED_B | 蓝 LED | P12 | 5V_ISO_OUT_EN | RS485 隔离电源 |
| P03 | VCC3V3_SD_EN | SD 卡电源 | P13 | HP_CTL_H | 耳机功放控制 |
| P04 | 5V_ISO_OUT_CAN_EN | CAN 隔离电源 | P14 | (NC) | 测试点 |
| P05 | CAN_120R_EN | CAN 端接 | P15 | (NC) | 测试点 |
| P06 | RS485_1_120R_EN | RS485_1 端接 | P16 | 4G Module_Select | |
| P07 | RS485_2_120R_EN | RS485_2 端接 | P17 | ACT_LED | 指示 LED |

```bash
# 确认芯片型号
cat /sys/bus/i2c/devices/4-0021/name

# 确认注册与线名
gpiodetect | grep 4-0021

# 查看引脚信息
gpioinfo -c gpiochip6

# 根据名字来查看引脚信息
gpioinfo HP_CTL_H

# 读写
## 读 P12
gpioget -c <pca9535的gpiochip> 12
## 写 P12
gpioset -c <pca9535的gpiochip> 12=1
```

## eeprom

```bash
# 查看 eeprom 节点
ls /sys/bus/i2c/devices/ | grep 0050

# 读 eeprom 内容
cat /sys/bus/i2c/devices/6-0050/eeprom | hexdump -C

# 写保护引脚(GPIO0_C6_u)
## 拉低解锁
gpioset -c gpiochip0 22=0
## 拉低锁定
gpioset -c gpiochip0 22=1

# 写入测试(写入后再读,应看到内容变化)
echo -n "rk35xx01B0" > /sys/bus/i2c/devices/6-0050/eeprom

# 清空
printf '\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff' | \
  dd of=/sys/bus/i2c/devices/6-0050/eeprom
```

## 双 RTC 测试

```bash
# 最简读法(无需安装包)
for r in rtc0 rtc1; do echo -n "$r: "; cat /sys/class/rtc/$r/date; cat /sys/class/rtc/$r/time; done

# 安装依赖
sudo apt install util-linux-extra

# 分辨两片 rtc(看设备挂的 i2c 总线)
for r in /sys/class/rtc/rtc?; do echo "$r $(cat $r/name) $(readlink -f $r/device)"; done

# 读两片时间(默认 hwclock 只动 rtc0,注意用 --rtc 指定)
sudo hwclock -r --rtc /dev/rtc0
sudo hwclock -r --rtc /dev/rtc1

# 写入测试
sudo hwclock --set --date "2026-10-13 12:00:00" --rtc /dev/rtc1
sudo hwclock -r --rtc /dev/rtc1
```

## USB 测试

```bash
lsusb
# 期望 0424 开头的 Microchip hub(USB5744;具体 PID 以实测为准)

# 4 个 Type-A 逐一插 U 盘
lsblk
# 出现 sda
```

## M.2 NVMe 测试 (PCIe3x4)

```bash
lspci | grep -i nvme
# 期望出现 NVMe 控制器
sudo lspci -vvv | grep -i 'lnksta'
# 期望 Speed 8GT/s, Width x4(PCIe3.0 x4,每 lane 8GT/s)

sudo apt install nvme-cli
sudo nvme list
sudo nvme smart-log /dev/nvme0

# 读写快测
dd if=/dev/nvme0n1 of=/tmp/t bs=1M count=512 oflag=direct
dd if=/tmp/t of=/dev/null bs=1M count=512 iflag=direct
```

## M.2 / mini-PCIe 其它插槽

| 插槽 | 总线 | 说明 |
| ---- | ---- | ---- |
| M.2 KEY-M (PCIE20) | pcie2x1l1 | PCIe2.0 x1(sheet 18);PERST 与 RTL8111H 共用一根线。**已插 476.9G SSD 实测枚举成功(2026-10-20)** |
| M.2 KEY-E (WIFI_BT) | pcie2x1l0 + USB2 + UART7 | **RTL8822CE 实测通过**;BT 固定 ttyS7;板载 WIFI_DISABLE(GPIO3_A2)/BT_DISABLE(GPIO1_C4) |
| mini-PCIe | SPI0_M3 | **spidev 已配置(`/dev/spidev0.0`)**;WM1302(SX1302)测试中,见 LoRa 章节 |

## WiFi 测试 (M.2 E-key)

模块型号：`RTL8822CE`
引脚信息：`GPIO1_C4 = BT_DISABLE_N`

```bash
# 1. 确认设备与驱动绑定(lspci 看到 RTL8822CE,dmesg 有 rtw_8822ce)
lspci | grep -i network
dmesg | grep rtw_8822ce | tail -3

# 2. 网络接口(注意:叫 wlP2p33s0,不是 wlan0 —— systemd 预测命名)
ip -br link | grep wl

# 3. 扫描(能看到 AP 列表 = 射频链路+固件全通)
nmcli device wifi list

# 4. 连接
## 连接开放网络
nmcli device wifi connect "SEEED-Guest"
## 连接加密网络
nmcli device wifi connect "SEEED-OFFICE" password "xxxx"
## 查看连接状态
nmcli device status

# 5. 速率/信号确认(连上后)
iw dev wlP2p33s0 link
```

## 蓝牙测试 (M.2 E-key)

```bash
# 查看 HCI 设备状态
hciconfig -a

# 扫描附近的蓝牙设备
bluetoothctl --timeout 15 -- scan on

# 连接蓝牙设备（以设备 MAC 地址为例）
bluetoothctl -- connect <MAC>
bluetoothctl -- connect D0:67:94:74:3F:CD

# 断开连接
bluetoothctl -- disconnect <MAC>
bluetoothctl -- disconnect D0:67:94:74:3F:CD

# 已配对设备列表
bluetoothctl devices

# 已连接设备的详细信息
bluetoothctl info
bluetoothctl info <MAC>
bluetoothctl info D0:67:94:74:3F:CD
```

## LoRa 测试 (WM1302, mini-PCIe)

```bash
# 克隆仓库
git clone https://github.com/Lesords/sx1302_hal.git -b feat/recomputer-industrial-rk3588 --depth=3

# 编译
cd sx1302_hal
make

# 运行
cd packet_forwarder/
sudo ./lora_pkt_fwd -c global_conf.json.sx1250.US915
```

## HDMI / DP 显示

```bash
# 连接状态(插拔屏看对应输出变 connected)
cat /sys/class/drm/card*-HDMI-A-1/status
cat /sys/class/drm/card*-DP-1/status
```

## GPU 测试 (Mali G610)

RK3588 为 Mali-G610(panthor/CSF 体系,vendor 内核走 Arm BSP + libmali g610):

```bash
sudo apt install -y glmark2-es2-drm glmark2-es2

# 桌面占用 DRM master 时先停桌面
systemctl stop gdm
timeout 60 glmark2-es2-drm
systemctl start gdm

# GNOME/Wayland 下跑
env WAYLAND_DISPLAY=wayland-0 XDG_RUNTIME_DIR=/run/user/1000 \
   timeout 20 glmark2-es2-wayland --off-screen >/dev/null 2>&1
# Or
WAYLAND_DISPLAY=wayland-0 XDG_RUNTIME_DIR=/run/user/1000 glmark2-es2-wayland --off-screen

# 查看 GPU 负载
cat /sys/class/devfreq/fb000000.gpu-panthor/load
# Or
cat /sys/class/devfreq/fb000000.gpu-*/load

# 查看 GPU 电源状态(只有运行中才会开电)
cat /sys/kernel/debug/pm_genpd/pm_genpd_summary | grep -i gpu
```

## NPU 测试

测试文件
```bash
rknn_benchmark_Linux.tar.gz
```

拷贝文件到 RK3588 开发板
```bash
scp rknn_benchmark_Linux.tar.gz root@<IP_ADDRESS>:/root
```

解压后进入目录
```bash
tar -zxvf rknn_benchmark_Linux.tar.gz

cd rknn_benchmark_Linux

# 执行（高负载）
./start.sh

# 单核测试(较低负载)
./open_npu.sh
```

查看 NPU 负载
```bash
cat /sys/kernel/debug/rknpu/load
```

## eMMC 健康状态

```bash
# 查看健康状态
cat /sys/block/mmcblk*/device/life_time
# 实测 0x01 0x01(Normal)

# 或 mmc-utils 详细版
sudo apt install mmc-utils
sudo mmc extcsd read /dev/mmcblk0 | grep -E 'Pre EOL|Life Time'
# 期望:Pre EOL 0x01(Normal),Life Time 0x01 0x01
```

## 压力测试

```bash
sudo apt install stress-ng
# 4×A76 + 4×A55 共 8 核 + 内存压力,30 分钟
stress-ng --cpu 8 --vm 4 --vm-bytes 256M --timeout 30m --metrics-brief
# 期间另开终端看热节流与风扇响应
cat /sys/class/thermal/thermal_zone*/temp
```

## 通讯口

### DI

引脚信息
```bash
DI_1 - GPIO1_B6_u - 14 -> 46
DI_2 - GPIO1_B7_u - 15 -> 47
```

控制方法
```bash
# DI_1
cd /sys/class/gpio
echo 46 > ./export
echo in > ./gpio46/direction
cat ./gpio46/value

# DI_2
cd /sys/class/gpio
echo 47 > ./export
echo in > ./gpio47/direction
cat ./gpio47/value
```

注：默认为 1，有外部供电时为 0

### DO

引脚信息
```bash
DO_1 - GPIO1_D6_u - 30 -> 62
DO_2 - GPIO1_D7_u - 31 -> 63
```

控制方法
```bash
# DO_1
cd /sys/class/gpio
echo 62 > ./export
echo out > ./gpio62/direction
echo 1 > ./gpio62/value

# DO_2
cd /sys/class/gpio
echo 63 > ./export
echo out > ./gpio63/direction
echo 1 > ./gpio63/value
```

注：默认不导通，输出为 1 时导通，无法输出高电平

### RS485 / RS232 测试 (CH344L)

```bash
# 查看 ttyACM 设备
ls /dev/ttyACM*
# 期望 ttyACM0~3(开箱即有)

# 查看设备
lsusb | grep -i QinHeng

# 查看内核日志
dmesg | grep cdc_acm | tail -4
```

查看引脚配置状态
```bash
cat /sys/kernel/debug/gpio | grep -i 485
# 参考输出
 gpio-499 (RS485_1_120R_EN     |sysfs               ) out hi
 gpio-500 (RS485_2_120R_EN     )
cat /sys/kernel/debug/gpio | grep -i 5V_ISO
# 参考输出
 gpio-497 (5V_ISO_OUT_CAN_EN   )
 gpio-503 (5V_ISO_OUT_EN       |sysfs               ) out hi
```

手动配置引脚操作
```bash
# 拉高 5V_ISO_OUT_EN
cd /sys/class/gpio
echo 503 > ./export
echo out > ./gpio503/direction
echo 1 > ./gpio503/value

# 拉高 RS485_1_120R_EN
cd /sys/class/gpio
echo 499 > ./export
echo out > ./gpio499/direction
echo 1 > ./gpio499/value

# 拉高 RS485_2_120R_EN, 参考上诉步骤，把 499 改为 500 即可
```

```bash
# 安装工具
sudo apt install minicom

# RS232
minicom -D /dev/ttyACM0

# RS485-1
minicom -D /dev/ttyACM1

# RS485-2
minicom -D /dev/ttyACM2

# 接收参考命令
stty -F /dev/ttyACM0 115200 raw -echo # 可以无须配置
cat /dev/ttyACM0 &

# 手动发送参考命令
echo "rs232 test" > /dev/ttyACM0
```

注意：
- RS232 和 RS485 都无须配置波特率
- RS232 需要接地，RS485 可以不需要接地
