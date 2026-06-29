---@diagnostic disable
-- ============================================================
-- U-77 : CTLDTroopManager:createLoadableGroup — guard / error cases
-- Module  : Feature D (src/CTLD_troop.lua)
-- ============================================================

do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")
local mgr = dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/_fd_setup.lua")

ctld_test.start("U-77", "createLoadableGroup — guard cases")

-- Guard: not a table
local ok1, e1 = mgr:createLoadableGroup(nil)
ctld_test.assert(ok1 == false, "nil config: returns false")
ctld_test.assertNotNil(e1,     "nil config: error message returned")

-- Guard: missing name
local ok2, e2 = mgr:createLoadableGroup({ composition = { inf = 4 } })
ctld_test.assert(ok2 == false, "no name: returns false")
ctld_test.assertNotNil(e2,     "no name: error message returned")

-- Guard: empty name
local ok3, e3 = mgr:createLoadableGroup({ name = "", composition = { inf = 4 } })
ctld_test.assert(ok3 == false, "empty name: returns false")
ctld_test.assertNotNil(e3,     "empty name: error message returned")

-- Guard: missing composition
local ok4, e4 = mgr:createLoadableGroup({ name = "X" })
ctld_test.assert(ok4 == false, "no composition: returns false")
ctld_test.assertNotNil(e4,     "no composition: error message returned")

-- Guard: all-zero composition
local ok5, e5 = mgr:createLoadableGroup({
    name = "Empty", composition = { inf = 0, mg = 0, at = 0 }
})
ctld_test.assert(ok5 == false, "zero composition: returns false")
ctld_test.assertNotNil(e5,     "zero composition: error message returned")

-- Guard: duplicate name (same as a standard template)
local ok6, e6 = mgr:createLoadableGroup({
    name = "Standard Group", composition = { inf = 1 }
})
ctld_test.assert(ok6 == false, "duplicate standard name: returns false")
ctld_test.assertNotNil(e6,     "duplicate standard name: error message returned")

-- Guard: duplicate name (same as a previously created custom)
mgr:createLoadableGroup({ name = "Recon", composition = { inf = 4, jtac = 1 } })
local ok7, e7 = mgr:createLoadableGroup({ name = "Recon", composition = { inf = 2 } })
ctld_test.assert(ok7 == false, "duplicate custom name: returns false")
ctld_test.assertNotNil(e7,     "duplicate custom name: error message returned")

-- Total template count unchanged after failed attempts
ctld_test.assertEqual(#mgr._templates, 3, "3 templates after 1 valid + 6 failed creates")

ctld_test.finish()
