#!/bin/bash

# 脚本名称: export_gpio_out.sh
# 脚本功能: 自动导出指定的树莓派GPIO引脚，设置其为输出模式，
#           并根据参数设置高电平或低电平。
#           如果GPIO已被导出，则直接进行电平设置。
# 用法:
#   ./export_gpio_out.sh <GPIO_NUMBER> <LEVEL>
#   <GPIO_NUMBER>: 树莓派的GPIO编号 (例如: 627)
#   <LEVEL>: 0 (低电平) 或 1 (高电平)
# 示例:
#   设置GPIO 627为输出并置为低电平: ./export_gpio_out.sh 627 0
#   设置GPIO 627为输出并置为高电平: ./export_gpio_out.sh 627 1

# 检查参数数量
if [ "$#" -ne 2 ]; then
    echo "用法: $0 <GPIO_NUMBER> <LEVEL>"
    echo "  <GPIO_NUMBER>: 树莓派的GPIO编号 (例如: 627)"
    echo "  <LEVEL>: 0 (低电平) 或 1 (高电平)"
    exit 1
fi

GPIO_NUMBER=$1
LEVEL=$2
GPIO_PATH="/sys/class/gpio/gpio${GPIO_NUMBER}"

# 验证GPIO编号是否为数字
if ! [[ "$GPIO_NUMBER" =~ ^[0-9]+$ ]]; then
    echo "错误: GPIO编号 '$GPIO_NUMBER' 必须是数字。"
    exit 1
fi

# 替换原有电平验证逻辑
if ! [[ "$LEVEL" =~ ^[0-9]+$ ]]; then
    echo "错误: 电平参数 '$LEVEL' 必须是数字。"
    exit 1
fi

if [ "$LEVEL" -ne 0 ] && [ "$LEVEL" -ne 1 ]; then
    echo "错误: 电平参数 '$LEVEL' 必须是 0 (低电平) 或 1 (高电平)。"
    exit 1
fi

echo "尝试操作 GPIO $GPIO_NUMBER..."

# 检查GPIO是否已导出
if [ ! -d "$GPIO_PATH" ]; then
    echo "GPIO $GPIO_NUMBER 未导出，正在导出..."
    echo "$GPIO_NUMBER" > /sys/class/gpio/export
    if [ $? -ne 0 ]; then
        echo "错误: 导出GPIO $GPIO_NUMBER 失败。请检查权限或GPIO编号是否有效。"
        echo "尝试使用 'sudo' 运行此脚本，或检查 /sys/class/gpio/export 的权限。"
        exit 1
    fi
    # 给系统一点时间让设备文件创建完成
    sleep 0.1
else
    echo "GPIO $GPIO_NUMBER 已经导出。"
fi

# 检查GPIO目录是否存在，以防导出失败但脚本未捕捉到
if [ ! -d "$GPIO_PATH" ]; then
    echo "错误: GPIO $GPIO_NUMBER 目录不存在，可能是导出失败。"
    exit 1
fi

# 设置GPIO方向为输出
echo "设置GPIO $GPIO_NUMBER 方向为 'out'..."
echo "out" > "${GPIO_PATH}/direction"
if [ $? -ne 0 ]; then
    echo "错误: 设置GPIO $GPIO_NUMBER 方向为 'out' 失败。请检查权限。"
    echo "尝试使用 'sudo' 运行此脚本。"
    exit 1
fi

# 设置GPIO电平
echo "设置GPIO $GPIO_NUMBER 电平为 $LEVEL..."
echo "$LEVEL" > "${GPIO_PATH}/value"
if [ $? -ne 0 ]; then
    echo "错误: 设置GPIO $GPIO_NUMBER 电平失败。请检查权限。"
    echo "尝试使用 'sudo' 运行此脚本。"
    exit 1
fi

echo "GPIO $GPIO_NUMBER 已成功设置为输出模式，并设置为 $LEVEL 电平。"
