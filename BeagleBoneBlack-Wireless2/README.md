# BeagleBoneBlack-Wireless2 测试文档

## 目录

- [设备相关](#设备相关)
  - [DFU 模式](#dfu-模式)
  - [账号信息](#账号信息)
  - [使用注意事项](#使用注意事项)
  - [EMMC 启动](#emmc-启动)

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
