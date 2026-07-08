#!/usr/bin/env python3

import RPi.GPIO as GPIO
import time
import os

num = 0

GPIO.setmode(GPIO.BCM)  # Set GPIO numbering mode
GPIO.setup(25, GPIO.IN, pull_up_down=GPIO.PUD_UP)  # Set GPIO25 as input with pull-up resistor
GPIO.add_event_detect(25, GPIO.FALLING, bouncetime=500)  # Add debounce time for stabilization

while True:
    if GPIO.event_detected(25):
        print("...External power off detected...")
        os.system("sync")  # Ensure data is written to disk
        print("...Saving data...")
        time.sleep(3)
        os.system("sync")  # Save data again

        while num < 5:
            print(f"--- {5 - num} seconds remaining ---")
            num += 1
            time.sleep(1)

        os.system("sudo shutdown -h now")  # Execute system shutdown
