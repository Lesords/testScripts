# InwayConnect-CM5

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
