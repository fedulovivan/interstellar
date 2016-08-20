Features and todos:
- ensure RTC is runnig on unit startup
- pressure sensors
- add water leakage sensors (wired or wireless)
- armed/disarmed mode (automatic by absence of movement detected/manual)
- decrease EEPROM write frequency
- fix daily reset issue when unit is being powered off when time is 00:00
- 433 mhz remote(?)
- connect sensors and valves using rj45 sockets
+ attach encoder
+ attach buttons
+ add wifi (esp8266)
+ publish statistics to https://thingspeak.com

Adjustable parameters:
	- display backlight on/off
	- display dev/debug info mode (sensors read values, http stat, esp connection stat, uptime)
	- manual valves management with buttons
	- cloud address (local for tests oe external)
	- date and time
	- feature for manual counters reset (or setting required values)
	- sound alarms on/off
	- send stat in event of changing value / or each n-mintes
