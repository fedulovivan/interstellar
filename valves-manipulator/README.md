
## Description

ESP8266-based box for remote manipulating of Gidrolock water valves.<br/>
Later was added wired water lakage sensor (branded as Equation and sold by Leroymerlin) and connection to water meters.
All software/firmware related files is located in [firmware](./firmware/) folder.

## Development

For the lua extension (sumneko.lua) working properly, current folder should be opened in vscode isolately (not to be browsed as as part of the interstellar folder)

## Flashing nodemcu firmware

run `flash.sh`

also old instructions on how to write nodemcu firmware to esp8266 could be found at [../mhz19-box-new/README.md]

## Uploading lua scripts

Install prerequisites:

- [jq](https://jqlang.org/) with `brew install jq`
- [luacheck](https://github.com/mpeterv/luacheck) with `brew install luacheck`
- [nodemcu-tool](https://github.com/AndiDittrich/NodeMCU-Tool) with `yarn global add nodemcu-tool@3.2.1`
- [esptool](https://github.com/espressif/esptool) with `pip install esptool` then need to re-open terminal

Set proper usb serial device in .nodemcutool config;

Run `./upload.sh` and check the results:

```shell
~/Desktop/Projects/interstellar/valves-manipulator/firmware (master*) » ./upload.sh                                                                                                             1 ↵ ivanf@mbp2021
Prerequisites ... OK
Checking init.lua                                 OK
Checking main.lua                                 OK
Checking wifi.lua                                 OK
Total: 0 warnings / 0 errors in 3 files
Checked sources ... OK
[config]      ~ Project based configuration loaded
[NodeMCU-Tool]~ Connected
[device]      ~ Arch: esp8266 | Version: 3.0.0 | ChipID: 0x5982 | FlashID: 0x164068
[NodeMCU-Tool]~ Uploading "version.txt" >> "version.txt"...
[connector]   ~ Transfer-Mode: hex
[NodeMCU-Tool]~ Uploading "config.json" >> "config.json"...
[NodeMCU-Tool]~ Uploading "init.lua" >> "init.lua"...
[NodeMCU-Tool]~ Uploading "main.lua" >> "main.lua"...
[NodeMCU-Tool]~ Uploading "wifi.lua" >> "wifi.lua"...
[NodeMCU-Tool]~ Bulk File Transfer complete!
[NodeMCU-Tool]~ disconnecting
Files uploaded ... OK
Size validated ... OK
Successfully uploded and validated all files
```

## Debugging / uart console / terminal

All log messages printed from application could be viewed via uart, so run the following script to open terminal:

`./terminal.sh`

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

send H28147 to /VALVE/STATE/METERS_SET<br>
send C32684 to /VALVE/STATE/METERS_SET

## TODOs

- (-) try build own https://github.com/nodemcu/nodemcu-firmware and LFS
- (-) implement blink codes
- (-) design a way to enter setup mode, need some access on hardware level (like reset button), or use some timeout after startup
- (-) document mqtt api (published topics, subscribed to topics)
- ---
- (-) add fuse and varistor (see [./docs/psu-typical-application.webp] and https://aliexpress.ru/item/4001035491729.html)
- (-) use wemos d1 mini as base module instead of bare esp-12 + ср340с circuit AKA add build-in СР340С chip + reset circuit
- (-) add to schematics and update pcb for 10k pull resistor for "wired water leakage sennsor"
- (-) software or hardware debouncing (hysteresis) for "wired water leakage sensor" handler to avoid iimediate sending "ceased alarm" message
- (-) add gidrolock valves pins information on silk layer
- (-) implement a safe way to solder AC wires
- (-) add jumper to be able to disconnect meanwell psu and connect external power (to DC line +15v)
- (-) add hardware buttons for manual valves management
- ---
- (+) fix potential overflow for tmr.time() -- should not be the case, 31 bits to store seconds should be enough for 68 years, same question arose here https://www.esp8266.com/viewtopic.php?p=58046
- (+) invoke saveMeterStateToFiles only if last value has been changed
- (+) implement startup page to setup mtqtt and wifi settings; create separate script which is able to receive post request with config file and save it AKA avoid hadcoding connection settings for mqtt server and wifi https://blog.avislab.com/nodemcu-web/; https://radioprog.ru/post/866
- (+) add build information (git commit) AKA add version file and ability to get it via mqtt 
- (+) use pre-compiled files - no sence to use this, since nodemcu expects init.lua as entrypoint and do not accept init.lc, also compilation is anyway performed directly on device after uploading source file
- (+) read variables from config.json
- (+) make base topic configurable, remove leading slash (get rid of hardcoded /VALVE value)
- (+) add box unique identifier
- (+) fix issue with no reconnection to mqtt server
- (+) Add "Reset" button instead of "Flash LUA"
- (+) Use sjson in lua sketch
- (+) add more powerfull 3.3v reg (LM1117DT 3.3 корпус TO-252 [https://www.chipdip.ru/product/lm1117dt-3.3-nopb])
- (+) change valves transistor to smd version (BC337 to BC817)
- (+) Get current state
- (+) Connect Equation wired water leakage sensor
- (+) Memoise last valve state and use it on boot
- (+) Ping server
- ---
- (?) make STATUS_UPDATE_INTERVAL value configurable

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
