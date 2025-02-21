wifi.setmode(wifi.SOFTAP)
wifi.ap.config({
    ssid = "valves-manipulator-" .. CHIPID,
    pwd = "welcome-to-hell"
})

print("access point started")
print("open in browser http://" .. wifi.ap.getip())

local server = net.createServer(net.TCP)

local function renderInput(name, value)
    return name .. "=<input type=\"text\" name=\"" .. name ..
    "\" value=\"" .. value .. "\" /><br />"
end

local function socketClose(socket)
    socket:close()
end

local function url_decode(str)
    str = str:gsub("%%(%x%x)", function(hex)
        return string.char(tonumber(hex, 16))
    end)
    str = str:gsub("%+", " ")
    return str
end

local function parse_urlencoded(s)
    local result = {}
    for key, value in string.gmatch(s, "([^&=?]-)=([^&=?]+)") do
        result[key] = url_decode(value)
    end
    return result
end

local function onReceive(socket, request)
    local _, _, method, path = string.find(request, "([A-Z]+) (.+) HTTP")
    local ischunk = method == nil and path == nil
    print("new request >>>\n" .. request .. "\n<<< end request")
    print("method=" .. (method ~= nil and method or "<nil>"))
    print("path=" .. (path ~= nil and path or "<nil>"))
    if method == "GET" and path == "/" then
        socket:send(
            "HTTP/1.0 200 OK\r\nServer: NodeMCU\r\nContent-Type: text/html\r\n\r\n" ..
            "<html><title>valves-manipulator</title><body>" ..
            "<h1>valves-manipulator setup</h1>" ..
            "<form action=\"/upload\" method=\"post\" enctype=\"application/x-www-form-urlencoded\">" ..
            renderInput("MQTT_BROKER_IP", CONFIG.MQTT_BROKER_IP) ..
            renderInput("MQTT_BROKER_PORT", CONFIG.MQTT_BROKER_PORT) ..
            renderInput("MQTT_BROKER_USER", CONFIG.MQTT_BROKER_USER) ..
            renderInput("MQTT_BROKER_PWD", CONFIG.MQTT_BROKER_PWD) ..
            renderInput("WIFI_SSID", CONFIG.WIFI_SSID) ..
            renderInput("WIFI_PWD", CONFIG.WIFI_PWD) ..
            renderInput("MQTT_TOPIC_BASE", CONFIG.MQTT_TOPIC_BASE) ..
            "<input type=\"submit\" value=\"Submit\">" ..
            "</form>" ..
            "</body></html>",
            socketClose
        )
        return
    elseif ischunk then
        local newjson = sjson.encode(parse_urlencoded(request))
        print("parsed", newjson)
        file.putcontents(FILES.CONFIG, newjson)
        file.putcontents(FILES.SETUP_COMPLETED, "")
        socket:send("HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\n\r\n" .. FILES.CONFIG .. " written", socketClose)
    end
end

if server then
    server:listen(80, function(conn)
        conn:on("receive", onReceive)
    end)
end
