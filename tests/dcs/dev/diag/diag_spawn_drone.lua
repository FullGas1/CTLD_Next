-- diag_spawn_drone.lua
-- Spawn MQ-9 Reaper (BLUE) and RQ-1A Predator (RED) via CTLDVehicleSpawner
-- to validate Group.Category.AIRPLANE + orbit route.

local AIRCRAFT_NAME = "Batumi_UH-1H_0-1"

local transport = Unit.getByName(AIRCRAFT_NAME)
if not transport or not transport:isExist() then
    env.info("[SPAWN_DRONE] aircraft not found: " .. AIRCRAFT_NAME); return
end

local spawner = CTLDVehicleSpawner.getInstance()
local pt      = transport:getPoint()
local hdg     = ctld.utils.getHeadingInRadians("spawn_drone", transport, true)

-- MQ-9 BLUE at 12 o'clock, 300m
local b_ox = pt.x + math.cos(hdg)            * 300
local b_oz = pt.z + math.sin(hdg)            * 300
local bPos = { x = b_ox, y = land.getHeight({ x = b_ox, y = b_oz }), z = b_oz }

spawner:spawnVehicleAt(
    {
        vehicleType = "MQ-9 Reaper",
        groupName   = "CTLD_MQ9_BLUE_TEST",
        unitName    = "CTLD_MQ9_BLUE_TEST_1",
        coalitionId = coalition.side.BLUE,
        country     = country.id.USA,
    },
    bPos)
env.info("[SPAWN_DRONE] MQ-9 Reaper BLUE spawned at 12h 300m, alt=" ..
    tostring(ctld.gs("jtacDroneAltitude") or 4000) .. "m")

-- RQ-1A Predator RED at 3 o'clock, 300m
local hdg3 = hdg + math.pi / 2
local r_ox = pt.x + math.cos(hdg3) * 300
local r_oz = pt.z + math.sin(hdg3) * 300
local rPos = { x = r_ox, y = land.getHeight({ x = r_ox, y = r_oz }), z = r_oz }

spawner:spawnVehicleAt(
    {
        vehicleType = "RQ-1A Predator",
        groupName   = "CTLD_RQ1A_RED_TEST",
        unitName    = "CTLD_RQ1A_RED_TEST_1",
        coalitionId = coalition.side.RED,
        country     = country.id.RUSSIA,
    },
    rPos)
env.info("[SPAWN_DRONE] RQ-1A Predator RED spawned at 3h 300m")
