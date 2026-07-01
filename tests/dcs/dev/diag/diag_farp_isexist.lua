---@diagnostic disable
local FARP_NAME = "DIAG_FARP_V2"
local results = {}

-- Via Airbase.getByName
local ab = Airbase.getByName(FARP_NAME)
results[#results+1] = "Airbase.getByName → " .. tostring(ab)

if ab then
    local okE, e = pcall(function() return ab:isExist() end)
    results[#results+1] = "ab:isExist() ok=" .. tostring(okE) .. " val=" .. tostring(e)

    -- destroy
    pcall(function() ab:destroy() end)

    local okE2, e2 = pcall(function() return ab:isExist() end)
    results[#results+1] = "après destroy: ab:isExist() ok=" .. tostring(okE2) .. " val=" .. tostring(e2)

    -- nouvelle ref
    local ab2 = Airbase.getByName(FARP_NAME)
    results[#results+1] = "Airbase.getByName après destroy → " .. tostring(ab2)

    -- world.getAirbases count
    local n = 0
    for _, a in ipairs(world.getAirbases() or {}) do
        local ok, nm = pcall(function() return a:getName() end)
        if ok and nm == FARP_NAME then n = n + 1 end
    end
    results[#results+1] = "world.getAirbases count=" .. n
end

local msg = table.concat(results, " | ")
trigger.action.outText(msg, 40)
return msg
