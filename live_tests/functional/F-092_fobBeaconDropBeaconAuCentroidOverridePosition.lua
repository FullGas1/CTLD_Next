---@diagnostic disable
-- ============================================================
-- F-92 : FOB beacon — dropBeacon au centroid (overridePosition)
-- Module  : CTLD_fob.lua + CTLD_beacon.lua
-- Vérifie que le beacon FOB est spawné au centroid du FOB
-- (100 m devant le transport) et non sous l'hélico.
-- REQUIRES: DCS mission running, BLUE player in slot
-- ============================================================

do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")
ctld_test.cleanup()

-- Purge objects from previous scene run
local function purgeLastScene()
    _CTLD_SCENE_LAST_SPAWNED = _CTLD_SCENE_LAST_SPAWNED or {}
    local destroyed = 0
    for _, name in ipairs(_CTLD_SCENE_LAST_SPAWNED) do
        local obj = StaticObject.getByName(name)
        if obj and obj:isExist() then obj:destroy(); destroyed = destroyed + 1
        else
            local grp = Group.getByName(name)
            if grp then grp:destroy(); destroyed = destroyed + 1 end
        end
    end
    _CTLD_SCENE_LAST_SPAWNED = {}
    if destroyed > 0 then
        env.info(string.format("[F-92] purge: %d object(s) destroyed from previous run", destroyed))
    end
end
purgeLastScene()

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_core.lua")

-- Stub CTLDPlayerManager (beacon init calls registerMenuSection)
CTLDPlayerManager = CTLDPlayerManager or {}
CTLDPlayerManager.getInstance = CTLDPlayerManager.getInstance
    or function() return { registerMenuSection = function() end } end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_beacon.lua")

-- Enable beacon + reset singleton for clean state
CTLDConfig.get().settings["enabledRadioBeaconDrop"] = true
EventDispatcher._instance    = nil
CTLDDCSEventBridge._instance = nil
CTLDBeaconManager._instance  = nil

ctld_test.start("F-92", "FOB beacon — dropBeacon avec overridePosition = centroid FOB")

-- ----------------------------------------------------------------
-- Guard: transport requis
-- ----------------------------------------------------------------
local transport = ctld_test.getTransport()
if not transport then ctld_test.finish() return end

-- ----------------------------------------------------------------
-- Compute centroid: 100 m à 12h du transport (même logique que CTLDFOBManager)
-- ----------------------------------------------------------------
local hdg      = ctld.utils.getHeadingInRadians("F-92", transport, true)
local pt       = transport:getPoint()
local centroid = {
    x = pt.x + math.cos(hdg) * 100,
    y = land.getHeight({ x = pt.x + math.cos(hdg) * 100,
                         y = pt.z + math.sin(hdg) * 100 }),
    z = pt.z + math.sin(hdg) * 100,
}

env.info(string.format("[F-92] transport pos: (%.1f, %.1f)", pt.x, pt.z))
env.info(string.format("[F-92] centroid:      (%.1f, %.1f)", centroid.x, centroid.z))

-- ----------------------------------------------------------------
-- Drop FOB beacon at centroid (isFOB=true → battery infinie)
-- ----------------------------------------------------------------
local bm     = CTLDBeaconManager.getInstance()
local beacon = bm:dropBeacon(transport, "TestPilot", true, centroid)

-- ----------------------------------------------------------------
-- Assertions
-- ----------------------------------------------------------------
ctld_test.assertNotNil(beacon,                               "beacon créé (dropBeacon retourne non-nil)")

if beacon then
    -- Position == centroid (±1 m)
    local dx = math.abs(beacon.position.x - centroid.x)
    local dz = math.abs(beacon.position.z - centroid.z)
    ctld_test.assert(dx < 1 and dz < 1,
        string.format("beacon.position == centroid (dx=%.2f dz=%.2f)", dx, dz))

    -- Fréquences assignées
    ctld_test.assert(beacon.vhf and beacon.vhf > 0,          "beacon.vhf assigné")
    ctld_test.assert(beacon.uhf and beacon.uhf > 0,          "beacon.uhf assigné")
    ctld_test.assert(beacon.fm  and beacon.fm  > 0,          "beacon.fm assigné")

    -- Batterie infinie (isFOB=true → batteryEndTime == -1)
    ctld_test.assertEqual(beacon.batteryEndTime, -1,         "batterie infinie (FOB beacon)")
    ctld_test.assert(beacon.isFOB == true,                   "beacon.isFOB == true")

    -- Groupes spawned
    ctld_test.assertNotNil(beacon.vhfGroupName,              "vhfGroupName présent")
    ctld_test.assertNotNil(beacon.uhfGroupName,              "uhfGroupName présent")
    ctld_test.assertNotNil(beacon.fmGroupName,               "fmGroupName présent")

    local vhfGrp = Group.getByName(beacon.vhfGroupName)
    local uhfGrp = Group.getByName(beacon.uhfGroupName)
    local fmGrp  = Group.getByName(beacon.fmGroupName)
    ctld_test.assertNotNil(vhfGrp,                           "groupe VHF existant en mission")
    ctld_test.assertNotNil(uhfGrp,                           "groupe UHF existant en mission")
    ctld_test.assertNotNil(fmGrp,                            "groupe FM  existant en mission")

    local freqMsg = string.format("VHF %.2f kHz / UHF %.2f MHz / FM %.2f MHz",
        beacon.vhf / 1000, beacon.uhf / 1000000, beacon.fm / 1000000)

    trigger.action.outText(
        "F-92 VISUAL CHECK (FOB beacon):\n" ..
        "  - 3 groupes beacon spawned ~100 m devant le transport\n" ..
        "  - Pas sous l'hélico\n" ..
        "  - " .. freqMsg .. "\n" ..
        "  - Batterie infinie (FOB)", 40)

    env.info(string.format("[F-92] Beacon at centroid (%.1f, %.1f) | %s",
        centroid.x, centroid.z, freqMsg))

    -- Save beacon groups for next purge
    _CTLD_SCENE_LAST_SPAWNED = _CTLD_SCENE_LAST_SPAWNED or {}
    _CTLD_SCENE_LAST_SPAWNED[#_CTLD_SCENE_LAST_SPAWNED + 1] = beacon.vhfGroupName
    _CTLD_SCENE_LAST_SPAWNED[#_CTLD_SCENE_LAST_SPAWNED + 1] = beacon.uhfGroupName
    _CTLD_SCENE_LAST_SPAWNED[#_CTLD_SCENE_LAST_SPAWNED + 1] = beacon.fmGroupName
end

ctld_test.finish()
