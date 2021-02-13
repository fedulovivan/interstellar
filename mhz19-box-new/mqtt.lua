
-- mqtt init code is borrowed from https://bitbucket.org/nadyrshin_ryu/esp8266_mqtt/src/master/mqtt.lua

local WIFI_SSID = "wifi domru ivanf"
local WIFI_PWD = "useitatyourownrisk"

local MQTT_BROKER_IP = "192.168.88.188"
local MQTT_BROKER_PORT = 1883
local MQTT_CLIENT_ID = "esp8266-mhz19"
local MQTT_BROKER_USER = "mosquitto"
local MQTT_BROKER_PWD = "5Ysm3jAsVP73nva"

-- built-in led pin
local LED_PIN = 4

-- for uploading scripts need to connect pin with ground on startup
local UART_ENABLE_PIN = 1 -- GPIO5(D1)

gpio.mode(LED_PIN, gpio.OUTPUT)
gpio.mode(UART_ENABLE_PIN, gpio.INPUT, gpio.PULLUP)

local uart_enabled = gpio.read(UART_ENABLE_PIN) == 1

wifi.setmode(wifi.STATION)
wifi.sta.config(WIFI_SSID, WIFI_PWD)
wifi.sta.connect()

local wifi_status_old = 0

function CalculateCrc(buffer)
    local sum = 0
    for i = 2, string.len( buffer ) - 1 do
        local byte = string.byte(buffer, i)
        sum = sum + byte
    end
    return bit.bnot(sum - 0x01)
end

function CheckCrc(a, b)
    return string.sub(string.format("%02X", a), -2) == string.sub(string.format("%02X", b), -2)
end

function GetByteFromBuffer(buffer, index)
    local normalBytesMap = { [0]=1; [1]=2; [2]=3; [3]=4; [4]=5; [5]=6; [6]=7; [7]=8; [8]=9 }
    return string.byte(buffer, normalBytesMap[index])
end

tmr.alarm(0, 5000, 1, function()

    if wifi.sta.status() == 5 then
        if wifi_status_old ~= 5 then

            local mqttClient = mqtt.Client(MQTT_CLIENT_ID, 120, MQTT_BROKER_USER, MQTT_BROKER_PWD)

            mqttClient:on("offline", function(client)
                tmr.stop(1)
            end)

            mqttClient:on("message", function(client, topic, data)
                if topic == "/ESP/LED/CMD" then
                    if data == "0" then
                        gpio.write(LED_PIN, gpio.HIGH)
                    end
                    if data == "1" then
                        gpio.write(LED_PIN, gpio.LOW)
                    end
                end
            end)

            mqttClient:connect(MQTT_BROKER_IP, MQTT_BROKER_PORT, 0, 1, function(conn)

                if uart_enabled then

                    uart.setup(0, 9600, 8, uart.PARITY_NONE, uart.STOPBITS_1, 0)

                    mqttClient:publish("/ESP/MH/DEBUG", "uart_enabled=true", 0, 0)
                    mqttClient:publish("/ESP/MH/DEBUG", uart.getconfig(0), 0, 0)

                    local buffer = ""

                    uart.on("data", 1, function(char)

                        buffer = buffer .. char

                        local current_buffer_length = string.len(buffer)

                        mqttClient:publish("/ESP/MH/DEBUG", string.format("%d 0x%02X", current_buffer_length, string.byte(char)), 0, 0)

                        local invalid_first_two_bytes = string.sub(buffer, 1, 2) ~= string.char(0xFF, 0x86)

                        if (invalid_first_two_bytes and current_buffer_length > 1) then
                            mqttClient:publish("/ESP/MH/DEBUG", "invalid buffer", 0, 0)
                            buffer = ""
                            return
                        end

                        local buffer_ready = current_buffer_length == 9

                        if buffer_ready == false then
                            return
                        end

                        local co2HighByte = GetByteFromBuffer(buffer, 2)
                        local co2LowByte = GetByteFromBuffer(buffer, 3)
                        local temperatureRaw = GetByteFromBuffer(buffer, 4)
                        local receivedCrc = GetByteFromBuffer(buffer, 8)

                        local calculatedCrc = CalculateCrc(buffer)

                        if CheckCrc(receivedCrc, calculatedCrc) then
                            local co2 = (256 * co2HighByte) + co2LowByte
                            local temperature = temperatureRaw - 40
                            mqttClient:publish("/ESP/MH/DATA", "{\"co2\":"..co2..",\"temp\":"..temperature.."}", 0, 0)
                            mqttClient:publish("/ESP/MH/CO2", co2, 0, 0)
                            mqttClient:publish("/ESP/MH/TEMP", temperature, 0, 0)
                        else
                            mqttClient:publish("/ESP/MH/DEBUG", string.format("crc mismatch: received %X and calculated %X", receivedCrc, calculatedCrc), 0, 0)
                        end

                        buffer = ""

                    end, 0)
                end

                mqttClient:subscribe("/ESP/LED/CMD", 0, function(conn)
                end)

                tmr.alarm(1, 5000, 1, function()

                    mqttClient:publish("/ESP/LED/STATE", tostring(gpio.read(LED_PIN)), 0, 0)

                    if uart_enabled then
                        uart.write(0, 0xFF, 0x01, 0x86, 0x00, 0x00, 0x00, 0x00, 0x00, 0x79)
                    end

                end)
            end)
        else
            -- wifi connection is established, do nothing
        end
    else
        -- print("Reconnect "..wifi_status_old.." "..wifi.sta.status())
        tmr.stop(1)
        wifi.sta.connect()
    end

    -- memoizing wifi connection status for the nex timer tick
    wifi_status_old = wifi.sta.status()
end)
