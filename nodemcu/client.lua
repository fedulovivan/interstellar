-- script enables uart custom listener if this pin value is LOW on startup 
-- send command 'quit' and hit RETURN in terminal to quit custom uart listener
-- to send data over http send 'foo=1&bar=2' to uart and hit RETURN
-- endpont is hardcoded so far
-- wifi connection parameters are hardcoded so far
-- custom uart is configured to 9600 and bound to GPIO13(D7)/RX and GPIO15(D8)/TX
local UART_ENABLE_PIN = 1 -- D1
gpio.mode(UART_ENABLE_PIN, gpio.INPUT, gpio.PULLUP)

wifi.setmode(wifi.STATION)
wifi.sta.config("wifi domru ivanf", "useitatyourownrisk")

inProgress = false

function makeRequest(queryString)
  if inProgress then
    print("FAILURE INPROGRESS")
    return
  end
  status = wifi.sta.status()
  if status ~= 5 then -- if not STA_GOTIP 
    print("FAILURE WIFI", status)
    return
  end
  -- presence a newline in string causes request to failure, need to trim it
  queryString = string.gsub(queryString, "\r", "")
  queryString = string.gsub(queryString, "\n", "")
  inProgress = true
  http.get(
    --'http://192.168.88.252:8080/?' .. queryString,
    'https://api.thingspeak.com/update?api_key=O85HL73QFP0AF5UC&' .. queryString,
    nil,
    function(code, data)
        inProgress = false
        if code < 0 then
            print("FAILURE HTTP", code)
        else
            print("SUCCESS HTTP", code)
        end
    end
  )
end

-- enable custom UART listener if special pin is pulled down
if gpio.read(UART_ENABLE_PIN) == 0 then
    
    --  use second uart at GPIO13(D7)/RX and GPIO15(D8)/TX
    uart.alt(1);
    -- adjust baudrate
    uart.setup(0, 9600, 8, uart.PARITY_NONE, uart.STOPBITS_1, 1)

    uart.on(
        "data",
        "\r",
        function(data)
            if data == "quit\r" then
                uart.on("data")
            else
                makeRequest(data) 
            end
        end, 
        0
    )
    tmr.alarm(0, 5000, tmr.ALARM_AUTO, function()
        print("PING")
    end)
end
