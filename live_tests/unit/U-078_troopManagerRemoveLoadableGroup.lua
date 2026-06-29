---@diagnostic disable
-- ============================================================
-- U-78 : CTLDTroopManager:removeLoadableGroup
-- Module  : Feature D (src/CTLD_troop.lua)
-- ============================================================

do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")
local mgr = dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/_fd_setup.lua")

ctld_test.start("U-78", "removeLoadableGroup")

-- Add a custom template
mgr:createLoadableGroup({ name = "Custom Alpha", composition = { inf = 4 } })
ctld_test.assertEqual(#mgr._templates, 3, "3 templates before remove")

local customT = mgr:_findTemplate("Custom Alpha")
local dbKey   = customT._dbKey
ctld_test.assertNotNil(CTLDObjectRegistry._db[dbKey], "ObjectRegistry entry present before remove")

-- Remove the custom template
local ok1, e1 = mgr:removeLoadableGroup("Custom Alpha")
ctld_test.assert(ok1 == true,  "remove custom: returns true")
ctld_test.assertNil(e1,        "remove custom: no error")
ctld_test.assertEqual(#mgr._templates, 2, "2 templates after remove")
ctld_test.assertNil(mgr:_findTemplate("Custom Alpha"), "findTemplate returns nil after remove")
ctld_test.assertNil(CTLDObjectRegistry._db[dbKey],     "ObjectRegistry entry cleared after remove")

-- Remove a standard template (allowed by Option A2 — no safety guard)
local ok2, e2 = mgr:removeLoadableGroup("Standard Group")
ctld_test.assert(ok2 == true,  "remove standard: returns true")
ctld_test.assertNil(e2,        "remove standard: no error")
ctld_test.assertEqual(#mgr._templates, 1, "1 template after removing standard")

-- Remove non-existent template
local ok3, e3 = mgr:removeLoadableGroup("Does Not Exist")
ctld_test.assert(ok3 == false, "remove unknown: returns false")
ctld_test.assertNotNil(e3,     "remove unknown: error message returned")

ctld_test.finish()
