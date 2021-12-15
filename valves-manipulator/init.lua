local CONFIG = {
    MQTT_BROKER_IP = "192.168.88.188",
    MQTT_BROKER_PORT = 1883,
    MQTT_CLIENT_ID = "esp8266-valves-manipulator",
    MQTT_BROKER_USER = "mosquitto",
    MQTT_BROKER_PWD = "5Ysm3jAsVP73nva",
    WIFI_SSID = "wifi domru ivanf",
    WIFI_PWD = "useitatyourownrisk",
    MQTT_TOPIC_SET = "/VALVE/STATE/SET",
    MQTT_TOPIC_STATUS = "/VALVE/STATE/STATUS",
    MQTT_TOPIC_METERS_SET_ZERO = "/VALVE/STATE/METERS_SET_ZERO",
    MQTT_TOPIC_METERS_SAVE = "/VALVE/STATE/METERS_SAVE",
};

local FILES = {
    IS_CLOSED_ON_STARTUP_FILE = "is_closed_on_startup.file",
    HOT_METER_FILE = "hot_meter.file",
    COLD_METER_FILE = "cold_meter.file",
};

local COMMANDS = {
    OPEN_CMD = "open",
    CLOSE_CMD = "close",
};

local STATUS_UPDATE_INTERVAL = 60000 * 1; -- 1 munite
local SAVE_METER_STATE_INTERVAL = 60000 * 30; -- 30 minutes

local VALVE_PIN = 2; -- GPIO4
local WATER_SENSOR_PIN = 6; -- GPIO12
local COLD_METER_PIN = 7; -- GPIO13
local HOT_METER_PIN = 5; -- GPIO14
local GREEN_LED_PIN = 0; -- GPIO16
-- local GREEN_LED_PIN = 4; -- GPIO2

-- mappings
local valvePinValueToStringState = { ["0"] = "opened", ["1"] = "closed" };
local leakageSensorPinValueToBooleanState = { ["0"] = "true", ["1"] = "false" };

-- global variables
local coldMeterTicks = 0;
local hotMeterTicks = 0;
local wifiPrevStatus = 0;
local greenLedState = false;
local mqttIsConnected = false;
local statusTimerTickNumber = 0;
local waterSensorPinLastValue = nil;
local mqttClient = nil;

-- timers
local TIMERS = {
    wifiReconnectTimer = tmr.create(),
    mqttReconnectTimer = tmr.create(),
    greenLedBlinkTimer = tmr.create(),
    sendStatusUpdateTimer = tmr.create(),
    pollWaterSensorTimer = tmr.create(),
    saveMeterStateTimer = tmr.create(),
};

local function saveMeterStateToFiles()
    file.putcontents(FILES.HOT_METER_FILE, tostring(hotMeterTicks));
    file.putcontents(FILES.COLD_METER_FILE, tostring(coldMeterTicks));
    print(
        "hotMeterTicks value " ..
        hotMeterTicks ..
        " and coldMeterTicks value " ..
        coldMeterTicks ..
        " saved to flash"
    );
end;

local function restoreMeterStateFromFiles()
    if file.exists(FILES.HOT_METER_FILE) then
        hotMeterTicks = tonumber(file.getcontents(FILES.HOT_METER_FILE));
        print("hotMeterTicks value " .. hotMeterTicks .. " was restored from flash");
    end
    if file.exists(FILES.COLD_METER_FILE) then
        coldMeterTicks = tonumber(file.getcontents(FILES.COLD_METER_FILE));
        print("coldMeterTicks value " .. coldMeterTicks .. " was restored from flash");
    end
end;

local function sendStatusUpdate()
    if not mqttIsConnected then
        print("sendStatusUpdate: mqtt is not connected");
        return 1;
    end
    local valvePinValue = gpio.read(VALVE_PIN);
    local waterSensorPinValue = gpio.read(WATER_SENSOR_PIN);
    local message = "{" ..
        "\"tick\":" ..
        tostring(statusTimerTickNumber) ..
        ",\"leakage\":" ..
        leakageSensorPinValueToBooleanState[tostring(waterSensorPinValue)] ..
        ",\"valve\":" ..
        "\"" .. valvePinValueToStringState[tostring(valvePinValue)] .. "\"" ..
        ",\"coldMeterTicks\":" .. tostring(coldMeterTicks) ..
        ",\"hotMeterTicks\":" .. tostring(hotMeterTicks) ..
    "}";
    mqttClient:publish(CONFIG.MQTT_TOPIC_STATUS, message, 0, 0);
    statusTimerTickNumber = statusTimerTickNumber + 1;
    return 0;
end;

local function coldMeterPinInterruptHandler()
    print("coldMeterPinInterruptHandler");
    coldMeterTicks = coldMeterTicks + 1;
    sendStatusUpdate();
end;

local function hotMeterPinInterruptHandler()
    print("hotMeterPinInterruptHandler");
    hotMeterTicks = hotMeterTicks + 1;
    sendStatusUpdate();
end;

local function saveIsClosedOnStartup()
    file.open(FILES.IS_CLOSED_ON_STARTUP_FILE, "w");
    file.close();
end;

local function resetIsClosedOnStartup()
    file.remove(FILES.IS_CLOSED_ON_STARTUP_FILE);
end;

local function goOnline()
    print("goOnline");
    mqttIsConnected = true;
    TIMERS.greenLedBlinkTimer:start();
    TIMERS.sendStatusUpdateTimer:start();
end;

local function goOffline()
    print("goOffline");
    mqttIsConnected = false;
    TIMERS.greenLedBlinkTimer:stop();
    TIMERS.sendStatusUpdateTimer:stop();
    gpio.write(GREEN_LED_PIN, gpio.HIGH); -- HIGH means OFF led
end;

local function onMqttServerConnFail(client, reason)
    print("onMqttServerConnFail: reason=" .. tostring(reason));
    goOffline();
end;

local function openValves()
    print("openValves");
    gpio.write(VALVE_PIN, gpio.LOW);
    resetIsClosedOnStartup();
    sendStatusUpdate();
end;

local function closeValves()
    print("closeValves");
    gpio.write(VALVE_PIN, gpio.HIGH);
    saveIsClosedOnStartup();
    sendStatusUpdate();
end;

local function handleMqttMessage(client, topic, data)
    print("mqtt message=" .. topic .. " data=" .. data);

    -- handle mqtt command and update valves state
    -- data is either "open" or "close"
    if topic == CONFIG.MQTT_TOPIC_SET then
        if data == COMMANDS.OPEN_CMD then
            openValves();
        end
        if data == COMMANDS.CLOSE_CMD then
            closeValves();
        end
    end

    -- handle meter set ticks zero level
    -- data format is "H21001" or "C34077"
    -- H21001 - set hot meter ticks to 21001
    -- C34077 - set cold meter ticks to 34077
    if topic == CONFIG.MQTT_TOPIC_METERS_SET_ZERO then
        local type = string.sub(data, 1, 1);
        local value = tonumber(string.sub(data, 2));
        if type == "H" and value ~= nil then
            print("value of hotMeterTicks updated from " .. hotMeterTicks .. " to " .. value);
            hotMeterTicks = value;
            saveMeterStateToFiles();
            sendStatusUpdate();
        end
        if type == "C" and value ~= nil then
            print("value of coldMeterTicks updated from " .. coldMeterTicks .. " to " .. value);
            coldMeterTicks = value;
            saveMeterStateToFiles();
            sendStatusUpdate();
        end
    end

    if topic == CONFIG.MQTT_TOPIC_METERS_SAVE then
        saveMeterStateToFiles();
    end

end

local function connectToMqtt()
    mqttClient:connect(
        CONFIG.MQTT_BROKER_IP,
        CONFIG.MQTT_BROKER_PORT,
        false,
        function()
            print("connected to mqtt server ip=" .. CONFIG.MQTT_BROKER_IP);
            mqttClient:on("message", handleMqttMessage)
            mqttClient:on("offline", goOffline);
            mqttClient:subscribe(
                {
                    [CONFIG.MQTT_TOPIC_SET] = 0,
                    [CONFIG.MQTT_TOPIC_METERS_SET_ZERO] = 0,
                    [CONFIG.MQTT_TOPIC_METERS_SAVE] = 0,
                },
                function()
                    print(
                        "mqtt subscribed to " ..
                        CONFIG.MQTT_TOPIC_SET .. ", " ..
                        CONFIG.MQTT_TOPIC_METERS_SET_ZERO .. ", " ..
                        CONFIG.MQTT_TOPIC_METERS_SAVE
                    );
                    goOnline();
                end
            )
        end,
        onMqttServerConnFail
    );
end;

--- START MAIN

print("valves manipulator starting..");

restoreMeterStateFromFiles();

-- setup gpio pins
gpio.mode(VALVE_PIN, gpio.OUTPUT);
gpio.mode(GREEN_LED_PIN, gpio.OUTPUT);
gpio.write(GREEN_LED_PIN, gpio.HIGH); -- HIGH means OFF led
gpio.mode(WATER_SENSOR_PIN, gpio.INPUT, gpio.PULLUP);
gpio.mode(COLD_METER_PIN, gpio.INT);
gpio.mode(HOT_METER_PIN, gpio.INT);
gpio.trig(COLD_METER_PIN, "down", coldMeterPinInterruptHandler);
gpio.trig(HOT_METER_PIN, "down", hotMeterPinInterruptHandler);

if file.exists(FILES.IS_CLOSED_ON_STARTUP_FILE) then
    gpio.write(VALVE_PIN, gpio.HIGH);
end

-- init wifi
wifi.setmode(wifi.STATION);
wifi.sta.config { ssid=CONFIG.WIFI_SSID, pwd=CONFIG.WIFI_PWD };
wifi.sta.connect();

-- create mqtt client instance
mqttClient = mqtt.Client(
    CONFIG.MQTT_CLIENT_ID,
    120,
    CONFIG.MQTT_BROKER_USER,
    CONFIG.MQTT_BROKER_PWD
);

TIMERS.greenLedBlinkTimer:register(500, tmr.ALARM_AUTO, function()
    gpio.write(
        GREEN_LED_PIN,
        greenLedState and gpio.LOW or gpio.HIGH
    );
    greenLedState = not greenLedState;
end);

TIMERS.mqttReconnectTimer:register(5000, tmr.ALARM_AUTO, function()
    if not mqttIsConnected then
        print("mqttIsConnected=" .. tostring(mqttIsConnected));
        connectToMqtt();
    end
end);

TIMERS.wifiReconnectTimer:register(5000, tmr.ALARM_AUTO, function()
    if wifi.sta.status() == 5 then
        if wifiPrevStatus ~= 5 then
            print("wifi is connected now, ip=" .. wifi.sta.getip());
            TIMERS.mqttReconnectTimer:start();
        end
    else
        print("not connected to wifi..");
        goOffline();
    end
    wifiPrevStatus = wifi.sta.status();
end);

-- send status updates
TIMERS.sendStatusUpdateTimer:register(STATUS_UPDATE_INTERVAL, tmr.ALARM_AUTO, sendStatusUpdate);

-- poll the water leakage pin state and
-- 1. close valves if leakage was detected
-- 2. send update if value has changed
TIMERS.pollWaterSensorTimer:register(1000, tmr.ALARM_AUTO, function()
    local pinValue = gpio.read(WATER_SENSOR_PIN);
    if pinValue == 0 then
        closeValves();
    end
    if waterSensorPinLastValue ~= pinValue then
        sendStatusUpdate();
    end
    waterSensorPinLastValue = pinValue;
end);

-- periodically save meter states to file
TIMERS.saveMeterStateTimer:register(SAVE_METER_STATE_INTERVAL, tmr.ALARM_AUTO, saveMeterStateToFiles);

-- poll water sensor pin state
TIMERS.pollWaterSensorTimer:start();

-- periodically check if wifi is connected
TIMERS.wifiReconnectTimer:start();

-- start saveMeterState timer
TIMERS.saveMeterStateTimer:start();
