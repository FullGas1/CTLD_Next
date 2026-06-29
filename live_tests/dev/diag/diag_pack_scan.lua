---@diagnostic disable
-- diag_pack_scan.lua — scan véhicules packables + force refresh menu

local pm = CTLDPlayerManager.getInstance()
local SLOT = "auto"
for k in pairs(pm._players) do
    if k:find("CH%-47") then SLOT = k; break end
end
local pObj = pm._players[SLOT]
local transport = Unit.getByName(SLOT)
if not transport then
    trigger.action.outText("[DIAG] transport introuvable", 10)
    return
end

local tPos = transport:getPoint()
local coa  = transport:getCoalition()
local maxDist = ctld.gs("maximumDistancePackableUnitsSearch") or 200

local msg = "[DIAG PACK SCAN]\nslot=" .. SLOT .. "\nmaxDist=" .. maxDist .. "\n\n"
msg = msg .. "GROUND units BLUE within 2000m:\n"

local groups = coalition.getGroups(coa, Group.Category.GROUND) or {}
for _, grp in ipairs(groups) do
    for _, unit in ipairs(grp:getUnits() or {}) do
        local uName = unit:getName()
        local live  = Unit.getByName(uName)
        if live and live:isExist() then
            local dist = ctld.utils.getDistance("diag", tPos, live:getPoint())
            if dist <= 2000 then
                local desc = CTLDCrateManager.getInstance():findDescriptorByUnitType(live:getTypeName())
                msg = msg .. string.format("  %s [%s] dist=%.0fm packable=%s\n",
                    uName, live:getTypeName(), dist, desc and "YES" or "no")
            end
        end
    end
end

-- Force refresh menu
CTLDVehicleSpawner.getInstance():refreshPackSection(pObj)
msg = msg .. "\n→ Pack menu refreshed"

trigger.action.outText(msg, 40)
return msg
