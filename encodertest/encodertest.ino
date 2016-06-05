#include <LiquidCrystal_I2C.h>
#include <DS1307RTC.h>
#include <LCD.h>

#define I2C_ADDR 0x27 

// these pins below are for pcf8574 from i2c adapter, not arduino
#define BACKLIGHT_PIN 3
#define En_pin  2
#define Rw_pin  1
#define Rs_pin  0
#define D4_pin  4
#define D5_pin  5
#define D6_pin  6
#define D7_pin  7

#define ENC_CLK_PIN  2  // encoder clock pin (also with interrupt attached to it)
#define ENC_DATA_PIN 11 // encoder data pin
#define ENC_SW_PIN 10   // encoder switch pin

#define MODE_NORMAL      0
#define MODE_EDIT_HOUR   1
#define MODE_EDIT_MINUTE 2

#define TOTAL_MODES 3 // total number of modes

#define EDIT_UNDEF -9999 // undefined value for editedValue

byte currentMode = MODE_NORMAL;
int editedValue  = EDIT_UNDEF;

unsigned long lastEncoderRead;
byte encoderSwitchState = LOW;
byte prevEncoderSwitchState;

byte hoursValid[] = {0, 23};
byte minutesValid[] = {0, 59};

// lcd init
LiquidCrystal_I2C lcd(I2C_ADDR, En_pin, Rw_pin, Rs_pin, D4_pin, D5_pin, D6_pin, D7_pin);

// time read from RTC module
tmElements_t tm;

void setup()
{
 
  // init lcd
  lcd.begin(20,4);
  lcd.setBacklightPin(BACKLIGHT_PIN, POSITIVE);
  lcd.setBacklight(HIGH);

  pinMode(ENC_CLK_PIN, INPUT);
  pinMode(ENC_DATA_PIN, INPUT);
  pinMode(ENC_SW_PIN, INPUT);

  attachInterrupt(digitalPinToInterrupt(ENC_CLK_PIN), handleEncoderClockInterrupt, CHANGE);

}

void loop()
{
  
  RTC.read(tm);

  encoderSwitchState = digitalRead(ENC_SW_PIN);
  
  // switch modes in loop
  if(prevEncoderSwitchState != encoderSwitchState && encoderSwitchState) {
    if(currentMode < TOTAL_MODES - 1) {
      currentMode++;
    } else {
      currentMode = 0;
    }
    editedValue = EDIT_UNDEF; // reset edited value each time when mode changes
  }
  prevEncoderSwitchState = encoderSwitchState; // remember last to be able to detect state change on next iteration

  updateEditedValue();
  
  updateLcd();
  
  delay(100);
}


void handleEncoderClockInterrupt() 
{

  if(currentMode == MODE_NORMAL) return; // ignore if not in edit mode
  
  unsigned long currTime = micros();

  int incr = currTime - lastEncoderRead < 5 * 1000 ? 10 : 1; // boost increment value when rotating rapidly, 5ms between pulses
  
  if(digitalRead(ENC_CLK_PIN) == digitalRead(ENC_DATA_PIN)) { // check rotation direction - CW or CCW
    editedValue += incr;  
  } else {
    editedValue -= incr;
  }

  lastEncoderRead = currTime;
}

void updateEditedValue() 
{
  // TODO check if edited value was actually changed before proceeding

  if (currentMode == MODE_NORMAL) return; // ignore if not in edit mode

  if (currentMode == MODE_EDIT_HOUR) {
    
    if(editedValue == EDIT_UNDEF) editedValue = tm.Hour;

    if(editedValue > hoursValid[1]) {
      editedValue = hoursValid[0];
    } else if (editedValue < hoursValid[0]) {
      editedValue = hoursValid[1];
    }
    
    tm.Hour = editedValue;
    RTC.write(tm);
    
  } else if (currentMode == MODE_EDIT_MINUTE) {

    if(editedValue == EDIT_UNDEF) editedValue = tm.Minute;

    if(editedValue > minutesValid[1]) {
      editedValue = minutesValid[0];
    } else if (editedValue < minutesValid[0]) {
      editedValue = minutesValid[1];
    }
    
    tm.Minute = editedValue;
    RTC.write(tm);
  }
}

void updateLcd() {

  lcd.setCursor(0, 0);
  lcd.print(modeToLabel(currentMode));
  
  lcd.setCursor(0, 1);
  if(editedValue == EDIT_UNDEF) {
    lcd.print("<None>");  
  } else {
    lcd.print(editedValue);
  }
  lcd.print("      ");

  // display time
  lcd.setCursor(12, 3);
  printZeroPadded(tm.Hour);
  lcd.write(':'); 
  printZeroPadded(tm.Minute);
  lcd.write(':'); 
  printZeroPadded(tm.Second);
  
}

char* modeToLabel(byte mode) {
  switch(mode) {
    case MODE_EDIT_HOUR:
      return "Edit hour  ";
    case MODE_EDIT_MINUTE:
      return "Edit minute";
    case MODE_NORMAL:
      return "Normal     ";
  }
}

void printZeroPadded(int num) {
  if(num >= 0 && num < 10) {
    lcd.write('0');
  }
  lcd.print(num, DEC);
}
