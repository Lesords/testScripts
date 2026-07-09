#!/usr/bin/env python3

import smbus
import time

bus = smbus.SMBus(3)

bus.write_byte_data(0x54, 0x02, 0x20)
time.sleep(0.5)
data = bus.read_i2c_block_data(0x54, 0x00, 2)
raw_adc = ((data[0] & 0x0F) * 256 + (data[1] & 0xF0) / 256)

print("Digital value of Analog Input : %d" %raw_adc)
