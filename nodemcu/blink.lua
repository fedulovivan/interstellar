local lighton=0
local pin=4
gpio.mode(pin, gpio.OUTPUT)
local mytimer = tmr.create()
mytimer:register(2000, tmr.ALARM_AUTO, function()
    if lighton==0 then
        lighton=1
        gpio.write(pin, gpio.HIGH)
    else
        lighton=0
        gpio.write(pin, gpio.LOW)
    end
end)
mytimer:start()
