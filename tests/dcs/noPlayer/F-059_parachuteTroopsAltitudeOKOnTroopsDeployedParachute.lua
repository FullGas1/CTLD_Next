---@diagnostic disable
-- F-59 : parachuteTroops — altitude OK → OnTroopsDeployed(parachute) publié, groupe retiré du transport
-- Module  : FA (CTLDTroopManager)
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

ctld_test.start("F-59", "parachuteTroops — altitude OK → OnTroopsDeployed(parachute), groupe déchargé")

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
    if k=="parachuteMinAltitudeTroops"  then return 50  end
    if k=="parachuteDescentRateTroops"  then return 100 end
    if k=="parachuteInertiaFactor"      then return 0.0 end
    if k=="parachuteLateralDriftMin"    then return 5   end
    if k=="parachuteLateralDriftMax"    then return 10  end
    return _origGs(k)
end

-- altAGL = 200 - 10 = 190m > 50m
local _origLandGetHeight = land.getHeight
land.getHeight = function(_) return 10 end

local mockTransport = {
    getPoint    = function() return { x=0, y=200, z=0 } end,
    getVelocity = function() return { x=0, y=0,   z=0 } end,
    getName     = function() return "MockTransport_F59" end,
}

CTLDDCSEventBridge.getInstance()
EventDispatcher.getInstance()
CTLDZoneManager.getInstance()
CTLDPlayerManager.getInstance()
local tm = CTLDTroopManager.getInstance()

-- Inject a loaded troop group directly into _inTransit
local troopGroup = CTLDTroopGroup:new({
    templateName = "TestGroup_F59",
    templateKey  = nil,
    unitTotal    = 3,
    weight       = 300,
    coalitionId  = 2,
})
tm._inTransit["UH-1H-1"] = troopGroup

-- Capture events
local deployedFired   = false
local deployedPayload = nil
EventDispatcher.getInstance():subscribe("OnTroopsDeployed", function(payload)
    deployedFired   = true
    deployedPayload = payload
end)

local playerObj = { unitName="UH-1H-1", groupId=9901, groupName="Grp_F59", coalition=2 }
tm:parachuteTroops(mockTransport, playerObj)

ctld_test.assert(deployedFired,                                         "OnTroopsDeployed published")
ctld_test.assert(deployedPayload and
    deployedPayload.trigger == "parachute",                             "OnTroopsDeployed trigger=parachute")
ctld_test.assert(deployedPayload and
    deployedPayload.troops == troopGroup,                               "OnTroopsDeployed correct troopGroup")
ctld_test.assert(tm._inTransit["UH-1H-1"] == nil,                      "troopGroup removed from _inTransit")

land.getHeight = _origLandGetHeight
ctld.gs = _origGs
ctld_test.finish()
