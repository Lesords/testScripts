#!/bin/sh
# ES8311 音频修复脚本(合并版)— 一次性修复录音 + 播放 + store 持久化
#
# 背景:原 es8311-fix-audio.sh(播放)末尾没有 alsactl store,导致 hp/Headphone 开关
#       不持久(重启回 off);而 es8311-fix-capture.sh(录音)有 store,会把播放的 off
#       一起固化。两个脚本分开跑会出现"修好一个另一个坏"的假象。
# 本脚本:录音(ADC)+ 播放(DAC + Headphone)全改,末尾统一 store,跑一次全好且持久。
# 用 name= 不用 numid=,跨板通用。

# ============ 播放(DAC + 耳机输出)============
amixer -c 0 cset name='Headphone'        1   > /dev/null 2>&1   # 耳机输出开关(控 widget + hp-con 功放,播放关键)
amixer -c 0 cset name='hp switch'         1   > /dev/null 2>&1   # 耳机开关(辅助)
amixer -c 0 cset name='DAC SDP MUTE'      0   > /dev/null 2>&1   # 解除 DAC 数字输入静音
amixer -c 0 cset name='DAC DSM MUTE'      0   > /dev/null 2>&1
amixer -c 0 cset name='DAC DEM MUTE'      0   > /dev/null 2>&1
amixer -c 0 cset name='DAC INVERT'        0   > /dev/null 2>&1
amixer -c 0 cset name='DAC RAM CLR'       0   > /dev/null 2>&1   # 停止清零 DAC RAM
amixer -c 0 cset name='DAC RAMP RATE'     0   > /dev/null 2>&1   # 禁软斜坡(否则音量爬升慢)
amixer -c 0 cset name='DAC VOLUME'        120 > /dev/null 2>&1   # 0dB
amixer -c 0 cset name='DAC OFFSET'        0   > /dev/null 2>&1
amixer -c 0 cset name='DAC SDP SRC MUX'   0   > /dev/null 2>&1   # SELECT SDP LEFT DATA

# ============ 录音(ADC)============
amixer -c 0 cset name='ADC SDP MUTE'      0   > /dev/null 2>&1   # 解除 ADC 输出静音(传输层)
amixer -c 0 cset name='ADC RAM CLR'       0   > /dev/null 2>&1   # 停止清零 ADC RAM(数据层)
amixer -c 0 cset name='BCLK INVERT'       0   > /dev/null 2>&1   # I2S 时钟不反相
amixer -c 0 cset name='MCLK INVERT'       0   > /dev/null 2>&1
amixer -c 0 cset name='ALC ENABLE'        0   > /dev/null 2>&1
amixer -c 0 cset name='ALC MAX LEVEL'     0   > /dev/null 2>&1
amixer -c 0 cset name='ALC MIN LEVEL'     0   > /dev/null 2>&1
amixer -c 0 cset name='ALC WIN SIZE'      0   > /dev/null 2>&1
amixer -c 0 cset name='ALC AUTOMUTE GATE THRESHOLD' 0 > /dev/null 2>&1
amixer -c 0 cset name='ALC AUTOMUTE VOLUME'         0 > /dev/null 2>&1
amixer -c 0 cset name='ALC AUTOMUTE WINSIZE'        0 > /dev/null 2>&1
amixer -c 0 cset name='DRC ENABLE'        0   > /dev/null 2>&1
amixer -c 0 cset name='DRC MAX LEVEL'     0   > /dev/null 2>&1
amixer -c 0 cset name='DRC MIN LEVEL'     0   > /dev/null 2>&1
amixer -c 0 cset name='DRC WIN SIZE'      0   > /dev/null 2>&1
amixer -c 0 cset name='ADC OSR'           16  > /dev/null 2>&1
amixer -c 0 cset name='ADC SCALE'         4   > /dev/null 2>&1
amixer -c 0 cset name='ADC RAMP RATE'     0   > /dev/null 2>&1
amixer -c 0 cset name='ADC VOLUME'        191 > /dev/null 2>&1   # 0dB
amixer -c 0 cset name='MIC PGA GAIN'      6   > /dev/null 2>&1   # 18dB
amixer -c 0 cset name='ADC FS MODE'       0   > /dev/null 2>&1
amixer -c 0 cset name='ADC INVERTED'      0   > /dev/null 2>&1
amixer -c 0 cset name='ADC SYNC'          1   > /dev/null 2>&1
amixer -c 0 cset name='DMIC MUX'          0   > /dev/null 2>&1   # 走模拟 AMIC

# 持久化(关键:写回 asound.state,重启保持)
alsactl store                                  > /dev/null 2>&1

echo "ES8311 audio + capture fix applied (full) + stored"
