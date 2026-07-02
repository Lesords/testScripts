# Beaglebone 测试文档

## 目录

- [设备相关](#设备相关)
  - [DFU 模式](#dfu-模式)
  - [OSPI 启动](#ospi-启动)
  - [JTAG 调试](#jtag-调试)
  - [Low Power Modes](#low-power-modes)
- [模块](#模块)
  - [lora (EVT only)](#lora-evt-only)
  - [EMMC (EVT only)](#emmc-evt-only)
  - [蓝牙](#蓝牙)
  - [WiFi RF 定频](#wifi-rf-定频)
- [传感器](#传感器)
  - [IMU INT0 中断引脚](#imu-int0-中断引脚)
- [外设接口](#外设接口)
  - [引脚编号](#引脚编号)
- [测试命令汇总](#测试命令汇总)

## 设备相关

### DFU 模式

触发条件: 使用 SD 卡启动模式, 并且检测不到 SD 卡时会出现 DFU 模式

Linux 主机扫描 DFU 设备
```bash
sudo dfu-util -l
```

参考链接: https://software-dl.ti.com/processor-sdk-linux/esd/AM62LX/latest/exports/docs/linux/Foundational_Components/U-Boot/UG-DFU.html

### OSPI 启动

需要使用 SD 卡启动模式, 并且 SD 卡中需要包含以下三个文件: tiboot3.bin, tispl.bin, u-boot.img
```bash
=> sf probe
=> fatload mmc 1 ${loadaddr} tiboot3.bin
=> sf update $loadaddr 0x0 $filesize
=> fatload mmc 1 ${loadaddr} tispl.bin
=> sf update $loadaddr 0x80000 $filesize
=> fatload mmc 1 ${loadaddr} u-boot.img
=> sf update $loadaddr 0x280000 $filesize
```

### JTAG 调试

配置文件路径

```bash
./configs/ti_am625evm.cfg
```

使用步骤

```bash
openocd -f ./ti_am625evm.cfg
```

推荐的 openocd 版本: 0.12.0

### Low Power Modes

正常睡眠
```bash
echo mem > /sys/power/state
```

定时唤醒
```bash
rtcwake -m mem -s 10
```

wifi 模块问题
```bash
ifconfig wlan0 down

rmmod cc33xx
rmmod cc33xx_sdio

rtcwake -m mem -s 10

modprobe cc33xx_sdio
modprobe cc33xx

ifconfig wlan0 up
```

## 模块

### lora (EVT only)

```bash
cd /mnt
./sx126x_demo_private tx
./sx126x_demo_private rx
./sx126x_demo_public tx
./sx126x_demo_public rx
```

### EMMC (EVT only)

```bash
# EMMC RST
cd /sys/class/gpio/
echo 513 > ./export
echo out > ./gpio513/direction
echo 1 > ./gpio513/value
```

### 蓝牙

> 先使用 USB 转网口连接设备, 使得设备可以正常上网

安装依赖项

```bash
apt install bluez
apt-get install bluez-test-scripts bluez-test-tools

systemctl enable bluetooth
systemctl start bluetooth
```

拷贝 ./scripts/start_bluetooth.sh 脚本到设备上, 运行脚本

```bash
chmod +x start_bluetooth.sh
./start_bluetooth.sh
```

### WiFi RF 定频

仓库已包含 CC33xx RF 测试脚本和 arm64 `calibrator` 工具：

```text
scripts/wifi_rf_test.sh
tools/calibrator
```

直接拷贝文件到设备目标路径：

```bash
scp -p scripts/wifi_rf_test.sh root@<board-ip>:/root/wifi_rf_test.sh
scp -p tools/calibrator root@<board-ip>:/usr/bin/calibrator
```

在设备端进入脚本目录：

```bash
cd /root
```

执行定频测试：

```bash
# 查看参数说明
./wifi_rf_test.sh

# ch6, 1 包链路检查
./wifi_rf_test.sh check

# ch6 连续发包 30 秒，用于频谱仪测试
./wifi_rf_test.sh tx 6 30

# ch6 单音 10 秒，offset=0
./wifi_rf_test.sh tone 6 10 0

# 异常中断后清理 TX/tone 并退出 PLT
./wifi_rf_test.sh stop
```

说明：
- `check` 只发 1 个包，用于确认 PLT、定频、TX start/stop 链路正常。
- `tx` 是连续 WiFi 包发射，适合看 WiFi 调制信号。
- `tone` 是单音/CW，适合看载波、频偏、杂散。
- 脚本会自动停止 `NetworkManager.service` 和 `wpa_supplicant.service`，关闭 `wlan0` 后再进入 PLT。

## 传感器

### IMU INT0 中断引脚

卸载驱动
```bash
cd /sys/bus/i2c/devices/1-006a/driver
echo 1-006a > ./unbind
```

配置传感器
```bash
# 打开加速度计 103 Hz
i2cset -y 1 0x6a 0x10 0x40

# 把 Data Ready 输出到 INT1
i2cset -y 1 0x6a 0x0d 0x01

# 关闭 "中断输出路由"（mask 掉所有到 INT1 的中断源）
i2cset -y 1 0x6a 0x0d 0x00
```

实时检测中断引脚
```bash
# 作用：自动卸载驱动, 配置传感器, 并且持续检测 INT1 引脚的变化
# 将 ./scripts/test_imu.sh 脚本拷贝到设备上, 运行脚本

# 开启唤醒中断
./test_imu.sh 1

# 关闭唤醒中断
./test_imu.sh 0
```

测试注意事项
- INT1 引脚的电阻为 R295
- 电阻上方连接的 U33 的 INT1 引脚, 电阻下方连接的 3V3 电源
- 测量 INT1 引脚变化, 需要晃动屏幕

## 外设接口

### 引脚编号

```bash
# old version - without WKUP_GPIO
GPIO0_0: 512
GPIO0_66: 512 + 66 = 578

# new version - with WKUP_GPIO
WKUP_GPIO0_0: 512
GPIO0_0:      519

## base - 512
  DSI - WKUP_GPIO0_0: GPIO512
  DSI - WKUP_GPIO0_3: GPIO515
  Sensor Power 引脚:  GPIO513

## base - 519
  EMMC 复位引脚：GPIO520
  OSPI RST 引脚：GPIO531
  OSPI INT 引脚：GPIO532
  SD 电源引脚：  GPIO535
  Boost 5V en 引脚： GPIO534
```

注意：
- `USB1_DRVVBUS` 引脚默认被驱动占用，修改为 IO 模式会导致 USB 口无法使用

## 测试命令汇总

```bash
# rgb 测试
cd /sys/class/leds/rgb\:red
echo 255 > ./brightness
echo 0 > ./brightness

# led
cd /sys/class/leds/badge\:matrix\:led1_a/
echo 1 > ./brightness
echo 0 > ./brightness

# 按键测试
evtest /dev/input/event0

# ADC
cd /sys/bus/iio/devices/iio\:device2
# 光照
cat ./in_voltage2_raw
# mikrobus
cat ./in_voltage1_raw

# buzzer
cd /sys/class/pwm/pwmchip1/
echo 0 > ./export
echo 1000000 > pwm0/period
echo 500000 > pwm0/duty_cycle
echo 1 > pwm0/enable
echo 0 > pwm0/enable

# epaper 屏幕
cd /mnt/
./epaper_test eagle_binary
./epaper_test beaglebone

# IMU
cd /sys/bus/iio/devices/iio\:device1
cat in_accel_x_raw in_accel_y_raw in_accel_z_raw

# 电量计
# 读取电池电压
i2cget -y 1 0x55 0x08 w

# 读取剩余容量
i2cget -y 1 0x55 0x10 w

# 读取电池电流
i2cget -y 1 0x55 0x14 w

# grove uart
minicom -D /dev/ttyS4 -b 9600

# mikrobus uart
minicom -D /dev/ttyS5 -b 9600

# QWIIC
# J6
i2cdetect  -r -y 2

# J7
i2cdetect  -r -y 3

# mikrobus
## ADC
cd /sys/bus/iio/devices/iio\:device2
cat ./in_voltage1_raw

## I2C
i2cdetect -r -y 2

## UART
minicom -D /dev/ttyS5 -b 9600

## PWM
cd /sys/class/pwm/pwmchip0/
echo 0 > ./export
echo 1000000 > pwm0/period
echo 500000 > pwm0/duty_cycle
echo 1 > pwm0/enable
echo 0 > pwm0/enable

## GPIO
cd /sys/class/gpio/
echo 603 > ./export
echo out > ./gpio603/direction
echo 1 > ./gpio603/value

## SPI
./lsm6dsx_spi_test -s 1000000 -m 0  /dev/spidev2.1

# eeprom
cd /sys/class/i2c-dev/i2c-1/device/1-0050
cat eeprom | hexdump -C
echo hh > ./eeprom
dmesg | grep -i eeprom

# OSPI 测速
dd if=/dev/mtdblock5 of=/tmp/test_file bs=1M count=10 oflag=direct
dd if=/dev/zero of=/dev/mtdblock5 bs=1M count=10 oflag=direct

# gpio
./test_gpio.sh 0
./test_gpio.sh 1
cat /sys/bus/iio/devices/iio\:device2/in_voltage2_raw
```
