// https://github.com/Arduino-IRremote/Arduino-IRremote
#include <IRremote.h>

// download from https://github.com/AlexGyver/GyverLibs/releases/download/GyverPower/GyverPower.zip
// and put to ~/Documents/Arduino/libraries
#include <GyverPower.h>

// uncomment to enable debug logging to serial console
// #define DEBUG 1

// gpio pin connected to IR receiver
// should support external interrupts
#define IR_INPUT_PIN 2

#define LEFT_BTN_PIN 3
#define RIGHT_BTN_PIN 4

// duration of emulated button press
#define BTN_PRESS_DURATION 200

// mcu will go to the sleep in three seconds after receiving last command from remote
// this lowers power consumption to 0.9mA
// (99% of this 0.9mA is consumed by 8389 IR receiver which is constanly powered)
#define LAST_CMD_SLEEP_DELAY 3000

// millis when last cmd was received
// should be updated on wake up
unsigned long lastReceivedAt;

void setup() {

    // interrupt handler attached to gpio pin 2
    attachInterrupt(0, wakeup, CHANGE);

    power.autoCalibrate();
    power.setSleepMode(POWERDOWN_SLEEP);

    // scale main clock down from 16mhz to 8mhz to increase stabilty on low voltage
    // since arduino pro mini is powered from 18650 lithium cell
    //
    // also in this case power consumption lowers from ~10mA to ~5mA in active mode (not in sleep),
    // but appears some bug with waking from sleep
    // first command from remote is ignored by unknown reason
    // power.setSystemPrescaler(PRESCALER_2);

    pinMode(LEFT_BTN_PIN, OUTPUT);
    pinMode(RIGHT_BTN_PIN, OUTPUT);

    digitalWrite(LEFT_BTN_PIN, LOW);
    digitalWrite(RIGHT_BTN_PIN, LOW);

    IrReceiver.begin(IR_INPUT_PIN, ENABLE_LED_FEEDBACK, USE_DEFAULT_FEEDBACK_LED_PIN);

    #ifdef DEBUG
        Serial.begin(115200);
        Serial.print(F("Ready to receive IR signals at pin "));
        Serial.println(IR_INPUT_PIN);
    #endif

}

void loop() {

    if (IrReceiver.decode()) {

        int isRepeat = IrReceiver.decodedIRData.flags & IRDATA_FLAGS_IS_REPEAT;

        if (IrReceiver.decodedIRData.command == 0x2 /* && !isRepeat */) {
            #ifdef DEBUG
                Serial.println(F("VOL up"));
            #endif
            digitalWrite(LEFT_BTN_PIN, HIGH);
            delay(BTN_PRESS_DURATION);
            digitalWrite(LEFT_BTN_PIN, LOW);
        }

        if (IrReceiver.decodedIRData.command == 0x3 /* && !isRepeat */) {
            #ifdef DEBUG
                Serial.println(F("VOL down"));
            #endif
            digitalWrite(RIGHT_BTN_PIN, HIGH);
            delay(BTN_PRESS_DURATION);
            digitalWrite(RIGHT_BTN_PIN, LOW);
        }

        lastReceivedAt = millis();
        IrReceiver.resume();

    }

    // enter sleep mode after receiving last command
    if (millis() - lastReceivedAt > LAST_CMD_SLEEP_DELAY) {
        power.sleep(SLEEP_FOREVER);
        #ifdef DEBUG
            Serial.println(F("Gone sleep untill next command from remote"));
        #endif
    }

}

/**
 * exit sleep upon receiving signal on IR receiver
 */
void wakeup() {
    lastReceivedAt = millis();
    IrReceiver.resume();
    #ifdef DEBUG
        Serial.println(F("Waked up"));
    #endif
}
