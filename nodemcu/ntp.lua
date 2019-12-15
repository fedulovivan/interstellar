-- TODO
-- try mdns
-- try writing counters to file
-- read zigbee sensors states

local WIFI_SSID = "wifi domru ivanf"
local WIFI_PWD = "useitatyourownrisk"

local MQTT_BROKER_IP = "192.168.88.207"
local MQTT_BROKER_PORT = 1883
local MQTT_CLIENT_ID = "esp8266-ntp-client"
local MQTT_BROKER_USER = "mosquitto"
local MQTT_BROKER_PWD = "5Ysm3jAsVP73nva"

local ISO_8601 = "%04d-%02d-%02dT%02d:%02d:%02dZ";

local wifiPrevStatus = 0

-- create timers
local wifiReconnectTmr = tmr.create()
local recurrentMqttMessageTmr = tmr.create()
local ntpSyncTmr = tmr.create()

-- setup wifi
wifi.setmode(wifi.STATION)
wifi.sta.config({ ssid=WIFI_SSID; pwd=WIFI_PWD })
wifi.sta.connect()

-- create mqtt client
local mqttClient = mqtt.Client(MQTT_CLIENT_ID, 120, MQTT_BROKER_USER, MQTT_BROKER_PWD)

mqttClient:on("offline", function(client)
    -- print("mqtt offline")
    recurrentMqttMessageTmr:stop()
end)

-- timer will be started after connnecting to mqtt broker
recurrentMqttMessageTmr:register(5000, tmr.ALARM_AUTO, function ()

    local sec, msec = rtctime.get()

    local tm = rtctime.epoch2cal(sec);

    mqttClient:publish("/NTP/DEBUG", sec.."."..msec, 0, 0)

    if sec > 0 then
        mqttClient:publish(
            "/NTP/DEBUG",
            string.format(
                ISO_8601,
                tm["year"], tm["mon"], tm["day"], tm["hour"], tm["min"], tm["sec"]
            ),
            0,
            0
        )
    end

    -- print("rtc, seconds="..sec.."."..msec)
end)

function NtpSync()
    sntp.sync("pool.ntp.org", function (seconds)
        -- print("ntp, seconds="..seconds)
    end)
end

function WifiConnect()

    -- print("wifiReconnectTmr prevStatus="..wifiPrevStatus.." currStatus="..wifi.sta.status())

    if wifi.sta.status() == 5 then

        if wifiPrevStatus ~= 5 then

            -- print("wifi connected")

            -- sync time immediately when wifi is avaialble
            NtpSync();
            -- do periodic syncs
            ntpSyncTmr:start();

            mqttClient:connect(MQTT_BROKER_IP, MQTT_BROKER_PORT, false, function(conn)

                -- print("mqtt connected")
                recurrentMqttMessageTmr:start();

            end)

        end
    else
        recurrentMqttMessageTmr:stop()
        -- print("wifi (re)connect")
        wifi.sta.connect()
    end

    -- memoizing wifi connection status for the next timer tick
    wifiPrevStatus = wifi.sta.status()

end

ntpSyncTmr:register(1800 * 1000, tmr.ALARM_AUTO, NtpSync)

WifiConnect();
wifiReconnectTmr:register(10000, tmr.ALARM_AUTO, WifiConnect);
wifiReconnectTmr:start()
