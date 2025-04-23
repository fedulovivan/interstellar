## Description

An experiment to try a toolchain for compiling and flashing avr mcu using only cli tools like avr-gcc and avrdude (no arduino, no platformio)

## Prerequisites

`brew install avrdude`
`brew tap osx-cross/avr && brew install avr-gcc`

## Variant 1 (bare c)

1. read connected device signature (optional) `avrdude -c usbasp -p atmega328p -v`
2. compile `avr-gcc -mmcu=atmega328p -Os -o blink.elf blink.c && avr-objcopy -O ihex -R .eeprom blink.elf blink.hex`
3. flash `avrdude -c usbasp -p atmega328p -U flash:w:blink.hex:i`

## Variant 2 (arduino libraries, still bare cli tooling, advises and makefiles by chatgpt)

make
make flash
make clean

https://chatgpt.com/c/67c9f6ec-6504-8009-b9ec-7ae77a887b88

