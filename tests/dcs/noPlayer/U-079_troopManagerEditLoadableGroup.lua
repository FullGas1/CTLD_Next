---@diagnostic disable
-- ============================================================
-- U-79 : CTLDTroopManager:editLoadableGroup
-- Module  : Feature D (src/CTLD_troop.lua)
-- ============================================================

do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")
local mgr = dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/_fd_setup.lua")

ctld_test.start("U-79", "editLoadableGroup")

-- Setup: one custom template
mgr:createLoadableGroup({
    name        = "Custom Bravo",
    composition = { inf = 6, at = 2 },
    side        = 2,
})
local t = mgr:_findTemplate("Custom Bravo")
ctld_test.assertEqual(t.total, 8, "initial total=8")
ctld_test.assertEqual(t.side,  2, "initial side=2")

-- Edit composition
local ok1, e1 = mgr:editLoadableGroup("Custom Bravo", {
    composition = { inf = 4, at = 4, jtac = 1 }
})
ctld_test.assert(ok1 == true, "edit composition: returns true")
ctld_test.assertNil(e1,       "edit composition: no error")
ctld_test.assertEqual(t.inf,   4, "inf updated to 4")
ctld_test.assertEqual(t.at,    4, "at updated to 4")
ctld_test.assertEqual(t.jtac,  1, "jtac set to 1")
ctld_test.assertEqual(t.total, 9, "total recomputed to 9")
ctld_test.assert(t.hasJtac,       "hasJtac recomputed to true")

-- Edit side only
local ok2 = mgr:editLoadableGroup("Custom Bravo", { side = 1 })
ctld_test.assert(ok2 == true, "edit side: returns true")
ctld_test.assertEqual(t.side, 1,  "side updated to 1")
ctld_test.assertEqual(t.total, 9, "total unchanged after side edit")

-- _dbKey unchanged (same name)
ctld_test.assertEqual(t._dbKey, "troop_Custom_Bravo", "_dbKey unchanged after edit")

-- ObjectRegistry updated with new units count
local entry = CTLDObjectRegistry._db[t._dbKey]
ctld_test.assertEqual(#entry.units, 9, "ObjectRegistry units count updated to 9")

-- Guard: edit standard template refused
local ok3, e3 = mgr:editLoadableGroup("Standard Group", { composition = { inf = 1 } })
ctld_test.assert(ok3 == false, "edit standard: returns false")
ctld_test.assertNotNil(e3,     "edit standard: error message returned")

-- Guard: template not found
local ok4, e4 = mgr:editLoadableGroup("Ghost", { composition = { inf = 1 } })
ctld_test.assert(ok4 == false, "edit unknown: returns false")
ctld_test.assertNotNil(e4,     "edit unknown: error message returned")

-- Guard: empty composition after edit
local ok5, e5 = mgr:editLoadableGroup("Custom Bravo", {
    composition = { inf = 0, at = 0, jtac = 0 }
})
ctld_test.assert(ok5 == false, "edit zero composition: returns false")
ctld_test.assertNotNil(e5,     "edit zero composition: error message returned")
ctld_test.assertEqual(t.total, 9, "total unchanged after failed edit")

ctld_test.finish()
