# RK3576-IO-Board

## 压力步骤

环境安装
```bash
sudo apt update
sudo apt install stress-ng
sudo apt install mpg123
```

压力测试工具
```bash
stress_test.sh
```

使用方法
```bash
./stress_test.sh
```

## GPU 测试步骤

环境安装
```bash
apt-get update

apt install -y glmark2-es2-drm
```

测试步骤
```bash
# 1. 先关闭桌面（lightdm 占用 DRM master，不关无法运行 DRM 渲染测试）
systemctl stop lightdm

# 2. 运行 GPU 压测（跑 60 秒，期间用万用表量 VDD_GPU_S0）
timeout 60 glmark2-es2-drm

# 3. 恢复桌面
systemctl start lightdm
```

## NPU 测试步骤

测试文件
```bash
rknn_benchmark_Linux.tar.gz
```

拷贝文件到 RK3576-IO-Board
```bash
scp rknn_benchmark_Linux.tar.gz root@<IP_ADDRESS>:/root
```

解压后进入目录
```bash
tar -zxvf rknn_benchmark_Linux.tar.gz

cd rknn_benchmark_Linux

# 执行
./start.sh
```
