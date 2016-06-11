Upload new flash to ESP:
./esptool.py --baud 9600 --port /dev/cu.wchusbserial1410 write_flash ~/Desktop/ESP_8266_v0.9.2.2\ AT\ Firmware.bin

Connect to network:

// turn itself to client
AT+CWMODE=1

// connect to home wifi
AT+CWJAP="wifi domru ivanf","*****"

Sending HTTP GET request:

// set single conn mode and initiate single connection
AT+CIPMUX=0
AT+CIPSTART="TCP","192.168.88.252",8080

// tell server get request size, including \r\n characters
AT+CIPSEND=62

// wait for > character and send string terminated with two \r\n
GET http://192.168.88.252:8080/?foo=123&bar=321 HTTP/1.0

// close connection (not required in single conn mode)
AT+CIPCLOSE
