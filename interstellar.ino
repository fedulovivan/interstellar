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

// system goes to armed mode if no motion detected for last 30 mins
#define ARMED_INTERVAL 7200000
byte globalArmed = false;
byte globalArmedLast = false;

#define PIR_PIN 4
long lastPirMillis = 0;

/*unsigned*/ int counters[] = {0, 0, 0, 0};

// last remembered states of each meter sensor
byte lastMeterState[2];

// last remembered day to run dialy reset
byte lastDialyReset;

LiquidCrystal_I2C lcd(I2C_ADDR, En_pin, Rw_pin, Rs_pin, D4_pin, D5_pin, D6_pin, D7_pin);

// how often values are periodically sent to cloud, 30 mins
#define PERIODIC_SEND_STAT_INTERVAL 1800000
unsigned long lastSentStat = 0;

// flag indicating if esp uart is started
byte espSerialStarted = 0;

// beeping timings and pin
#define BEEPER_PIN 13
#define BEEP_ON 50   // ms
#define BEEP_OFF 100 // ms
#define BEEP_DANGER_ON 2000  // ms
#define BEEP_DANGER_OFF 1000 // ms

byte beeperDangerMode = 0;
byte beeperGlobalState = LOW;
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

// water leakage sensor
#define WATER_LEAKAGE_SENSOR_PIN 2
byte waterLeakageLast;

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

  // set pir pin mode
  pinMode(PIR_PIN, INPUT);

  // button pins setup
  pinMode(BTN_01_PIN, INPUT);
  pinMode(BTN_02_PIN, INPUT);
  pinMode(BTN_03_PIN, INPUT);
  pinMode(BTN_04_PIN, INPUT);

  // beeper pin mode
  pinMode(BEEPER_PIN, OUTPUT);

  // valve pins setup
  pinMode(HOT_VALVE_PIN, OUTPUT);
  pinMode(COLD_VALVE_PIN, OUTPUT);

  // water leakage sensor
  pinMode(WATER_LEAKAGE_SENSOR_PIN, INPUT);

  // update with unitial values
  updateHotValve();
  updateColdValve();

  // init analog pins, meters reeds are connected to
  pinMode(HOT_METER_PIN,  INPUT);
  pinMode(COLD_METER_PIN, INPUT);

  // set actual initial values to avoid capturing undesired pulse
  lastMeterState[HOT] = readMeter(HOT_METER_PIN);
  lastMeterState[COLD] = readMeter(COLD_METER_PIN);

  // pull saved values from eeprom
  // for(byte i = 0; i < COUNTERS_SIZE; i++) {
    // EEPROM.get(i, counters[i]);
    // EEPROM.get(i * 2, counters[i]);
  //counters[i] = eepromReadInt(i * 2);
  //eepromWriteInt(i * 2, counters[i]);
  // }

  for (int i = 0 ; i < EEPROM.length() ; i++) {
    // EEPROM.put(i * sizeof(int), (int)0);
  }

  EEPROM.get(0, counters[TOTAL_HOT]);
  EEPROM.get(2, counters[TOTAL_COLD]);
  EEPROM.get(4, counters[DAILY_HOT]);
  EEPROM.get(6, counters[DAILY_COLD]);

  // counters[0] = eepromReadInt(0);
  // counters[1] = eepromReadInt(2);
  // counters[2] = eepromReadInt(4);
  // counters[3] = eepromReadInt(6);


  // read initial value for dialy reset detection
  // TODO monitor correct RTC startup
  lastDialyReset = day();

  // init lcd
  lcd.begin(20, 4);
  lcd.setBacklightPin(BACKLIGHT_PIN, POSITIVE);
  lcd.setBacklight(HIGH);

  // show some welcome screen
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

  // handle beep
  handleBeep();

  // read data from esp uart
//  if (espSerialStarted) {
//    // read all available bytes from serial but dump only first 4 to lcd
//    lcd.setCursor(16, 0);
//    int bytes = espSerial.available();
//    if (bytes) {
//        for(int i = 0; i < bytes; i++) {
//          char readChar = espSerial.read();
//          if(i < 4) {
//            lcd.write(readChar);
//          } else {
//            break;
//          }
//        }
//     }
//  }

  // send statistics immediately and then periodically
  if (lastSentStat == 0 || millis() - lastSentStat >= PERIODIC_SEND_STAT_INTERVAL) {
      sendStat();
  }

  // update last time when pir sensor detected activity
  // if (digitalRead(PIR_PIN) == true) {
  //     lastPirMillis = millis();
  // }
  // TODO dummy for absent pir sensor
  lastPirMillis = millis();

  // entering armed mode if no motion was detected by pir within last N seconds
  globalArmed = millis() - lastPirMillis >= ARMED_INTERVAL;
  if (globalArmed != globalArmedLast) {
      beep(globalArmed ? 2 : 5, 0);
      sendStat();
  }
  globalArmedLast = globalArmed;

  byte waterLeakage = digitalRead(WATER_LEAKAGE_SENSOR_PIN);
  if (waterLeakage != waterLeakageLast && waterLeakage == false) {
      emergency();
  }
  waterLeakageLast = waterLeakage;

}

void sendStat() {

    if (!espSerialStarted) return;

    espSerial.print( "field1=" + String(counters[TOTAL_HOT]  * IMP_WEIGHT));
    espSerial.print("&field2=" + String(counters[TOTAL_COLD] * IMP_WEIGHT));
    espSerial.print("&field3=" + String(counters[DAILY_HOT]  * IMP_WEIGHT));
    espSerial.print("&field4=" + String(counters[DAILY_COLD] * IMP_WEIGHT));
    espSerial.print("&field5=" + String(globalArmed));
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
    //eepromWriteInt(DAILY_HOT * 2, 0);
    counters[DAILY_COLD] = 0;
    //eepromWriteInt(DAILY_COLD * 2, 0);
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

// unsigned int eepromReadInt(int addr) {
//   byte raw[2];
//   for(byte i = 0; i < 2; i++) raw[i] = EEPROM.read(addr+i);
//   unsigned int &num = (unsigned int&)raw;
//   return num;
// }

// void eepromWriteInt(int addr, unsigned int num) {
//   byte raw[2];
//   (unsigned int&)raw = num;
//   for(byte i = 0; i < 2; i++) EEPROM.write(addr+i, raw[i]);
// }

//void eepromWriteInt(int addr, int value) {
//  byte lowByte = ((value >> 0) & 0xFF);
//  byte highByte = ((value >> 8) & 0xFF);
//  EEPROM.write(addr, lowByte);
//  EEPROM.write(addr + 1, highByte);
//}
//
//int eepromReadInt(int addr) {
//  byte lowByte = EEPROM.read(addr);
//  byte highByte = EEPROM.read(addr + 1);
//  return ((lowByte << 0) & 0xFF) + ((highByte << 8) & 0xFF);
//}

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

    beep(3, 0); // beep 3 times to indicate consumption of 10 liters of hot water

    counters[TOTAL_HOT]++;
    counters[DAILY_HOT]++;

    //eepromWriteInt(TOTAL_HOT * 2, counters[TOTAL_HOT]);
    //eepromWriteInt(DAILY_HOT * 2, counters[DAILY_HOT]);

  } else if (channel == COLD) {

    beep(1, 0); // beep 1 time to indicate consumption of 10 liters of cold water

    counters[TOTAL_COLD]++;
    counters[DAILY_COLD]++;

    //eepromWriteInt(TOTAL_COLD * 2, counters[TOTAL_COLD]);
    //eepromWriteInt(DAILY_COLD * 2, counters[DAILY_COLD]);

  }

  // emergency: undesired water consumption detected when system is in armed mode
  if (globalArmed) {
    emergency();
  }

  sendStat();
}

// cut off water
// make 5 long beeps
void emergency() {
    hotValveState = HIGH;
    coldValveState = HIGH;
    beep(5, 1);
}

void updateLcd() {

  lcd.setCursor(2, 0);
  lcd.print("Day  Total");

  // hot dialy/total
  lcd.setCursor(0, 1);
  lcd.print("H ");
  lcd.print(counters[DAILY_HOT]/* * IMP_WEIGHT, 2*/);
  lcd.write(' ');
  lcd.print(counters[TOTAL_HOT]/* * IMP_WEIGHT, 2*/);

  // cold dialy/total
  lcd.setCursor(0, 2);
  lcd.print("C ");
  lcd.print(counters[DAILY_COLD]/* * IMP_WEIGHT, 2*/);
  lcd.write(' ');
  lcd.print(counters[TOTAL_COLD]/* * IMP_WEIGHT, 2*/);

  // indicate valves
  lcd.setCursor(13, 1);
  lcd.print(hotValveState ? "CLS" : "OPN");
  lcd.setCursor(13, 2);
  lcd.print(coldValveState ? "CLS" : "OPN");

  // meter states hot/cold
  lcd.setCursor(17, 1);
  lcd.print(stateToLabel(lastMeterState[HOT]));
  lcd.setCursor(17, 2);
  lcd.print(stateToLabel(lastMeterState[COLD]));

  // display time
  lcd.setCursor(12, 3);
  printZeroPadded(hour());
  lcd.write(':');
  printZeroPadded(minute());
  lcd.write(':');
  printZeroPadded(second());

  // indicate arm mode
  lcd.setCursor(0, 3);
  lcd.print(globalArmed ? "GUARD" : "WORK ");

}

char* stateToLabel(int state) {
  switch(state) {
    case SENSOR_ST_OPEN:
      return "OPN";
    case SENSOR_ST_CLOSE:
      return "CLS";
    case SENSOR_ST_SHORT:
      return "SCH";
    case SENSOR_ST_LOST:
      return "LST";
    case SENSOR_ST_UNDETERMINATE:
      return "UND";
  }
}

// request beeping
// cnt - how many times to beep
// dangerMode - use long beeps with lons pauses to indicate something wrong is happening
void beep(byte cnt, byte dangerMode) {
    beepsRequestedGlobal = cnt;
    beeperDangerMode = dangerMode;
}

// handle beeping
void handleBeep() {
  if (beepsRequestedGlobal > 0) {
      unsigned long currentMillis = millis();
      if (beeperGlobalState == LOW && currentMillis - lastSubbeepMillis >= (beeperDangerMode == 1 ? BEEP_DANGER_OFF : BEEP_OFF))  {
           beeperGlobalState = HIGH;
           lastSubbeepMillis = currentMillis;
      } else if (beeperGlobalState == HIGH && currentMillis - lastSubbeepMillis >= (beeperDangerMode == 1 ? BEEP_DANGER_ON : BEEP_ON))  {
           beeperGlobalState = LOW;
           lastSubbeepMillis = currentMillis;
           beepsRequestedGlobal--;
      }
  }
  digitalWrite(BEEPER_PIN, beeperGlobalState);
}
