#include <Time.h> // https://github.com/PaulStoffregen/Time
#include <TimeLib.h> // https://github.com/PaulStoffregen/Time
#include <LiquidCrystal_I2C.h> //https://github.com/fdebrabander/Arduino-LiquidCrystal-I2C-library
#include <Wire.h> 
#include <DS3232RTC.h> //http://github.com/JChristensen/DS3232RTC
#include <LCD.h> //https://bitbucket.org/fmalpartida/new-liquidcrystal
#include <EEPROM.h>
#include <SoftwareSerial.h>

SoftwareSerial espSerial(5, 6); // RX, TX

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

#define HOT_METER_PIN  A0
#define COLD_METER_PIN A1

#define IMP_WEIGHT 0.01 // one pulse from counter is equal to 10 liters or 0,01 m^3

#define SENSOR_TH_OPEN  850 // analog value read from sensor pin when reed switch is open
#define SENSOR_TH_CLOSE 615 // --,,-- is closed
#define TH_SENS         60  // sensivity corridor. even if analog value differs from expected at this amount
                            // (either in positive or negative side), state is still considered matching expectations 

#define SENSOR_ST_OPEN          0 // reed is open 
#define SENSOR_ST_CLOSE         1 // reed is closed
#define SENSOR_ST_SHORT         2 // short circuit of meter
#define SENSOR_ST_LOST          3 // lost contact with meter
#define SENSOR_ST_UNDETERMINATE 4 // failed matching with thresholds

#define TOTAL_HOT  0
#define TOTAL_COLD 1
#define DAILY_HOT  2
#define DAILY_COLD 3

#define COUNTERS_SIZE 4

#define HOT  0
#define COLD 1

unsigned int counters[] = {0, 0, 0, 0};

// last remembered states of each meter sensor
byte lastMeterState[2];

// last remembered day to run dialy reset
byte lastDialyReset;

LiquidCrystal_I2C lcd(I2C_ADDR, En_pin, Rw_pin, Rs_pin, D4_pin, D5_pin, D6_pin, D7_pin);

// how often values are periodically sent to cloud
#define PERIODIC_SEND_STAT_INTERVAL 600000
unsigned long lastSentStat = 0;

// flag indicating if esp uart is started
byte espSerialStarted = 0;

// beeping timings and pin
#define BEEPER_PIN 13
#define BEEP_ON 50   // ms
#define BEEP_OFF 100 // ms

byte beeperGlabalState = LOW;
byte beepsRequestedGlobal = 0;

unsigned long lastBeeperMillis = 0;
unsigned long lastSubbeepMillis = 0;

// buttons
#define BTN_01_PIN 12
#define BTN_02_PIN 11
#define BTN_03_PIN 10
#define BTN_04_PIN 9

// valves
#define HOT_VALVE_PIN 8
#define COLD_VALVE_PIN 7

// valves are configured closed on startup
byte hotValveState = HIGH;
byte coldValveState = HIGH;

// last remembered button state to detect state change
byte btn01prev = LOW;
byte btn02prev = LOW;
byte btn03prev = LOW;
byte btn04prev = LOW;

#define METER_READ_INTERVAL 1000
unsigned long lastMeterRead = 0;

void setup()
{
  setSyncProvider(RTC.get);

  // button pins setup
  pinMode(BTN_01_PIN, INPUT);
  pinMode(BTN_02_PIN, INPUT);
  pinMode(BTN_03_PIN, INPUT);
  pinMode(BTN_04_PIN, INPUT);

  // valve pins setup
  pinMode(HOT_VALVE_PIN, OUTPUT);
  pinMode(COLD_VALVE_PIN, OUTPUT);

  // update with unitial values
  updateHotValve();
  updateColdValve(); 

  // init analog pins, meters reeds are connected to
  pinMode(HOT_METER_PIN,  INPUT);
  pinMode(COLD_METER_PIN, INPUT);

  // set actual initial values to avoid capturing unsired pulse 
  lastMeterState[HOT] = readMeter(HOT_METER_PIN);
  lastMeterState[COLD] = readMeter(COLD_METER_PIN);

  // pull saved values from eeprom
  for(byte i = 0; i < COUNTERS_SIZE; i++) {
    counters[i] = eepromReadInt(i*2);
  }

  // read initial value for dialy reset detection
  // TODO monitor correct RTC startup
  lastDialyReset = day();
 
  // init lcd
  lcd.begin(20, 4);
  lcd.setBacklightPin(BACKLIGHT_PIN, POSITIVE);
  lcd.setBacklight(HIGH);

  // present some welcome screen
  lcd.home();
  lcd.print("Interstellar");
  writeDotWithDelay(3);
  
  lcd.clear();

}

void loop()
{
  
  // delay serial startup, give time for esp to start
  if (!espSerialStarted && millis() > 10000) {
      espSerial.begin(9600);
      espSerialStarted = 1;
  }

  // read meters
  if (millis() - lastMeterRead >= METER_READ_INTERVAL) {
      handleMeterStateChange(HOT,  HOT_METER_PIN);
      handleMeterStateChange(COLD, COLD_METER_PIN);
      lastMeterRead = millis();
  }

  // reading buttons
  int btn01 = digitalRead(BTN_01_PIN);
  int btn02 = digitalRead(BTN_02_PIN);
  int btn03 = digitalRead(BTN_03_PIN);
  int btn04 = digitalRead(BTN_04_PIN);

  // updating valves state on request
  if (btn01 != btn01prev) {
      if (btn01 == HIGH) {
          hotValveState = !hotValveState;
      }
      btn01prev = btn01;
  }
  if (btn02 != btn02prev) {
      if (btn02 == HIGH) {
          coldValveState = !coldValveState;
      }
      btn02prev = btn02;
  }

  // update output signals
  updateHotValve();
  updateColdValve();  

  // reset dialy counters
  resetDailyCounters();
  
  // update lcd
  updateLcd();

  // use beep with 0 cnt to track surrent state only
  beep(0);
  digitalWrite(BEEPER_PIN, beeperGlabalState);

  // read data from esp uart
  if (espSerialStarted) {
    // read all available bytes from serial but dump only first 4 to lcd
    lcd.setCursor(16, 0);
    int bytes = espSerial.available();
    if (bytes) {
        for(int i = 0; i < bytes; i++) {
          char readChar = espSerial.read();
          if(i < 4) lcd.write(readChar);
        }
     }    
  }
  
  // send statistics immediately and then periodically
  if (lastSentStat == 0 || millis() - lastSentStat >= PERIODIC_SEND_STAT_INTERVAL) {
      sendStat();
  }
  
}

void sendStat() {

    if (!espSerialStarted) return;

    espSerial.print(  "field1=" + String(counters[TOTAL_HOT]  * IMP_WEIGHT));
    espSerial.print( "&field2=" + String(counters[TOTAL_COLD] * IMP_WEIGHT));
    espSerial.print( "&field3=" + String(counters[DAILY_HOT]  * IMP_WEIGHT));
    espSerial.print( "&field4=" + String(counters[DAILY_COLD] * IMP_WEIGHT));
    espSerial.print("\r");

    lastSentStat = millis();
}

void updateHotValve() {
  digitalWrite(HOT_VALVE_PIN, hotValveState);
}

void updateColdValve() {
  digitalWrite(COLD_VALVE_PIN, coldValveState);
}

void resetDailyCounters() {
  if(lastDialyReset != day()) {
    counters[DAILY_HOT] = 0;
    eepromWriteInt(DAILY_HOT * 2, 0);
    counters[DAILY_COLD] = 0;
    eepromWriteInt(DAILY_COLD * 2, 0);
    lastDialyReset = day();
  }
}

void handleMeterStateChange(byte channel, int pinNum) {
  byte state = readMeter(pinNum);
  if (state != lastMeterState[channel]) {
    meterStateChange(channel, state);
    lastMeterState[channel] = state;
  }
}

int readMeter(int pinNum) {
  
  int meanVal = analogReadMean(pinNum);

  if(meanVal < SENSOR_TH_CLOSE - TH_SENS) {
    return SENSOR_ST_SHORT;
  } else if (meanVal > SENSOR_TH_OPEN + TH_SENS) {
    return SENSOR_ST_LOST;    
  } else if (meanVal < SENSOR_TH_OPEN + TH_SENS && meanVal > SENSOR_TH_OPEN - TH_SENS) {
    return SENSOR_ST_OPEN;
  } else if (meanVal < SENSOR_TH_CLOSE + TH_SENS && meanVal > SENSOR_TH_CLOSE - TH_SENS) {
    return SENSOR_ST_CLOSE;
  } else {
    return SENSOR_ST_UNDETERMINATE;
  }
}

int analogReadMean(int pinNum) {
   byte samples = 5;
   byte i = 0;
   int total = 0;
   while(i++ < samples) {
     delay(5);
     total += analogRead(pinNum);
   }
   return total/samples;
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

void writeDotWithDelay(int dots) {
  while(dots--) { 
    lcd.write('.');
    delay(300);
  }
}

void printZeroPadded(int num) {
  if(num >= 0 && num < 10) {
    lcd.write('0');
  }
  lcd.print(num, DEC);
}

void meterStateChange(byte channel, int state) {
  if (state == SENSOR_ST_CLOSE) {
    tickMeter(channel); // tick +10 liters
  }
}

void tickMeter(byte channel) {

  if (channel == HOT) {

    beep(3); // beep 3 times to indicate consumption of 10 liters of hot water
    
    counters[TOTAL_HOT]++;
    counters[DAILY_HOT]++;
    eepromWriteInt(TOTAL_HOT * 2, counters[TOTAL_HOT]);
    eepromWriteInt(DAILY_HOT * 2, counters[DAILY_HOT]);

  } else if (channel == COLD) {


    beep(1); // beep 1 time to indicate consumption of 10 liters of cold water
    
    counters[TOTAL_COLD]++;
    counters[DAILY_COLD]++;
    eepromWriteInt(TOTAL_COLD * 2, counters[TOTAL_COLD]);
    eepromWriteInt(DAILY_COLD * 2, counters[DAILY_COLD]);

  }

  sendStat();
}

void updateLcd() {

  lcd.setCursor(2, 0);
  lcd.print("Day  Total");
  
  // hot dialy/total 
  lcd.setCursor(0, 1);
  lcd.print("H ");
  lcd.print(counters[DAILY_HOT] * IMP_WEIGHT, 2);
  lcd.write(' ');
  lcd.print(counters[TOTAL_HOT] * IMP_WEIGHT, 2);

  // cold dialy/total
  lcd.setCursor(0, 2);
  lcd.print("C ");
  lcd.print(counters[DAILY_COLD] * IMP_WEIGHT, 2);
  lcd.write(' ');
  lcd.print(counters[TOTAL_COLD] * IMP_WEIGHT, 2);

  // meter states hot/cold
  lcd.setCursor(16, 1);
  lcd.print(stateToLabel(lastMeterState[HOT]));
  lcd.setCursor(16, 2);
  lcd.print(stateToLabel(lastMeterState[COLD]));
  
  // display time
  lcd.setCursor(12, 3);
  printZeroPadded(hour());
  lcd.write(':'); 
  printZeroPadded(minute());
  lcd.write(':'); 
  printZeroPadded(second());
}

char* stateToLabel(int state) {
  switch(state) {
    case SENSOR_ST_OPEN:
      return "Open";
    case SENSOR_ST_CLOSE:
      return "Clsd";
    case SENSOR_ST_SHORT:
      return "Shrt";
    case SENSOR_ST_LOST:
      return "Lost";
    case SENSOR_ST_UNDETERMINATE:
      return "Undt";
  }
}


void beep(int cnt) {
  if (beepsRequestedGlobal > 0) {
      unsigned long currentMillis = millis();
      if (beeperGlabalState == LOW && currentMillis - lastSubbeepMillis >= BEEP_OFF)  {
           beeperGlabalState = HIGH;
           lastSubbeepMillis = currentMillis;
      } else if (beeperGlabalState == HIGH && currentMillis - lastSubbeepMillis >= BEEP_ON)  {
           beeperGlabalState = LOW;
           lastSubbeepMillis = currentMillis;
           beepsRequestedGlobal--;
      }
  } else {
    beepsRequestedGlobal = cnt;
  }
}

