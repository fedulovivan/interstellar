## Description

A seperate CO2 sensor box with wifi interface which connects to mqtt server and sends statistics.
esp8266 flashed with latest nodemcu. Firmware is written on lua. CO2 sensor is mhz19b.

## Flashing esp8266 with nodemcu

1. install flashing tool `pip install esptool`
1. build fresh firmware binary with on https://nodemcu-build.com/
1. power esp8266 with GPOI0 connected to ground
1. flash `esptool.py --baud 115200 --port /dev/tty.wchusbserial1420 write_flash 0x0000 ~/Downloads/nodemcu-dev-11-modules-2021-12-16-18-33-39-integer.bin`

## Uploading lua script

1. Remove jumpers which connect mhz19 UART with esp8266 UART
1. Connect ch340 UART adapter to board
1. Connect adapter to laptop
1. Press flashing red button on the bottom of board
1. Connect microusb cable to power the board
1. Use command to flash `luac -p mqtt.lua && nodemcu-tool upload mqtt.lua`
1. Double-check size of uploaded size manually with `nodemcu-tool fsinfo`

## Schematics
TODO

## Firmware

init.lua - entrypoint
mqtt.lua - main script

## Notes

More text lua scripts are located in ../nodemcu-old