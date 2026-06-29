---@diagnostic disable
-- ============================================================
-- F-27 : CTLDCrateManager.registerMMCrate → crate enregistrée
-- Module  : R1 (src/CTLD_crate.lua)
-- ============================================================

do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_core.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_crate.lua")

ctld_test.start("F-27", "registerMMCrate → crate enregistrée")

-- Inject spawnableCrates
CTLDConfig.get().settings["spawnableCrates"] = {
    ammo = { { unit = "M92_Ammo_Pallet", cratesRequired = 1 } },
}

EventDispatcher._instance    = nil
CTLDDCSEventBridge._instance = nil

local mgr = CTLDCrateManager.getInstance()

-- Mock static cargo object
local mockPos = { x = 100, y = 5, z = 200 }
local mockStatic = {
    _name      = "cargo_static_01",
    _coalition = coalition.side.BLUE,
    getName       = function(self) return self._name end,
    getPoint      = function(self) return mockPos end,
    getCoalition  = function(self) return self._coalition end,
    isExist       = function(self) return true end,
}
local mockDesc = { typeName = "M92_Ammo_Pallet" }

-- Before registration: unknown
ctld_test.assertNil(mgr:getCrateByName("cargo_static_01"), "crate inconnue avant registration")

-- Register
mgr:registerMMCrate(mockStatic, mockDesc)

-- After registration: found
local crate = mgr:getCrateByName("cargo_static_01")
ctld_test.assertNotNil(crate, "getCrateByName retourne la crate après registerMMCrate")
ctld_test.assertEqual(crate.crateName, "cargo_static_01", "crateName correct")
ctld_test.assertEqual(crate.spawnMethod, CTLDCrate.SPAWN_METHOD.MISSION_MAKER, "spawnMethod == MISSION_MAKER")
ctld_test.assertEqual(crate.coalition, coalition.side.BLUE, "coalition == BLUE")
ctld_test.assertEqual(crate.descriptor.unit, "M92_Ammo_Pallet", "descriptor.unit correct")
ctld_test.assert(crate:isOnGround(), "crate est au sol (SPAWNED)")

-- Double registration is silently ignored
mgr:registerMMCrate(mockStatic, mockDesc)
ctld_test.assertEqual(mgr:getCrateByName("cargo_static_01"), crate, "double registration ignorée — même objet")

-- Unknown type is skipped
local mockStatic2 = {
    _name      = "cargo_static_02",
    _coalition = coalition.side.BLUE,
    getName      = function(self) return self._name end,
    getPoint     = function(self) return mockPos end,
    getCoalition = function(self) return self._coalition end,
    isExist      = function(self) return true end,
}
mgr:registerMMCrate(mockStatic2, { typeName = "UNKNOWN_TYPE_XYZ" })
ctld_test.assertNil(mgr:getCrateByName("cargo_static_02"), "type inconnu → crate non enregistrée")

ctld_test.finish()
