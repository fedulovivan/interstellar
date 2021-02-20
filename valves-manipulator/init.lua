
print("valves manipulator starting..");

local MQTT_BROKER_IP = "192.168.88.188";
local MQTT_BROKER_PORT = 1883;
local MQTT_CLIENT_ID = "esp8266-valves-manipulator";
local MQTT_BROKER_USER = "mosquitto";
local MQTT_BROKER_PWD = "5Ysm3jAsVP73nva";

local loStates = { ["off"]=true, ["OFF"]=true, ["0"]=true };
local highStates = { ["on"]=true, ["ON"]=true, ["1"]=true };

local MQTT_TOPIC = "/VALVE/STATE/SET";

local VALVE_PIN = 2; -- GPIO4
local BUILTIN_LED_PIN = 4; -- GPIO16
local GREEN_LED_PIN = 5; -- GPIO14

gpio.mode(VALVE_PIN, gpio.OUTPUT);
gpio.mode(BUILTIN_LED_PIN, gpio.OUTPUT);
gpio.mode(GREEN_LED_PIN, gpio.OUTPUT);
gpio.write(GREEN_LED_PIN, gpio.HIGH);

-- init wifi
wifi.setmode(wifi.STATION);
wifi.sta.config { ssid="wifi domru ivanf", pwd="useitatyourownrisk" };
wifi.sta.connect();

-- global variables
local wifiPrevStatus = 0;
local wifiReconnectTmr = tmr.create();
local mqttReconnectTimer = tmr.create();
local greenLedBlinkTimer = tmr.create();
local greenLedState = false;
local mqttIsConnected = false;

-- create mqtt client instance
local mqttClient = mqtt.Client(
    MQTT_CLIENT_ID,
    120,
    MQTT_BROKER_USER,
    MQTT_BROKER_PWD
);

function startGreenLedBlinker()
    print("startGreenLedBlinker");
    mqttIsConnected = true;
    greenLedBlinkTimer:start();
end;

function stopGreenLedBlinker()
    print("stopGreenLedBlinker");
    mqttIsConnected = false;
    greenLedBlinkTimer:stop();
    gpio.write(GREEN_LED_PIN, gpio.HIGH);
end;

function onMqttServerOffline()
    print("onMqttServerOffline");
    stopGreenLedBlinker();
end;

function onMqttServerConnFail(client, reason)
    print("onMqttServerConnFail, reason=" .. tostring(reason));
    stopGreenLedBlinker();
end;

function connectToMqtt()

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
                        gpio.write(BUILTIN_LED_PIN, gpio.LOW);
                    end
                    if highStates[data] then
                        gpio.write(VALVE_PIN, gpio.HIGH);
                        gpio.write(BUILTIN_LED_PIN, gpio.HIGH);
                    end
                end

            end)

            mqttClient:on("offline", onMqttServerOffline);

            mqttClient:subscribe(MQTT_TOPIC, 0, function(conn)
                print("mqtt subscribed to " .. MQTT_TOPIC);
                startGreenLedBlinker();
            end)

        end,
        onMqttServerConnFail
    );

end;

greenLedBlinkTimer:register(500, tmr.ALARM_AUTO, function()
    gpio.write(
        GREEN_LED_PIN,
        greenLedState and gpio.LOW or gpio.HIGH
    );
    greenLedState = not greenLedState;
end);


mqttReconnectTimer:register(5000, tmr.ALARM_AUTO, function()
    if not mqttIsConnected then
        print("mqttIsConnected=" .. tostring(mqttIsConnected));
        connectToMqtt();
    end
end);

wifiReconnectTmr:register(5000, tmr.ALARM_AUTO, function()

    if wifi.sta.status() == 5 then

        if wifiPrevStatus ~= 5 then

            print("wifi is connected now, ip=" .. wifi.sta.getip());

            mqttReconnectTimer:start();

        end

    else

        print("not connected to wifi..");
        stopGreenLedBlinker();

    end

    wifiPrevStatus = wifi.sta.status();

end);

wifiReconnectTmr:start();
