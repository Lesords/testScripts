#!/bin/bash

ioctl_app dtop "08 00 00 00 2e 00 00 01"
ioctl_app wifi "dstart 15 1 0"
ioctl_app wifi "mp_mode_en 0"
