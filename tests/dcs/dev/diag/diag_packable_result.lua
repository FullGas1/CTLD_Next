---@diagnostic disable
-- diag_packable_result.lua — résultat exact de findPackableVehicles

local pm = CTLDPlayerManager.getInstance()
local SLOT = "auto"
for k in pairs(pm._players) do
    if k:find("CH%-47") then SLOT = k; break end
end
local transport = Unit.getByName(SLOT)
if not transport then
    trigger.action.outText("[DIAG] transport introuvable", 10)
    return
end

local vs  = CTLDVehicleSpawner.getInstance()
local maxDist = ctld.gs("maximumDistancePackableUnitsSearch") or 200
local result  = vs:findPackableVehicles(transport)

local msg = "[DIAG PACKABLE]\nslot=" .. SLOT .. "\nmaxDist=" .. maxDist .. "\n"
msg = msg .. "found=" .. #result .. "\n"
for i, v in ipairs(result) do
    local unit = Unit.getByName(v.unitName)
    local dist = unit and ctld.utils.getDistance("diag", transport:getPoint(), unit:getPoint()) or -1
    msg = msg .. string.format("  [%d] %s [%s] dist=%.0fm\n",
        i, v.unitName, tostring(v.descriptor and v.descriptor.unit), dist)
end

trigger.action.outText(msg, 30)
return msg
