# Vendor Storage — MAC 地址产线写入工具

## 工具

| 文件 | 来源 | 说明 |
|------|------|------|
| `vendor_storage_official.c` | Rockchip buildroot（官方） | `-r ID` / `-w ID,DATA` / `-R` 读全部 |
| `vendor_storage.c` | 自定义简化版 | `-r ID -t hex` / `-w ID -t hex -i DATA` |

## 编译

```bash
make                    # 编译两个工具（设备上直接跑）
make install            # 安装到 /usr/local/bin/
```

## 使用

```bash
# 读 LAN MAC
vendor_storage_official -r VENDOR_LAN_MAC_ID
vendor_storage -r VENDOR_LAN_MAC_ID -t hex

# 写 LAN MAC（首次开机前！）
vendor_storage_official -w VENDOR_LAN_MAC_ID,AABBCCDDEEFF
vendor_storage -w VENDOR_LAN_MAC_ID -t hex -i AABBCCDDEEFF

# 读全部
vendor_storage_official -R

# 帮助
vendor_storage_official -h
vendor_storage -h
```

## 产线流程

```
① 刷固件（eMMC 全新/低格）
② 写入 MAC（本工具，首次开机前）
③ 首次开机（U-Boot 读到我们的 MAC，不生成随机值）
④ 刷机升级（vendor storage 保留，MAC 不变）
```

## 存储位置

eMMC 扇区 7168，4 副本 × 64KB

## 注意

- 已开过机的板子，U-Boot env 缓存了随机 MAC，改 vendor storage 不生效
- 产线必须**首次开机前**写入
- `/tmp` 重启清空，工具需部署到 `/usr/local/bin/`
