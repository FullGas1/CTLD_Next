---@diagnostic disable
-- F-58 : parachuteCrates — altitude trop basse → message, aucun event, crate LOADED
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

ctld_test.start("F-58", "parachuteCrates — altitude trop basse → aucun event, crate LOADED")

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

local _origGs = ctld.gs
ctld.gs = function(k)
    if k=="parachuteMinAltitudeCrates" then return 30 end
    return _origGs(k)
end

-- Mock land.getHeight: ground at 100m MSL → transport at 110m MSL → altAGL=10m < 30m
local _origLandGetHeight = land.getHeight
land.getHeight = function(_) return 100 end

local mockTransport = {
    getPoint    = function() return { x=0, y=110, z=0 } end,
    getVelocity = function() return { x=0, y=0,   z=0 } end,
    getName     = function() return "MockTransport_F58" end,
}

CTLDDCSEventBridge.getInstance()
EventDispatcher.getInstance()
CTLDZoneManager.getInstance()
CTLDPlayerManager.getInstance()
local cm = CTLDCrateManager.getInstance()

local crate = CTLDCrate:new({
    crateName   = "test_crate_F58",
    descriptor  = { unit="M92_Ammo_Pallet", cratesRequired=1, weight=500 },
    spawnMethod = CTLDCrate.SPAWN_METHOD.MISSION_MAKER,
    position    = { x=0, y=100, z=0 },
    heading     = 0,
    coalition   = 2,
    dcsStatic   = nil,
})
crate:load(mockTransport)
cm.crates["test_crate_F58"] = crate

local eventFired = false
EventDispatcher.getInstance():subscribe("OnCrateParachuting", function() eventFired = true end)

local playerObj = { unitName="UH-1H-1", groupId=9901, groupName="Grp_F58", coalition=2 }
cm:parachuteCrates(mockTransport, playerObj)

ctld_test.assert(not eventFired,                              "OnCrateParachuting NOT fired (alt too low)")
ctld_test.assert(crate.state == CTLDCrate.STATE.LOADED,       "crate remains LOADED")
ctld_test.assert(crate.isParachuting == false,                "crate.isParachuting still false")

land.getHeight = _origLandGetHeight
ctld.gs = _origGs
ctld_test.finish()
