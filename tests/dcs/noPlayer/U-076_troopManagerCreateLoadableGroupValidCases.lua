---@diagnostic disable
-- ============================================================
-- U-76 : CTLDTroopManager:createLoadableGroup — valid cases
-- Module  : Feature D (src/CTLD_troop.lua)
-- ============================================================

do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")
local mgr = dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/_fd_setup.lua")

ctld_test.start("U-76", "createLoadableGroup — valid cases")

-- Initial state: 2 standard templates
ctld_test.assertEqual(#mgr._templates, 2, "init: 2 standard templates")

-- Create a minimal custom group (single field)
local ok1, err1 = mgr:createLoadableGroup({
    name        = "Mortar Only",
    composition = { mortar = 8 },
    side        = 1,
})
ctld_test.assert(ok1 == true,  "mortar-only: returns true")
ctld_test.assertNil(err1,      "mortar-only: no error")
ctld_test.assertEqual(#mgr._templates, 3, "mortar-only: template added to list")

local t = mgr:_findTemplate("Mortar Only")
ctld_test.assertNotNil(t,              "mortar-only: findTemplate returns entry")
ctld_test.assertEqual(t.mortar,  8,    "mortar-only: mortar=8")
ctld_test.assertEqual(t.inf,     0,    "mortar-only: inf defaults to 0")
ctld_test.assertEqual(t.total,   8,    "mortar-only: total=8")
ctld_test.assert(t.custom == true,     "mortar-only: custom=true")
ctld_test.assert(t.disabled == false,  "mortar-only: disabled=false")
ctld_test.assertEqual(t.side,    1,    "mortar-only: side=1")
ctld_test.assertNotNil(t._dbKey,       "mortar-only: _dbKey set")
ctld_test.assertNotNil(CTLDObjectRegistry._db[t._dbKey], "mortar-only: ObjectRegistry entry created")

-- Create a full composition (all fields explicit)
local ok2 = mgr:createLoadableGroup({
    name        = "Heavy Squad",
    composition = { inf = 8, mg = 2, at = 2, aa = 1, mortar = 1, jtac = 1 },
    side        = 2,
})
ctld_test.assert(ok2 == true, "heavy: returns true")
ctld_test.assertEqual(#mgr._templates, 4, "heavy: template added")

local t2 = mgr:_findTemplate("Heavy Squad")
ctld_test.assertEqual(t2.total,   15,  "heavy: total=15")
ctld_test.assert(t2.hasJtac,          "heavy: hasJtac=true")

-- Create with side=nil (both coalitions)
local ok3 = mgr:createLoadableGroup({
    name        = "Universal",
    composition = { inf = 4 },
})
ctld_test.assert(ok3 == true, "universal: returns true")
local t3 = mgr:_findTemplate("Universal")
ctld_test.assertNil(t3.side, "universal: side=nil")

-- Standard templates still intact
local ts = mgr:_findTemplate("Standard Group")
ctld_test.assertNotNil(ts,            "standard template still present")
ctld_test.assert(ts.custom == false,  "standard template: custom=false")

ctld_test.finish()
