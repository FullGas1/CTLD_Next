---@diagnostic disable
-- ============================================================
-- F-36 : CTLDTroopManager.extract
-- Module  : R2 (src/CTLD_troop.lua)
-- ============================================================

do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_core.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/core/CTLD_objectRegistry.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/core/CTLDParachuteEffect.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_troop.lua")

ctld_test.start("F-36", "extract")

CTLDConfig.get().settings["loadableGroups"]       = {}
CTLDConfig.get().settings["numberOfTroops"]       = 10
CTLDConfig.get().settings["maxExtractDistance"]   = 125

local mgr  = CTLDTroopManager.getInstance():init()
local unit = ctld_test.getTransport()
if not unit then ctld_test.finish() return end

local unitName  = unit:getName()
local coalition = unit:getCoalition()

-- Stub _isInAir → always on ground
mgr._isInAir = function(self, u) return false end

-- Guard: no dropped groups → false
local r0 = mgr:extract(unit)
ctld_test.assert(not r0, "extract → false si aucun groupe dropped")

-- Guard: already has troops → false
local grpA = CTLDTroopGroup:new({ templateKey="k", templateName="Existing",
    unitTotal=3, weight=320, hasJtac=false, coalitionId=coalition, countryId=unit:getCountry() })
mgr._inTransit[unitName] = grpA
local r1 = mgr:extract(unit)
ctld_test.assert(not r1, "extract → false si déjà des troupes")
mgr._inTransit[unitName] = nil

-- Inject a mock dropped group near the unit position
local unitPos = unit:getPoint()
local mockUnit = {
    _pos     = { x = unitPos.x + 10, y = unitPos.y, z = unitPos.z + 10 },
    _country = unit:getCountry(),
    getPoint   = function(self) return self._pos end,
    getCountry = function(self) return self._country end,
}
local mockGroup = {
    _name = "MockDroppedGrp",
    _units = { mockUnit, mockUnit, mockUnit },
    getName    = function(self) return self._name end,
    getUnits   = function(self) return self._units end,
    getUnit    = function(self, i) return self._units[i] end,
    isExist    = function(self) return true end,
    destroy    = function(self)
        ctld.utils.log("INFO", "mockGroup:destroy() called")
    end,
}

-- Override Group.getByName to return mock group
local origGetByName = Group.getByName
Group.getByName = function(name)
    if name == "MockDroppedGrp" then return mockGroup end
    return origGetByName(name)
end

-- Register in _droppedGroups
mgr._droppedGroups[coalition] = { "MockDroppedGrp" }

-- extract success
local r2 = mgr:extract(unit)
ctld_test.assert(r2, "extract → true (groupe nearby)")

-- Transit group created as EXTRACTED
local extracted = mgr:getInTransit(unitName)
ctld_test.assertNotNil(extracted,                          "getInTransit retourne le groupe extrait")
ctld_test.assertEqual(extracted.state, CTLDTroopGroup.STATE.EXTRACTED, "état == EXTRACTED")
ctld_test.assertEqual(extracted.templateName, "MockDroppedGrp", "templateName == nom du groupe")
ctld_test.assertEqual(extracted.unitTotal, 3,              "unitTotal == 3 (nb units)")

-- Group removed from _droppedGroups
ctld_test.assertEqual(#mgr._droppedGroups[coalition], 0, "groupe retiré de _droppedGroups après extract")

-- Restore Group.getByName
Group.getByName = origGetByName

ctld_test.finish()
