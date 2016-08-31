###Features and todos:
- ensure RTC is runnig on unit startup
- pressure sensors
- add water leakage sensors (wired or wireless)
- armed/disarmed mode (automatic by absence of movement detected/manual)
- decrease EEPROM write frequency
- fix daily reset issue when unit is being powered off when time is 00:00
- 433 mhz remote(?)
- use sockets (eg rj45)
- menu sounds
- 12v for beeper and pwm
+ send stat in event of changing value / or each n-mintes
+ connect sensors and valves
+ attach encoder
+ attach buttons
+ add wifi (esp8266)
+ publish statistics to https://thingspeak.com

###Adjustable parameters:
- display backlight on/off
- display dev/debug info mode (sensors read values, http stat, esp connection stat, uptime)
- manual valves management with buttons
- cloud address (local for tests or external)
- date and time
- feature for manual counters reset (or setting required values)
- sound alarms on/off	

###Buttons:
- SET
- BACK
- NEXT
- PREV

###Menu lib features:
- Flat list - [SET] enables menu mode, [BACK] exits menu, [NEXT] and [PREV] to navigates elements
- Display some variable no action on [NEXT], [PREV]
- Edit labeled options (On/Off), (open/closed), select value from predefined list
- Edit simple number (with limits)
- Edit big number (with limits)

###Menu elements:
- Sound on/off
- Backlight on/off
- Reset counters
- Edit hour
- Edit minute
- Edit total hot
- Edit total cold
- Cold valve open/closed
- Hot valve open/closed
- Watchdog on/off
- Response from ESP
