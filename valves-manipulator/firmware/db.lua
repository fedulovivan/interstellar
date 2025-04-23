local db = {
    filename = "db.json",
    period = 1000 * 60 * 5, -- 5 minutes
    timer = nil, -- No need to create tmr object unless needed
}

local Props = { -- Move outside db table to save memory
    BootCount = "bootCount",
    ColdMeter = "coldMeter",
    HotMeter = "hotMeter",
}

function db:Init()
    self.timer = self.timer or tmr.create() -- Reuse existing timer if already created
    self.timer:alarm(self.period, tmr.ALARM_AUTO, function() self:store() end)
    print("db: Init complete")
end

function db:Set(key, value)
    self.data = self.data or {} -- Initialize only if needed
    self.data[key] = value
    print("db: Set " .. key .. "=" .. tostring(value))
end

function db:Get(key)
    self:load() -- Lazy load only when needed
    return self.data and self.data[key] or nil
end

function db:Inc(key)
    self:load()
    self:Set(key, (self:Get(key) or 0) + 1)
    print("db: Inc " .. key .. " to " .. self:Get(key))
end

function db:load()
    if self.data then return end -- Don't reload if already in memory

    if file.exists(self.filename) then
        local f = file.open(self.filename, "r")
        if f then
            local raw = f:read("*a") -- Read file in one go (consider chunking for large files)
            f:close()
            self.data = raw and sjson.decode(raw) or {}
            print("db: Data loaded from " .. self.filename)
        end
    else
        self.data = {}
        print("db: " .. self.filename .. " does not exist, initializing empty db")
    end
    collectgarbage() -- Free memory
end

function db:store()
    if not self.data then return end

    local f = file.open(self.filename, "w+")
    if f then
        f:write(sjson.encode(self.data)) -- Streamlined encoding
        f:close()
        print("db: Data saved to " .. self.filename)
    end
    collectgarbage() -- Free memory
end

return db
