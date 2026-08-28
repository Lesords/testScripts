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
