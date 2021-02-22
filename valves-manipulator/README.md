
## Description

ESP8266-based box for remote manipulating of Gidrolock water valves

## Flashing

`luac init.lua && nodemcu-tool upload init.lua && nodemcu-tool fsinfo`

## TODOs

- Button for manual management
- Get statistics (uptime, current state)
- Use pre-compiled files
+ Memoise last valve state and use it on boot
+ Ping server
