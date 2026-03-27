# reComputer-R22

## Ubuntu 驱动适配

```bash
sudo apt install git

git clone https://github.com/Seeed-Studio/seeed-linux-dtoverlays
cd seeed-linux-dtoverlays
sudo ./scripts/reTerminal.sh --device reComputer-R22

sudo sed -i 's/^dtparam=spi=on/# dtparam=spi=on/' /boot/firmware/config.txt
sudo sed -i 's/^dtparam=i2c_arm=on/# dtparam=i2c_arm=on/' /boot/firmware/config.txt
sudo sed -i '$a dtoverlay=reComputer-R22' /boot/firmware/config.txt

sudo sed -i 's/^dtparam=spi=on/# dtparam=spi=on/' /boot/firmware/config.txt
sudo sed -i 's/^dtparam=i2c_arm=on/# dtparam=i2c_arm=on/' /boot/firmware/config.txt

sudo reboot
```

## Ubuntu 多网口适配

修复 pcie bug 的设备树文件

```bash
pciex1-compat-pi5-overlay.dts
pciex1-compat-pi5.dtbo
```
