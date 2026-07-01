---@diagnostic disable
-- ============================================================
-- U-81 : CTLDTroopManager:_resolveTemplateForLegacy
-- Module  : Q1 (src/CTLD_troop.lua)
-- ============================================================

do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")
local mgr = dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/_fd_setup.lua")
-- Templates: "Standard Group" (total=10), "JTAC Group" (total=5)

ctld_test.start("U-81", "_resolveTemplateForLegacy — integer + table inputs")

-- Integer exact match
local t1 = mgr:_resolveTemplateForLegacy(2, 10)
ctld_test.assertNotNil(t1,                       "int 10: returns template")
ctld_test.assertEqual(t1.name, "Standard Group", "int 10: picks Standard Group (total=10)")

-- Integer closest match
local t2 = mgr:_resolveTemplateForLegacy(2, 6)
ctld_test.assertNotNil(t2,                    "int 6: returns template")
ctld_test.assertEqual(t2.name, "JTAC Group",  "int 6: closest is JTAC Group (total=5, delta=1 vs Standard delta=5)")

local t3 = mgr:_resolveTemplateForLegacy(1, 9)
ctld_test.assertNotNil(t3,                       "int 9: returns template")
ctld_test.assertEqual(t3.name, "Standard Group", "int 9: closest is Standard Group (delta=1)")

-- Integer 0 → closest to 0 → JTAC Group (total=5)
local t4 = mgr:_resolveTemplateForLegacy(2, 0)
ctld_test.assertNotNil(t4,                   "int 0: returns template (closest to 0)")
ctld_test.assertEqual(t4.name, "JTAC Group", "int 0: JTAC Group (total=5 < 10)")

-- Composition table: sum=10 → Standard Group
local t5 = mgr:_resolveTemplateForLegacy(2, { inf=6, mg=2, at=2 })
ctld_test.assertNotNil(t5,                       "table {inf=6,mg=2,at=2}: returns template")
ctld_test.assertEqual(t5.name, "Standard Group", "table sum=10: picks Standard Group")

-- Composition table: sum=4 → JTAC Group (total=5, delta=1)
local t6 = mgr:_resolveTemplateForLegacy(1, { inf=4 })
ctld_test.assertNotNil(t6,                   "table {inf=4}: returns template")
ctld_test.assertEqual(t6.name, "JTAC Group", "table sum=4: JTAC Group (total=5, delta=1)")

-- Disabled template is skipped
local disableOrig = mgr._templates[1].disabled
mgr._templates[1].disabled = true   -- disable Standard Group
local t7 = mgr:_resolveTemplateForLegacy(2, 10)
ctld_test.assertEqual(t7.name, "JTAC Group", "disabled template skipped: falls back to JTAC Group")
mgr._templates[1].disabled = disableOrig  -- restore

-- Empty templates → nil
local origTemplates = mgr._templates
mgr._templates = {}
local t8 = mgr:_resolveTemplateForLegacy(2, 5)
ctld_test.assertNil(t8, "no templates: returns nil")
mgr._templates = origTemplates   -- restore

ctld_test.finish()
