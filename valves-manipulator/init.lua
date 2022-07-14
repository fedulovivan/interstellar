local CHIPID = node.chipid();

local CONFIG = {
    MQTT_BROKER_IP = "192.168.88.188",
    MQTT_BROKER_PORT = 1883,
    MQTT_CLIENT_ID = "esp8266-valves-manipulator-" .. CHIPID,
    MQTT_BROKER_USER = "mosquitto",
    MQTT_BROKER_PWD = "5Ysm3jAsVP73nva",
    WIFI_SSID = "wifi domru ivanf",
    WIFI_PWD = "useitatyourownrisk",
    MQTT_TOPIC_SET = "/VALVE/" .. CHIPID .. "/STATE/SET",
    MQTT_TOPIC_STATUS = "/VALVE/" .. CHIPID .. "/STATE/STATUS",
    MQTT_TOPIC_METERS_SET = "/VALVE/" .. CHIPID .. "/STATE/METERS_SET",
    MQTT_TOPIC_METERS_SAVE = "/VALVE/" .. CHIPID .. "/STATE/METERS_SAVE",
};

local MQTT_SUBSCRIPTIONS = {
    [CONFIG.MQTT_TOPIC_SET] = 0,
    [CONFIG.MQTT_TOPIC_METERS_SET] = 0,
    [CONFIG.MQTT_TOPIC_METERS_SAVE] = 0,
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

local VALVE_OPEN = gpio.LOW;
local VALVE_CLOSED = gpio.HIGH;
local WATER_SENSOR_LEAKAGE_DETECTED = gpio.LOW;

-- global variables
local coldMeterTicks = 0;
local hotMeterTicks = 0;
local wifiPrevStatus = 0;
local mqttIsConnected = false;
local waterSensorPinLastValue = gpio.HIGH;
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

local function sendStatusUpdate(origin)
    if not mqttIsConnected then
        print("sendStatusUpdate: mqtt not yet connected (origin=" .. origin .. ")");
        return 1;
    end
    local waterSensorPinValue = gpio.read(WATER_SENSOR_PIN);
    local valvePinValue = gpio.read(VALVE_PIN);
    local message = sjson.encode({
        time = tmr.time(),
        leakage = waterSensorPinValue == WATER_SENSOR_LEAKAGE_DETECTED,
        valve = valvePinValue == VALVE_OPEN and "opened" or "closed",
        coldMeterTicks = coldMeterTicks,
        hotMeterTicks = hotMeterTicks,
        origin = origin,
    });
    mqttClient:publish(CONFIG.MQTT_TOPIC_STATUS, message, 0, 0);
    return 0;
end;

local function coldMeterPinInterruptHandler()
    print("coldMeterPinInterruptHandler");
    coldMeterTicks = coldMeterTicks + 1;
    sendStatusUpdate("coldMeterPinInterruptHandler");
end;

local function hotMeterPinInterruptHandler()
    print("hotMeterPinInterruptHandler");
    hotMeterTicks = hotMeterTicks + 1;
    sendStatusUpdate("hotMeterPinInterruptHandler");
end;

local function saveIsClosedOnStartup()
    if not file.exists(FILES.IS_CLOSED_ON_STARTUP_FILE) then
        file.open(FILES.IS_CLOSED_ON_STARTUP_FILE, "w");
        file.close();
    end;
end;

local function resetIsClosedOnStartup()
    if file.exists(FILES.IS_CLOSED_ON_STARTUP_FILE) then
        file.remove(FILES.IS_CLOSED_ON_STARTUP_FILE);
    end;
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

local function openValves()
    print("openValves");
    gpio.write(VALVE_PIN, VALVE_OPEN);
    resetIsClosedOnStartup();
    sendStatusUpdate("openValves");
end;

local function closeValves(--[[ withStatusUpdate ]])
    print("closeValves");
    gpio.write(VALVE_PIN, VALVE_CLOSED);
    -- if withStatusUpdate then
    -- end;
    sendStatusUpdate("closeValves");
    saveIsClosedOnStartup();
end;

local function handleMqttMessage(client, topic, data)
    print("mqtt message=" .. tostring(topic) .. " data=" .. tostring(data));

    -- handle mqtt command and update valves state
    -- data is either "open" or "close"
    if topic == CONFIG.MQTT_TOPIC_SET and data ~= nil then
        if data == COMMANDS.OPEN_CMD then
            openValves();
        elseif data == COMMANDS.CLOSE_CMD then
            closeValves();
        else
            print("unexpected data");
        end

    -- ability to set meter values
    -- data string is "H21001" or "C34077"
    -- H21001 - set hot meter ticks to 21001
    -- C34077 - set cold meter ticks to 34077
    elseif topic == CONFIG.MQTT_TOPIC_METERS_SET and data ~= nil then
        local type = string.sub(data, 1, 1);
        local value = tonumber(string.sub(data, 2));
        if type == "H" and value ~= nil then
            print("value of hotMeterTicks updated from " .. hotMeterTicks .. " to " .. value);
            hotMeterTicks = value;
            saveMeterStateToFiles();
            sendStatusUpdate("handleMqttMessage");
        elseif type == "C" and value ~= nil then
            print("value of coldMeterTicks updated from " .. coldMeterTicks .. " to " .. value);
            coldMeterTicks = value;
            saveMeterStateToFiles();
            sendStatusUpdate("handleMqttMessage");
        else
            print("unexpected data");
        end

    -- ability to toggle saveMeterStateToFiles
    elseif topic == CONFIG.MQTT_TOPIC_METERS_SAVE then
        saveMeterStateToFiles();

    else
        print("unexpected topic");
    end

end

local function connectToMqtt()
    mqttClient:connect(
        CONFIG.MQTT_BROKER_IP,
        CONFIG.MQTT_BROKER_PORT,
        -- secure
        false,
        -- connection succeeded
        function ()
            print("connected to mqtt server ip=" .. CONFIG.MQTT_BROKER_IP);
            mqttClient:on("message", handleMqttMessage);
            mqttClient:on("offline", goOffline);
            mqttClient:subscribe(
                MQTT_SUBSCRIPTIONS,
                function()
                    print("mqtt subscribed");
                    goOnline();
                end
            );
        end,
        -- connection failed
        function (client, reason)
            print("mqttClient:connect failed. reason=" .. tostring(reason));
            goOffline();
        end
    );
end;

--- START MAIN

print("valves manipulator starting...");

print("chipid=" .. CHIPID);

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
    local isHigh = gpio.read(GREEN_LED_PIN) == gpio.HIGH;
    gpio.write(
        GREEN_LED_PIN,
        isHigh and gpio.LOW or gpio.HIGH
    );
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
        print("not connected to wifi...");
        goOffline();
    end
    wifiPrevStatus = wifi.sta.status();
end);

-- send status updates periodically
TIMERS.sendStatusUpdateTimer:register(STATUS_UPDATE_INTERVAL, tmr.ALARM_AUTO, function()
    sendStatusUpdate("sendStatusUpdateTimer");
end);

-- poll the water leakage pin state and
-- 1. close valves if leakage was detected
-- 2. send update if value has changed
TIMERS.pollWaterSensorTimer:register(1000, tmr.ALARM_AUTO, function()
    local waterSensorPinValue = gpio.read(WATER_SENSOR_PIN);
    local valvePinValue = gpio.read(VALVE_PIN);
    if waterSensorPinValue == WATER_SENSOR_LEAKAGE_DETECTED and valvePinValue == VALVE_OPEN then
        closeValves(--[[ false ]]);
    end
    if waterSensorPinLastValue ~= waterSensorPinValue then
        sendStatusUpdate("waterSensorPinLastValue");
    end
    waterSensorPinLastValue = waterSensorPinValue;
end);

-- periodically save meter states to file
TIMERS.saveMeterStateTimer:register(SAVE_METER_STATE_INTERVAL, tmr.ALARM_AUTO, saveMeterStateToFiles);

-- poll water sensor pin state
TIMERS.pollWaterSensorTimer:start();

-- periodically check if wifi is connected
TIMERS.wifiReconnectTimer:start();

-- start saveMeterState timer
TIMERS.saveMeterStateTimer:start();
