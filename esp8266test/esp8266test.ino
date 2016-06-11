#define DELAY_AFTER_SEND 200
#define DELAY_ON_ERR 1000

int cnt = 0;
int errCount = 0;

void setup() {
  Serial.begin(115200);
}

void loop() {
 
  if(sendString(String(cnt) + "," + String(errCount))) {
    cnt++;
    errCount = 0; // reset at first success
  } else {
    errCount++; // encrement error counter on send error
  }

}

bool sendString(String str) {

  String baseGet = F("GET http://192.168.88.252:8080/?");
  String endingGet = F(" HTTP/1.0\r\n\r\n\r\n");
  
  String payload = baseGet + str + endingGet;
  
  Serial.print("AT+CIPMUX=0\r\n");
  delay(DELAY_AFTER_SEND);
  if(!Serial.find("OK")) {
    delay(DELAY_ON_ERR);
    return false;
  }

  Serial.print(F("AT+CIPSTART=\"TCP\",\"192.168.88.252\",8080\r\n"));
  delay(DELAY_AFTER_SEND);
  if(!Serial.find("OK")) {
    Serial.print("AT+CIPCLOSE\r\n");
    delay(DELAY_ON_ERR);
    return false;
  }
  Serial.print("AT+CIPSEND=" + String(payload.length()) + "\r\n");
  delay(DELAY_AFTER_SEND * 2);
  if(!Serial.find(">")) {
    Serial.print("AT+CIPCLOSE\r\n");
    delay(DELAY_ON_ERR);
    return false;
  }
  Serial.print(payload);
  delay(DELAY_AFTER_SEND);
  return true;
}



// reset esp at max errors threshold reached
//  if(errCount > 100) {
//    Serial.print("AT+RST\r\n");
//    errCount = 0;
//    delay(25000);
//  } 
 
