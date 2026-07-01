-- diag_deploy_drone.lua
-- Test CTLDJTACManager:deployDroneCrate directly via Witchcraft.
-- Spawns MQ-9 BLUE at 300m ahead, then checks group category and alt.

local AIRCRAFT_NAME = "Batumi_UH-1H_0-1"
local transport = Unit.getByName(AIRCRAFT_NAME)
if not transport or not transport:isExist() then
    return "[DEPLOY_DRONE] aircraft not found"
end

local pt  = transport:getPoint()
local hdg = ctld.utils.getHeadingInRadians("deploy_drone", transport, true)
local ox  = pt.x + math.cos(hdg) * 300
local oz  = pt.z + math.sin(hdg) * 300
local pos = { x = ox, y = land.getHeight({ x = ox, y = oz }), z = oz }

local desc = { unit = "MQ-9 Reaper", desc = "MQ-9 Repear - JTAC" }
local ok   = CTLDJTACManager.get():deployDroneCrate(transport, pos, desc, country.id.USA)

-- Wait 0.5s then check group
local result = "deployDroneCrate returned: " .. tostring(ok)
timer.scheduleFunction(function()
    -- Find CTLD_JTAC_DRONE groups
    local found = {}
    for _, g in ipairs(coalition.getGroups(coalition.side.BLUE)) do
        local n = g:getName()
        if string.sub(n, 1, 16) == "CTLD_JTAC_DRONE_" then
            local u1  = g:getUnit(1)
            local alt = u1 and u1:getPoint().y or -1
            local cat = g:getCategory()
            table.insert(found, string.format("%s cat=%d alt=%.0f", n, cat, alt))
        end
    end
    if #found == 0 then
        env.info("[DEPLOY_DRONE] No CTLD_JTAC_DRONE_ group found in BLUE coalition")
    else
        for _, s in ipairs(found) do
            env.info("[DEPLOY_DRONE] " .. s)
        end
    end
end, {}, timer.getTime() + 2)

return result
