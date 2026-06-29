---@diagnostic disable
-- Diagnostic MT-11 : force onAILand + trace zone lookup
local u = Unit.getByName("heliai_mt11")
if not u or not u:isExist() then return "heliai_mt11 NOT FOUND" end

local cm  = CTLDCoreManager.getInstance()
local tm  = CTLDTroopManager.getInstance()
local zm  = CTLDZoneManager.getInstance()
local pt  = u:getPoint()
local coa = u:getCoalition()

local r = {}
r[#r+1] = "inAir=" .. tostring(u:inAir())
r[#r+1] = "_aiPilotNames.heliai_mt11=" .. tostring(cm._aiPilotNames and cm._aiPilotNames["heliai_mt11"])
r[#r+1] = "_aiTeams[2]=" .. tostring(cm._aiTeams and cm._aiTeams[2] and #cm._aiTeams[2] or "nil")
r[#r+1] = "pos=(" .. math.floor(pt.x) .. "," .. math.floor(pt.z) .. ")"
r[#r+1] = "coa=" .. tostring(coa)

-- Zone containment check
local pickZone = zm:getAIPickupZoneAt(pt, coa)
r[#r+1] = "pickZone=" .. tostring(pickZone and pickZone.name or "NIL")

if pickZone then
    r[#r+1] = "_aiTroopStock=" .. tostring(pickZone._aiTroopStock ~= nil)
end

-- Check all AIZ_P zones individually
for zname, zone in pairs(zm._troopZones) do
    if zone.isAIPickup then
        local inZ = zone:isInZone(pt)
        local dist = ctld.utils.getDistance("diag", pt, zone.center)
        r[#r+1] = "  zone=" .. zname .. " active=" .. tostring(zone.active)
              .. " inZone=" .. tostring(inZ)
              .. " dist=" .. math.floor(dist) .. " r=" .. math.floor(zone.radius or 0)
    end
end

-- Force onAILand
ctld.utils.log("INFO", "[DIAG-MT11] forcing onAILand")
local ok, err = pcall(cm.onAILand, cm, { id = world.event.S_EVENT_LAND, initiator = u })
if not ok then r[#r+1] = "onAILand ERROR: " .. tostring(err)
else r[#r+1] = "onAILand OK | hasTroops=" .. tostring(tm:hasTroops("heliai_mt11")) end

return table.concat(r, " | ")
