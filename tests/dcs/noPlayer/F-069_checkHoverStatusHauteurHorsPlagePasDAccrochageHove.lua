---@diagnostic disable
-- F-69 : checkHoverStatus — hauteur hors plage → pas d'accrochage, hoverStatus reset
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

ctld_test.start("F-69", "checkHoverStatus — hauteur hors plage → pas d'accrochage")

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
    if k=="enableHoverSlingload"    then return true  end
    if k=="enableCrates"            then return true  end
    if k=="enableSmokeDrop"         then return false end
    if k=="enabledFOBBuilding"      then return false end
    if k=="enablePackingVehicles"   then return false end
    if k=="enabledRadioBeaconDrop"  then return false end
    if k=="reconF10Menu"            then return false end
    if k=="JTAC_jtacStatusF10"      then return false end
    if k=="JTAC_dropEnabled"        then return false end
    if k=="minimumHoverHeight"      then return 7.5   end
    if k=="maximumHoverHeight"      then return 12.0  end
    if k=="maxDistanceFromCrate"    then return 5.5   end
    if k=="hoverTime"               then return 5     end
    if k=="maxSlingloadSpeed"       then return 50    end
    if k=="internalCargoLimits"     then return {}    end
    if k=="unitActions" then
        return { ["UH-1H"] = { crates=true, troops=false, canParachute=false, canSlingload=true } }
    end
    return _origGs(k)
end

local _origInAir = ctld.utils.inAir
ctld.utils.inAir = function(_) return true end

-- Transport at y=200, crate at y=100 → heightDiff=100 > maximumHoverHeight(12) → too high
local mockTransport = {
    isExist     = function() return true end,
    getName     = function() return "UH-1H-1" end,
    getPoint    = function() return { x=0, y=200, z=0 } end,
    getVelocity = function() return { x=0, y=0,   z=0 } end,
}
Unit.getByName = function(n)
    if n == "UH-1H-1" then return mockTransport end
    return nil
end

CTLDDCSEventBridge.getInstance()
EventDispatcher.getInstance()
CTLDZoneManager.getInstance()

local pm = CTLDPlayerManager.getInstance()
CTLDTroopManager.getInstance()
CTLDVehicleSpawner.getInstance()
local cm = CTLDCrateManager.getInstance()
CTLDBeaconManager.getInstance()
CTLDReconManager.getInstance()
CTLDJTACManager.get()

local crate = CTLDCrate:new({
    crateName   = "TestCrate_F69",
    descriptor  = { desc="Ammo", unit="Ammo_Crate", weight=500 },
    spawnMethod = CTLDCrate.SPAWN_METHOD.CRATE_SPAWN,
    position    = { x=0, y=100, z=0 },
    coalition   = 2,
    heading     = 0,
    dcsStatic   = nil,
})
cm.crates["TestCrate_F69"] = crate

local _origGetDist = ctld.utils.getDistance
ctld.utils.getDistance = function(_, p1, p2)
    local dx = (p1.x or 0) - (p2.x or 0)
    local dz = (p1.z or 0) - (p2.z or 0)
    return math.sqrt(dx*dx + dz*dz)
end

pm._players["UH-1H-1"] = {
    unitName="UH-1H-1", groupId=9901, groupName="Grp_F69",
    coalition=2, typeName="UH-1H",
    isTransport=true, canCarryVehicles=false,
    loadedCrates={}, loadedTroops={}, loadedVehicles={},
    addLoadedCrate = function() end,
    removeLoadedCrate = function() end,
}

local eventFired = false
EventDispatcher.getInstance():subscribe("OnCrateLoaded", function(p)
    if p and p.trigger == "slingload" then eventFired = true end
end)

local _origSched = timer.scheduleFunction
timer.scheduleFunction = function() end
cm:checkHoverStatus()
timer.scheduleFunction = _origSched

ctld_test.assert(not eventFired,                    "OnCrateLoaded NOT fired (too high)")
ctld_test.assert(not crate.inTransitOnSlingload,    "inTransitOnSlingload=false (no hook)")
ctld_test.assert(crate:isOnGround(),                "crate still on ground")
ctld_test.assert(cm._hoverStatus["UH-1H-1"] == nil, "hoverStatus reset (no countdown started)")

ctld.utils.getDistance = _origGetDist
ctld.utils.inAir = _origInAir
ctld.gs = _origGs
ctld_test.finish()
