---@diagnostic disable
-- Nom unique garanti (horodaté) → pas de résidu possible
local FARP_NAME = "DIAG_FARP_" .. tostring(math.floor(timer.getTime()))
local results   = {}
local function r(msg) results[#results+1] = msg end

local function countName(name)
    local n = 0
    for _, a in ipairs(world.getAirbases() or {}) do
        local ok, nm = pcall(function() return a:getName() end)
        if ok and nm == name then n = n + 1 end
    end
    return n
end

-- Spawn
local batumi = Airbase.getByName("Batumi")
local refPt  = batumi and batumi:getPoint() or { x = -355000, y = 0, z = 617000 }
local sx, sz = refPt.x, refPt.z - 2037
local okS, obj = pcall(coalition.addStaticObject, country.id.USA, {
    name = FARP_NAME, type = "SINGLE_HELIPAD",
    category = "Heliports", x = sx, y = sz, heading = 0,
    start_time = 0, dead = false, transportable = { randomTransportable = false },
})
r("spawn ok=" .. tostring(okS and obj ~= nil))
r("count après spawn=" .. countName(FARP_NAME))  -- doit être 1

-- Récupérer
local ab = Airbase.getByName(FARP_NAME)
r("getByName → " .. tostring(ab ~= nil))
if ab then
    local _, e1 = pcall(function() return ab:isExist() end)
    r("isExist avant destroy=" .. tostring(e1))

    pcall(function() ab:destroy() end)

    local _, e2 = pcall(function() return ab:isExist() end)
    r("isExist après destroy=" .. tostring(e2))

    r("count après destroy=" .. countName(FARP_NAME))  -- 0 si destroy a marché, 1 sinon

    local ab2 = Airbase.getByName(FARP_NAME)
    r("getByName après destroy → " .. tostring(ab2 ~= nil))
end

local msg = "name=" .. FARP_NAME .. " | " .. table.concat(results, " | ")
trigger.action.outText(msg, 40)
return msg
