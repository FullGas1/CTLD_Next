---@diagnostic disable
-- F-57 : parachuteCrates — altitude OK → OnCrateParachuting publié, crate FALLING
-- Module  : FA (CTLDCrateManager)
do local f=io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")

local SRC = "C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/"
dofile(SRC.."CTLD_menu.lua")
dofile(SRC.."lib/CTLD_objectRegistry.lua")
dofile(SRC.."lib/CTLDParachuteEffect.lua")
dofile(SRC.."CTLD_core.lua")
dofile(SRC.."CTLD_zone.lua")
dofile(SRC.."CTLD_troop.lua")
dofile(SRC.."CTLD_vehicle.lua")
dofile(SRC.."CTLD_crate.lua")
dofile(SRC.."CTLD_beacon.lua")
dofile(SRC.."CTLD_recon.lua")
dofile(SRC.."CTLD_jtac.lua")
dofile(SRC.."CTLD_player.lua")

ctld_test.start("F-57", "parachuteCrates — altitude OK → OnCrateParachuting + crate FALLING")

CTLDPlayerManager._instance  = nil
ctld.MenuManager._instance   = nil
EventDispatcher._instance    = nil
CTLDDCSEventBridge._instance = nil
CTLDZoneManager._instance    = nil
CTLDTroopManager._instance   = nil
CTLDVehicleSpawner._instance = nil
_cmInstance                  = nil
CTLDBeaconManager._instance  = nil
CTLDReconManager._instance   = nil
CTLDJTACManager._instance    = nil

-- Config: minAlt=30m, descentRate=100m/s (fast for test)
local _origGs = ctld.gs
ctld.gs = function(k)
    if k=="parachuteMinAltitudeCrates"  then return 30  end
    if k=="parachuteDescentRateCrates"  then return 100 end  -- fast descent for short test timer
    if k=="parachuteInertiaFactor"      then return 0.0 end  -- no inertia for determinism
    if k=="parachuteLateralDriftMin"    then return 5   end
    if k=="parachuteLateralDriftMax"    then return 10  end
    return _origGs(k)
end

-- Mock land.getHeight: ground at 10m MSL → transport at 110m MSL → altAGL=100m
local _origLandGetHeight = land.getHeight
land.getHeight = function(_) return 10 end

-- Mock transport at 110m MSL
local mockTransport = {
    getPoint    = function() return { x=0, y=110, z=0 } end,
    getVelocity = function() return { x=0, y=0,   z=0 } end,
    getName     = function() return "MockTransport_F57" end,
}

-- Setup managers
CTLDDCSEventBridge.getInstance()
EventDispatcher.getInstance()
CTLDZoneManager.getInstance()
CTLDPlayerManager.getInstance()
local cm = CTLDCrateManager.getInstance()

-- Register a mock crate pre-loaded on mockTransport
local crate = CTLDCrate:new({
    crateName   = "test_crate_F57",
    descriptor  = { unit="M92_Ammo_Pallet", cratesRequired=1, weight=500 },
    spawnMethod = CTLDCrate.SPAWN_METHOD.MISSION_MAKER,
    position    = { x=0, y=10, z=0 },
    heading     = 0,
    coalition   = 2,
    dcsStatic   = nil,
})
crate:load(mockTransport)
cm.crates["test_crate_F57"] = crate

-- Capture events
local parachutingFired = false
local parachutingPayload = nil
EventDispatcher.getInstance():subscribe("OnCrateParachuting", function(payload)
    parachutingFired   = true
    parachutingPayload = payload
end)

-- Call parachuteCrates
local playerObj = { unitName="UH-1H-1", groupId=9901, groupName="Grp_F57", coalition=2 }
cm:parachuteCrates(mockTransport, playerObj)

-- Assertions (synchronous — immediate effects only)
ctld_test.assert(parachutingFired,                                   "OnCrateParachuting published")
ctld_test.assert(parachutingPayload ~= nil,                          "OnCrateParachuting payload non-nil")
ctld_test.assert(parachutingPayload and
    parachutingPayload.crateName == "test_crate_F57",                "OnCrateParachuting crateName correct")
ctld_test.assert(parachutingPayload and
    parachutingPayload.altitude ~= nil and
    parachutingPayload.altitude >= 30,                               "OnCrateParachuting altitude >= minAlt")
ctld_test.assert(crate.isParachuting == true,                        "crate.isParachuting = true")
ctld_test.assert(crate.state == CTLDCrate.STATE.FALLING,             "crate state = FALLING")
ctld_test.assert(crate.estimatedLandingTime ~= nil,                  "estimatedLandingTime set")

-- Restore
land.getHeight = _origLandGetHeight
ctld.gs = _origGs
ctld_test.finish()
