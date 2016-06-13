#define DELAY_AFTER_SEND 500
#define DELAY_ON_ERR 500

int success  = 0;
int err1 = 0;
int err2 = 0;
int err3 = 0;
int err4 = 0;

void setup() {
  Serial.begin(115200);
}

void loop() {

  int code = sendString(
    String(success) + "," + String(err1) + "," + String(err2) + "," + String(err3) + "," + String(err4)
  );
 
  switch(code) {
    case 1:
      err1++;
      break;
    case 2:
      err2++;
      break;
    case 3:
      err3++;
      break;
    case 4:
      err4++;
      break;
    default:
      success++;
  }

  delay(1000);

}

int sendString(String str) {

  String baseGet = F("GET http://192.168.88.252:8080/?");
  String endingGet = F(" HTTP/1.0\r\n\r\n\r\n");
  
  String getPayload = baseGet + str + endingGet;
  
  Serial.print("AT+CIPMUX=0\r\n");
  delay(DELAY_AFTER_SEND);
  
  if(!Serial.find("OK")) {
    delay(DELAY_ON_ERR);
    return 1;
  }

  Serial.print(F("AT+CIPSTART=\"TCP\",\"192.168.88.252\",8080\r\n"));
  delay(DELAY_AFTER_SEND);
  
  if(!Serial.find("CONNECT")) {
    Serial.print("AT+CIPCLOSE\r\n");
    delay(DELAY_ON_ERR);
    return 2;
  }

  Serial.print("AT+CIPSEND=" + String(getPayload.length()) + "\r\n");
  delay(DELAY_AFTER_SEND * 2);
  
  if(!Serial.find(">")) {
    Serial.print("AT+CIPCLOSE\r\n");
    delay(DELAY_ON_ERR);
    return 3;
  }
  
  Serial.print(getPayload);
  delay(DELAY_AFTER_SEND * 2);
  if(!Serial.find("OK")) {
    Serial.print("AT+CIPCLOSE\r\n");
    delay(DELAY_ON_ERR);
    return 4;
  }
  
  return 0;
} 
 
