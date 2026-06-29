---@diagnostic disable
-- F-62 : parachuteVehicle — altitude trop basse → aucun event, vehicle LOADED
-- Module  : FA (CTLDVehicleSpawner)
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

ctld_test.start("F-62", "parachuteVehicle — altitude trop basse → aucun event, vehicle LOADED")

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
    if k=="parachuteMinAltitudeVehicles" then return 30 end
    return _origGs(k)
end

-- altAGL = 110 - 100 = 10m < 30m
local _origLandGetHeight = land.getHeight
land.getHeight = function(_) return 100 end

local mockTransport = {
    getPoint    = function() return { x=0, y=110, z=0 } end,
    getVelocity = function() return { x=0, y=0,   z=0 } end,
    getName     = function() return "MockTransport_F62" end,
}

CTLDDCSEventBridge.getInstance()
EventDispatcher.getInstance()
CTLDZoneManager.getInstance()
CTLDPlayerManager.getInstance()
local vs = CTLDVehicleSpawner.getInstance()

local vehicle = CTLDVehicle:new({
    id          = 1002,
    vehicleType = "M1045 HMMWV TOW",
    unit        = nil,
    spawnData   = { coalitionId=2 },
})
vehicle:setState(CTLDVehicle.STATE.LOADED)
vehicle.loadTransportName = mockTransport:getName()
vs._vehicles[1002] = vehicle

local eventFired = false
EventDispatcher.getInstance():subscribe("OnVehicleParachuting", function() eventFired = true end)

local playerObj = { unitName="UH-1H-1", groupId=9901, groupName="Grp_F62", coalition=2 }
vs:parachuteVehicle(mockTransport, 1002, playerObj)

ctld_test.assert(not eventFired,                                "OnVehicleParachuting NOT fired (alt too low)")
ctld_test.assert(vehicle.state == CTLDVehicle.STATE.LOADED,     "vehicle remains LOADED")

land.getHeight = _origLandGetHeight
ctld.gs = _origGs
ctld_test.finish()
