# reComputer-R21

## Ubuntu 驱动适配

```bash
# R21 设备兼容 ubuntu 系统
sudo apt install git

git clone https://github.com/Seeed-Studio/seeed-linux-dtoverlays
cd seeed-linux-dtoverlays
sudo ./scripts/reTerminal.sh --device reComputer-R2x

sudo sed -i 's/^dtparam=spi=on/# dtparam=spi=on/' /boot/firmware/config.txt
sudo sed -i 's/^dtparam=i2c_arm=on/# dtparam=i2c_arm=on/' /boot/firmware/config.txt
sudo sed -i '$a dtoverlay=reComputer-R21' /boot/firmware/config.txt

sudo reboot
```

文件介绍：
```bash
config-origin.txt: ubuntu 系统原始配置文件
config-work.txt:   ubuntu 系统驱动适配后的配置文件
```
