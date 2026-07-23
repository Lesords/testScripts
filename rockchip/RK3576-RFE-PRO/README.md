# RK3576-RFE-PRO

## 设备信息

```bash
账号：linaro
密码：linaro
```

## 打开 Root 账号的 SSH 连接服务

```bash
# 打开配置文件
vim /etc/ssh/sshd_config

# 修改以下配置项
PermitRootLogin yes

# 重新启动 SSH 服务
systemctl restart sshd

# 设置 root 密码
passwd root
```

## eeprom

```bash
# 查看 eeprom 相关信息
dmesg | grep -i eeprom

# 读写测试
cd /sys/class/i2c-dev/i2c-2/device/2-0050
cat eeprom | hexdump -C
echo hh > ./eeprom
```

## GPU 测试步骤

测试步骤
```bash
# 1. 先关闭桌面（lightdm 占用 DRM master，不关无法运行 DRM 渲染测试）
systemctl stop lightdm

# 2.1 运行 GPU 测试（跑 60 秒，随机场景）
timeout 60 glmark2-es2-drm

# 2.2 高负载命令
glmark2-es2-drm --run-forever --swap-mode immediate \
    -b terrain:bloom=true:tilt-shift=true

# 2.3 较低负载命令
glmark2-es2-drm -b shading --run-forever

# 3. 恢复桌面
systemctl start lightdm
```

查看 GPU 负载
```
cat /sys/class/devfreq/27800000.gpu/load
```
