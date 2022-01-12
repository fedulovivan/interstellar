
## Description

ESP8266-based box for remote manipulating of Gidrolock water valves.<br/>
Later was added wired water lakage sensor (branded as Equation and sold by Leroymerlin) and connection to water meters

## Flashing

Run `./upload.sh`<br>
Note that [nodemcu-tool](https://github.com/AndiDittrich/NodeMCU-Tool) utility (last tested with v3.2.1) should be installed in advance with `npm install nodemcu-tool -g`

```
johnny@mbp2015:~/Desktop/Projects/interstellar/valves-manipulator$ ./upload.sh
file size 8924
Checking init.lua OK
Total: 0 warnings / 0 errors in 1 file
[config]      ~ Project based configuration loaded
[NodeMCU-Tool]~ Connected
[device]      ~ Arch: esp8266 | Version: 3.0.0 | ChipID: 0xc1217d | FlashID: 0x1640e0
[NodeMCU-Tool]~ Uploading "init.lua" >> "init.lua"...
[connector]   ~ Transfer-Mode: hex
[NodeMCU-Tool]~ File Transfer complete!
[NodeMCU-Tool]~ disconnecting
OK! successfully uploded and verified size
```

## UART console

`sudo screen /dev/tty.wchusbserial1420 115200`
exit with `Ctrl + A` then `Ctrl + D`

## Pin values

*VALVE_PIN* 0 - valves open; 1 - valves closed<br/>
*WATER_SENSOR_PIN* 0 - leakage detected; 1 - no leakage

## RCA for the error on attempt to attach interrupt handler for the pins with IO index >= 13:

```cpp
#define GPIO_PIN_NUM 13
#define NUM_GPIO              GPIO_PIN_NUM
static inline int platform_gpio_exists( unsigned pin ) { return pin < NUM_GPIO; }
luaL_argcheck(L, platform_gpio_exists(pin) && pin>0, 1, "Invalid interrupt pin");
```

## GPIO to IO index

```lua
local HOT_METER_PIN = 11; -- GPIO9
local HOT_METER_PIN = 12; -- GPIO10
local HOT_METER_PIN = 13; -- GPIO8
local HOT_METER_PIN = 14; -- GPIO6
local HOT_METER_PIN = 9; -- GPIO11
```

## Set intial meter values via MQTT

send H100 to /VALVE/STATE/METERS_SET_ZERO
send C100 to /VALVE/STATE/METERS_SET_ZERO

## Flashing nodemcu

- press "Flash Nodemcu" button on board
- power board
- run `./flash-nodemcu.sh`

also instructions on how to write nodemcu firmware to esp8266 could be found at [../mhz19-box-new/README.md]

## TODOs

- (-) fix issue with reconnection to mqtt server
- (-) software debouncing (hysteresis) for water leakage sennsor handler
- (-) Add build-in СР340С chip + reset sircuit
- (-) Buttons for manual valves management
- (-) Use pre-compiled files / LFS

- (+) Add "Reset" button instead of "Flash LUA"
- (+) Use sjson in lua sketch
- (+) add more powerfull 3.3v reg (LM1117DT 3.3 корпус TO-252 [https://www.chipdip.ru/product/lm1117dt-3.3-nopb])
- (+) change valves transistor to smd version (BC337 to BC817)
- (+) Get current state
- (+) Connect Equation wired water leakage sensor
- (+) Memoise last valve state and use it on boot
- (+) Ping server

## Test Cases

- TODO

## Parts list

Socket types - SP13, GX16, GX12
MIL-STD 5015 [https://aliexpress.ru/item/32620267150.html]

Final
- valves: 4 x SP13 4P [https://aliexpress.ru/item/4000057522634.html]
- leakage sensors KF141V 6P x 2 [https://aliexpress.ru/item/4000902916398.html]
- water meters KF141V 4P x 2 [https://aliexpress.ru/item/4000902916398.html]

Potential sockets
- KF141V spring terminal vertical [https://aliexpress.ru/item/4000901980140.html]
- GX16 socket 4 pin x 4 pcs - valves [https://aliexpress.ru/item/4000145079106.html]
- GX12 socket 3 pin x 4 pcs - water leakage sensor
- GX12 socket 4 pin x 4 pcs - water meters

Glands
- PG6 / PG9 IP68 cable gland x 2 pcs [https://aliexpress.ru/item/1005002584721230.html]

Buttons
- Red waterproof button PBS-33b x 2 pcs [https://aliexpress.ru/item/1005002671842887.html]
- Green waterproof button PBS-33b x 2 pcs

Cases
- Waterproof case x 2 pcs - [https://aliexpress.ru/item/1005001890887248.html]

PSUs
- 12v ac dc psu x 2 pcs [https://aliexpress.ru/item/33011812383.html]
                        [https://aliexpress.ru/item/32769700877.html]
                        [https://aliexpress.ru/item/10000317754857.html]
                        [https://aliexpress.ru/item/32258088214.html]
                        [https://aliexpress.ru/item/4001035491729.html]
                        meanwell IRM-10-12
                        hilink HLK-PM12
