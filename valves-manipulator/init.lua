-- constants
local MQTT_BROKER_IP = "192.168.88.188";
local MQTT_BROKER_PORT = 1883;
local MQTT_CLIENT_ID = "esp8266-valves-manipulator";
local MQTT_BROKER_USER = "mosquitto";
local MQTT_BROKER_PWD = "5Ysm3jAsVP73nva";

local loStates = { ["off"]=true, ["OFF"]=true, ["0"]=true };
local highStates = { ["on"]=true, ["ON"]=true, ["1"]=true };

local IS_CLOSED_ON_STARTUP_FILE = "is_closed_on_startup.file";

local MQTT_TOPIC_SET = "/VALVE/STATE/SET";
local MQTT_TOPIC_STATUS = "/VALVE/STATE/STATUS";

local VALVE_PIN = 2; -- GPIO4
local BUILTIN_LED_PIN = 4; -- GPIO16
local GREEN_LED_PIN = 5; -- GPIO14

-- global variables
local wifiPrevStatus = 0;
local wifiReconnectTmr = tmr.create();
local mqttReconnectTimer = tmr.create();
local greenLedBlinkTimer = tmr.create();
local statusTimer = tmr.create();
local greenLedState = false;
local mqttIsConnected = false;
local statusTimerTickNumber = 0;

print("valves manipulator starting..");

-- setup gpio pins
gpio.mode(VALVE_PIN, gpio.OUTPUT);
gpio.mode(BUILTIN_LED_PIN, gpio.OUTPUT);
gpio.mode(GREEN_LED_PIN, gpio.OUTPUT);
gpio.write(GREEN_LED_PIN, gpio.HIGH);

if file.exists(IS_CLOSED_ON_STARTUP_FILE) then
    gpio.write(VALVE_PIN, gpio.HIGH);
    gpio.write(BUILTIN_LED_PIN, gpio.HIGH);
end

-- init wifi
wifi.setmode(wifi.STATION);
wifi.sta.config { ssid="wifi domru ivanf", pwd="useitatyourownrisk" };
wifi.sta.connect();

-- create mqtt client instance
local mqttClient = mqtt.Client(
    MQTT_CLIENT_ID,
    120,
    MQTT_BROKER_USER,
    MQTT_BROKER_PWD
);

function saveIsClosedOnStartup()
    file.open(IS_CLOSED_ON_STARTUP_FILE, "w");
    file.close();
end;

function resetIsClosedOnStartup()
    file.remove(IS_CLOSED_ON_STARTUP_FILE);
end;

function goOnline()
    print("goOnline");
    mqttIsConnected = true;
    greenLedBlinkTimer:start();
    statusTimer:start();
end;

function goOffline()
    print("goOffline");
    mqttIsConnected = false;
    greenLedBlinkTimer:stop();
    statusTimer:stop();
    gpio.write(GREEN_LED_PIN, gpio.HIGH);
end;

function onMqttServerConnFail(client, reason)
    print("onMqttServerConnFail, reason=" .. tostring(reason));
    goOffline();
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

                if topic == MQTT_TOPIC_SET then
                    if loStates[data] then
                        gpio.write(VALVE_PIN, gpio.LOW);
                        gpio.write(BUILTIN_LED_PIN, gpio.LOW);
                        resetIsClosedOnStartup();
                    end
                    if highStates[data] then
                        gpio.write(VALVE_PIN, gpio.HIGH);
                        gpio.write(BUILTIN_LED_PIN, gpio.HIGH);
                        saveIsClosedOnStartup();
                    end
                end

            end)

            mqttClient:on("offline", goOffline);

            mqttClient:subscribe(MQTT_TOPIC_SET, 0, function(conn)
                print("mqtt subscribed to " .. MQTT_TOPIC_SET);
                goOnline();
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
        goOffline();

    end

    wifiPrevStatus = wifi.sta.status();

end);

statusTimer:register(30000, tmr.ALARM_AUTO, function()
    mqttClient:publish(MQTT_TOPIC_STATUS, "tick #" .. statusTimerTickNumber, 0, 0);
    statusTimerTickNumber = statusTimerTickNumber + 1;
end);

wifiReconnectTmr:start();
