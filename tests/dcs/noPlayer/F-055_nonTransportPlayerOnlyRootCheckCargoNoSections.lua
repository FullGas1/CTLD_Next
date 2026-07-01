---@diagnostic disable
-- F-55 : non-transport player → only root CTLD + Check Cargo (no sections)
-- Module  : R5 (CTLD_player.lua + tous managers)
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

ctld_test.start("F-55", "non-transport player — no section submenus (except root + Check Cargo)")

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
    if k=="enableCrates"           then return true  end
    if k=="enableSmokeDrop"        then return true  end
    if k=="enabledFOBBuilding"     then return true  end
    if k=="enablePackingVehicles"  then return true  end
    if k=="enabledRadioBeaconDrop" then return true  end
    if k=="reconF10Menu"           then return true  end
    if k=="JTAC_jtacStatusF10"     then return true  end
    if k=="JTAC_dropEnabled"       then return true  end
    if k=="JTAC_allowStandbyMode"  then return false end
    if k=="JTAC_allowSmokeRequest" then return false end
    if k=="JTAC_allow9Line"        then return false end
    return _origGs(k)
end

CTLDDCSEventBridge.getInstance()
EventDispatcher.getInstance()
CTLDZoneManager.getInstance()
CTLDPlayerManager.getInstance()
CTLDTroopManager.getInstance()
CTLDVehicleSpawner.getInstance()
CTLDCrateManager.getInstance()
CTLDBeaconManager.getInstance()
CTLDReconManager.getInstance()
CTLDJTACManager.get()

-- Non-transport unit (isTransport=false)
local playerObj = {
    unitName="F-16C-1", groupId=9901, groupName="Grp_F55",
    coalition=2, typeName="F-16C bl.52d",
    isTransport=false, canCarryVehicles=false,
}
CTLDPlayerManager.getInstance():buildMenu(playerObj)
local menu = ctld.MenuManager:getInstance():getMenuByGroupId(9901)
local root  = ctld.tr("CTLD")

local function has(path)
    return menu and menu:_getNode(path) ~= nil
end

-- Root must exist (always created)
ctld_test.assert(has({root}),                                             "Root CTLD present")
-- No transport sections
ctld_test.assert(not has({root, ctld.tr("Troop Commands")}),             "Troop Commands absent (isTransport=false)")
ctld_test.assert(not has({root, ctld.tr("Request Equipment")}),               "Request Equipment absent (isTransport=false)")
ctld_test.assert(not has({root, ctld.tr("Crate Commands")}),             "Crate Commands absent (isTransport=false)")
ctld_test.assert(not has({root, ctld.tr("Smoke")}),                      "Smoke absent (isTransport=false)")
ctld_test.assert(not has({root, ctld.tr("Radio Beacons")}),              "Radio Beacons absent (isTransport=false)")
-- RECON and JTAC are not gated by isTransport
ctld_test.assert(has({root, ctld.tr("RECON")}),                          "RECON present (no isTransport guard)")
ctld_test.assert(has({root, ctld.tr("JTAC")}),                           "JTAC present (no isTransport guard)")

ctld.gs = _origGs
ctld_test.finish()
