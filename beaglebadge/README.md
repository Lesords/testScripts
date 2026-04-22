# OSPI 启动

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

# Low Power Modes

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

# DFU 模式

触发条件: 使用 SD 卡启动模式, 并且检测不到 SD 卡时会出现 DFU 模式

Linux 主机扫描 DFU 设备
```bash
sudo dfu-util -l
```

参考链接: https://software-dl.ti.com/processor-sdk-linux/esd/AM62LX/latest/exports/docs/linux/Foundational_Components/U-Boot/UG-DFU.html

# JTAG 调试

使用步骤

```bash
openocd -f ./ti_am625evm.cfg
```

推荐的 openocd 版本: 0.12.0

# 蓝牙

> 先使用 USB 转网口连接设备, 使得设备可以正常上网

安装依赖项

```bash
apt install bluez
apt-get install bluez-test-scripts bluez-test-tools

systemctl enable bluetooth
systemctl start bluetooth
```

拷贝 start_bluetooth.sh 脚本到设备上, 运行脚本

```bash
chmod +x start_bluetooth.sh
./start_bluetooth.sh
```

# 引脚编号

```bash
# old version - without WKUP_GPIO
GPIO0_0: 512
GPIO0_66: 512 + 66 = 578

# new version - with WKUP_GPIO
GPIO0_0: 519

base - 519
EMMC 复位引脚：GPIO520
OSPI RST 引脚：GPIO531
OSPI INT 引脚：GPIO532
SD 电源引脚：GPIO535
Sensor 引脚：GPIO513
Boost 5V en 引脚: GPIO534
```

# 测试命令

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
./epaper_test
./epaper_test_boy

# lora
cd /mnt
./sx126x_demo

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

# EMMC RST
cd /sys/class/gpio/
echo 513 > ./export
echo out > ./gpio513/direction
echo 1 > ./gpio513/value

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
