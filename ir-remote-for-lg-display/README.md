
## Flashing sketch

Dont forget to alter boards.txt file for correct programming chinese arduino pro mini with atmega 168p
File location: `/Applications/Arduino.app/Contents/Java/hardware/arduino/avr/boards.txt`
Replace string `pro.menu.cpu.16MHzatmega168.build.mcu=atmega168` with `pro.menu.cpu.16MHzatmega168.build.mcu=atmega168p`.
Then Arduino IDE should be restarted.
(!) Dont forget to compile sketch for 8mhz board when setSystemPrescaler is used
(!) Optionally you may need to replace `pro.menu.cpu.8MHzatmega168.build.mcu=atmega168` with `pro.menu.cpu.8MHzatmega168.build.mcu=atmega168p` when setSystemPrescaler is used.

## Arduino Pro Mini Board modifications to descrease power consumption

- Removed 5v SOT-23 voltage regulator
- Removed power indicator red led

## Diptrace Notes

Used external library https://github.com/Just-AndyE/DipTrace-Adruino-Library