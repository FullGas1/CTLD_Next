---@diagnostic disable
-- F-71 : cutSlingload — AGL > 40m → crate détruite, OnCrateLost(slingload_cut_impact)
-- Module  : FB (CTLDCrateManager)
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

ctld_test.start("F-71", "cutSlingload — AGL > 40m → OnCrateLost(slingload_cut_impact)")

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
ctld.gs = function(k) return _origGs(k) end

-- AGL = 200 - 10 = 190m > 40 → crate destroyed
local _origLandGetHeight = land.getHeight
land.getHeight = function(_) return 10 end

local mockTransport = {
    isExist     = function() return true end,
    getName     = function() return "UH-1H-1" end,
    getPoint    = function() return { x=0, y=200, z=0 } end,
    getVelocity = function() return { x=0, y=0,   z=0 } end,
}

CTLDDCSEventBridge.getInstance()
EventDispatcher.getInstance()
CTLDZoneManager.getInstance()
CTLDPlayerManager.getInstance()
CTLDTroopManager.getInstance()
CTLDVehicleSpawner.getInstance()
local cm = CTLDCrateManager.getInstance()
CTLDBeaconManager.getInstance()
CTLDReconManager.getInstance()
CTLDJTACManager.get()

-- Inject a loaded+slingloaded crate
local crate = CTLDCrate:new({
    crateName   = "TestCrate_F71",
    descriptor  = { desc="Ammo", unit="Ammo_Crate", weight=500 },
    spawnMethod = CTLDCrate.SPAWN_METHOD.CRATE_SPAWN,
    position    = { x=0, y=10, z=0 },
    coalition   = 2,
    heading     = 0,
    dcsStatic   = nil,
})
crate:load(mockTransport)
crate.inTransitOnSlingload = true
cm.crates["TestCrate_F71"] = crate

local lostFired   = false
local lostPayload = nil
EventDispatcher.getInstance():subscribe("OnCrateLost", function(p)
    lostFired   = true
    lostPayload = p
end)

local playerObj = { unitName="UH-1H-1", groupId=9901 }
cm:cutSlingload(mockTransport, playerObj)

ctld_test.assert(lostFired,                                                        "OnCrateLost fired")
ctld_test.assert(lostPayload and lostPayload.trigger == "slingload_cut_impact",    "trigger=slingload_cut_impact")
ctld_test.assert(cm.crates["TestCrate_F71"] == nil,                                "crate removed from registry")
ctld_test.assert(not crate.inTransitOnSlingload,                                   "inTransitOnSlingload=false")

land.getHeight = _origLandGetHeight
ctld.gs = _origGs
ctld_test.finish()
