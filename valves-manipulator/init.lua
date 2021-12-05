-- constants
local MQTT_BROKER_IP = "192.168.88.188";
local MQTT_BROKER_PORT = 1883;
local MQTT_CLIENT_ID = "esp8266-valves-manipulator";
local MQTT_BROKER_USER = "mosquitto";
local MQTT_BROKER_PWD = "5Ysm3jAsVP73nva";
local WIFI_SSID = "wifi domru ivanf";
local WIFI_PWD = "useitatyourownrisk";

local OPEN_CMD = "open";
local CLOSE_CMD = "close";

local valvePinValueToStringState = { ["0"]="opened", ["1"]="closed" };
local leakageSensorPinValueToBooleanState = { ["0"]="true", ["1"]="false" };

local IS_CLOSED_ON_STARTUP_FILE = "is_closed_on_startup.file";

local MQTT_TOPIC_SET = "/VALVE/STATE/SET";
local MQTT_TOPIC_STATUS = "/VALVE/STATE/STATUS";

local VALVE_PIN = 2; -- GPIO4
local BUILTIN_LED_PIN = 4; -- GPIO16
local GREEN_LED_PIN = 5; -- GPIO14
local WATER_SENSOR_PIN = 6; -- GPIO12

-- constants
local STATUS_UPDATE_INTERVAL = 60000;

-- global variables
local wifiPrevStatus = 0;
local wifiReconnectTimer = tmr.create();
local mqttReconnectTimer = tmr.create();
local greenLedBlinkTimer = tmr.create();
local statusTimer = tmr.create();
local waterSensorTimer = tmr.create();
local greenLedState = false;
local mqttIsConnected = false;
local statusTimerTickNumber = 0;
local waterSensorPinLastValue = nil;

print("valves manipulator starting..");

-- setup gpio pins
gpio.mode(VALVE_PIN, gpio.OUTPUT);
gpio.mode(BUILTIN_LED_PIN, gpio.OUTPUT);
gpio.mode(GREEN_LED_PIN, gpio.OUTPUT);
gpio.write(GREEN_LED_PIN, gpio.HIGH);
gpio.mode(WATER_SENSOR_PIN, gpio.INPUT, gpio.PULLUP);

if file.exists(IS_CLOSED_ON_STARTUP_FILE) then
    gpio.write(VALVE_PIN, gpio.HIGH);
    gpio.write(BUILTIN_LED_PIN, gpio.HIGH);
end

-- init wifi
wifi.setmode(wifi.STATION);
wifi.sta.config { ssid=WIFI_SSID, pwd=WIFI_PWD };
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

function sendStatusUpdate()
    local valvePinValue = gpio.read(VALVE_PIN);
    local waterSensorPinValue = gpio.read(WATER_SENSOR_PIN);
    local message = "{" ..
        "\"tick\":" ..
        tostring(statusTimerTickNumber) ..
        ",\"leakage\":" ..
        leakageSensorPinValueToBooleanState[tostring(waterSensorPinValue)] ..
        ",\"valve\":" ..
        "\"" .. valvePinValueToStringState[tostring(valvePinValue)] .. "\"" ..
    "}";
    mqttClient:publish(MQTT_TOPIC_STATUS, message, 0, 0);
    statusTimerTickNumber = statusTimerTickNumber + 1;
end;

function openValves()
    gpio.write(VALVE_PIN, gpio.LOW);
    gpio.write(BUILTIN_LED_PIN, gpio.LOW);
    resetIsClosedOnStartup();
    sendStatusUpdate();
end;

function closeValves()
    gpio.write(VALVE_PIN, gpio.HIGH);
    gpio.write(BUILTIN_LED_PIN, gpio.HIGH);
    saveIsClosedOnStartup();
    sendStatusUpdate();
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
                -- handle mqtt command and update valves state
                if topic == MQTT_TOPIC_SET then
                    if --[[ loStates[data] ]]data == OPEN_CMD then
                        openValves();
                    end
                    if --[[ highStates[data] ]]data == CLOSE_CMD then
                        closeValves();
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

wifiReconnectTimer:register(5000, tmr.ALARM_AUTO, function()
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

-- send status updates
statusTimer:register(STATUS_UPDATE_INTERVAL, tmr.ALARM_AUTO, sendStatusUpdate);

-- poll the water leakage pin state and
-- 1. close valves if leakage was detected
-- 2. send update if value has changed
waterSensorTimer:register(1000, tmr.ALARM_AUTO, function()
    local pinValue = gpio.read(WATER_SENSOR_PIN);
    if pinValue == 0 then
        closeValves();
    end
    if waterSensorPinLastValue ~= pinValue then
        sendStatusUpdate();
    end
    waterSensorPinLastValue = pinValue;
end);

waterSensorTimer:start();

wifiReconnectTimer:start();
