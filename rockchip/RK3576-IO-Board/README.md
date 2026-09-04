# RK3576-IO-Board

## 目录

- [EMMC 刷入步骤](#emmc-刷入步骤)
- [SPI Flash 刷入步骤](#spi-flash-刷入步骤)
- [设备状态](#设备状态)
  - [查看电源状态](#查看电源状态)
- [压力测试步骤](#压力测试步骤)
- [GPU 测试步骤](#gpu-测试步骤)
- [NPU 测试步骤](#npu-测试步骤)
- [DSI 屏幕](#dsi-屏幕)
- [WiFi 测试步骤](#WiFi-测试步骤)
- [蓝牙测试步骤](#蓝牙测试步骤)
- [蓝牙音频测试步骤](#蓝牙音频测试步骤)
- [RTC 设备测试步骤](#rtc-设备测试步骤)
- [音频测试步骤](#音频测试步骤)
- [RK1820 加速卡](#rk1820-加速卡)
- [40pin 引脚功能测试](#40pin-引脚功能测试)
  - [CAN 引脚测试](#CAN-引脚测试)
  - [PWM 引脚测试](#PWM-引脚测试)
  - [I2C 引脚测试](#I2C-引脚测试)
  - [UART 引脚测试](#UART-引脚测试)
  - [SPI 引脚测试](#SPI-引脚测试)
  - [I2S(SAI)引脚测试](#i2ssai引脚测试)

## EMMC 刷入步骤

```bash
# windows
upgrade_tool.exe db rk3576_spl_loader_v1.03.102.bin
upgrade_tool.exe wl 0 Armbian-unofficial_26.05.0-trunk_Recomputer-rk3576-module_noble_vendor_6.1.115_xfce_desktop.img
upgrade_tool.exe rd

# linux
upgrade_tool db rk3576_spl_loader_v1.03.102.bin
upgrade_tool wl 0 Armbian-unofficial_26.05.0-trunk_Recomputer-rk3576-module_noble_vendor_6.1.115_xfce_desktop.img
upgrade_tool rd
```

## SPI Flash 刷入步骤

固件路径
```bash
./spi-flash-boot-file/rkspi_loader.img
```

烧录命令
```bash
# linux
upgrade_tool db rk3576_spl_loader_v1.03.102.bin
upgrade_tool wl 0 rkspi_loader.img
upgrade_tool rd
```

注意：
```bash
# 需要把以下设备树文件放到对应的文件系统中，否则系统启动之后会导致无法识别到 spi flash
./spi-flash-boot-file/rk3576-recomputer-rk3576-module.dtb
```

## 设备状态

### 查看电源状态

```bash
cat /sys/kernel/debug/pm_genpd/pm_genpd_summary
```

## 压力测试步骤

环境安装
```bash
sudo apt update
sudo apt install stress-ng
sudo apt install mpg123
```

压力测试工具
```bash
stress_test.sh
```

使用方法
```bash
./stress_test.sh
```

## GPU 测试步骤

环境安装
```bash
sudo apt-get update

# 安装驱动包（若固件中有，可以忽略）
sudo apt install -y libmali-bifrost-g52-g24p0-x11-wayland-gbm
# 安装测试工具
sudo apt install -y glmark2-es2-drm
sudo apt install -y glmark2-es2
```

测试步骤 - xfce 桌面
```bash
# 1. 先关闭桌面（lightdm 占用 DRM master，不关无法运行 DRM 渲染测试）
systemctl stop lightdm

# 2.1 运行 GPU 测试（跑 60 秒，随机场景）
timeout 60 glmark2-es2-drm

# 2.2 高负载命令
glmark2-es2-drm --run-forever --swap-mode immediate \
    -b terrain:bloom=true:tilt-shift=true

# 2.3 较低负载命令
glmark2-es2-drm -b shading --run-forever

# 3. 恢复桌面
systemctl start lightdm

# 无须显示屏
glmark2-es2-drm --off-screen --run-forever
```

测试步骤 - gnome 桌面
```bash
# 桌面必须活着（off-screen 也需要它做 EGL 初始化）
systemctl is-active gdm
# 期望: active
pgrep -c gnome-shell
# 期望: ≥1

# 加速状态确认（30 秒）
eglinfo -B | grep -A3 "GBM platform"
# 期望: EGL vendor string: ARM + arm_release_ver: g24p0-...
# 异常: llvmpipe / Mesa = 软渲染

# 工具包依赖
glmark2-es2

# 测试命令
WAYLAND_DISPLAY=wayland-0 XDG_RUNTIME_DIR=/run/user/121 glmark2-es2-wayland --off-screen

# 单次高负载命令
WAYLAND_DISPLAY=wayland-0 XDG_RUNTIME_DIR=/run/user/121 glmark2-es2-wayland --off-screen -b terrain

# 长时间高负载命令
WAYLAND_DISPLAY=wayland-0 XDG_RUNTIME_DIR=/run/user/121 glmark2-es2-wayland --off-screen \
  -b terrain:duration=60 -b refract:duration=60 -b shadow:duration=60 \
  -b 'effect2d:kernel=1,1,1,1,1;1,1,1,1,1;1,1,1,1,1;:duration=60'

# 无限循环单个高负载场景
WAYLAND_DISPLAY=wayland-0 XDG_RUNTIME_DIR=/run/user/121 glmark2-es2-wayland --off-screen --run-forever -b terrain:duration=60
```

查看 GPU 负载
```
cat /sys/class/devfreq/27800000.gpu/load
```

## NPU 测试步骤

测试文件
```bash
rknn_benchmark_Linux.tar.gz
```

拷贝文件到 RK3576-IO-Board
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

## DSI 屏幕

DSI 屏幕型号
```bash
树莓派二代 7 英寸触摸屏
```

配置步骤
```bash
# 编辑配置文件
vim /boot/armbianEnv.txt

# 修改 overlay 为以下内容(V2 版本后的新固件)
overlay_prefix=recomputer-rk3576-ioboard
overlays=raspi-7inch-touchscreen
```

注意事项
```bash
需要跳线才能正常使用 DSI 中的 I2C

跳线位置：DSI 座子和 40 PIN 之间, 40 PIN 旁边
跳线方向：DSI 座子 -> 40 PIN, 两个跳线都要
```

## WiFi 测试步骤

自动连接 WiFi

```bash
# 拷贝 configs/90-wifi-wlan0.yaml 到设备中的 /etc/netplan/ 目录下
scp configs/90-wifi-wlan0.yaml root@<IP_ADDRESS>:/etc/net

# 修改配置权限
chmod 600 /etc/netplan/90-wifi-wlan0.yaml

# 然后重启即可生效
```

手动连接 WiFi

```bash
# 方法一
## 获取 WiFi 网络 ID
id=$(wpa_cli -i wlan0 add_network)

## 设置 WiFi SSID 和密码
wpa_cli -i wlan0 set_network $id ssid '"CMW-AP"'
wpa_cli -i wlan0 set_network $id psk '"12345678"'

## 开发网络，无密钥管理
wpa_cli set_network 0 key_mgmt NONE

## 启用并选择网络
wpa_cli -i wlan0 enable_network $id
wpa_cli -i wlan0 select_network $id

# 方法二
nmcli device wifi connect "CMW-AP" password "密码" ifname wlan0
## 开发网络，无密钥管理
nmcli device wifi connect "CMW-AP" wifi-sec.key-mgmt none
```

扫描 WiFi

```bash
# 方法一
## 开启扫描
wpa_cli -i wlan0 scan

## 获取扫描结果
wpa_cli -i wlan0 scan_results | grep -i CMW

## 手动过滤扫描结果

# 方法二
## 主动重新扫描
nmcli device wifi rescan ifname wlan0

## 查看扫描结果
nmcli device wifi list ifname wlan0
```

## 蓝牙测试步骤

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

## 蓝牙音频测试步骤

```bash
# 安装蓝牙音频依赖
apt install pipewire-pulse wireplumber
apt install libspa-0.2-bluetooth

# 禁 PulseAudio(防冲突)
systemctl --user mask pulseaudio.socket pulseaudio.service
killall pulseaudio

# 起 PipeWire 栈
# 如果这三个应用已经在运行,请先杀掉
nohup pipewire >/tmp/pw.log 2>&1 &
sleep 1
nohup wireplumber >/tmp/wp.log 2>&1 &
sleep 1
nohup pipewire-pulse >/tmp/pwp.log 2>&1 &

# 配对(只做一次)
bluetoothctl power on
bluetoothctl pair D0:67:94:74:3F:CD
bluetoothctl trust D0:67:94:74:3F:CD
# 配对过的设备可以直接连接
bluetoothctl connect D0:67:94:74:3F:CD

# 设系统输出到蓝牙耳机
pactl set-default-sink bluez_output.D0_67_94_74_3F_CD.1
# 音量拉满
pactl set-sink-volume bluez_output.D0_67_94_74_3F_CD.1 100%

# 播放音频
pw-play ./test.mp3
paplay ./test.mp3
```

## RTC 设备测试步骤

安装工具

```bash
sudo apt install util-linux-extra
```

测试命令

```bash
# 设置 RTC 时间为 2024-11-24 12:00:00
sudo hwclock --set --date "2024-11-24 12:00:00"

# 查看 RTC 时间
sudo hwclock -r
```

## 音频测试步骤

播放音频

```bash
# 安装音频测试工具
sudo apt update
sudo apt install mpg123

# 播放音频文件（以 test.mp3 为例）
mpg123 -a hw:0,0 ./test.mp3
# 或者
aplay -D plughw:0,0 ./Canon.wav

# 如果有音频异常的话，可以使用脚本来修复
# 拷贝 scripts/es8311-fix-audio.sh 文件到设备，然后执行
./es8311-fix-audio.sh
```

录音

```bash
# 音频回环测试
arecord -D hw:0,0 -f cd -t raw | aplay -D hw:0,0 -f cd

# 录音测试（录制 3 秒钟的音频并保存为 rec.wav）
arecord -D plughw:0,0 -d 3 -f cd -vv rec.wav
```

## RK1820 加速卡

环境依赖

- 下载 `rknn3_rk182x_m2_installer_arm64.tgz` 文件并解压, 然后使用 `install.sh` 脚本安装
- 将 pcie-rkep.ko 内核模块拷贝到开发板的 /lib/modules/ 目录下，然后重启设备

命令参考

```bash
# 查看内核模块是否加载成功
lsmod | grep -i pcie

# 查看设备是否识别成功
lspci | grep -i 182

# 查看加速卡设备信息
rknn-smi info

# 状态监控
rknn-smi info -w

# 查看服务状态
systemctl status rknn3.service
```

加速卡设备信息
```bash
# rknn-smi info
+------------------------+---------------+---------------+----------------------+
| rknn-smi      Version: 1.3.0                                                  |
+========================+===============+===============+======================+
| Device        Status   | Health        | Power(mW)     | Npu(%)               |
| Chip          Name     | Bus-Id        | Temp(C)       | Memory-Usage(MB)     |
+========================+===============+===============+======================+
| 0             Online   | OK            | NA            | 0                    |
| 0             RK1820   | 0000:01:00.0  | 33            | 32   / 2560          |
+========================+===============+===============+======================+
```

LLM 模型测试

```bash
rknn3_session_test Qwen2.5-0.5B.rknn Qwen2.5-0.5B.weight Qwen2.5-0.5B.tokenizer.gguf Qwen2.5-0.5B.embed.bin 1024 256 0xff

# 当前目录的文件夹结构如下：
root@recomputer-rk3576-module:~/qwen# ls
Qwen2.5-0.5B.embed.bin  Qwen2.5-0.5B.rknn  Qwen2.5-0.5B.tokenizer.gguf  Qwen2.5-0.5B.weight
root@recomputer-rk3576-module:~/qwen# md5sum ./*
f4f80996c9cf5596e0d51753b2b1f14e  ./Qwen2.5-0.5B.embed.bin
ee6a6d0ff5f11d3e7927a51a23d8a77d  ./Qwen2.5-0.5B.rknn
d73d50daadcab1ef8a2bed50b407739c  ./Qwen2.5-0.5B.tokenizer.gguf
d46024149781b66c6dc085075eaa52b5  ./Qwen2.5-0.5B.weight
# 注：文件过大不提供，需自行下载
```

CNN 模型测试

```bash
rknn3_model_test mobilenet_v2.rknn mobilenet_v2.weight '' '' 0x01 10kkk

# 当前目录的文件夹结构如下：
root@recomputer-rk3576-module:~/cnn# ls
mobilenet_v2.rknn  mobilenet_v2.weight
root@recomputer-rk3576-module:~/cnn# md5sum ./*
ea2a2abed2ce1ef9d49e4c159c99c285  ./mobilenet_v2.rknn
2e117b6a8c08b85cf6ba1016b48014c6  ./mobilenet_v2.weight
# 注：对应的模型文件可以在 models 目录下找到
```

## 40pin 引脚功能测试

### CAN 引脚测试

CAN0 引脚编号信息

| 引脚编号 | 功能 | 说明 |
| -------- | ---- | ---- |
| 38       | CAN0_TX_M2 | CAN 输出 |
| 40       | CAN0_RX_M2 | CAN 输入 |

CAN1 引脚编号信息

| 引脚编号 | 功能 | 说明 |
| -------- | ---- | ---- |
| 13       | CAN1_TX_M2 | CAN 输出 |
| 11       | CAN1_RX_M2 | CAN 输入 |

```bash
overlay_prefix=recomputer-rk3576-module-io-board
overlays=40pin-can0 40pin-can1
```

测试命令
```bash
# 安装工具
sudo apt install can-utils

# 启动 can
## 方法一
sudo ip link set can0 type can bitrate 500000 dbitrate 2000000 fd on
sudo ip link set can0 up
## 方法二（本机用，rk 开发版不支持）
sudo ip link set can0 up type can bitrate 500000
sudo ip link set can1 up type can bitrate 500000

# 测试收发
candump can1
cansend can0 141#9C.00.00.00.00.00.00.00
```

```bash
# 回环测试
ip link set can1 type can bitrate 500000 dbitrate 2000000 fd on loopback on
ip link set can1 up

# 自发自收
candump can1 -n 1 &
cansend can1 141#9C.00.00.00.00.00.00.11
```

注意：
- rk3576 上的 can 需要外置的 CAN 收发器才能正常使用
- 回环测试无需外置收发器，但只能测试本机收发，无法与其他设备通信

### PWM 引脚测试

引脚编号信息(按 PWM 编号排序)

| 引脚编号 | 功能 |
| -------- | ---- |
| 33       | PWM0_CH0_M0 |
| 32       | PWM1_CH0_M2 |
| 26       | PWM1_CH1_M2 |
| 19       | PWM1_CH2_M2 |
| 24       | PWM1_CH3_M2 |
| 23       | PWM1_CH4_M2 |
| 16       | PWM2_CH0_M2 |
| 18       | PWM2_CH1_M2 |
| 28       | PWM2_CH2_M1 |
| 27       | PWM2_CH3_M1 |
| 12       | PWM2_CH6_M2 |

引脚编号信息(按引脚编号排序;每个通道是独立设备,`pwmchip` 编号动态分配,测试时按寄存器地址定位)

| 引脚编号 | 功能 | overlay | 设备地址 | 说明 |
| -------- | ---- | ------- | -------- | ---- |
| 12       | PWM2_CH6_M2 | 40pin-pwm2-ch6 | 2ade6000 | |
| 16       | PWM2_CH0_M2 | 40pin-pwm2-ch0 | 2ade0000 | |
| 18       | PWM2_CH1_M2 | 40pin-pwm2-ch1 | 2ade1000 | |
| 19       | PWM1_CH2_M2 | 40pin-pwm1-ch2 | 2add2000 | 与 SPI1_MOSI 互斥 |
| 23       | PWM1_CH4_M2 | 40pin-pwm1-ch4 | 2add4000 | 与 SPI1_SCLK 互斥 |
| 24       | PWM1_CH3_M2 | 40pin-pwm1-ch3 | 2add3000 | 与 SPI1_CSN0 互斥 |
| 26       | PWM1_CH1_M2 | 40pin-pwm1-ch1 | 2add1000 | 与 SPI1_CSN1 互斥 |
| 27       | PWM2_CH3_M1 | 40pin-pwm2-ch3 | 2ade3000 | 加载后 i2c6 被关闭 |
| 28       | PWM2_CH2_M1 | 40pin-pwm2-ch2 | 2ade2000 | 加载后 i2c6 被关闭 |
| 32       | PWM1_CH0_M2 | 40pin-pwm1-ch0 | 2add0000 | |
| 33       | PWM0_CH0_M0 | 40pin-pwm0-ch0 | 27330000 | |

```bash
overlay_prefix=recomputer-rk3576-module-io-board
overlays=40pin-pwm0-ch0 40pin-pwm1-ch0 40pin-pwm1-ch1 40pin-pwm1-ch2 40pin-pwm1-ch3 40pin-pwm1-ch4 40pin-pwm2-ch0 40pin-pwm2-ch1 40pin-pwm2-ch2 40pin-pwm2-ch3 40pin-pwm2-ch6
```

测试步骤
```bash
P=/sys/class/pwm/pwmchipX
echo 0        > $P/export
echo 1000000  > $P/pwm0/period      # 单位 ns:1ms = 1kHz
echo  500000  > $P/pwm0/duty_cycle  # 50%(必须先 period 后 duty)
echo 1        > $P/pwm0/enable
```

#### PWM 测试工具 pwm40

`tools/pwm40` 按物理引脚编号操作，自动按设备地址定位 pwmchip(不受编号漂移影响)。

部署
```bash
scp tools/pwm40 root@<IP_ADDRESS>:/usr/local/bin/
```

使用方法
```bash
pwm40 list              # 全通道总览: 引脚/通道/pwmchip/duty/频率/状态
pwm40 32 50             # 引脚 32 输出 50% @ 1kHz(默认频率)
pwm40 12 80 20000       # 引脚 12 输出 80% @ 20kHz
pwm40 32 off            # 停止并释放该通道
```

### I2C 引脚测试

引脚编号信息(按引脚编号排序;`i2c-N` 编号动态分配,测试时按寄存器地址定位)

| 引脚编号 | 功能 | overlay | 设备地址 | 说明 |
| -------- | ---- | ------- | -------- | ---- |
| 3        | I2C3_SDA_M1 | 40pin-i2c3 | 2ac60000 | |
| 5        | I2C3_SCL_M1 | 40pin-i2c3 | 2ac60000 | |
| 22       | I2C7_SDA_M1 | 40pin-i2c7 | 2aca0000 | 同上 |
| 7        | I2C7_SCL_M1 | 40pin-i2c7 | 2aca0000 | 与 SPI3/SAI3/UART3 互斥 |
| 27       | I2C6_SDA_M3 | 无需 overlay | 2ac90000 | 摄像头控制总线,默认已启用 |
| 28       | I2C6_SCL_M3 | 无需 overlay | 2ac90000 | 同上 |
| 31       | I2C8_SDA_M2 | 40pin-i2c8 | 2acb0000 | 同上 |
| 29       | I2C8_SCL_M2 | 40pin-i2c8 | 2acb0000 | 与 40pin-uart7 互斥 |
| 40       | I2C4_SDA_M1 | 40pin-i2c4 | 2ac70000 | 同上 |
| 38       | I2C4_SCL_M1 | 40pin-i2c4 | 2ac70000 | 与 CAN0/UART6 互斥 |

```bash
overlay_prefix=recomputer-rk3576-module-io-board
overlays=40pin-i2c3 40pin-i2c4 40pin-i2c7 40pin-i2c8
```

测试步骤
```bash
i2cdetect -y -r N
```

### UART 引脚测试

引脚编号信息(按引脚编号排序;`ttySN` 编号动态分配,测试时按寄存器地址定位)

| 引脚编号 | 功能 | overlay | 设备地址 | 说明 |
| -------- | ---- | ------- | -------- | ---- |
| 7        | UART3_TX_M0 | 40pin-uart3 | 2ad60000 | 与 SPI3/SAI3/I2C7 互斥 |
| 22       | UART3_RX_M0 | 40pin-uart3 | 2ad60000 | 与 SPI3/SAI3/I2C7 互斥 |
| 8        | UART0_TX_M0 | 无需 overlay | 2ad40000 | 调试串口,默认启用 |
| 10       | UART0_RX_M0 | 无需 overlay | 2ad40000 | 同上 |
| 11       | UART2_RX_M1 | 40pin-uart2 | 2ad50000 | 与 CAN1 互斥 |
| 13       | UART2_TX_M1 | 40pin-uart2 | 2ad50000 | 同上 |
| 23       | UART11_RX_M1 | 40pin-uart11 | 2afd0000 | 与 SPI1/PWM1 互斥 |
| 24       | UART11_TX_M1 | 40pin-uart11 | 2afd0000 | 同上 |
| 26       | UART9_TX_M0 | 40pin-uart9 | 2adc0000 | TX/RX 跨脚分布 |
| 32       | UART9_RX_M0 | 40pin-uart9 | 2adc0000 | 与 PWM1_CH0 互斥 |
| 29       | UART7_TX_M0 | 40pin-uart7 | 2ada0000 | 与 I2C8 互斥 |
| 31       | UART7_RX_M0 | 40pin-uart7 | 2ada0000 | 同上 |
| 38       | UART6_TX_M0 | 40pin-uart6 | 2ad90000 | 与 CAN0/I2C4 互斥 |
| 40       | UART6_RX_M0 | 40pin-uart6 | 2ad90000 | 同上 |

```bash
overlay_prefix=recomputer-rk3576-module-io-board
overlays=40pin-uart2 40pin-uart3 40pin-uart6 40pin-uart7 40pin-uart9 40pin-uart11
```

测试步骤
```bash
# 回环测试: 短接 TX/RX 两脚后自发自收(把 N 换成对应的串口编号)
stty -F /dev/ttySN 115200 raw -echo
cat /dev/ttySN &
echo "uart test" > /dev/ttySN
```

### SPI 引脚测试

SPI1(M1)

| 引脚编号 | 功能 | overlay | 设备地址 | 说明 |
| -------- | ---- | ------- | -------- | ---- |
| 19       | SPI1_MOSI_M1 | 40pin-spi1 | 2ad00000 | 与 PWM1_CH2/UART11/SAI2 互斥 |
| 21       | SPI1_MISO_M1 | 40pin-spi1 | 2ad00000 | 与 PWM0_CH0_M2/UART11/SAI2 互斥 |
| 23       | SPI1_CLK_M1 | 40pin-spi1 | 2ad00000 | 与 PWM1_CH4/UART11/SAI2 互斥 |
| 24       | SPI1_CSN0_M1 | 40pin-spi1 | 2ad00000 | 与 PWM1_CH3/UART11/SAI2 互斥 |
| 26       | UART-引脚测试SPI1_CSN1_M1 | 40pin-spi1 | 2ad00000 | 与 PWM1_CH1/UART9/SAI2 互斥 |

SPI3(M0)

| 引脚编号 | 功能 | overlay | 设备地址 | 说明 |
| -------- | ---- | ------- | -------- | ---- |
| 7        | SPI3_CLK_M0 | 40pin-spi3 | 2ad20000 | 与 SAI3/UART3/I2C7 互斥 |
| 15       | SPI3_MISO_M0 | 40pin-spi3 | 2ad20000 | 与 SAI3/UART3/CAN1_M3 互斥 |
| 22       | SPI3_MOSI_M0 | 40pin-spi3 | 2ad20000 | 与 SAI3/UART3/I2C7 互斥 |
| 36       | SPI3_CSN0_M0 | 40pin-spi3 | 2ad20000 | 与 SAI3/UART3/CAN1_M3 互斥 |

```bash
overlay_prefix=recomputer-rk3576-module-io-board
overlays=40pin-spi1 40pin-spi3
```

测试方法

```bash
# 部署工具
scp tools/lsm6dsx_spi_test root@<IP_ADDRESS>:/usr/local/bin/

# 使用方法
lsm6dsx_spi_test <spi-node>
lsm6dsx_spi_test /dev/spidev1.0
```

注意事项：使用的传感器为 LSM6DS3, 传感器的 SAO 引脚接开发板的 MISO 引脚，传感器的 SDA 接开发板的 MOSI 引脚

### I2S(SAI)引脚测试

SAI3(M2)—— 40pin 上有 overlay 支持的 I2S

| 引脚编号 | 功能 | overlay | 设备地址 | 说明 |
| -------- | ---- | ------- | -------- | ---- |
| 12       | SAI3_MCLK_M2 | 40pin-sai3 | 2a630000 | 与 PWM2_CH6 互斥 |
| 7        | SAI3_SCLK_M2 | 40pin-sai3 | 2a630000 | 与 SPI3/UART3/I2C7 互斥 |
| 22       | SAI3_LRCK_M2 | 40pin-sai3 | 2a630000 | 与 SPI3/UART3/I2C7 互斥 |
| 15       | SAI3_SDO_M2 | 40pin-sai3 | 2a630000 | 与 SPI3/UART3/CAN1_M3 互斥 |
| 36       | SAI3_SDI_M2 | 40pin-sai3 | 2a630000 | 与 SPI3/UART3/CAN1_M3 互斥 |

```bash
# 查看 SAI3 引脚状态
cat /sys/kernel/debug/pinctrl/pinctrl-rockchip-pinctrl/pinmux-pins | grep sai3
```

完整声卡测试(接线 / ko 与 dtbo 编译 / 验证)见 [i2s-module/README.md](i2s-module/README.md)。
