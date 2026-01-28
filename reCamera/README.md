# reCamera

## 设备信息

USB 直连模式下的 IP
```bash
192.168.42.1
```

WiFi AP 信息
```bash
账号：reCamera_xxxxxx (xxxxxx 为 MAC 地址后六位)
密码：12345678
```

默认登录用户名和密码
```bash
用户名: recamera
密码: recamera
```

工作区界面
```bash
http://192.168.42.1/#/workspace
```

设置界面
```bash
http://192.168.42.1/#/init
```

预览界面
```bash
http://192.168.42.1/#/dashboard
```

## 恢复出厂设置

> 长按 User 按键上电，直到看到 红色指示灯常亮 后松开按键

## OTA

旧版本固件 OTA 升级命令 (0.1.3)
```bash
# 前提：手动拷贝新的 upgrade.sh 到执行目录

cd /home/recamera
# ls 查看当前路径文件，必须查看到 upgrade.sh 才表示路径没有问题！！！
ls
# 给脚本添加执行权限
chmod u+x ./upgrade.sh
# 升级操作
sudo ./upgrade.sh start ./sg2002_reCamera_0.2.1_emmc_ota.zip
```

新版本固件 OTA 升级命令 (0.2.0 及以上)
```bash
sudo /mnt/system/upgrade.sh start ./sg2002_reCamera_0.2.1_emmc_ota.zip
```

## 压力测试

```bash
stress-ng --cpu 1 --cpu-method all --timeout 1h
```

## Halow

控制天线引脚
```bash
# 控制天线引脚
cd /sys/class/gpio
echo 431 > ./export
echo out > gpio431/direction
echo 0 > ./gpio431/value
```

获取 User 按键状态 (`BT_EN`)
```bash
cat /sys/class/gpio/gpio510/value

# 默认为 1，点击按键值为 0
```

### Halow Driver

查看设备信息
```bash
dmesg | grep -i mmc1 | grep -i new
dmesg | grep -i mmc1
```

查看网络设备信息
```bash
ifconfig -a
ip link
```

### Halow 定频测试步骤

前提条件：需要先把 wpa_supplicant_s1g 程序关闭

```bash
$ ps | grep -i wpa
  773 root     wpa_supplicant -B -i wlan0 -c /etc/wpa_supplicant.conf
  789 root     wpa_supplicant_s1g -B -Dnl80211 -ihalow0 -c /etc/wpa_supplicant_s1g.conf
 1178 root     grep -i wpa
$ kill -9 <pid>
# 避免干扰，两个 wpa 程序都需要关闭

$ ps | grep -i hostapd
 1232 root     hostapd -B /etc/hostapd_2g4.conf
 3668 recamera grep -i hostapd
# kill -9 <pid>

# 关闭普通 wifi
$ ifconfig wlan0 down
$ ifconfig wlan1 down
```

Raspberry Pi 4B 设备注意事项：
- 需要把命令中的 halow0 改为 wlan0
- 将 morsectrl 工具拷贝到设备中的 /sbin/ 文件夹下

#### 定频固件

reCamera

```bash
# 固件原名: mm6108-dvt_14p1.bin
# 驱动版本：v1.14.1
# 固件信息
[root@reCamera]~# md5sum /lib/firmware/morse/mm6108.bin
6ad4cbcdd77e8a21c769951284de4632  /lib/firmware/morse/mm6108.bin
```

Raspberry Pi 4B

```bash
# 固件原名: mm6108-dvt.bin
# 驱动版本：v1.12.4
# 固件信息
root@ekh01-ac64:~# md5sum /lib/firmware/morse/mm6108.bin
9754ee2429e22937e21848fd08a2f0b2  /lib/firmware/morse/mm6108.bin
```

#### 发送测试

```bash
# 设备使能 (ifconfig 已经有 halow0 设备则可跳过此步骤)
ifconfig halow0 up

# 设置信道、带宽
morsectrl -i halow0 channel -c 863500 -o 1 -p 1 -n 0

# 参数介绍
 -c 863500: 设置信道为863500kHz，具体见支持信道表
 -o 1: 设置带宽为 1MHz，可选值为1、2、4、8
 -p 1
 -n 0

# 设置带宽、速率
morsectrl -i halow0 txrate enable -b 1 -m 0 -f 0 -t 0 -s 0
# 参数介绍
 -b 1: 设置带宽为 1MHz，可选值为1、2、4、8
 -m 0: 设置速率为 MCS0，可选值为10、0~7
 -f 0
 -t 0
 -s 0

# 调整功率值，步进为1dB，范围-15~+15
morsectrl -i halow0 txscaler 0

# 开启发射
morsectrl -i halow0 rpg start -s 1000 -c -1

# 停止发射，下发其他信道或模式时先下发该指令
morsectrl -i halow0 rpg stop
```

#### 接收测试

```bash
# 设备使能(ifconfig 已经有 halow0 设备则可跳过此步骤)
ifconfig halow0 up

# 设置信道、带宽等参数
morsectrl -i halow0 channel -c 863500 -o 1 -p 1 -n 0

# 开启接收
morsectrl -i halow0 rpg start -l

# 查询收包数量
morsectrl -i halow0 rpg stats

# 复位收包数量
morsectrl -i halow0 rpg reset
```
