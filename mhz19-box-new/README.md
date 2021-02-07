## Description

A seperate CO2 sensor box with wifi interface which connects to mqtt server and sends statistics.
esp8266 flashed with latest nodemcu. Firmware is written on lua. CO2 sensor is mhz19b.

## Flashing

1. Remove jumpers which connects mhz19 UART with esp8266 UART
2. Connect usb-to-serial ch340 adapter to board
3. Connect adapter to laptop
4. Press flashing red button on the bottom of board
5. Connect microusb cable to power the board
6. Use command to flash `luac -p mqtt.lua && nodemcu-tool upload mqtt.lua`
7. Verify size of uploaded size manually with `nodemcu-tool fsinfo`

## Schematics
TODO

## Firmware

init.lua - entrypoint
mqtt.lua - main script

## Notes

More text lua scripts are located in interstellar/nodemcu-old