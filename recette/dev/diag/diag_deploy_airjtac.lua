-- diag_deploy_airjtac.lua — test CTLDJTACManager:deployAirJTAC (new API)
-- Patches old build in running mission, then tests.

-- Patch deployAirJTAC (old build only has deployDroneCrate)
CTLDJTACManager.deployAirJTAC = CTLDJTACManager.deployDroneCrate

local AIRCRAFT_NAME = "Batumi_UH-1H_0-1"
local transport = Unit.getByName(AIRCRAFT_NAME)
if not transport or not transport:isExist() then return "aircraft not found" end

local pt  = transport:getPoint()
local hdg = ctld.utils.getHeadingInRadians("airjtac", transport, true)
local ox  = pt.x + math.cos(hdg) * 350
local oz  = pt.z + math.sin(hdg) * 350
local pos = { x = ox, y = land.getHeight({ x = ox, y = oz }), z = oz }

local desc = {
    unit          = "MQ-9 Reaper",
    desc          = "MQ-9 Repear - JTAC",
    isJTAC        = true,
    spawnCategory = Group.Category.AIRPLANE,
}
local ok = CTLDJTACManager.get():deployAirJTAC(transport, pos, desc, country.id.USA)
return "deployAirJTAC=" .. tostring(ok)
