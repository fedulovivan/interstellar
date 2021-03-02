// download from https://github.com/AlexGyver/GyverLibs/tree/master/GyverPower
// and put to /Users/johnny/Documents/Arduino/libraries
#include <GyverPower.h>

void setup() {
    pinMode(13, OUTPUT);
    attachInterrupt(2, wakeup, FALLING);
    power.autoCalibrate();
    power.setSleepMode(POWERDOWN_SLEEP);
    // power.setSystemPrescaler(PRESCALER_2);
    power.hardwareDisable(PWR_ADC | PWR_I2C | PWR_SPI | PWR_UART0 | PWR_UART1 | PWR_UART2 | PWR_UART3);
}

void loop() {
    for(uint8_t i = 0; i < 10; i++) {
        digitalWrite(13, !digitalRead(13));
        delay(300);
    }
    power.sleep(SLEEP_2048MS);
    // power.sleep(SLEEP_FOREVER);
}

void wakeup() {

}
