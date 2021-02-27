print("nodemcu-liquidcrystal-test");

backend_meta = require "lc-i2c4bit";
lc_meta = require "liquidcrystal";

-- create display object
lc = lc_meta(backend_meta{sda=1, scl=2}, false, true, 16)
backend_meta = nil
lc_meta = nil

-- lc:backlight(false)
-- lc:clear() -- clear display
-- lc:blink(true) -- enable cursor blinking
-- lc:home() -- reset cursor position
-- lc:write("hello", " ", "world") -- write string
lc:write("Hello world!");
lc:cursorMove(1, 2)
lc:write("Ivan =)");

print("end");