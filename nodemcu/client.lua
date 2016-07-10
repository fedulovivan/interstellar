wifi.setmode(wifi.STATION)
wifi.sta.config("wifi domru ivanf", "useitatyourownrisk")

inProgress = false

function makeRequest(queryString)
  if inProgress then
    print("in progress")
    return
  end
  status = wifi.sta.status()
  if status ~= 5 then -- not STA_GOTIP 
    print("wifi error", status)
    return
  end
  queryString = string.gsub(queryString, "\r", "")
  inProgress = true
  http.get(
    --'http://192.168.88.252:8080/',
    'https://api.thingspeak.com/update?api_key=O85HL73QFP0AF5UC&' .. queryString,
    nil,
    function(code, data)
        inProgress = false
        if code < 0 then
            print("request failed", code)
        else
            print("success", code, data)
        end
    end
  )
end

--cnt = 0
--TMR_ID = 0
--tmr.alarm(TMR_ID, 1000, tmr.ALARM_AUTO, function()
--  cnt = cnt + 1
--  makeRequest("cnt=" .. cnt)
--end)

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