# testScripts

本仓库用于整理多个 Seeed 硬件平台的 bring-up、功能验证、压力测试、RF 测试、刷机和调试相关脚本与资源。

仓库按产品或板卡系列拆分目录。根目录 README 只作为入口索引，具体测试步骤优先查看各目录下的 `README.md`。

## 目录说明

| 路径 | 内容 |
| --- | --- |
| [InwayConnect-CM5/](InwayConnect-CM5/) | CM5 载板驱动、接口、传感器、电源和压力测试。 |
| [beaglebadge/](beaglebadge/) | BeagleBadge / Beaglebone 启动、调试、RF、低功耗和外设测试。 |
| [rockchip/RK3576-IO-Board/](rockchip/RK3576-IO-Board/) | RK3576 IO Board 刷机、压力、GPU/NPU、显示、蓝牙和 RTC 测试。 |
| [reCamera/](reCamera/) | reCamera 设备访问、OTA、压力测试、HaLow 驱动和定频测试。 |
| [reComputer-R22/](reComputer-R22/) | reComputer R22 Ubuntu 适配、PCIe overlay、GPIO 和网口工具。 |
| [recomputer-R21/](recomputer-R21/) | reComputer R21 Ubuntu 适配说明和配置文件参考。 |
| [XIAO-RP2350/](XIAO-RP2350/) | RP2350 powman 低功耗示例。 |
| [XIAO-RA4M1/](XIAO-RA4M1/) | XIAO RA4M1 DFU 固件资源。 |
| [micropython/](micropython/) | Blink、RGB、ADC、OLED 等 MicroPython 示例。 |
| [Debugger/Debugger_test_seeeduino/](Debugger/Debugger_test_seeeduino/) | Seeed XIAO 系列 PlatformIO 上传和调试测试工程。 |

## 快速使用

1. 确认目标板卡或产品型号，进入对应目录。
2. 阅读该目录下的 `README.md`，按需拷贝脚本、工具、固件或配置文件到目标设备。
3. 在目标设备上安装依赖并执行测试命令；部分命令需要 `root` 或 `sudo` 权限。

## 安全注意事项

- 执行前先阅读脚本内容。部分测试会修改 GPIO、停止网络服务、写入启动介质、刷写固件或触发看门狗复位。
- 执行命令前确认板卡型号、系统版本/镜像、接口名和 GPIO 编号是否匹配当前设备。
- 压力、RF、Camera、GPU、NPU 和电源相关测试可能影响温度、网络连接或系统稳定性，建议保留串口或其他恢复路径。
