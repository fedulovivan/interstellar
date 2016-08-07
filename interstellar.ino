#include <Time.h> // https://github.com/PaulStoffregen/Time
#include <TimeLib.h> // https://github.com/PaulStoffregen/Time
#include <LiquidCrystal_I2C.h> //https://github.com/fdebrabander/Arduino-LiquidCrystal-I2C-library
#include <Wire.h> 
#include <DS3232RTC.h> //http://github.com/JChristensen/DS3232RTC
#include <LCD.h> //https://bitbucket.org/fmalpartida/new-liquidcrystal
#include <EEPROM.h>
#include <SoftwareSerial.h>

SoftwareSerial espSerial(5, 6); // RX, TX, inverse_logic

#define DEBUG 1

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

// last remembered day to rud dialy reset
byte lastDialyReset;

LiquidCrystal_I2C lcd(I2C_ADDR, En_pin, Rw_pin, Rs_pin, D4_pin, D5_pin, D6_pin, D7_pin);

// how often values sent to cloud
unsigned long previousMillis = 0;
const long interval = 60000;

byte espSerialStarted = 0;

// beeping
const byte beeperPin = 13;

const int beepOn = 50;   // ms
const int beepOff = 100; // ms

byte beeperGlabalState = LOW;
byte beepsRequestedGlobal = 0;

unsigned long lastBeeperMillis = 0;
unsigned long lastSubbeepMillis = 0;

void setup()
{

  //pinMode(5, OUTPUT);
  //digitalWrite(5, LOW);
  
//#ifdef DEBUG
//  Serial.begin(9600);
//#endif

// espSerial.begin(9600);

  setSyncProvider(RTC.get);

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
  //if(RTC.read(tm)) {
    lastDialyReset = day();
  //}
 
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
  //RTC.read(tm);

  // delay serial startup, give time for esp to start
  if (!espSerialStarted && millis() > 10000) {
      espSerial.begin(9600);
      espSerialStarted = 1;
  }

  handleMeterStateChange(HOT,  HOT_METER_PIN);
  handleMeterStateChange(COLD, COLD_METER_PIN);

  resetDailyCounters();
  
  updateLcd();

  beep(0); // use beep with 0 cnt to track surrent state only
  digitalWrite(beeperPin, beeperGlabalState);

  if (espSerialStarted) {
    
    // send statitistics
    unsigned long currentMillis = millis();
    if (currentMillis - previousMillis >= interval) {
      previousMillis = currentMillis;
      espSerial.print(  "field1=" + String(counters[TOTAL_HOT]  * IMP_WEIGHT));
      espSerial.print( "&field2=" + String(counters[TOTAL_COLD] * IMP_WEIGHT));
      espSerial.print( "&field3=" + String(counters[DAILY_HOT]  * IMP_WEIGHT));
      espSerial.print( "&field4=" + String(counters[DAILY_COLD] * IMP_WEIGHT));
      espSerial.print("\r");
    }
  
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

//#ifdef DEBUG
//  Serial.println("st_ch");
//  Serial.print("ch=");
//  Serial.print(channel, DEC);
//  Serial.print(",pin=");
//  Serial.println(pinNum, DEC);
//#endif

  }
}

int readMeter(int pinNum) {
  
  int meanVal = analogReadMean(pinNum);

//#ifdef DEBUG
//  Serial.println("rd_mt");
//  Serial.print("pin=");
//  Serial.print(pinNum, DEC);
//  Serial.print(",val=");
//  Serial.println(meanVal, DEC);  
//#endif

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
   byte samples = 10;
   byte i = 0;
   int total = 0;
   while(i++ < samples) {
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
  
  // TODO
  // implement valves closing handling
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

      if (beeperGlabalState == LOW && currentMillis - lastSubbeepMillis >= beepOff)  {
           beeperGlabalState = HIGH;
           lastSubbeepMillis = currentMillis;
      } else if (beeperGlabalState == HIGH && currentMillis - lastSubbeepMillis >= beepOn)  {
           beeperGlabalState = LOW;
           lastSubbeepMillis = currentMillis;
           beepsRequestedGlobal--;
      }
    
  } else {
    beepsRequestedGlobal = cnt;
  }
}

