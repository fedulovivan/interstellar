
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
CONFIG = sjson.decode(file.getcontents(FILES.CONFIG))

print("valves-manipulator starting...");
print("GIT_REV=" .. GIT_REV)
print("CHIPID=" .. CHIPID)
print("CONFIG=" .. sjson.encode(CONFIG))

if file.exists(FILES.SETUP_COMPLETED) then
    print("setup is completed, running main.lua")
    dofile("main.lua")
else
    print("setup is required, running wifi.lua")
    dofile("wifi.lua")
end