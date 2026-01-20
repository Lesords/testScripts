# reCamera

## 设备信息

USB 直连模式下的 IP
```bash
192.168.42.1
```

默认登录用户名和密码
```bash
用户名: recamera
密码: recamera
```

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
