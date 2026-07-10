# Raw magnetometer data (is it accessible over SPI?)
# DPM Data
# Incorporate in Versatile Framework

import time
from .ICM20948 import ICM20948
from .bus import SPI_Bus, I2C_Bus

import argparse

parser = argparse.ArgumentParser(description='Test ICM20948 IMU')
parser.add_argument('--i2c', action='store_true', help='Use I2C interface instead of SPI')
args = parser.parse_args()


imu = ICM20948()

for i in range(10):
    try:
        if args.i2c:
            bus = I2C_Bus()
        else:
            bus = SPI_Bus()

        imu._setup(bus)
    except Exception as e:
        print('got exception: {} - trying again'.format(e.args[0]))

    if imu.AK09916_initialized:
        break


# Print out reading every second
while True:
    print('  '.join(['{:> 7.3}'.format(float(x)) for x in imu.measure()]))
    # 设置中断引脚为低电平
    print("IMU_INT Low\n")
    config = (1 << 4) | (0 << 7)  # INT_EN: 使能所有中断，INT1_ACTL:
    imu._acc.WriteReg(0x0F, config)
    time.sleep(1)
    # 设置中断引脚为高电平
    print("IMU_INT High\n")
    config = (1 << 4) | (1 << 7)  # INT_EN: 使能所有中断，INT1_ACTL:
    imu._acc.WriteReg(0x0F, config)
    time.sleep(1)
