Flash esp8266 with nodemcu firmware:
./esptool.py --baud 115200 --port /dev/cu.wchusbserial1410 write_flash 0x0000 ~/Downloads/nodemcu-master-8-modules-2016-06-12-12-58-18-integer.bin

Build nodemcu firmware online:
http://nodemcu-build.com

uart console
sudo screen /dev/cu.wchusbserial1410 115200

Regular AT commands to make http request:

// turn itself to client
AT+CWMODE=1

// connect to home wifi
AT+CWJAP="wifi domru ivanf","*****"

Sending HTTP GET request:

// set single conn mode and initiate single connection
AT+CIPMUX=0
AT+CIPSTART="TCP","192.168.88.252",8080

//
AT+CIPSTATUS

// tell server get request size, including \r\n characters
AT+CIPSEND=62

// wait for > character and send string terminated with two \r\n
GET http://192.168.88.252:8080/?foo=123&bar=321 HTTP/1.0

// close connection (not required in single conn mode)
AT+CIPCLOSE
