# RK3576-IO-Board

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

sudo apt install -y libmali-bifrost-g52-g24p0-x11-wayland-gbm glmark2-es2-drm
```

测试步骤
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

# 修改 overlay 为以下内容
overlay_prefix=recomputer-rk3576-devkit
overlays=raspi-7inch-touchscreen
```

注意事项
```bash
需要跳线才能正常使用 DSI 中的 I2C

跳线位置：DSI 座子和 40 PIN 之间, 40 PIN 旁边
跳线方向：DSI 座子 -> 40 PIN, 两个跳线都要
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
bluetoothctl info <MAC>
bluetoothctl info D0:67:94:74:3F:CD
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
