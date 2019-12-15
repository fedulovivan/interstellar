ruslan`s sample scripts
https://bitbucket.org/nadyrshin_ryu/esp8266_mqtt/src/master/mqtt.lua
https://bitbucket.org/nadyrshin_ryu/esp8285_bn-sz01/src/master/mqtt_bn-sz01_dim_smooth.lua

- mqtt client on esp8266 written on lua
    nodemcu ide: https://esp8266.ru/esplorer/
    building nodemcu firmware online: http://nodemcu-build.com with mqtt enabled
    flash nodecu from cli: ~/Desktop/ESP8266/esptool/esptool.py --baud 115200 --port /dev/cu.wchusbserial1410 write_flash 0x0000 ~/Downloads/nodemcu-master-10-modules-2019-11-27-20-40-20-integer.bin

    https://esp8266.ru/esp8266-podkluchenie-obnovlenie-proshivki/

    open serial in console:
    sudo screen /dev/cu.wchusbserial1410 115200

- install and run mqtt brocker "mosquitto" (https://mosquitto.org/)
    brew install mosquitto
    run mosquitto -v

    or install it on hassio

    mosquitto/5Ysm3jAsVP73nva


- launch home assistant in docker
    download image https://hub.docker.com/r/homeassistant/home-assistant/
    create container and forward its 8123 port to outside
    open web ui http://127.0.0.1:8123/

- connect to mqtt brocker in configuration.yaml (mqtt:broker:192.168.88.211)

- add mqtt "sensor"
    https://www.home-assistant.io/integrations/sensor.mqtt/
    sensor:
        - platform: mqtt
            name: "ESP8266 Random Source"
            state_topic: "/ESP/DHT/TEMP"
            unit_of_measurement: "R"

- launch hassio on rpi 2
    how to flash: https://computers.tutsplus.com/articles/how-to-flash-an-sd-card-for-raspberry-pi--mac-53600
    flash sd card: sudo dd if=~/Downloads/hassos_rpi2-2.12.img of=/dev/disk2 bs=2m
    connect pi via ethernet and wait 20 mins
    ligin with: ivan/P7a5EfDWNxJqm7F
    ssh: root/Tb4mqFCJtY4ubmY
    ssh root@hassio.local


- using cli tool to upload lua scripts to esp8266
    git clone https://github.com/4refr0nt/luatool
    cd luatool/luatool
    luac -p ~/Dropbox/Arduino/interstellar/nodemcu/mqtt.lua && /Users/johnny/Desktop/Projects/luatool/luatool/luatool.py --port /dev/cu.wchusbserial1410 --src ~/Dropbox/Arduino/interstellar/nodemcu/mqtt.lua --dest mqtt.lua --baud 1200 --verbose
    or via https://www.npmjs.com/package/nodemcu-tool
    yarn global add nodemcu-tool
    luac -p mqtt.lua && nodemcu-tool -p /dev/cu.wchusbserial1410 upload mqtt.lua

https://habr.com/ru/post/411259/

/ESP/MH/DEBUG 1 0xFF
/ESP/MH/DEBUG 2 0x86
/ESP/MH/DEBUG 3 0x05
/ESP/MH/DEBUG 4 0x41
/ESP/MH/DEBUG 5 0x44
/ESP/MH/DEBUG 6 0x00
/ESP/MH/DEBUG 7 0x00
/ESP/MH/DEBUG 8 0x00
/ESP/MH/DEBUG 9 0xF0
/ESP/MH/CO2 1345
/ESP/MH/TEMP 28

- installing wiring pi
    clone mirror since official repo git://git.drogon.net/wiringPi is offline:(
    git clone https://github.com/WiringPi/WiringPi
    cd WiringPi
    ./build
    gpio -v

- nodejs
    uname -m
    https://nodejs.org/dist/latest-v10.x/
    https://nodejs.org/dist/latest-v10.x/node-v10.17.0-linux-armv7l.tar.gz
