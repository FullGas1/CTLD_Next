---@diagnostic disable
local FARP_NAME = "DIAG_TEST_FARP_1"

-- Spawn 1 nm (1852 m) à l'ouest de Batumi (ouest = -z)
local batumi = Airbase.getByName("Batumi")
local refPt  = batumi and batumi:getPoint() or { x = -355000, y = 0, z = 617000 }
local sx = refPt.x
local sz = refPt.z - 1852
local sy = land.getHeight({ x = sx, y = sz })

-- Cleanup résidu éventuel
local old = StaticObject.getByName(FARP_NAME)
if old and old:isExist() then pcall(function() old:destroy() end) end

local okS, obj = pcall(coalition.addStaticObject, country.id.USA, {
    name = FARP_NAME, type = "Invisible FARP", shape_name = "invisiblefarp",
    category = "Heliports", x = sx, y = sz, heading = 0,
    start_time = 0, dead = false, transportable = { randomTransportable = false },
})
if not okS or not obj then return "Spawn FARP échoué : " .. tostring(obj) end

local ab = Airbase.getByName(FARP_NAME)
if not ab then return "FARP spawné mais Airbase.getByName → nil" end

local results = {}
-- Tester plusieurs indices
for i = 0, 3 do
    local ok, u = pcall(function() return ab:getUnit(i) end)
    results[#results+1] = string.format("getUnit(%d)=ok:%s val:%s", i, tostring(ok), tostring(u))
end
-- Infos airbase
local okC, cat  = pcall(function() return ab:getCategory() end)
local okD, desc = pcall(function() return ab:getDesc() end)
results[#results+1] = "category=" .. tostring(cat)
results[#results+1] = "desc=" .. (type(desc)=="table" and "table" or tostring(desc))

local msg = table.concat(results, " | ")
trigger.action.outText(msg, 30)
return msg
