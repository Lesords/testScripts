# BeagleBoneBlack-Wireless2 测试文档

## 目录

- [设备相关](#设备相关)
  - [DFU 模式](#dfu-模式)
  - [JTAG](#jtag)
  - [账号信息](#账号信息)
  - [使用注意事项](#使用注意事项)
  - [EMMC 启动](#emmc-启动)
- [LED](#led)
- [GPIO 扩展排针](#gpio-扩展排针)
- [WiFi](#WiFi)
- [蓝牙](#蓝牙)
- [MCU-ADC](#mcu-adc)
- [HDMI](#hdmi)
- [脚本服务](#脚本服务)
  - [循环上电计数](#循环上电计数)

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

## GPIO 扩展排针

P8/P9 排针引脚对照表·默认态（开机 SEL 全 0；`G0_xx` = gpiochip3 线 xx，`G1_xx` = gpiochip4，`MCU_xx` = gpiochip2）

```
              P8（J1）                                 P9（J28）
┌────────────┬──────┬────────────┐        ┌────────────┬──────┬────────────┐
│  1  GND    │      │  2  GND    │        │  1  GND    │      │  2  GND    │
│  3  G0_89  │ 对   │  4  G1_3   │        │  3  3V3    │      │  4  3V3    │
│  5  G0_90  │ 对   │  6  G1_4   │        │  5  DC_5V  │      │  6  DC_5V  │
│  7  MCU_1  │ 对   │  8  G1_5   │        │  7  VSYS5V │      │  8  VSYS5V │
│  9  MCU_11 │ 对   │ 10  G1_6   │        │  9  PWR_BTN│      │ 10  RSTOUT │
│ 11  G0_25  │ 对   │ 12  G0_26  │        │ 11  G0_71  │ 对   │ 12  MCU_16 │
│ 13  G0_29  │ 对   │ 14  G0_28  │        │ 13  G0_72  │ 特   │ 14  HDMI   │
│ 15  G0_23  │ 对   │ 16  G0_24  │        │ 15  G1_16  │ 特   │ 16  HDMI   │
│ 17  G0_27  │ 对   │ 18  G0_38  │        │ 17  G1_15  │ 对   │ 18  G1_19  │
│ 19  G0_30  │ 对   │ 20  G1_1   │        │ 19  G0_43  │ 对   │ 20  G0_44  │
│ 21  G0_87  │ 对   │ 22  G1_2   │        │ 21  G1_18  │ 对   │ 22  G1_17  │
│ 23  G0_88  │ 借22 │ 24  MDIO   │        │ 23  HDMI   │ 借22 │ 24  G1_25  │
│ 25  MDIO   │      │ 26  HDMI   │        │ 25  G0_39  │ 对   │ 26  G1_24  │
│ 27  G0_63  │ 对   │ 28  G0_64  │        │ 27  G0_20  │ 对   │ 28  G0_7   │
│ 29  G0_61  │ 对   │ 30  G0_62  │        │ 29  G0_10  │ 对   │ 30  G0_9   │
│ 31  G0_59  │ 对   │ 32  G0_60  │        │ 31  G0_8   │ 借30 │ 32  AIN7   │
│ 33  G0_58  │ 对   │ 34  G0_56  │        │ 33  AIN4   │      │ 34  GND    │
│ 35  G0_57  │ 对   │ 36  G0_55  │        │ 35  AIN6   │      │ 36  AIN5   │
│ 37  G0_53  │ 对   │ 38  G0_54  │        │ 37  AIN2   │      │ 38  AIN3   │
│ 39  G0_51  │ 对   │ 40  G0_52  │        │ 39  AIN0   │      │ 40  AIN1   │
│ 41  G0_49  │ 对   │ 42  G0_50  │        │ 41  G1_30  │ 对   │ 42  G0_15  │
│ 43  G0_47  │ 对   │ 44  G0_48  │        │ 43  GND    │      │ 44  GND    │
│ 45  G0_45  │ 对   │ 46  G0_46  │        │ 45  GND    │      │ 46  GND    │
└────────────┴──────┴────────────┘        └────────────┴──────┴────────────┘
```

> - 对 = 左右两脚互为一对（同行横向配对），杜邦线桥接即可回环测试
> - 借xx = 搭档不可测，借上行 xx 脚配对；特 = P9_13↔P9_15 两个落单脚互配
> - HDMI / MDIO / AIN 不做 GPIO 测试；P9_11/13 经 PCA9306 电平转换（可测）

自动化测试

```bash
# 拷贝脚本到设备上
scp ./scripts/bbw2-gpio-tui.sh root@<IP_ADDRESS>:/root/

# 执行脚本
./bbw2-gpio-tui.sh
```

手动测试

```bash
# 拉高/拉低引脚
## 方法一：线名（前提是有配置）
timeout -s INT 3 gpioset P8_41=1
timeout -s INT 3 gpioset P8_41=0
## 方法二：chip + 线号
timeout -s INT 3 gpioset -c gpiochip3 49=1
timeout -s INT 3 gpioset -c gpiochip3 49=0

# 读引脚状态
## 方法一：线名
gpioget P8_41
## 方法二：chip + 线号
gpioget -c gpiochip3 49
## 预期结果：悬空=0（下拉）；P9_11/13 上拉配置，悬空=1
```

引脚切换

```bash
# 切换 / 恢复（默认 SEL 全 0）
timeout -s INT 1 gpioset EXP_SW_SEL1=1
timeout -s INT 1 gpioset EXP_SW_SEL1=0
```

切换后引脚对应线（对照表 = SEL=0 列）

```
┌───────┬────────┬────────┬───────┐
│ 脚    │ SEL=0  │ SEL=1  │ SEL   │
├───────┼────────┼────────┼───────┤
│ P8_7  │ MCU_1  │ G0_91  │ 1     │
│ P8_9  │ MCU_11 │ G1_0   │ 1     │
│ P8_13 │ G0_29  │ G1_14  │ 3     │
│ P8_19 │ G0_30  │ G1_13  │ 3     │
│ P8_33 │ G0_58  │ G0_31  │ 6     │
│ P8_37 │ G0_53  │ MCU_10 │ 2     │
│ P8_38 │ G0_54  │ MCU_9  │ 2     │
│ P9_12 │ MCU_16 │ G0_14  │ 7     │
│ P9_15 │ G1_16  │ MCU_15 │ 3     │
│ P9_17 │ G1_15  │ G1_28  │ 8     │
│ P9_18 │ G1_19  │ G1_29  │ 8     │
│ P9_19 │ G0_43  │ MCU_14 │ 5     │
│ P9_20 │ G0_44  │ MCU_13 │ 5     │
│ P9_21 │ G1_18  │ G1_8   │ 8     │
│ P9_22 │ G1_17  │ G1_7   │ 8     │
│ P9_24 │ G1_25  │ G0_19  │ 11+12 │
│ P9_27 │ G0_20  │ G0_13  │ 10    │
│ P9_28 │ G0_7   │ G0_32  │ 7     │
│ P9_30 │ G0_9   │ G0_34  │ 7     │
│ P9_31 │ G0_8   │ G0_35  │ 7     │
│ P9_42 │ G0_15  │ G0_13  │ 9     │
└───────┴────────┴────────┴───────┘
```

> P9_24 为组合切换：SEL11=1 且 SEL12=0 才到 G0_19（SEL12 恒 0，勿动）
> SEL4（P8_18 另一档接 GND）、SEL12/13（I2C0 活总线 / HDMI 音频）勿动

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

查看蓝牙状态
```bash
hciconfig
```

开启低功耗蓝牙
```bash
# 拷贝 ./scripts/start_bluetooth.sh 脚本到设备上, 运行脚本
./start_bluetooth.sh

# 然后使用 低功耗蓝牙工具 可以搜索到 bbw2-ble 设备，选择连接即可
```

注：蓝牙需要接天线

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

## HDMI

HDMI 状态查看
```bash
# 显示器 EDID 报的可用模式
cat /sys/class/drm/card0-HDMI-A-1/modes

# 查看虚拟分辨率
cat /sys/class/graphics/fb0/virtual_size
```

修改默认的分辨率
```bash
# 打开配置文件
vi /boot/firmware/extlinux/extlinux.conf

# 找到需要修改的选项，在 append 末尾添加对应的启动参数 video=HDMI-A-1:1920x1080@50
# 如下所示：
    append console=ttyS2,115200n8 earlycon=ns16550a,mmio32,0x02800000 root=/dev/mmcblk0p3 ro rootfstype=ext4 fsck.repair=yes rootwait net.ifnames=0  video=HDMI-A-1:1920x1080@30

# 完整例子
label emmc-root-1080p-30
    kernel /Image.gz
    append console=ttyS2,115200n8 earlycon=ns16550a,mmio32,0x02800000 root=/dev/mmcblk0p3 ro rootfstype=ext4 fsck.repair=yes rootwait net.ifnames=0  video=HDMI-A-1:1920x1080@30
    fdtdir /
    fdtoverlays /ti/k3-am6254-bbw2-exp-gpio.dtbo
# 注：不同启动项目的配置不一样，所以可以基于想要的启动项来修改
```
注：纯终端界面无法运行中动态修改分辨率

输出不同分辨率的测试数据
```bash
# 安装工具
sudo apt install -y libdrm-tests

# 拿 connector 编号
modetest -M tidss -c

# 切换分辨率
modetest -M tidss -s 44:1920x1080@RG16
modetest -M tidss -s 44:1280x720@RG16
modetest -M tidss -s 44:832x624@RG16
modetest -M tidss -s 44:640x480@RG16
```

HDMI 音频测试
```bash
# 安装工具
sudo apt update && sudo apt install -y alsa-utils mpg123

# 播放音频(需要提前拷贝 test.mp3 到设备上)
mpg123 -a hw:0,0 ./test.mp3
```

## 脚本服务

### 循环上电计数

```bash
# 拷贝脚本和服务到设备上
scp ./boot-count/boot-count.sh root@<IP_ADDRESS>:/usr/local/sbin/
scp ./boot-count/boot-count.service  root@<IP_ADDRESS>:/etc/systemd/system/

# 例子
scp ./boot-count/boot-count.sh root@10.0.0.240:/usr/local/sbin/
scp ./boot-count/boot-count.service  root@10.0.0.240:/etc/systemd/system/

# 启动服务
systemctl daemon-reload && systemctl enable --now boot-count.service

# 查看结果
cat /var/lib/boot-count
cat /var/lib/boot-log
```
