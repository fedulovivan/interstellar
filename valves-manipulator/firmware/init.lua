DB = require("db")
DB:Init()
DB:Inc(DB.Props.BootCount)

print(node.heap())

FILES = {
    CONFIG = "config.json",
    COLD_METER = "cold_meter.txt",
    HOT_METER = "hot_meter.txt",
    IS_CLOSED_ON_STARTUP = "is_closed_on_startup.txt",
    VERSION = "version.txt",
    SETUP_COMPLETED = "setup-completed.txt",
}

GIT_REV = file.getcontents(FILES.VERSION)
CHIPID = node.chipid()
if file.exists(FILES.CONFIG) then
    CONFIG = sjson.decode(file.getcontents(FILES.CONFIG))
else
    error("init: " ..  FILES.CONFIG .. " does not exist")
end

print("init: valves-manipulator starting...");
print("init: GIT_REV=" .. GIT_REV)
print("init: CHIPID=" .. CHIPID)
print("init: CONFIG=" .. sjson.encode(CONFIG))

if file.exists(FILES.SETUP_COMPLETED) then
    print("init: setup is completed, running main")
    dofile("main.lua")
else
    print("init: setup is required, running wifi")
    dofile("wifi.lua")
end