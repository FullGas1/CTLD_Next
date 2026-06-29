---@diagnostic disable
-- F-61 : parachuteVehicle — altitude OK → OnVehicleParachuting publié
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

ctld_test.start("F-61", "parachuteVehicle — altitude OK → OnVehicleParachuting publié")

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
    if k=="parachuteMinAltitudeVehicles" then return 30  end
    if k=="parachuteDescentRateVehicles" then return 100 end
    if k=="parachuteInertiaFactor"       then return 0.0 end
    if k=="parachuteLateralDriftMin"     then return 5   end
    if k=="parachuteLateralDriftMax"     then return 10  end
    return _origGs(k)
end

-- altAGL = 200 - 10 = 190m > 30m
local _origLandGetHeight = land.getHeight
land.getHeight = function(_) return 10 end

local mockTransport = {
    getPoint    = function() return { x=0, y=200, z=0 } end,
    getVelocity = function() return { x=0, y=0,   z=0 } end,
    getName     = function() return "MockTransport_F61" end,
}

CTLDDCSEventBridge.getInstance()
EventDispatcher.getInstance()
CTLDZoneManager.getInstance()
CTLDPlayerManager.getInstance()
local vs = CTLDVehicleSpawner.getInstance()

-- Inject a loaded vehicle
local vehicle = CTLDVehicle:new({
    id          = 1001,
    vehicleType = "M1045 HMMWV TOW",
    unit        = nil,
    spawnData   = { coalitionId=2, country=2, vehicleType="M1045 HMMWV TOW",
                    groupName="VehGroup_F61", unitName="VehUnit_F61" },
})
vehicle:setState(CTLDVehicle.STATE.LOADED)
vehicle.loadTransportName = mockTransport:getName()
vs._vehicles[1001] = vehicle

-- Capture events
local parachutingFired   = false
local parachutingPayload = nil
EventDispatcher.getInstance():subscribe("OnVehicleParachuting", function(payload)
    parachutingFired   = true
    parachutingPayload = payload
end)

local playerObj = { unitName="UH-1H-1", groupId=9901, groupName="Grp_F61", coalition=2 }
vs:parachuteVehicle(mockTransport, 1001, playerObj)

ctld_test.assert(parachutingFired,                                        "OnVehicleParachuting published")
ctld_test.assert(parachutingPayload ~= nil,                               "OnVehicleParachuting payload non-nil")
ctld_test.assert(parachutingPayload and
    parachutingPayload.vehicle == vehicle,                                "OnVehicleParachuting vehicle correct")
ctld_test.assert(parachutingPayload and
    parachutingPayload.altitude >= 30,                                    "OnVehicleParachuting altitude >= minAlt")
ctld_test.assert(parachutingPayload and
    parachutingPayload.estimatedLandingPos ~= nil,                        "estimatedLandingPos set")
ctld_test.assert(vehicle.state == CTLDVehicle.STATE.DELIVERED,            "vehicle state = DELIVERED (unloaded from transport)")

land.getHeight = _origLandGetHeight
ctld.gs = _origGs
ctld_test.finish()
