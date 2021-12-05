
## Description

ESP8266-based box for remote manipulating of Gidrolock water valves.<br/>
Later was added wired water lakage sensor (branded as Equation and sold by Leroymerlin)

## Flashing

Run `./upload.sh`<br>
Note that [nodemcu-tool](https://github.com/AndiDittrich/NodeMCU-Tool) utility (last tested with v3.2.1) should be installed in advance with `npm install nodemcu-tool -g`

```
johnny@mbp2015:~/Desktop/Projects/interstellar/valves-manipulator$ ./upload.sh
4982
[config]      ~ Project based configuration loaded
[NodeMCU-Tool]~ Connected
[device]      ~ Arch: esp8266 | Version: 3.0.0 | ChipID: 0x2777c | FlashID: 0x1640e0
[NodeMCU-Tool]~ Uploading "init.lua" >> "init.lua"...
[connector]   ~ Transfer-Mode: hex
[NodeMCU-Tool]~ File Transfer complete!
[NodeMCU-Tool]~ disconnecting
[config]      ~ Project based configuration loaded
[NodeMCU-Tool]~ Connected
[device]      ~ Arch: esp8266 | Version: 3.0.0 | ChipID: 0x2777c | FlashID: 0x1640e0
[device]      ~ Free Disk Space: 507 KB | Total: 516 KB | 1 Files
[device]      ~ Files stored into Flash (SPIFFS)
[device]      ~  - init.lua (4982 Bytes)
[NodeMCU-Tool]~ disconnecting
```

## Pin values

*VALVE_PIN* 0 - valves open; 1 - valves closed<br/>
*WATER_SENSOR_PIN* 0 - leakage detected; 1 - no leakage

## TODOs

- (-) Button for manual management
- (-) Use pre-compiled files
- (+) Get current state
- (+) Connect Equation wired water leakage sensor
- (+) Memoise last valve state and use it on boot
- (+) Ping server
