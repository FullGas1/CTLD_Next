---@diagnostic disable
-- F-70 : releaseSlingload — AGL ≤ maximumHoverHeight → OnCrateUnloaded(slingload_release), crate unloaded
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

ctld_test.start("F-70", "releaseSlingload — AGL OK → OnCrateUnloaded(slingload_release)")

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
    if k=="maximumHoverHeight" then return 12.0 end
    return _origGs(k)
end

-- Transport at y=108, land.getHeight=100 → AGL=8 ≤ 12 → release OK
local _origLandGetHeight = land.getHeight
land.getHeight = function(_) return 100 end

local mockTransport = {
    isExist     = function() return true end,
    getName     = function() return "UH-1H-1" end,
    getPoint    = function() return { x=10, y=108, z=10 } end,
    getVelocity = function() return { x=0, y=0, z=0 } end,
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
    crateName   = "TestCrate_F70",
    descriptor  = { desc="Ammo", unit="Ammo_Crate", weight=500 },
    spawnMethod = CTLDCrate.SPAWN_METHOD.CRATE_SPAWN,
    position    = { x=10, y=100, z=10 },
    coalition   = 2,
    heading     = 0,
    dcsStatic   = nil,
})
crate:load(mockTransport)
crate.inTransitOnSlingload = true
cm.crates["TestCrate_F70"] = crate

local eventFired   = false
local eventPayload = nil
EventDispatcher.getInstance():subscribe("OnCrateUnloaded", function(p)
    eventFired   = true
    eventPayload = p
end)

local playerObj = { unitName="UH-1H-1", groupId=9901 }
cm:releaseSlingload(mockTransport, playerObj)

ctld_test.assert(eventFired,                                                    "OnCrateUnloaded fired")
ctld_test.assert(eventPayload and eventPayload.trigger == "slingload_release",  "trigger=slingload_release")
ctld_test.assert(not crate.inTransitOnSlingload,                                "inTransitOnSlingload=false after release")
ctld_test.assert(crate.state == CTLDCrate.STATE.LANDED,                         "crate state=LANDED")

land.getHeight = _origLandGetHeight
ctld.gs = _origGs
ctld_test.finish()
