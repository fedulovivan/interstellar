ruslan`s sample scripts with mqtt
https://bitbucket.org/nadyrshin_ryu/esp8266_mqtt/src/master/mqtt.lua
https://bitbucket.org/nadyrshin_ryu/esp8285_bn-sz01/src/master/mqtt_bn-sz01_dim_smooth.lua

- mqtt client on esp8266 written on lua
    nodemcu ide: https://esp8266.ru/esplorer/
    building nodemcu firmware online: http://nodemcu-build.com with mqtt module enabled
    flash nodecu from cli:
    ```shell
    ~/Desktop/ESP8266/esptool/esptool.py\
    --baud 115200\
    --port /dev/cu.wchusbserial1410\
    write_flash 0x0000\
    ~/Downloads/nodemcu-master-10-modules-2019-11-27-20-40-20-integer.bin
    ```

    https://esp8266.ru/esp8266-podkluchenie-obnovlenie-proshivki/

    open serial in console:
    sudo screen /dev/cu.wchusbserial1410 115200

- install and run mqtt brocker "mosquitto" (https://mosquitto.org/)
    `brew install mosquitto`
    check version
    `mosquitto -v`
    or install mosquitto as hassio addon
    credentials: mosquitto/5Ysm3jAsVP73nva

- launch home assistant in docker (on lunux or on mac)
    download image https://hub.docker.com/r/homeassistant/home-assistant/
    create container and forward its 8123 port to outside
    open web ui http://127.0.0.1:8123/

- specify connection to mqtt broker in configuration.yaml (mqtt:broker:192.168.88.211)

- add mqtt "sensor"
    https://www.home-assistant.io/integrations/sensor.mqtt/
    ```yaml
    sensor:
        - platform: mqtt
            name: "ESP8266 Random Source"
            state_topic: "/ESP/DHT/TEMP"
            unit_of_measurement: "R"
    ```

- launching hassio on rpi 2
    how to flash rpi: https://computers.tutsplus.com/articles/how-to-flash-an-sd-card-for-raspberry-pi--mac-53600
    flash sd card:
    `sudo dd if=~/Downloads/hassos_rpi2-2.12.img of=/dev/disk2 bs=2m`
    connect pi via ethernet and wait 20 mins
    ligin with: ivan/P7a5EfDWNxJqm7F
    ssh: root/Tb4mqFCJtY4ubmY
    ssh root@hassio.local

- cli tools for uploading lua scripts to esp8266
    `git clone https://github.com/4refr0nt/luatool`
    `cd luatool/luatool`
    `luac -p ~/Dropbox/Arduino/interstellar/nodemcu/mqtt.lua && /Users/johnny/Desktop/Projects/luatool/luatool/luatool.py --port /dev/cu.wchusbserial1410 --src ~/Dropbox/Arduino/interstellar/nodemcu/mqtt.lua --dest mqtt.lua --baud 1200 --verbose`
    or via https://www.npmjs.com/package/nodemcu-tool (which is way more faster and stable)
    `yarn global add nodemcu-tool`
    `luac -p mqtt.lua && nodemcu-tool -p /dev/cu.wchusbserial1410 upload mqtt.lua`

- Подключаем счетчик воды к умному дому
    https://habr.com/ru/post/411259/

- installing wiring pi
    `clone mirror since official repo git://git.drogon.net/wiringPi is offline:(`
    `git clone https://github.com/WiringPi/WiringPi`
    `cd WiringPi`
    `./build`
    `gpio -v`

- nodejs downloads
    check current os arch:
    `uname -m`
    https://nodejs.org/dist/latest-v10.x/
    https://nodejs.org/dist/latest-v10.x/node-v10.17.0-linux-armv7l.tar.gz

- mdns
    query all hosts on linux:
    `avahi-browse --all`
    query all ssh services on macos:
    from https://apple.stackexchange.com/a/76621:
    `dns-sd -B _services._dns-sd._udp`
    `dns-sd -B _ssh`
    `dns-sd -L hassio _ssh`
    or install https://apps.apple.com/us/app/discovery-dns-sd-browser/id1381004916

    mdns results table: 3fff1628
    {
        ["hassio._ssh._tcp.local"] = {
            ["port"] = 22,
            ["name"] = hassio,
            ["hostname"] = hassio,
            ["service"] = _ssh._tcp.local,
            ["ipv6"] = fe80::b5a5:bce8:43dd:2bd1,
            ["ipv4"] = 192.168.88.207,
        }
    }

-  telegram bot
    t.me/Mhz19Bot