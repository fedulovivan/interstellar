#!/bin/bash

esptool.py --baud 115200 --port /dev/tty.wchusbserial1420 write_flash 0x0000 ./nodemcu-dev-11-modules-2021-12-16-18-33-39-integer.bin