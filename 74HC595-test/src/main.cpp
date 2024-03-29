#include <Arduino.h>

// downloaded from https://github.com/AlexGyver/GyverLibs/releases/download/GyverTimers/GyverTimers.zip
#include <GyverTimers.h>

// downloaded from https://github.com/WifWaf/MH-Z19/archive/refs/heads/master.zip
#include <MHZ19.h>

// 74HC595 ST_CP pin
#define LATCH_PIN 8
// 74HC595 SH_CP pin
#define CLOCK_PIN 13
// 74HC595 DS pin
#define DATA_PIN 12

// tick period for the test sketch
// counter update speed
#define COUNTER_TICK_PERIOD 10

// doubled dynamic indication frequency
#define FREQUENCY 800

// total count of digits in indicator
#define TOTAL_DIGITS 4

// mhz19 baudrate
#define BAUDRATE 9600

// character to segments mappings
#define _0 0b00111111
#define _1 0b00000110
#define _2 0b01011011
#define _3 0b01001111
#define _4 0b01100110
#define _5 0b01101101
#define _6 0b01111101
#define _7 0b00100111
#define _8 0b01111111
#define _9 0b01101111
#define _OFF 0b000000000
#define _ERROR_CH 0b011111001
#define _MINUS 0b01000000

// number to corresponding character mapping
uint8_t NUMBER_SYMBOLS[10] = {_0, _1, _2, _3, _4, _5, _6, _7, _8, _9};

// arduino pins connected to indicator digits
uint8_t DIGIT_PINS[TOTAL_DIGITS] = {
    4,
    5,
    6,
    7,
};

// global variable which stores dispayed characters
// filled with writeSymbols
uint8_t DISPLAYED_SYMBOLS[TOTAL_DIGITS] = {
    _MINUS,
    _MINUS,
    _MINUS,
    _MINUS
};

unsigned long counterTickTimer = 0L;
unsigned long readCo2Timer = 0;
int counter = 0;
uint8_t currentDigit = 0;

MHZ19 myMHZ19;

uint8_t getSymbolFromNumber(uint8_t value) {
    if (value >= 0 && value <= 9) {
        return NUMBER_SYMBOLS[value];
    }
    return _MINUS;
}

void writeSymbol(uint8_t symbol) {
    digitalWrite(LATCH_PIN, LOW);
    shiftOut(DATA_PIN, CLOCK_PIN, MSBFIRST, ~symbol);
    digitalWrite(LATCH_PIN, HIGH);
}

void offAll() {
    writeSymbol(_OFF);
}

void writeCurrentDigit() {
    writeSymbol(DISPLAYED_SYMBOLS[currentDigit]);
}

void writeSymbols(uint8_t d1, uint8_t d2, uint8_t d3, uint8_t d4, uint8_t output[]) {
    output[0] = d1;
    output[1] = d2;
    output[2] = d3;
    output[3] = d4;
}

void splitNumberIntoSymbols(int input, uint8_t output[]) {
    uint8_t d1 = getSymbolFromNumber(input % 10);
    uint8_t d2 = getSymbolFromNumber((input / 10) % 10);
    uint8_t d3 = getSymbolFromNumber((input / 100) % 10);
    uint8_t d4 = getSymbolFromNumber((input / 1000) % 10);
    writeSymbols(
        d1,
        d2,
        d3,
        d4 == 0 ? _MINUS : d4,
        output
    );
}

/**
 * setup
 */
void setup() {

    // init 74HC595 pins
    pinMode(LATCH_PIN, OUTPUT);
    pinMode(CLOCK_PIN, OUTPUT);
    pinMode(DATA_PIN, OUTPUT);

    // common anodes pins
    for (int i = 0; i < TOTAL_DIGITS; i++) {
        pinMode(DIGIT_PINS[i], OUTPUT);
    }

    // dynamic indication frequency
    Timer1.setFrequency(FREQUENCY);
    Timer1.enableISR(CHANNEL_A);

    // hardware serial which is connected to mhz19
    Serial.begin(BAUDRATE);
    myMHZ19.begin(Serial);
    myMHZ19.autoCalibration();

}

/**
 * main loop
 */
void loop() {

    // if (millis() - counterTickTimer >= COUNTER_TICK_PERIOD) {
    //     if (counter < 9999) {
    //         counter++;
    //     } else {
    //         counter = 0;
    //     }
    //     splitNumberIntoSymbols(counter, DISPLAYED_SYMBOLS);
    //     counterTickTimer = millis();
    // }

    if (millis() - readCo2Timer >= 2000) {
        int CO2 = myMHZ19.getCO2(false);
        if (myMHZ19.errorCode == RESULT_OK) {
            splitNumberIntoSymbols(CO2, DISPLAYED_SYMBOLS);
        } else {
            writeSymbols(
                getSymbolFromNumber(myMHZ19.errorCode),
                _ERROR_CH,
                _OFF,
                _OFF,
                DISPLAYED_SYMBOLS
            );
        }
        readCo2Timer = millis();
    }

}

/**
 * interrupt service routine
 */
ISR(TIMER1_A) {

    // switch off all segments
    offAll();

    // switch off all digits
    for (int i = 0; i < TOTAL_DIGITS; i++) {
        digitalWrite(DIGIT_PINS[i], HIGH);
    }

    // fire digit for current update cycle
    digitalWrite(DIGIT_PINS[currentDigit], LOW);

    // write segments for current digit
    writeCurrentDigit();

    // loop over 4 digits of indicator
    if (currentDigit < TOTAL_DIGITS - 1) {
        currentDigit++;
    } else {
        currentDigit = 0;
    }

}
