---@diagnostic disable
-- ============================================================
-- F-93 : FOB unpack complet — fobScene + beacon au centroid
-- Simule CTLDFOBManager._onFOBBuilt directement (bypass timer/caisses).
-- Vérifie que le beacon est spawné au centroid après le build de la scène.
-- REQUIRES: DCS mission running, BLUE player in slot
-- ============================================================

do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")
ctld_test.cleanup()

-- Purge previous scene objects
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
        env.info(string.format("[F-93] purge: %d object(s) from previous run", destroyed))
    end
end
purgeLastScene()

local SRC = "C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/"
dofile(SRC .. "CTLD_core.lua")

-- Stub CTLDPlayerManager (beacon + troop managers call registerMenuSection)
CTLDPlayerManager = CTLDPlayerManager or {}
CTLDPlayerManager.getInstance = CTLDPlayerManager.getInstance
    or function() return { registerMenuSection = function() end } end

-- Stub CTLDZoneManager (registerFOBAsLogistic not needed for this visual test)
CTLDZoneManager = CTLDZoneManager or {}
CTLDZoneManager.getInstance = CTLDZoneManager.getInstance
    or function()
        return {
            registerFOBAsLogistic   = function() end,
            unregisterLogistic      = function() end,
            getLogisticZoneAtPoint  = function() return nil end,
            getLogisticZonesForCoalition = function() return {} end,
        }
    end

dofile(SRC .. "lib/CTLD_objectRegistry.lua")
dofile(SRC .. "CTLD_beacon.lua")
dofile(SRC .. "CTLD_sceneManager.lua")
dofile(SRC .. "scenes/CTLD_fobScene.lua")
dofile(SRC .. "CTLD_fob.lua")

-- Reset singletons for clean state
EventDispatcher._instance    = nil
CTLDDCSEventBridge._instance = nil
CTLDBeaconManager._instance  = nil
CTLDFOBManager._instance     = nil

CTLDConfig.get().settings["enabledRadioBeaconDrop"] = true
CTLDConfig.get().settings["enabledFOBBuilding"]     = true
CTLDConfig.get().settings["buildTimeFOB"]           = 0   -- no wait
CTLDConfig.get().settings["fobLogisticZoneRadius"]  = 150

ctld_test.start("F-93", "FOB unpack complet — fobScene + beacon au centroid")

-- ----------------------------------------------------------------
-- Guard: transport requis
-- ----------------------------------------------------------------
local transport = ctld_test.getTransport()
if not transport then ctld_test.finish() return end

-- ----------------------------------------------------------------
-- Compute centroid (100 m devant le transport)
-- ----------------------------------------------------------------
local hdg      = ctld.utils.getHeadingInRadians("F-93", transport, true)
local pt       = transport:getPoint()
local centroid = {
    x = pt.x + math.cos(hdg) * 100,
    y = land.getHeight({ x = pt.x + math.cos(hdg) * 100,
                         y = pt.z + math.sin(hdg) * 100 }),
    z = pt.z + math.sin(hdg) * 100,
}
env.info(string.format("[F-93] centroid: (%.1f, %.1f)", centroid.x, centroid.z))

-- ----------------------------------------------------------------
-- Play fobScene → in onComplete, call _onFOBBuilt directly
-- ----------------------------------------------------------------
local mgr    = CTLDSceneManager.getInstance()
local fobMgr = CTLDFOBManager.getInstance()

mgr:playScene(transport, "fobScene", { centroid = centroid }, function(scene)
    env.info("[F-93] fobScene complete. Spawned objects: " .. #scene._spawnedObjs)

    -- Save scene objects for purge
    _CTLD_SCENE_LAST_SPAWNED = {}
    for _, obj in ipairs(scene._spawnedObjs) do
        if obj and obj.getName then
            _CTLD_SCENE_LAST_SPAWNED[#_CTLD_SCENE_LAST_SPAWNED + 1] = obj:getName()
        end
    end

    -- Trigger the full post-build logic (zone registration + beacon drop)
    fobMgr:_onFOBBuilt(scene, transport:getName(), "TestPilot", centroid,
        transport:getCoalition(), transport:getCountry(), {})

    -- Check beacon was created
    local fobId  = "fob_001"
    local fob    = fobMgr._fobs[fobId]
    if fob and fob.beacon then
        local bk = fob.beacon
        local dx = math.abs(bk.position.x - centroid.x)
        local dz = math.abs(bk.position.z - centroid.z)
        env.info(string.format("[F-93] beacon at (%.1f, %.1f) centroid=(%.1f, %.1f) dx=%.2f dz=%.2f",
            bk.position.x, bk.position.z, centroid.x, centroid.z, dx, dz))

        local freqMsg = string.format("VHF %.2f kHz / UHF %.2f MHz / FM %.2f MHz",
            bk.vhf / 1000, bk.uhf / 1000000, bk.fm / 1000000)

        trigger.action.outText(
            "F-93 VISUAL CHECK (FOB complet):\n" ..
            "  - FOB container + watchtower spawned ~100m devant\n" ..
            "  - Beacon au centroid (pas sous l'hélico)\n" ..
            "  - " .. freqMsg .. "\n" ..
            "  - Batterie infinie (FOB)", 40)

        -- Save beacon groups for purge
        if bk.vhfGroupName then
            _CTLD_SCENE_LAST_SPAWNED[#_CTLD_SCENE_LAST_SPAWNED + 1] = bk.vhfGroupName
        end
        if bk.uhfGroupName then
            _CTLD_SCENE_LAST_SPAWNED[#_CTLD_SCENE_LAST_SPAWNED + 1] = bk.uhfGroupName
        end
        if bk.fmGroupName then
            _CTLD_SCENE_LAST_SPAWNED[#_CTLD_SCENE_LAST_SPAWNED + 1] = bk.fmGroupName
        end
    else
        trigger.action.outText("F-93 FAIL: beacon manquant après _onFOBBuilt", 20)
        env.info("[F-93] FAIL: beacon nil")
    end
end)

ctld_test.finish()
