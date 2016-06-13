wifi.setmode(wifi.STATION)
wifi.sta.config("wifi domru ivanf", "useitatyourownrisk")

function makeRequest(str)
  if wifi.sta.status() ~= 5 then
    return
  end  
  http.get("http://192.168.88.252:8080/?" .. str, nil, function(code, data)
    if code < 0 then
      print("HTTP request failed", code)
    else
      print(code, data)
    end
  end)
end

cnt = 0
TMR_ID = 0
tmr.alarm(TMR_ID, 300, tmr.ALARM_AUTO, function()
  cnt = cnt + 1
  makeRequest("cnt=" .. cnt)
end)

--uart.on(
--    "data", 
--    "\r",
--    function(data)
--        makeRequest(data);
--    end, 
--    0
--)
