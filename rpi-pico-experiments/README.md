## Description

RPI Pico test sketches

## Tooling

Go to https://www.raspberrypi.com/documentation/microcontrollers/micropython.html and download https://micropython.org/download/rp2-pico/rp2-pico-latest.uf2

Connect Pico to usb and copy uf2 image to pico disk

Install rshell `pipx install rshell`

## Variant 1 (micropython)

rshell -p /dev/tty.usbmodem1101 --buffer-size 512 cp blink.py /pyboard/main.py
rshell -p /dev/tty.usbmodem1101
cd /pyboard