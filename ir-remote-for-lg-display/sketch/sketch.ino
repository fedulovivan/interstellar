// https://github.com/Arduino-IRremote/Arduino-IRremote
#include <IRremote.h>
// https://github.com/contrem/arduino-timer
#include <arduino-timer.h>

auto leftBtnTimer = timer_create_default();
auto rightBtnTimer = timer_create_default();

int IR_RECEIVE_PIN = 2;

int LEFT_BTN_PIN = 3;
int RIGHT_BTN_PIN = 4;

int BTN_DELAY = 300;

void leftBtnRelease() {
    digitalWrite(LEFT_BTN_PIN, LOW);
}

void rightBtnRelease() {
    digitalWrite(RIGHT_BTN_PIN, LOW);
}

void setup() {

    pinMode(LEFT_BTN_PIN, OUTPUT);
    pinMode(RIGHT_BTN_PIN, OUTPUT);

    digitalWrite(LEFT_BTN_PIN, LOW);
    digitalWrite(RIGHT_BTN_PIN, LOW);

    Serial.begin(115200);

    IrReceiver.begin(IR_RECEIVE_PIN, ENABLE_LED_FEEDBACK, USE_DEFAULT_FEEDBACK_LED_PIN);

    Serial.print(F("Ready to receive IR signals at pin "));
    Serial.println(IR_RECEIVE_PIN);
}

void loop() {

    if (IrReceiver.decode()) {

        int isRepeat = IrReceiver.decodedIRData.flags & IRDATA_FLAGS_IS_REPEAT;

        if (IrReceiver.decodedIRData.command == 0x2 /* && !isRepeat */) {
            Serial.println("VOL up");
            digitalWrite(LEFT_BTN_PIN, HIGH);
            leftBtnTimer.in(BTN_DELAY, leftBtnRelease);
        }

        if (IrReceiver.decodedIRData.command == 0x3 /* && !isRepeat */) {
            Serial.println("VOL down");
            digitalWrite(RIGHT_BTN_PIN, HIGH);
            rightBtnTimer.in(BTN_DELAY, rightBtnRelease);
        }

        IrReceiver.resume();
    }

    leftBtnTimer.tick();
    rightBtnTimer.tick();
}
