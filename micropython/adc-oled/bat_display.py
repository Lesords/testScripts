# boot.py

from machine import Pin, ADC, SoftI2C, I2C
import time
from ssd1306 import SSD1306_I2C

i2c = SoftI2C(sda=Pin(6), scl=Pin(7))
display = SSD1306_I2C(128, 64, i2c)
display.rotate(90)
display.text("Hello Seeed",0,0)
display.show()
# Function to initialize the GPIO pin for enabling battery voltage reading

enable_pin = Pin(19, Pin.OUT)
enable_pin.value(1)  # Set the pin to high to enable battery voltage reading

adc = ADC(Pin(29))  # Initialize the ADC on GPIO29

conversion_factor = 3.3 / (1 << 12)  # Conversion factor for 12-bit ADC and 3.3V reference

while True:
    result = adc.read_u16() >> 4  # Read the ADC value
    voltage = result * conversion_factor * 2  # Calculate the voltage, considering the voltage divider (factor of 2)
    #print("Raw value: 0x{:03x}, voltage: {:.2f} V".format(result, voltage))
    print(f"voltage: {voltage:.2f} V")
    display.text(f"voltage: {voltage:.2f} V",0, 10)
    display.show()
    display.fill(0)
    time.sleep(0.5)  # Delay for 500 milliseconds