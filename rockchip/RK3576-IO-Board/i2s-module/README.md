# I2S(SAI3)声卡套件 — MAX98357A

适用:reComputer RK3576 Module Dev Kit,40pin SAI3(M2)。
引脚定义与测试方法见仓库主 [README.md](../README.md) 的「I2S(SAI)引脚测试」。

## 目录结构

| 路径 | 内容 |
| ---- | ---- |
| `sai3-max98357a.dts` | overlay 源(SAI3 控制器 + codec 节点 + simple-audio-card 声卡三件套) |
| `codec-ko/{max98357a.c, Makefile}` | codec 驱动源(取自内核 `sound/soc/codecs/`)与板编封装 |
| `output/sai3-max98357a.dtbo` | 编译产物:设备树 overlay |
| `output/snd-soc-max98357a.ko` | 编译产物:codec 驱动(板上编译,vermagic 对应 `6.1.115-vendor-seeed-rk3576`) |

machine 驱动(simple-audio-card)为内核 builtin(`CONFIG_SND_SIMPLE_CARD=y`),无需编译。

## 路线一:直接使用 output 产物

适用于目标板内核版本与产物一致(`uname -r` 为 `6.1.115-vendor-seeed-rk3576`)。

```bash
# ① dtbo 上板(文件名必须带 overlay_prefix 前缀,否则 armbianEnv 静默不加载)
scp output/sai3-max98357a.dtbo \
    root@<IP_ADDRESS>:/boot/dtb/rockchip/overlay/recomputer-rk3576-module-io-board-40pin-sai3-max98357a.dtbo

# ② ko 入模块库并刷新索引
scp output/snd-soc-max98357a.ko root@<IP_ADDRESS>:/root/
ssh root@<IP_ADDRESS> "cp /root/snd-soc-max98357a.ko /lib/modules/\$(uname -r)/updates/ && depmod -a"

# ③ 启用
# /boot/armbianEnv.txt:
overlay_prefix=recomputer-rk3576-module-io-board
overlays=40pin-sai3-max98357a
```

## 路线二:手动编译

适用于内核版本不同/升级后(ko 必须重编),或修改了 dts/驱动源。

### dtbo(本地编译)

```bash
dtc -q -I dts -O dtb -o sai3-max98357a.dtbo sai3-max98357a.dts
scp sai3-max98357a.dtbo root@<IP_ADDRESS>:/boot/dtb/rockchip/overlay/recomputer-rk3576-module-io-board-40pin-sai3-max98357a.dtbo
```

### ko(板上本地编译,vermagic/CRC 与内核天然匹配;镜像自带 gcc 和 linux-headers)

```bash
scp -r codec-ko root@<IP_ADDRESS>:/root/
ssh root@<IP_ADDRESS>
cd /root/codec-ko && make
cp snd-soc-max98357a.ko /lib/modules/$(uname -r)/updates/
depmod -a
```

## 接线(40pin → codec 模块)

| 40pin | 信号 | MAX98357A |
| ----- | ---- | --------- |
| 15    | SAI3_SDO  | DIN  |
| 7     | SAI3_SCLK | BCLK |
| 22    | SAI3_LRCK | LRC  |
| 1/17  | 3.3V      | VIN  |
| 6 等  | GND       | GND  |

(MCLK 不需接;PCM5102 换 `compatible = "ti,pcm5102a"` 重编即可)

## 验证(重启后)

```bash
lsmod | grep max98357      # codec 驱动被设备树 compatible 自动拉起
aplay -l                   # 出现 "40pin-SAI3" 声卡

# 需要把 N 改为实际声卡号
speaker-test -c 2 -r 48000 -D hw:N,0   # 喇叭粉噪 = 全链路通
mpg123 -a hw:N,0 ./test.mp3
```

## 维护注记

- 内核升级后 `output/` 里的 ko 失效(vermagic 不符),走路线二重编并更新产物
- dtbo 不受内核版本影响
- 与 UART3/SPI3/CAN1_M3/I2C7/PWM2_CH6(脚 12)互斥,勿同挂
