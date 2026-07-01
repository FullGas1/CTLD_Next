---@diagnostic disable
-- ============================================================
-- F-34 : CTLDTroopManager.deploy — on ground, pas d'EXZ
-- Module  : R2 (src/CTLD_troop.lua)
-- ============================================================

do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_core.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/core/CTLD_objectRegistry.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_zone.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/core/CTLDParachuteEffect.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_troop.lua")

ctld_test.start("F-34", "deploy — on ground, pas d'EXZ")

CTLDConfig.get().settings["loadableGroups"]           = {
    { name = "Alpha Squad", inf = 3, mg = 1, at = 0, aa = 0, mortar = 0, jtac = 0 },
}
CTLDConfig.get().settings["numberOfTroops"]           = 10
CTLDConfig.get().settings["nbLimitSpawnedTroops"]     = { 0, 0 }
CTLDConfig.get().settings["enableFastRopeInsertion"]  = false
CTLDConfig.get().settings["spawnDistanceInCircle"]    = 10
CTLDConfig.get().settings["fastRopeMaximumHeight"]    = 18.28

local mgr  = CTLDTroopManager.getInstance():init()
local unit = ctld_test.getTransport()
if not unit then ctld_test.finish() return end

local unitName  = unit:getName()
local coalition = unit:getCoalition()

-- Guard: no troops → deploy returns false
local r0 = mgr:deploy(unit)
ctld_test.assert(not r0, "deploy → false si pas de troupes")

-- Inject troops directly
local template = CTLDConfig.get().settings["loadableGroups"][1]
local zone = { zoneName="Z", flagName="f", coalition=0, active=true, limit=-1 }
mgr:loadFromZone(unit, zone, template)
ctld_test.assert(mgr:hasTroops(unitName), "troupes chargées avant deploy")

-- Stub CTLDObjectRegistry.spawnObject to avoid real DCS group spawn
local spawnedKey, spawnedCoalition = nil, nil
local mockDCSGroup = {
    _name = "MockTroopGroup_01",
    getName   = function(self) return self._name end,
    getUnits  = function(self) return {} end,
    isExist   = function(self) return true end,
}
CTLDObjectRegistry.spawnObject = function(key, coa, country, x, z, hdg, opts)
    spawnedKey       = key
    spawnedCoalition = coa
    return mockDCSGroup
end

-- CTLDZoneManager stub: no EXZ zone
local zm = CTLDZoneManager.getInstance()
zm.isUnitInZone = function(self, uName, zType)
    if zType == "extract" then return nil end
    return nil
end

-- Stub _isInAir to simulate on-ground (unit may actually be flying in mission)
mgr._isInAir = function(self, u) return false end

-- deploy
local r1 = mgr:deploy(unit)
ctld_test.assert(r1, "deploy → true (au sol, pas d'EXZ)")

-- spawnObject was called
ctld_test.assertNotNil(spawnedKey,       "CTLDObjectRegistry.spawnObject appelé")
ctld_test.assertEqual(spawnedCoalition,  coalition, "spawnObject appelé avec bonne coalition")

-- Troops cleared from transit
ctld_test.assert(not mgr:hasTroops(unitName), "hasTroops == false après deploy")
ctld_test.assertNil(mgr:getInTransit(unitName), "getInTransit == nil après deploy")

-- Group registered in _droppedGroups
ctld_test.assert(#mgr._droppedGroups[coalition] > 0, "groupe ajouté à _droppedGroups")
ctld_test.assertEqual(mgr._droppedGroups[coalition][1], mockDCSGroup._name, "nom du groupe correct")

ctld_test.finish()
