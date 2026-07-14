# InwayConnect-CM5

## 目录

- [手动加载驱动步骤](#手动加载驱动步骤)
- [压力测试](#压力测试)
- [LED](#led)
- [DI](#di)
- [DO](#do)
- [eeprom](#eeprom)
- [IMU](#imu)
- [ADC](#adc)
- [RTC](#rtc)
- [看门狗](#看门狗)
- [Buzzer](#buzzer)
- [Speaker](#speaker)
- [TPM](#tpm)
- [UPS](#ups)
- [One Wire](#one-wire)
- [4G module](#4g-module)
- [通讯接口](#通讯接口)
  - [RS232 串口](#rs232-串口)
  - [CAN](#can)

## 手动加载驱动步骤

```bash
# 拉取仓库
git clone https://github.com/Lesords/seeed-linux-dtoverlays.git -b reachy_mini --depth=1

# 部署
sudo ./scripts/reTerminal.sh --device rpi-cm5-inway --keep-kernel

# 重启设备
sudo reboot
```

## 压力测试

安装依赖

```bash
sudo apt install stress
```

拷贝 test_stress.sh 到设备里面，然后执行

```bash
./test_stress.sh
```

Ctrl + C 停止测试

## LED

```bash
# 打开
sudo bash -c "echo 1 > /sys/class/leds/led-red/brightness"
sudo bash -c "echo 1 > /sys/class/leds/led-blue/brightness"
sudo bash -c "echo 1 > /sys/class/leds/led-green/brightness"
sudo bash -c "echo 1 > /sys/class/leds/led_usr1/brightness"
sudo bash -c "echo 1 > /sys/class/leds/led_usr2/brightness"
sudo bash -c "echo 1 > /sys/class/leds/led_usr3/brightness"

# 关闭
sudo bash -c "echo 0 > /sys/class/leds/led-red/brightness"
sudo bash -c "echo 0 > /sys/class/leds/led-blue/brightness"
sudo bash -c "echo 0 > /sys/class/leds/led-green/brightness"
sudo bash -c "echo 0 > /sys/class/leds/led_usr1/brightness"
sudo bash -c "echo 0 > /sys/class/leds/led_usr2/brightness"
sudo bash -c "echo 0 > /sys/class/leds/led_usr3/brightness"
```

ACT 控制方法

```bash
cd /sys/class/leds/ACT

# 清空触发事件
sudo bash -c "echo none > ./trigger"

# 打开
sudo bash -c "echo 0 > ./brightness"

# 关闭
sudo bash -c "echo 1 > ./brightness"

# 注：由于极性问题，可能会导致亮灭状态与实际相反
```

PWR 控制方法

```bash
cd /sys/class/leds/PWR

# 清空触发事件
sudo bash -c "echo none > ./trigger"

# 打开
sudo bash -c "echo 1 > ./brightness"

# 关闭
sudo bash -c "echo 0 > ./brightness"

# 注：由于极性问题，可能会导致亮灭状态与实际相反
```

## DI

引脚编号

```bash
gpio573 - GPIO4 - CM4_IN1 - EXT_IN1
gpio574 - GPIO5 - CM4_IN2 - EXT_IN2
```

测试步骤

```bash
# EXT_IN1, EXT_IN2 步骤类似
cd /sys/class/gpio
echo 573 > export
echo in > gpio573/direction
cat gpio573/value
```

注：引脚默认值为1，外部有电压会变为 0

## DO

引脚编号

```bash
gpio595 - GPIO26 - CM4_OUT - EXT_OUT
```

测试步骤

```bash
cd /sys/class/gpio
echo 595 > export
echo out > gpio595/direction
echo 1 > gpio595/value
# 拉高导通
```

注：无法输出高电平，只能测试导通

## eeprom

```bash
cd /sys/bus/i2c/devices/3-0050

# 修改 eeprom 信息
sudo bash -c "echo recomputer > ./eeprom"

# 查看 eeprom 信息
sudo cat ./eeprom | hexdump -C

# 打开写保护
sudo bash -c "echo 1 > ./3-00505/force_ro"

# 关闭写保护
sudo bash -c "echo 0 > ./3-00505/force_ro"
```

## IMU

方法一（不支持中断测试）

```bash
# 拉取仓库
git clone https://github.com/laughingrice/ICM20948.git --depth=1

cd ICM20948/Code/

# 修改仓库配置
vi ICM20948/defines.py

# 修改 以下参数
I2C_PORT = 3
ICM20948_I2C_ADDRESS = 0x68

# 运行(需要在 Code 目录下执行)
python -m ICM20948 --i2c
```

方法二

```bash
# 拷贝当前仓库下的 ICM20948 文件夹到设备里面，然后执行
# 注：需要拷贝整个文件夹，相关配置已修改，可以直接运行
python -m ICM20948 --i2c

# 获取中断引脚状态 - Debian 12
gpioget gpiochip0 0

# 目前的程序是 1s 切换一次中断引脚状态
```

## ADC

```bash
# 安装依赖
pip install smbus-cffi --break-system-packages

# 拷贝 test_adc.py 到设备里面，然后执行
sudo ./test_adc.py

# 读数大概为 1024 左右
```

## RTC

查看 rtc 的节点

```bash
ls /sys/class/rtc
```

关闭时间同步服务

```bash
sudo systemctl stop systemd-timesyncd.service
sudo systemctl disable systemd-timesyncd.service
```

设置 RTC 时间

```bash
sudo hwclock --set --date "2025-11-24 12:00:00" -f /dev/rtc1
```

查看 RTC 时间
```bash
sudo hwclock -r -f /dev/rtc1
```

## 看门狗

安装 开门狗
```bash
sudo apt install watchdog
```

修改看门狗配置
```bash
sudo vim /etc/watchdog.conf
```
文件内容：
```bash
watchdog-device = /dev/watchdog

# Set the hardware timeout (default is 1 minute)
watchdog-timeout = 120

# Set the interval between tests (should be shorter than watchdog-timeout)
interval = 15

# Set system load limits
max-load-1 = 24
# max-load-5 = 18
# max-load-15 = 12

# Enable real-time priority
realtime = yes
priority = 1
```

启动开门狗服务
```bash
sudo systemctl start watchdog
```

测试 - 模拟系统崩溃情况
```bash
sudo sh -c "echo 1 > /proc/sys/kernel/sysrq"
sudo sh -c "echo 'c' > /proc/sysrq-trigger"
```

成功触发之后，系统会在一定时间无响应后自动重启。

注：修改配置文件之后需要重启服务才能正常使用

## Buzzer

Debian 13

```bash
# 打开
gpioset -c 14 13=1

# 关闭
gpioset -c 14 13=0
```
Debian 12

```bash
# 打开
gpioset gpiochip14 13=1

# 关闭
gpioset gpiochip14 13=0
```
## Speaker

静音

Debian 13

```bash
# 取消静音
gpioset -c 14 15=1

# 静音
gpioset -c 14 15=0
```

Debian 12

```bash
# 取消静音
gpioset gpiochip14 15=1

# 静音
gpioset gpiochip14 15=0
```

播放测试

```bash
aplay -D hw:2,0 ./bbno.wav
```

## TPM

查看设备
```bash
ls /dev/ | grep tpm
```

通讯测试
```bash
sudo apt-get install tpm2-tools libtss2-dev

# 读取 TPM 版本信息
sudo tpm2_getcap properties-fixed
```

## UPS

拷贝 ups_detect.py 到设备里面，然后执行

```bash
sudo ./ups_detect.py
```

## One Wire

```bash
# 查看设备
ls /sys/bus/w1/devices/
# 有 w1_bus_master1 节点表示 One Wire 桥接设备识别成功（DS2482S-100+T&R桥接芯片）

# 获取 One Wire 设备列表（外接设备）
cd /sys/bus/w1/devices/
cat ./w1_bus_master1/w1_master_slaves
# 注：需要使用兼容的 One Wire 设备，才能获取到数据

# 查看 One Wire 设备信息（土壤温湿度传感器 - 黑色双叉 - MT05S-B Rev 4.03）
cat /sys/bus/w1/devices/28-040008031600/w1_slave
cat /sys/bus/w1/devices/28-040008031600/temperature
# 注：目前可以获取到温度信息，但是协议可能不完全兼容，读数看起来不准确
```

## 4G module

AT 指令参考

```bash
# AT 指令
纯测试：AT

查询网络信息：AT+QNWINFO

查询(U)SIM 卡的国际移动用户识别码：AT+CIMI
```

测试命令

```bash
sudo minicom -D /dev/ttyUSB2 -b 115200
```

## 通讯接口

### RS232 串口

```bash
# 安装依赖
sudo apt install minicom

# 打开指定串口
sudo minicom -D /dev/ttyAMA4
```

注意：退出 minicom 时，按下 `Ctrl + A`，然后按 `Q`，最后选择 yes 确认退出

### CAN

```bash
# 启动 can
sudo ip link set can0 up type can bitrate 500000
sudo ip link set can1 up type can bitrate 500000

# 下载工具
sudo apt install can-utils

# 测试收发
candump can1
cansend can0 141#9C.00.00.00.00.00.00.00
```
