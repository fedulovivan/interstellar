###Features and todos:
- [ ] implement UPS 
- [ ] ensure RTC is runnig on unit startup
- [ ] pressure sensors
- [ ] add wired water leakage sensors
- [ ] decrease EEPROM write frequency
- [ ] fix daily reset issue (keep last reset time in eeprom)
- [ ] 433 mhz remote(?)
- [ ] use sockets to connect sensors (eg rj45)
- [ ] menu sounds
- [ ] 12v for beeper and pwm
- [x] armed/disarmed mode (automatic by absence of movement detected/manual)
- [x] send stat in event of changing value / or each n-mintes
- [x] connect sensors and valves
- [x] attach encoder
- [x] attach buttons
- [x] add wifi (esp8266)
- [x] publish statistics to https://thingspeak.com

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