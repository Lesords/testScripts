#!/bin/sh
# ES8311 录音修复脚本 — 修复录音 peak=0 / 无声
#
# 根因：/var/lib/alsa/asound.state 被整体改乱，ADC/时钟/ALC/DRC 一堆控件都是错值，
#       导致 ADC 无输出（连底噪都没有，peak≈4）。只改 mute/RAM CLR 不够，必须整套复位。
# 方案：对照好板基准值，把录音相关的 ADC 配置全部复位 + store。
# 注：用 name= 而非 numid=，避免不同板子 numid 分配不同失效。

# ===== ADC 数据/传输层 =====
amixer -c 0 cset name='ADC SDP MUTE' 0   > /dev/null 2>&1   # REG0A[6] 解除 ADC→I2S 输出静音
amixer -c 0 cset name='ADC RAM CLR' 0    > /dev/null 2>&1   # 停止持续清零 ADC 数据 RAM

# ===== I2S 时钟极性（反相会采样错位 → ADC 无输出）=====
amixer -c 0 cset name='BCLK INVERT' 0    > /dev/null 2>&1
amixer -c 0 cset name='MCLK INVERT' 0    > /dev/null 2>&1

# ===== ALC / DRC（坏板被开了 + 异常参数压信号）=====
amixer -c 0 cset name='ALC ENABLE' 0                  > /dev/null 2>&1
amixer -c 0 cset name='ALC MAX LEVEL' 0               > /dev/null 2>&1
amixer -c 0 cset name='ALC MIN LEVEL' 0               > /dev/null 2>&1
amixer -c 0 cset name='ALC WIN SIZE' 0                > /dev/null 2>&1
amixer -c 0 cset name='ALC AUTOMUTE GATE THRESHOLD' 0 > /dev/null 2>&1
amixer -c 0 cset name='ALC AUTOMUTE VOLUME' 0         > /dev/null 2>&1
amixer -c 0 cset name='ALC AUTOMUTE WINSIZE' 0        > /dev/null 2>&1
amixer -c 0 cset name='DRC ENABLE' 0                  > /dev/null 2>&1
amixer -c 0 cset name='DRC MAX LEVEL' 0               > /dev/null 2>&1
amixer -c 0 cset name='DRC MIN LEVEL' 0               > /dev/null 2>&1
amixer -c 0 cset name='DRC WIN SIZE' 0                > /dev/null 2>&1

# ===== ADC 参数复位（好板基准）=====
amixer -c 0 cset name='ADC OSR' 16        > /dev/null 2>&1   # 过采样率
amixer -c 0 cset name='ADC SCALE' 4       > /dev/null 2>&1
amixer -c 0 cset name='ADC RAMP RATE' 0   > /dev/null 2>&1
amixer -c 0 cset name='ADC VOLUME' 191    > /dev/null 2>&1   # 0dB
amixer -c 0 cset name='MIC PGA GAIN' 6    > /dev/null 2>&1   # 18dB
amixer -c 0 cset name='ADC FS MODE' 0     > /dev/null 2>&1
amixer -c 0 cset name='ADC INVERTED' 0    > /dev/null 2>&1
amixer -c 0 cset name='ADC SYNC' 1        > /dev/null 2>&1
amixer -c 0 cset name='DMIC MUX' 0        > /dev/null 2>&1   # 走模拟 AMIC

# 持久化（重启保持）
alsactl store                              > /dev/null 2>&1

echo "ES8311 capture config applied (full reset) + stored"
