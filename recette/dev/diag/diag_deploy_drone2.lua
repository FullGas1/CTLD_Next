-- diag_deploy_drone2.lua — test deployDroneCrate avec pcall guard sur getTask

local AIRCRAFT_NAME = "Batumi_UH-1H_0-1"
local transport = Unit.getByName(AIRCRAFT_NAME)
if not transport or not transport:isExist() then return "aircraft not found" end

local pt  = transport:getPoint()
local hdg = ctld.utils.getHeadingInRadians("drone2", transport, true)
local ox  = pt.x + math.cos(hdg) * 400
local oz  = pt.z + math.sin(hdg) * 400
local pos = { x = ox, y = land.getHeight({ x = ox, y = oz }), z = oz }

-- Patch getTask guard on spawnJTAC (since old build is loaded)
local _origSpawnJTAC = CTLDJTACManager.spawnJTAC
CTLDJTACManager.spawnJTAC = function(self, groupName, cfg, spawner)
    local dcsGroup = Group.getByName(groupName)
    if not dcsGroup then return nil end
    local ok, result = pcall(_origSpawnJTAC, self, groupName, cfg, spawner)
    if not ok then
        env.info("[DRONE2] spawnJTAC pcall caught: " .. tostring(result))
        return nil
    end
    return result
end

local desc = { unit = "MQ-9 Reaper", desc = "MQ-9 Repear - JTAC", isDrone = true, isJTAC = true }
local ok = CTLDJTACManager.get():deployDroneCrate(transport, pos, desc, country.id.USA)
env.info("[DRONE2] deployDroneCrate returned: " .. tostring(ok))
return "deployDroneCrate=" .. tostring(ok)
