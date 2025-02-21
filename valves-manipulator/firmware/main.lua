
local TOPIC_MANAGE = string.format("%s/%s/manage", CONFIG.MQTT_TOPIC_BASE, CHIPID)
local TOPIC_STATUS = string.format("%s/%s/status", CONFIG.MQTT_TOPIC_BASE, CHIPID)
local TOPIC_INIT = string.format("%s/%s/init", CONFIG.MQTT_TOPIC_BASE, CHIPID)
local TOPIC_LOG = string.format("%s/%s/log", CONFIG.MQTT_TOPIC_BASE, CHIPID)
local TOPIC_METERS_UPD = string.format("%s/%s/meters/update", CONFIG.MQTT_TOPIC_BASE, CHIPID)
local TOPIC_METERS_SAVE = string.format("%s/%s/meters/save", CONFIG.MQTT_TOPIC_BASE, CHIPID)
local TOPIC_ENTER_SETUP = string.format("%s/%s/enter-setup", CONFIG.MQTT_TOPIC_BASE, CHIPID)

local SUBSCRIPTIONS = {
    [TOPIC_MANAGE] = 0,
    [TOPIC_METERS_UPD] = 0,
    [TOPIC_METERS_SAVE] = 0,
    [TOPIC_ENTER_SETUP] = 0,
}

local MQTT_CLIENT_ID = string.format("%s-%s", CONFIG.MQTT_TOPIC_BASE, CHIPID)

local OPEN_CMD = "open"
local CLOSE_CMD = "close"

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

-- other variables
local cmt = 0; -- coldMeterTicks
local hmt = 0; -- hotMeterTicks
local cmtLw = 0; -- coldMeterTicksLastWritten
local hmtLw = 0; -- hotMeterTicksLastWritten
local wifiPrevStatus = 0;
local mqttIsConnected = false;
local waterSensorPinLastValue = gpio.HIGH;
local mqttClient;

-- timers
local timers = {
    ledBlink = tmr.create(),
    wifiReconnect = tmr.create(),
    mqttReconnect = tmr.create(),
    sendStatusUpdate = tmr.create(),
    pollWaterSensor = tmr.create(),
    saveMeterState = tmr.create(),
};

local function log(value)
    print(value)
    if mqttIsConnected then
        mqttClient:publish(TOPIC_LOG, value, 0, 0)
    end
end

local function saveMeterStateToFiles(force)
    if (force or hmt > hmtLw) then
        file.putcontents(FILES.HOT_METER, tostring(hmt))
        hmtLw = hmt
        log("hotMeterTicks=" .. hmt .. " saved to flash");
    end
    if (force or cmt > cmtLw) then
        file.putcontents(FILES.COLD_METER, tostring(cmt))
        cmtLw = cmt
        log("coldMeterTicks=" .. cmt .. " saved to flash");
    end
end;

local function restoreTicks()
    log("restoring meter state from files...");
    if file.exists(FILES.HOT_METER) then
        hmt = tonumber(file.getcontents(FILES.HOT_METER), 10);
        log("hotMeterTicks value " .. hmt .. " was restored from flash");
    end
    if file.exists(FILES.COLD_METER) then
        cmt = tonumber(file.getcontents(FILES.COLD_METER), 10);
        log("coldMeterTicks value " .. cmt .. " was restored from flash");
    end
end;

local function sendStatusUpdate(origin)
    if not mqttIsConnected then
        log("sendStatusUpdate: mqtt not yet connected (origin=" .. origin .. ")");
        return 1;
    end
    local waterSensorPinValue = gpio.read(WATER_SENSOR_PIN);
    local valvePinValue = gpio.read(VALVE_PIN);
    mqttClient:publish(TOPIC_STATUS, sjson.encode({
        time = tmr.time(),
        leakage = waterSensorPinValue == WATER_SENSOR_LEAKAGE_DETECTED,
        valve = valvePinValue == VALVE_OPEN and "opened" or "closed",
        coldMeterTicks = cmt,
        hotMeterTicks = hmt,
        origin = origin,
        chipid = CHIPID,
    }), 0, 0);
    return 0;
end;

local function coldMeterPinInterruptHandler()
    log("coldMeterPinInterruptHandler");
    cmt = cmt + 1;
    sendStatusUpdate("coldMeterPinInterruptHandler");
end;

local function hotMeterPinInterruptHandler()
    log("hotMeterPinInterruptHandler");
    hmt = hmt + 1;
    sendStatusUpdate("hotMeterPinInterruptHandler");
end;

local function saveIsClosedOnStartup()
    if not file.exists(FILES.IS_CLOSED_ON_STARTUP) then
        file.open(FILES.IS_CLOSED_ON_STARTUP, "w");
        file.close();
    end;
end;

local function resetIsClosedOnStartup()
    if file.exists(FILES.IS_CLOSED_ON_STARTUP) then
        file.remove(FILES.IS_CLOSED_ON_STARTUP);
    end;
end;

local function goOnline()
    mqttIsConnected = true;
    log("goOnline");
    timers.ledBlink:start();
    timers.sendStatusUpdate:start();
    mqttClient:publish(TOPIC_INIT, sjson.encode({
        CHIPID = CHIPID,
        GIT_REV = GIT_REV,
        CONFIG = CONFIG,
        MQTT_CLIENT_ID = MQTT_CLIENT_ID,
        TOPICS = {
            TOPIC_MANAGE,
            TOPIC_STATUS,
            TOPIC_INIT,
            TOPIC_METERS_UPD,
            TOPIC_METERS_SAVE,
            TOPIC_ENTER_SETUP,
            TOPIC_LOG,
        }
    }), 0, 0);
end;

local function goOffline()
    mqttIsConnected = false;
    log("goOffline");
    timers.ledBlink:stop();
    timers.sendStatusUpdate:stop();
    gpio.write(GREEN_LED_PIN, gpio.HIGH); -- HIGH means OFF led
end;

local function openValves()
    log("openValves");
    gpio.write(VALVE_PIN, VALVE_OPEN);
    resetIsClosedOnStartup();
    sendStatusUpdate("openValves");
end;

local function closeValves()
    log("closeValves");
    gpio.write(VALVE_PIN, VALVE_CLOSED);
    sendStatusUpdate("closeValves");
    saveIsClosedOnStartup();
end;

local function handleMqttMessage(client, topic, data)
    log("mqtt message=" .. tostring(topic) .. " data=" .. tostring(data));

    -- handle mqtt command and update valves state
    -- data is either "open" or "close"
    if topic == TOPIC_MANAGE and data ~= nil then
        if data == OPEN_CMD then
            openValves();
        elseif data == CLOSE_CMD then
            closeValves();
        else
            log("unexpected data");
        end

    -- ability to set meter values
    -- data string is "H21001" or "C34077"
    -- H21001 - set hot meter ticks to 21001
    -- C34077 - set cold meter ticks to 34077
    elseif topic == TOPIC_METERS_UPD and data ~= nil then
        local type = string.sub(data, 1, 1);
        local value = tonumber(string.sub(data, 2));
        if type == "H" and value ~= nil then
            log("value of hotMeterTicks updated from " .. hmt .. " to " .. value);
            hmt = value;
            saveMeterStateToFiles(true);
            sendStatusUpdate("handleMqttMessage");
        elseif type == "C" and value ~= nil then
            log("value of coldMeterTicks updated from " .. cmt .. " to " .. value);
            cmt = value;
            saveMeterStateToFiles(true);
            sendStatusUpdate("handleMqttMessage");
        else
            log("unexpected data");
        end

    -- ability to toggle saveMeterStateToFiles
    elseif topic == TOPIC_METERS_SAVE then
        saveMeterStateToFiles(true);

    elseif topic == TOPIC_ENTER_SETUP then
        file.remove(FILES.SETUP_COMPLETED);

    else
        log("unexpected topic");
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
            log("connected to mqtt server ip=" .. CONFIG.MQTT_BROKER_IP);
            mqttClient:on("message", handleMqttMessage);
            mqttClient:on("offline", goOffline);
            mqttClient:subscribe(
                SUBSCRIPTIONS,
                function()
                    log("mqtt subscribed");
                    goOnline();
                end
            );
        end,
        -- connection failed
        function (client, reason)
            log("mqttClient:connect failed. reason=" .. tostring(reason));
            goOffline();
        end
    );
end;

--- START MAIN
restoreTicks();

-- setup gpio pins
gpio.mode(VALVE_PIN, gpio.OUTPUT);
gpio.mode(GREEN_LED_PIN, gpio.OUTPUT);
gpio.write(GREEN_LED_PIN, gpio.HIGH); -- HIGH means OFF led
gpio.mode(WATER_SENSOR_PIN, gpio.INPUT, gpio.PULLUP);
gpio.mode(COLD_METER_PIN, gpio.INT);
gpio.mode(HOT_METER_PIN, gpio.INT);
gpio.trig(COLD_METER_PIN, "down", coldMeterPinInterruptHandler);
gpio.trig(HOT_METER_PIN, "down", hotMeterPinInterruptHandler);

if file.exists(FILES.IS_CLOSED_ON_STARTUP) then
    gpio.write(VALVE_PIN, gpio.HIGH);
end

-- init wifi
wifi.setmode(wifi.STATION);
wifi.sta.config { ssid=CONFIG.WIFI_SSID, pwd=CONFIG.WIFI_PWD };
wifi.sta.connect();

-- create mqtt client instance
mqttClient = mqtt.Client(
    MQTT_CLIENT_ID,
    120,
    CONFIG.MQTT_BROKER_USER,
    CONFIG.MQTT_BROKER_PWD
);

timers.ledBlink:register(500, tmr.ALARM_AUTO, function()
    local isHigh = gpio.read(GREEN_LED_PIN) == gpio.HIGH;
    gpio.write(
        GREEN_LED_PIN,
        isHigh and gpio.LOW or gpio.HIGH
    );
end);

timers.mqttReconnect:register(5000, tmr.ALARM_AUTO, function()
    if not mqttIsConnected then
        log("mqttIsConnected=" .. tostring(mqttIsConnected));
        connectToMqtt();
    end
end);

timers.wifiReconnect:register(5000, tmr.ALARM_AUTO, function()
    if wifi.sta.status() == 5 then
        if wifiPrevStatus ~= 5 then
            log("wifi is connected ip=" .. wifi.sta.getip());
            timers.mqttReconnect:start();
        end
    else
        goOffline();
        log("not connected to wifi...");
    end
    wifiPrevStatus = wifi.sta.status();
end);

-- send status updates periodically
timers.sendStatusUpdate:register(STATUS_UPDATE_INTERVAL, tmr.ALARM_AUTO, function()
    sendStatusUpdate("sendStatusUpdateTimer");
end);

-- poll the water leakage pin state and
-- 1. close valves if leakage was detected
-- 2. send update if value has changed
timers.pollWaterSensor:register(1000, tmr.ALARM_AUTO, function()
    local waterSensorPinValue = gpio.read(WATER_SENSOR_PIN);
    local valvePinValue = gpio.read(VALVE_PIN);
    if waterSensorPinValue == WATER_SENSOR_LEAKAGE_DETECTED and valvePinValue == VALVE_OPEN then
        closeValves();
    end
    if waterSensorPinLastValue ~= waterSensorPinValue then
        sendStatusUpdate("waterSensorPinLastValue");
    end
    waterSensorPinLastValue = waterSensorPinValue;
end);

-- periodically save meter states to file
timers.saveMeterState:register(SAVE_METER_STATE_INTERVAL, tmr.ALARM_AUTO, function()
    saveMeterStateToFiles(false)
end);

-- poll water sensor pin state
timers.pollWaterSensor:start();

-- periodically check if wifi is connected
timers.wifiReconnect:start();

-- start saveMeterState timer
timers.saveMeterState:start();
