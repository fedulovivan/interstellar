#include <LiquidCrystal_I2C.h>
#include <Wire.h>
#include <Time.h>
#include <DS1307RTC.h>
#include <LCD.h>
#include <EEPROM.h>

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

// time read from RTC module
tmElements_t tm;

LiquidCrystal_I2C lcd(I2C_ADDR, En_pin, Rw_pin, Rs_pin, D4_pin, D5_pin, D6_pin, D7_pin);

void setup()
{
  
//#ifdef DEBUG
//  Serial.begin(9600);
//#endif

  // init analig pins meters reeds are connected
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
  if(RTC.read(tm)) {
    lastDialyReset = tm.Day;
  }
 
  // init lcd
  lcd.begin(16,2);
  lcd.setBacklightPin(BACKLIGHT_PIN, POSITIVE);
  lcd.setBacklight(LOW);

  // present some welcome screen
  lcd.home();
  lcd.print("Interstellar");
  writeDotWithDelay(3);
  
  lcd.clear();
}

void loop()
{
  RTC.read(tm);

  handleMeterStateChange(HOT,  HOT_METER_PIN);
  handleMeterStateChange(COLD, COLD_METER_PIN);

  resetDailyCounters();
  
  updateLcd();

  delay(100);
}

void resetDailyCounters() {
  if(lastDialyReset != tm.Day) {
    counters[DAILY_HOT] = 0;
    eepromWriteInt(DAILY_HOT * 2, 0);
    counters[DAILY_COLD] = 0;
    eepromWriteInt(DAILY_COLD * 2, 0);
    lastDialyReset = tm.Day;
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
    counters[TOTAL_HOT]++;
    counters[DAILY_HOT]++;
    eepromWriteInt(TOTAL_HOT * 2, counters[TOTAL_HOT]);
    eepromWriteInt(DAILY_HOT * 2, counters[DAILY_HOT]);
  } else if (channel == COLD) {
    counters[TOTAL_COLD]++;
    counters[DAILY_COLD]++;
    eepromWriteInt(TOTAL_COLD * 2, counters[TOTAL_COLD]);
    eepromWriteInt(DAILY_COLD * 2, counters[DAILY_COLD]);
  }
  
}

void updateLcd() {

  // time
  lcd.setCursor(11, 0);
  printZeroPadded(tm.Hour);
  lcd.write((tm.Second % 2) == 0 ? ':' : ' '); // blinking
  printZeroPadded(tm.Minute);

  // hot dialy/total 
  lcd.setCursor(0, 0);
  lcd.print(counters[DAILY_HOT] * IMP_WEIGHT, 2);
  lcd.write('/');
  lcd.print(counters[TOTAL_HOT] * IMP_WEIGHT, 2);

  // cold dialy/total
  lcd.setCursor(0, 1);
  lcd.print(counters[DAILY_COLD] * IMP_WEIGHT, 2);
  lcd.write('/');
  lcd.print(counters[TOTAL_COLD] * IMP_WEIGHT, 2);

  // meter states hot/cold
  lcd.setCursor(11, 1);
  lcd.print(stateToLabel(lastMeterState[HOT]));
  lcd.write(',');
  lcd.print(stateToLabel(lastMeterState[COLD]));
  
}

char* stateToLabel(byte state) {
  switch(state) {
    case SENSOR_ST_OPEN:
      return "OP";
    case SENSOR_ST_CLOSE:
      return "CL";
    case SENSOR_ST_SHORT:
      return "SH";
    case SENSOR_ST_LOST:
      return "LS";
    case SENSOR_ST_UNDETERMINATE:
      return "UD";
  }
}

