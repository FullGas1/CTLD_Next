---@diagnostic disable
-- ============================================================
-- U-23 : CTLDCrateAssemblyManager — singleton + getTemplateForUnit
-- Module  : M6 (src/CTLD_aasystem.lua)
-- Objectif:
--   - getInstance() retourne une instance unique (singleton)
--   - getTemplateForUnit() trouve le template pour une part connue
--   - getTemplateForUnit() trouve le template pour une repair unit
--   - getTemplateForUnit() retourne nil pour une unit inconnue
-- ============================================================

do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_core.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_aasystem.lua")

ctld_test.start("U-23", "CTLDCrateAssemblyManager singleton + getTemplateForUnit")

CTLDCrateAssemblyManager._instance = nil
EventDispatcher._instance          = nil
CTLDDCSEventBridge._instance       = nil

-- Singleton
local ok1 = pcall(function() CTLDCrateAssemblyManager.getInstance() end)
ctld_test.assert(ok1, "getInstance() ne crash pas")

local m1 = CTLDCrateAssemblyManager._instance
ctld_test.assertNotNil(m1, "première instance non-nil")

local m2 = CTLDCrateAssemblyManager.getInstance()
ctld_test.assert(m1 == m2, "deux appels getInstance() retournent la même référence")

-- _completeSystems initialisé vide
ctld_test.assertNotNil(m1._completeSystems, "_completeSystems est une table")
local count = 0
for _ in pairs(m1._completeSystems) do count = count + 1 end
ctld_test.assertEqual(count, 0, "_completeSystems vide à l'init")

-- getTemplateForUnit — part connue (HAWK)
local tmplHawk = m1:getTemplateForUnit("Hawk ln")
ctld_test.assertNotNil(tmplHawk, "getTemplateForUnit('Hawk ln') retourne non-nil")
ctld_test.assertEqual(tmplHawk.name, "HAWK AA System", "template.name == 'HAWK AA System'")

-- getTemplateForUnit — autre part du même système
local tmplHawk2 = m1:getTemplateForUnit("Hawk tr")
ctld_test.assertNotNil(tmplHawk2, "getTemplateForUnit('Hawk tr') retourne non-nil")
ctld_test.assertEqual(tmplHawk2.name, "HAWK AA System", "Hawk tr → HAWK AA System")

-- getTemplateForUnit — repair unit
local tmplRepair = m1:getTemplateForUnit("HAWK Repair")
ctld_test.assertNotNil(tmplRepair, "getTemplateForUnit('HAWK Repair') retourne non-nil")
ctld_test.assertEqual(tmplRepair.name, "HAWK AA System", "HAWK Repair → HAWK AA System")

-- getTemplateForUnit — autre système (BUK)
local tmplBuk = m1:getTemplateForUnit("SA-11 Buk LN 9A310M1")
ctld_test.assertNotNil(tmplBuk, "getTemplateForUnit BUK launcher retourne non-nil")
ctld_test.assertEqual(tmplBuk.name, "BUK AA System", "BUK launcher → BUK AA System")

-- getTemplateForUnit — unit inconnue
local tmplNil = m1:getTemplateForUnit("M1A2 SEP v3 TUSK II")
ctld_test.assertNil(tmplNil, "getTemplateForUnit(inconnu) retourne nil")

-- getTemplateForUnit — nil arg
local tmplNilArg = m1:getTemplateForUnit(nil)
ctld_test.assertNil(tmplNilArg, "getTemplateForUnit(nil) retourne nil sans crash")

-- TEMPLATES contient exactement 6 systèmes
local tmplCount = #CTLDCrateAssemblyManager.TEMPLATES
ctld_test.assertEqual(tmplCount, 6, "TEMPLATES contient 6 systèmes")

ctld_test.finish()
