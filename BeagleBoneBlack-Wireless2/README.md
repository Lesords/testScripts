# BeagleBoneBlack-Wireless2 测试文档

## 目录

- [设备相关](#设备相关)
  - [DFU 模式](#dfu-模式)
  - [JTAG](#jtag)
  - [账号信息](#账号信息)
  - [使用注意事项](#使用注意事项)
  - [EMMC 启动](#emmc-启动)
- [LED](#led)
- [WiFi](#WiFi)
- [蓝牙](#蓝牙)
- [MCU-ADC](#mcu-adc)

## 设备相关

### DFU 模式

触发条件: 使用 SD 卡启动模式, 并且检测不到 SD 卡时会出现 DFU 模式

实际步骤：拔掉 SD 卡，按住复位键，插入电源，等待 5 秒后松开复位键。

Linux 主机扫描 DFU 设备
```bash
sudo dfu-util -l
```

Windows 需要查看 设备管理器 中是否有 DFU 设备
```bash
# 挂载位置
通用串行总线设备
  AM62x DFU
```

参考链接: https://software-dl.ti.com/processor-sdk-linux/esd/AM62X/latest/exports/docs/linux/Foundational_Components/U-Boot/UG-DFU.html

### JTAG

配置文件位置：`configs/bbw2_jtag.cfg`

```bash
# 启动 OpenOCD 调试服务：接管探针、扫链识别目标
openocd -f configs/bbw2_jtag.cfg
# 预期结果：Info : JTAG tap: am625.cpu tap/device found: 0x0bb7e02f (mfg: 0x017 (Texas Instruments), part: 0xbb7e, ver: 0x0)

# 连接调试端口（另外一个终端）
telnet localhost 4444
## 列出全部目标（4×A53 / R5 / sysctrl / M4）
targets
## 关闭
shutdown
```

参考链接：https://software-dl.ti.com/processor-sdk-linux/esd/AM62X/latest/exports/docs/linux/Foundational_Components/U-Boot/Apps-SPL-Debug-OpenOCD.html

### 账号信息

默认账号信息

```bash
账号：debian
密码：temppwd

# 手动启动后需要修改密码
```

> root 账号需要根据固件来决定是否启用，默认情况下 root 账号是禁用的。
>
> 如果启动了 root 账号，默认密码为 root

### 使用注意事项

- 设备启动后，默认会自动扩容分区，并且会自动重启设备，期间不要下电

### EMMC 启动

刷写 tiboot3.bin 到 EMMC 的 Boot0 分区, 需要通过 sd 卡先进入到系统中

```bash
# 关闭 EMMC Boot0 分区的只读属性
sudo bash -c "echo 0 > /sys/block/mmcblk0boot0/force_ro"
# 刷写 tiboot3.bin 到 EMMC 的 Boot0 分区
sudo dd if=/boot/firmware/tiboot3.bin of=/dev/mmcblk0boot0 seek=0 bs=512

# 从 Boot0 启动
sudo mmc bootpart enable 1 2 /dev/mmcblk0
sudo mmc bootbus set single_backward x1 x8 /dev/mmcblk0
```

刷文件系统到 EMMC, 需要通过 sd 卡先进入到 uboot（启动中点击 空格）

```bash
# 在 uboot 模式下输入以下命令
ums 0 mmc 0

# 然后会在主机中挂载 emmc 分区内容，使用对应的工具刷写固件到 emmc 分区
```

## LED

```bash
cd /sys/class/leds/
# 打开 LED
echo 1 > ./USR0/brightness
echo 1 > ./USR1/brightness
echo 1 > ./USR2/brightness
echo 1 > ./USR3/brightness

# 关闭 LED
echo 0 > ./USR0/brightness
echo 0 > ./USR1/brightness
echo 0 > ./USR2/brightness
echo 0 > ./USR3/brightness
```

## WiFi

```bash
# 查看 wlan0 网卡信息
ip link | grep -i wlan0

# 查看网络状态
wpa_cli -i wlan0 status

# 扫描网络
## 开始扫描
wpa_cli -i wlan0 scan
## 查看扫描结果
wpa_cli -i wlan0 scan_results
```

## 蓝牙

```bash
# 查看蓝牙状态
hciconfig
```

## MCU-ADC

芯片状态相关
```bash
# BSL(可烧录态)
需要上拉 invoke 引脚，然后重新上电

# PCU(运行态)
不要上拉 invoke 引脚，芯片上电后即可运行
```

固件刷入
```bash
# 探测芯片
openocd -f ./configs/mspm0_probe.cfg -c "init" -c "targets" -c "shutdown"
# 注：PCU 状态下无法识别到芯片，需要进入 BSL 后再探测
# 无法识别的日志为：Error: Error connecting DP: cannot read IDR

# 探测成功后可以直接刷固件，命令如下
openocd -f configs/bbw2_mspm0_flash.cfg \
  -c "init" -c "targets" \
  -c "program firmwares/pcu_bbw2.bin 0 verify" \
  -c "reset run" -c "shutdown"
# 注：烧录完后需要拔掉 invoke，然后复位下芯片

# 芯片复位
gpioset -c gpiochip3 0=0 >/dev/null 2>&1 & P=$!; sleep 0.3; kill -9 $P 2>/dev/null; gpioset -c gpiochip3 0=1 >/dev/null 2>&1 & P=$!; sleep 0.3; kill -9 $P 2>/dev/null

# 这个时候只能扫描到芯片地址，需要重启设备，MCU 芯片才会重新工作
```

查看芯片是否正常工作
```bash
# 查看 I2C 设备
i2cdetect -r -y 1
# 0x20=ADC 0x50=EEPROM 在线即正常
```

查看 ADC 值
```bash
cd /sys/bus/iio/devices/iio\:device0

# ADC_CH0
cat in_voltage0_raw

# ADC_CH1
cat in_voltage1_raw

# ADC_CH2
cat in_voltage2_raw

# ADC_CH3
cat in_voltage3_raw

# ADC_CH4
cat in_voltage4_raw

# ADC_CH5
cat in_voltage5_raw

# ADC_CH6
cat in_voltage6_raw

# ADC_CH7
cat in_voltage7_raw
```
