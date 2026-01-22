#!/bin/bash

# 脚本名称: export_gpio_in.sh
# 脚本功能: 自动导出指定的树莓派GPIO引脚，设置其为输入模式，
#           并读取并输出其当前值。
#           如果GPIO已被导出，则只读取并输出其值。
# 用法:
#   ./export_gpio_in.sh <GPIO_NUMBER>
#   <GPIO_NUMBER>: 树莓派的GPIO编号 (例如: 628)
# 示例:
#   读取GPIO 628的输入值: ./export_gpio_in.sh 628

# 检查参数数量
if [ "$#" -ne 1 ]; then
    echo "用法: $0 <GPIO_NUMBER>"
    echo "  <GPIO_NUMBER>: 树莓派的GPIO编号 (例如: 628)"
    exit 1
fi

GPIO_NUMBER=$1
GPIO_PATH="/sys/class/gpio/gpio${GPIO_NUMBER}"

# 验证GPIO编号是否为数字
if ! [[ "$GPIO_NUMBER" =~ ^[0-9]+$ ]]; then
    echo "错误: GPIO编号 '$GPIO_NUMBER' 必须是数字。"
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

# 设置GPIO方向为输入 (如果当前不是输入模式)
CURRENT_DIRECTION=$(cat "${GPIO_PATH}/direction" 2>/dev/null)
if [ "$CURRENT_DIRECTION" != "in" ]; then
    echo "设置GPIO $GPIO_NUMBER 方向为 'in'..."
    echo "in" > "${GPIO_PATH}/direction"
    if [ $? -ne 0 ]; then
        echo "错误: 设置GPIO $GPIO_NUMBER 方向为 'in' 失败。请检查权限。"
        echo "尝试使用 'sudo' 运行此脚本。"
        exit 1
    fi
else
    echo "GPIO $GPIO_NUMBER 方向已经是 'in'。"
fi

# 读取GPIO值
echo "正在读取GPIO $GPIO_NUMBER 的值..."
GPIO_VALUE=$(cat "${GPIO_PATH}/value" 2>/dev/null) # 2>/dev/null suppresses errors if file not found
if [ $? -ne 0 ]; then
    echo "错误: 读取GPIO $GPIO_NUMBER 的值失败。请检查权限。"
    echo "尝试使用 'sudo' 运行此脚本。"
    exit 1
fi

echo "------------------------------------"
echo "GPIO $GPIO_NUMBER 当前值为: $GPIO_VALUE"
echo "------------------------------------"

echo "操作完成。"
