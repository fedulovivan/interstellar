#include <LiquidCrystal_I2C.h>
#include <Wire.h>
#include <Time.h>
#include <DS1307RTC.h>
#include <LCD.h>
#include <EEPROM.h>

// pcf8574 address
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

#define COUNTER_PIN 12

#define IMP_WEIGHT 10 // one pulse from counter is equal to 10 liters

#define TOTAL_LITERS_EEPROM_ADDR 0

#define TODAY_LITERS_EEPROM_ADDR 2

unsigned int totalLiters; // stores  liters/10 value
byte todayLiters;

int lastCounterState;

LiquidCrystal_I2C lcd(I2C_ADDR, En_pin, Rw_pin, Rs_pin, D4_pin, D5_pin, D6_pin, D7_pin);

void setup()
{
  pinMode(COUNTER_PIN, INPUT);

  // pull laste saved value from eeprom
  totalLiters = eepromReadInt(TOTAL_LITERS_EEPROM_ADDR);
  todayLiters = eepromReadInt(TODAY_LITERS_EEPROM_ADDR);

  // init lcd
  lcd.begin(16,2);
  lcd.setBacklightPin(BACKLIGHT_PIN, POSITIVE);
  lcd.setBacklight(HIGH);

  // show welcome screen
  lcd.home();
  lcd.print("Interstellar");
  writeDotWithDelay(3);
  
  lcd.clear();
}

void loop()
{

  // read counter sensor
  int counterState = digitalRead(COUNTER_PIN);
  if(counterState != lastCounterState) {
    cntStateChange(counterState);
    lastCounterState = counterState;
  }

  // update lcd 
  updateTime();
  updateLiters();

  delay(50);
}

void eepromWriteInt(int addr, int value) {
  byte lowByte = ((value >> 0) & 0xFF);
  byte highByte = ((value >> 8) & 0xFF);
  EEPROM.write(addr, lowByte);
  EEPROM.write(addr + 1, highByte);
}

int eepromReadInt(int addr) {
  byte lowByte = EEPROM.read(addr);
  byte highByte = EEPROM.read(addr + 1);
  return ((lowByte << 0) & 0xFF) + ((highByte << 8) & 0xFF);
}

void updateTime() {
  tmElements_t tm;
  if(RTC.read(tm)) {
    lcd.setCursor(0, 0);
    printZeroPadded(tm.Hour);
    lcd.write(':');
    printZeroPadded(tm.Minute);
    lcd.write(':');
    printZeroPadded(tm.Second);
  }
}

void writeDotWithDelay(int dots) {
  while(dots--) { 
    lcd.write('.');
    delay(500);
  }
}

void printZeroPadded(int num) {
  if(num >= 0 && num < 10) {
    lcd.write('0');
  }
  lcd.print(num, DEC);
}

void cntStateChange(int state) {
  if(state == HIGH) {
    plus10liters(); // tick +10 liters
  }
  // TODO
  // handle valves closing here
}

void plus10liters() {
   totalLiters++;
   eepromWriteInt(TOTAL_LITERS_EEPROM_ADDR, totalLiters); // consume 2 bytes
}

void updateLiters() {
  lcd.setCursor(0,1);
  lcd.print(totalLiters * IMP_WEIGHT, DEC);
  lcd.print(" liters");
}

