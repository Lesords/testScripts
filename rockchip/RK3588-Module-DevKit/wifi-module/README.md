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

### 进入

```bash
# 无输出就稍等几秒再继续(主线驱动初始化完成的标志)
ls /sys/class/net | grep -E '^wl'
systemctl stop NetworkManager
rmmod 88x2ce 2>/dev/null
# 关键: 若上次残留已加载, 必须先卸(modprobe 对已加载模块是空操作, 不会重新探测设备)
rmmod rtw88_8822ce
modprobe 88x2ce
# 等驱动注册网卡, 必须等
sleep 3

# 接口名 udev 会改, 动态取
WIFI=$(ls /sys/class/net | grep -E '^wl' | head -1)
[ -n "$WIFI" ] || echo "未发现无线网卡! 查: dmesg | grep -i 88x2ce | tail -5"
ip link set $WIFI up

rtwpriv $WIFI mp_start
# 出现 "mp_start ok" 即已进入定频模式
```

### 验证定频模式正常（3 条命令）

```bash
rtwpriv $WIFI mp_get_txpower 0
# 预期: 返回功率索引+dBm(如 94 / 21dBm) → 芯片通信正常

# ch36/BW20/MCS0 发包
rtwpriv $WIFI 36 0 a HTMCS0 1
rtwpriv $WIFI mp_query
# 预期: Tx OK > 0 且 Fail = 0 → 发射正常

# 停发
rtwpriv $WIFI stop
```

三条全过 = 定频模式正常, 可接仪表。想验接收: `mp_channel 1 && mp_ant_rx a && mp_arx start && mp_arx phy`(实验室环境应看到收包计数)。

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

### 进入

```bash
systemctl stop bluetooth && pkill -9 bluetoothd
modprobe btusb && hciconfig hci0 up
/usr/local/bin/rtlbtmp
> enable usb:/dev/hci0
# 等 enable[Success:0] 再继续(enable 是异步的!)
```

### 验证定频模式正常（2402MHz 单载波一起一停）

```
bt_mp_SetParam 1,0;2,0x08;3,0x00;4,0x00;6,0xFF;7,0x0B;9,0xA078;11,0x000000c6967e;

# 单载波起 — 频谱仪 2402MHz 应出载波
bt_mp_Exec 34

# 停
bt_mp_Exec 35
```

两条 Exec 都返回 [Success:0] + 频谱仪出波形 = 定频模式正常。

### 退出 + 恢复

```
disable
quit
```
板上: `systemctl start bluetooth`

脚本化喂命令必须加节拍（否则 enable 完成前执行后续命令会全报 [BT not enabled]）:
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
