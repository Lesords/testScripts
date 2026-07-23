#!/bin/sh
# ES8311 音频修复脚本 — 修复开机无声音 / 3分钟预热问题

# DAC RAMP RATE = 0 (disable soft ramp)
# REG37[7:4] 软斜坡速率，0=瞬时变化（根因：15时音量爬升需4.7分钟）
amixer cset numid=67 0   > /dev/null 2>&1

# DAC VOLUME = 120 (0dB)
# REG32 DAC音量，120=0dB
amixer cset numid=62 120 > /dev/null 2>&1

# DAC RAM CLR = off
# REG31[3] DAC RAM清零，1=持续清零导致静音
amixer cset numid=59 0   > /dev/null 2>&1

# DAC DEM MUTE = off
# REG31[5] 去加重静音，1=DAC输出被静音
amixer cset numid=57 0   > /dev/null 2>&1

# DAC INVERT = off
# REG31[4] 输出反相，1=相位翻转180°
amixer cset numid=58 0   > /dev/null 2>&1

# DAC OFFSET = 0
# REG33 直流偏移，非零=输出叠加DC偏移
amixer cset numid=61 0   > /dev/null 2>&1

# DAC SDP MUTE = off
# REG09[6] 数字输入静音，1=丢弃I2S数据
amixer cset numid=56 0   > /dev/null 2>&1

# hp switch = on
# 耳机输出开关，0=关闭无声音
amixer cset numid=77 1   > /dev/null 2>&1

# Headphone Switch = on
# 耳机输出使能，0=关闭无声音
amixer cset numid=78 1   > /dev/null 2>&1

# DMIC MUX = DMIC DISABLE
# ADC输入源选择，板子用模拟麦(AMIC)，应关闭数字麦路径
amixer cset numid=82 0   > /dev/null 2>&1

echo "ES8311 audio config applied"
