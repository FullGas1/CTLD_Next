---@diagnostic disable
-- F-67 : canSlingload=true, transport EN VOL → menus Release/Cut présents
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

ctld_test.start("F-67", "canSlingload=true, transport en vol — menus Release/Cut présents")

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
    if k=="enableSmokeDrop"        then return false end
    if k=="enabledFOBBuilding"     then return false end
    if k=="enablePackingVehicles"  then return false end
    if k=="enabledRadioBeaconDrop" then return false end
    if k=="reconF10Menu"           then return false end
    if k=="JTAC_jtacStatusF10"     then return false end
    if k=="JTAC_dropEnabled"       then return false end
    if k=="unitActions" then
        return { ["UH-1H"] = { crates=true, troops=false, canParachute=false, canSlingload=true } }
    end
    return _origGs(k)
end

-- Transport reported as IN AIR
local _origInAir = ctld.utils.inAir
ctld.utils.inAir = function(_) return true end

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

local playerObj = {
    unitName="UH-1H-1", groupId=9901, groupName="Grp_F67",
    coalition=2, typeName="UH-1H",
    isTransport=true, canCarryVehicles=false,
}
CTLDPlayerManager.getInstance():buildMenu(playerObj)
local menu = ctld.MenuManager:getInstance():getMenuByGroupId(9901)
local root = ctld.tr("CTLD")
local cc   = ctld.tr("Crate Commands")

local function has(path)
    return menu and menu:_getNode(path) ~= nil
end

ctld_test.assert(has({root, cc, ctld.tr("Release Slingload")}), "Release Slingload present (canSlingload=true, in air)")
ctld_test.assert(has({root, cc, ctld.tr("Cut Slingload")}),     "Cut Slingload present (canSlingload=true, in air)")

ctld.utils.inAir = _origInAir
ctld.gs = _origGs
ctld_test.finish()
