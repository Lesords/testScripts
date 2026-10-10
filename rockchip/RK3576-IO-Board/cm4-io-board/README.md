# 适配 CM4 IO Board 底板

## 编译

`output/` 已含预编译产物，可直接部署使用，无需编译。仅当修改了 `dts/` 源文件后才需要重新编译：

```bash
make              # dts/*.dts → output/*.dtbo（增量编译）
make install      # 编完 scp 到设备 /boot/dtb/rockchip/overlay/（默认 10.0.0.128，DEVICE=x.x.x.x 可覆盖）
make clean
```

依赖仅系统 `dtc`（device-tree-compiler 包）+ `cpp`，无需内核树。新 `.dts` 放入 `dts/` 即自动纳入。

## 使用

产物拷到设备 `/boot/dtb/rockchip/overlay/`（`make install` 或手动 scp），在 `/boot/armbianEnv.txt` 中按需组合：

```
# 热插拔版
overlays=rk3576-usb-drd0-host rk3576-usb-hub-reset rk3576-sdmmc0-1bit
# 或
overlays=rk3576-usb-drd0-host rk3576-usb-hub-reset rk3576-sdmmc0-1bit-noremovable
```

| overlay | 作用 |
|--------|------|
| `rk3576-usb-drd0-host` | Type-C 口固定 host 模式 |
| `rk3576-usb-hub-reset` | 拉高 GPIO2_C1 释放板上 USB hub 复位 |
| `rk3576-sdmmc0-1bit` | SD 1-bit + 轮询热插拔（无卡检测引脚的底板） |
| `rk3576-sdmmc0-1bit-noremovable` | SD 1-bit + 固定设备（无热插拔，与上行二选一） |

重启生效。

验证：`dmesg | grep "1-1:1.0"` 应见 `4 ports detected`（hub），`cat /proc/device-tree/usb@23000000/dr_mode` 应为 `host`。
