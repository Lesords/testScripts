# RTL8822CE 定频测试步骤

## 0. 安装（每块板一次性）

```bash
scp output/rtl88x2ce-mp-kit-20261029.tar.gz root@10.0.0.201:/root/
ssh root@10.0.0.201
cd /root && tar xzf rtl88x2ce-mp-kit-20261029.tar.gz && cd rtl8822ce-mp-kit

# 装 88x2ce.ko + rtwpriv/rtlbtmp + MP 固件, 自带 vermagic 校验
sh install.sh
```

注：需要修改 IP 为实际上的板子 IP 地址

> 前置: `ls /sys/class/net` 里出现 `wl*` 网卡后再操作——那是主线驱动初始化完成的标志(开机约半分钟), 提前 rmmod 会把设备留在半初始化状态

## 1. WiFi 定频

### TLDR

初始化定频模式

````bash
systemctl stop NetworkManager
modprobe -r 88x2ce 2>/dev/null
modprobe -r rtw88_8822ce 2>/dev/null
modprobe 88x2ce
sleep 3

WIFI=$(ls /sys/class/net | grep -E '^wl' | head -1)
[ -n "$WIFI" ] || echo "未发现无线网卡! 查: dmesg | grep -i 88x2ce | tail -5"
ifconfig $WIFI up
rtwpriv $WIFI mp_start
````

发送波形

```bash
WIFI=$(ls /sys/class/net | grep -E '^wl' | head -1)
ifconfig $WIFI up

rtwpriv $WIFI mp_start

rtwpriv $WIFI mp_txpower patha=0,pathb=100
rtwpriv $WIFI mp_channel 36
rtwpriv $WIFI mp_bandwidth 40M=0,shortGI=0
rtwpriv $WIFI mp_ant_tx b
rtwpriv $WIFI mp_rate 22
rtwpriv $WIFI mp_ctx count=%100,pkt
```

停止发送

```bash
WIFI=$(ls /sys/class/net | grep -E '^wl' | head -1)

rtwpriv $WIFI mp_ctx stop
```

### 自动化脚本

```bash
# 部署脚本
scp ./scripts/* root@10.0.0.201:/root/
# 然后通过 root 账号进入设备中执行以下命令即可

# 进入定频模式
./load_ko.sh

# 发送波形
start.sh

# 停止发送
stop.sh
```

脚本部分命令讲解
```bash
# 进入定频模式
rtwpriv $WIFI mp_start

# 退出定频模式
rtwpriv $WIFI mp_ctx stop

# 设置发送功率
rtwpriv $WIFI mp_txpower patha=0,pathb=100

# 设置天线
rtwpriv $WIFI mp_ant_tx b
```

### 进入定频模式

```bash
# 查看网卡节点名字
ls /sys/class/net | grep -E '^wl'

# 关闭 NetworkManager, 避免干扰
systemctl stop NetworkManager

# 卸载主线驱动, 加载定频驱动
modprobe -r 88x2ce 2>/dev/null
modprobe -r rtw88_8822ce 2>/dev/null
modprobe 88x2ce

# 等驱动注册网卡, 必须等
sleep 3

# 接口名 udev 会改, 动态取
WIFI=$(ls /sys/class/net | grep -E '^wl' | head -1)
[ -n "$WIFI" ] || echo "未发现无线网卡! 查: dmesg | grep -i 88x2ce | tail -5"
ifconfig $WIFI up

rtwpriv $WIFI mp_start
# 出现 "mp_start ok" 即已进入定频模式
```

### 验证定频模式

```bash
# 查看功率索引 + dBm
rtwpriv $WIFI mp_get_txpower 0
# 预期: 返回功率索引+dBm(如 94 / 21dBm) → 芯片通信正常

# ch36/BW20/MCS0 发包
rtwpriv $WIFI 36 0 a HTMCS0 1

# 查询发包计数
rtwpriv $WIFI mp_query
# 预期: Tx OK > 0 且 Fail = 0 → 发射正常

# 停发
rtwpriv $WIFI stop
```

注：以上命令用于测试定频模式是否正常, 也可用频谱仪验证是否出波形

### 退出 + 恢复

```bash
# 退出定频模式
rtwpriv $WIFI mp_stop

# 卸载定频驱动
rmmod 88x2ce

# 恢复主线驱动
modprobe rtw88_8822ce
systemctl start NetworkManager
```

## 2. 蓝牙定频

### TLDR

```bash
rtlbtmp

# 交互命令
enable usb:/dev/hci0

# 模块复位
bt_mp_Exec 0

# 调制波信号测试 - channel 0 (2402MHz)，DH5
## 默认功率 6.3dbm
bt_mp_SetParam 1,0;2,0x02;3,0x05;4,0x00;5,0x7F;7,0x00;9,0xA078;11,0x000000c6967e
## 大功率 9dbm
bt_mp_SetParam 1,0;2,0x02;3,0x05;4,0x00;6,0x7F;7,0x07;9,0xA078;11,0x000000c6967e

## start tx
bt_mp_Exec 34

## stop tx
bt_mp_Exec 35

# 单载波
bt_mp_Exec 0
bt_mp_Exec 38
bt_mp_Report 17

## channel 0, 3DH5
### 默认功率
bt_mp_SetParam 1,0;2,0x08;3,0x00;6,0xFF;7,0x00;9,0x3FFFF;11,0x000000c6967e
### 大功率
bt_mp_SetParam 1,0;2,0x08;3,0x00;6,0xFF;7,0x07;9,0x3FFFF;11,0x000000c6967e

## start tx
bt_mp_Exec 34

## stop tx
bt_mp_Exec 35
```

参考流程
```bash
root@recomputer-rk3588-industrial:~# rtlbtmp
:::::::::::::::::::::::::::::::::::::::::::::::::
:::::::: Bluetooth MP Test Tool Starting 2024.05.9 ::::::::
> enable usb:/dev/hci0
> enable[Success:0]

> bt_mp_Exec 0

bt_mp_Exec[Success:0]
> > bt_mp_Exec,0,0x00

> bt_mp_SetParam 1,0;2,0x02;3,0x05;4,0x00;5,0x7F;7,0x00;9,0xA078;11,0x000000c6967e
bt_mp_SetParam[Success:0]
> bt_mp_SetParam,11,0x00

> bt_mp_Exec 34
bt_mp_Exec[Success:0]
> bt_mp_Exec,34,0x00
```

### 进入定频模式

```bash
# 关闭蓝牙服务, 杀掉 bluetoothd
systemctl stop bluetooth && pkill -9 bluetoothd

# 重新加载 btusb 驱动, 并启动 hci0
modprobe btusb && hciconfig hci0 up

# 进入蓝牙定频模式
/usr/local/bin/rtlbtmp
# 交互命令, 直接输入以下内容
enable usb:/dev/hci0
# 等 enable[Success:0] 再继续(enable 是异步的!)
```

### 验证定频模式

```
# 设置载波参数（2402MHz 单载波连续波）
bt_mp_SetParam 1,0;2,0x08;3,0x00;4,0x00;6,0xFF;7,0x0B;9,0xA078;11,0x000000c6967e;

# 发送
bt_mp_Exec 34

# 停止发送
bt_mp_Exec 35
```

两条 Exec 都返回 [Success:0] + 频谱仪出波形 = 定频模式正常

### 退出 + 恢复

```
disable
quit
```
板上: `systemctl start bluetooth`

### 注意事项

> 脚本化喂命令必须加节拍（否则 enable 完成前执行后续命令会全报 [BT not enabled]）:

```bash
{ printf "enable usb:/dev/hci0\n"; sleep 15; printf "bt_mp_Exec 34\n"; sleep 5; printf "bt_mp_Exec 35\n"; printf "disable\n"; sleep 1; printf "quit\n"; } | /usr/local/bin/rtlbtmp
```

---

## 3. 测试前版本自检

```bash
# WiFi 驱动: 版本 + 内核匹配 (vermagic 必须与 uname -r 完全一致, install.sh 装时已校验)
modinfo 88x2ce | grep -E "^version|^vermagic"
#   预期 version: v5.14.0.4-281-g3cdcb2de9.20250723_COEX20240327-2727_beta

# rtwpriv 工具版本
rtwpriv -v
#   预期: rtwpriv version:V5.8.6_20230526

# BT 工具: 启动横幅含 "Bluetooth MP Test Tool Starting 2024.05.9"
# BT MP 固件加载校验 = enable usb:/dev/hci0 返回 enable[Success:0] (§2)
# WiFi 侧芯片校验 = mp_get_txpower 返回功率索引/dBm (§1 验证步骤)
```

完整测试矩阵(各调制/信道/速率/功率/RX)见 `定频软件/` 原始文档(模组厂 XLS 指令表)。

## 4. FAQ

### 天线编号

```bash
默认使用 1 编号来测试，2 编号没有蓝牙信号
```
