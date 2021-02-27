
## Flashing sketch

Dont forget to alter boards.txt file for correct programming chinese arduino pro mini with atmega 168p
File location: `/Applications/Arduino.app/Contents/Java/hardware/arduino/avr/boards.txt`
Replace string `pro.menu.cpu.16MHzatmega168.build.mcu=atmega168` with `pro.menu.cpu.16MHzatmega168.build.mcu=atmega168p`.
Then Arduino IDE should be restarted.

## Arduino Pro Mini Board modifications

- Removed 5v SOT-23 voltage regulator
- PWD red led

## Diptrace Notes

https://github.com/Just-AndyE/DipTrace-Adruino-Library