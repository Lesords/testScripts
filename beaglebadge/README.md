测试命令

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
dd if=/dev/zero of=/dev/mtdblock5 bs=256k count=10
dd of=/dev/zero if=/dev/mtdblock5 bs=256k count=10

# gpio
./test_gpio.sh 0
./test_gpio.sh 1
cat /sys/bus/iio/devices/iio\:device2/in_voltage2_raw
```
