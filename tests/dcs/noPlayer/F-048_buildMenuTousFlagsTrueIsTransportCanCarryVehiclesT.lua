---@diagnostic disable
-- F-48 : buildMenu() tous flags true, isTransport+canCarryVehicles → toutes sections présentes
-- Module  : R5 (CTLD_player.lua + tous managers)
-- Objectif: Vérifier que toutes les sections F10 sont présentes quand toutes les features sont ON.
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

ctld_test.start("F-48", "buildMenu() — tous flags true → toutes sections présentes")

-- Reset all singletons
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

-- All features ON (real config already loaded, ensure all flags true)
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

-- Instantiate all managers (triggers registerMenuSection calls)
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

-- Build menu for UH-1H (isTransport=true, canCarryVehicles=false)
local playerObj = {
    unitName="UH-1H-1", groupId=9901, groupName="Grp_F48",
    coalition=2, typeName="UH-1H",
    isTransport=true, canCarryVehicles=false,
}
CTLDPlayerManager.getInstance():buildMenu(playerObj)
local menu = ctld.MenuManager:getInstance():getMenuByGroupId(9901)
local root  = ctld.tr("CTLD")

local function has(path)
    return menu and menu:_getNode(path) ~= nil
end

ctld_test.assert(has({root}),                             "Root CTLD submenu")
ctld_test.assert(has({root, ctld.tr("Troop Commands")}),  "Troop Commands (troops=true)")
ctld_test.assert(has({root, ctld.tr("Request Equipment")}),    "Request Equipment (enableCrates)")
ctld_test.assert(has({root, ctld.tr("Crate Commands")}),  "Crate Commands (enableCrates)")
ctld_test.assert(has({root, ctld.tr("Smoke")}),           "Smoke (enableSmokeDrop)")
ctld_test.assert(has({root, ctld.tr("Radio Beacons")}),   "Radio Beacons (enabledRadioBeaconDrop)")
ctld_test.assert(has({root, ctld.tr("RECON")}),           "RECON (reconF10Menu)")
ctld_test.assert(has({root, ctld.tr("JTAC")}),            "JTAC (JTAC_jtacStatusF10)")
-- canCarryVehicles=false → Vehicle Commands absent
ctld_test.assert(not has({root, ctld.tr("Vehicle Commands")}), "Vehicle Commands absent (canCarryVehicles=false)")
-- Sub-entries in Crate Commands
ctld_test.assert(has({root, ctld.tr("Crate Commands"), ctld.tr("Pack Vehicle")}), "Pack Vehicle present (enablePackingVehicles)")

ctld.gs = _origGs
ctld_test.finish()
