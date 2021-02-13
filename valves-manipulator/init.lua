
print("valves manipulator starting..");

local MQTT_BROKER_IP = "192.168.88.188"
local MQTT_BROKER_PORT = 1883
local MQTT_CLIENT_ID = "esp8266-mhz19"
local MQTT_BROKER_USER = "mosquitto"
local MQTT_BROKER_PWD = "5Ysm3jAsVP73nva"

local loStates = { ["off"]=true, ["OFF"]=true, ["0"]=true };
local highStates = { ["on"]=true, ["ON"]=true, ["1"]=true };

local MQTT_TOPIC = "/VALVE/STATE/SET";

-- built-in led pin
local VALVE_PIN = 1 -- GPIO5(D1)
local LED_PIN = 4 -- GPIO16(D4)

gpio.mode(VALVE_PIN, gpio.OUTPUT--[[ , gpio.PULLUP ]]);
gpio.mode(LED_PIN, gpio.OUTPUT--[[ , gpio.PULLUP ]]);

wifi.setmode(wifi.STATION);
wifi.sta.config { ssid="wifi domru ivanf", pwd="useitatyourownrisk" };
wifi.sta.connect();

local wifi_status_prev = 0;

local reconnect_tmr = tmr.create();

reconnect_tmr:register(5000, tmr.ALARM_AUTO, function()

    if wifi.sta.status() == 5 then

        if wifi_status_prev ~= 5 then

            print("wifi is connected now, ip=" .. wifi.sta.getip());

            local mqttClient = mqtt.Client(MQTT_CLIENT_ID, 120, MQTT_BROKER_USER, MQTT_BROKER_PWD);

            mqttClient:connect(
                MQTT_BROKER_IP,
                MQTT_BROKER_PORT,
                false,
                function(client)

                    print("connected to mqtt server ip=" .. MQTT_BROKER_IP);

                    mqttClient:on("message", function(client, topic, data)

                        print("mqtt message=" .. topic .. " data=" .. data);

                        if topic == MQTT_TOPIC then
                            if loStates[data] then
                                gpio.write(VALVE_PIN, gpio.LOW);
                                gpio.write(LED_PIN, gpio.LOW);
                            end
                            if highStates[data] then
                                gpio.write(VALVE_PIN, gpio.HIGH);
                                gpio.write(LED_PIN, gpio.HIGH);
                            end
                        end

                    end)

                    mqttClient:subscribe(MQTT_TOPIC, 0, function(conn)
                        print("mqtt subscribed to " .. MQTT_TOPIC);
                    end)

                end,
                function(client, reason)
                    print("failed to connect to mqtt server: " .. reason);
                end
            );

        end

    else

        print("not connected to wifi..");

    end

    wifi_status_prev = wifi.sta.status();

end);

reconnect_tmr:start();
