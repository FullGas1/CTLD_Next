---@diagnostic disable
-- ============================================================
-- U-54 : CTLDObjectRegistry — get() + findByDCSType()
-- Module  : P1 (src/core/CTLD_objectRegistry.lua)
-- Objectif: Vérifier lookups directs et reverse lookup par DCS typeName
-- ============================================================

do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/core/CTLD_objectRegistry.lua")

ctld_test.start("U-54", "CTLDObjectRegistry get() + findByDCSType()")

-- ── get() ─────────────────────────────────────────────────────
local farp = CTLDObjectRegistry.get("FARP")
ctld_test.assertNotNil(farp,                          "T1a: get(FARP) non-nil")
ctld_test.assertEqual(farp and farp.groupType, "STATIC", "T1b: FARP.groupType == STATIC")
ctld_test.assertEqual(farp and farp.category, "Heliports", "T1c: FARP.category == Heliports")

local guard = CTLDObjectRegistry.get("FARP_Security_Guard")
ctld_test.assertNotNil(guard,                           "T2a: get(FARP_Security_Guard) non-nil")
ctld_test.assertEqual(guard and guard.groupType, "GROUND", "T2b: FARP_Security_Guard.groupType == GROUND")
ctld_test.assert(guard and type(guard.units) == "table" and #guard.units == 3, "T2c: 3 units in descriptor")

ctld_test.assertNil(CTLDObjectRegistry.get("nonexistent_key"), "T3: get(unknown) == nil")

-- ── findByDCSType() ──────────────────────────────────────────
local k1, d1 = CTLDObjectRegistry.findByDCSType("ammo_cargo")
ctld_test.assertEqual(k1, "ammo_cargo",    "T4a: findByDCSType(ammo_cargo) key correct")
ctld_test.assertNotNil(d1,                 "T4b: findByDCSType(ammo_cargo) desc non-nil")

local k2, d2 = CTLDObjectRegistry.findByDCSType("Cargo06")
ctld_test.assertEqual(k2, "Cargo06",       "T5:  findByDCSType(Cargo06) key correct")

local k3, d3 = CTLDObjectRegistry.findByDCSType(nil)
ctld_test.assertNil(k3,                    "T6a: findByDCSType(nil) key == nil")
ctld_test.assertNil(d3,                    "T6b: findByDCSType(nil) desc == nil")

local k4, d4 = CTLDObjectRegistry.findByDCSType("totally_unknown_dcs_type")
ctld_test.assertNil(k4,                    "T7a: findByDCSType(unknown) key == nil")
ctld_test.assertNil(d4,                    "T7b: findByDCSType(unknown) desc == nil")

ctld_test.finish()
