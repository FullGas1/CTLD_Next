---@diagnostic disable
-- ============================================================
-- U-80 : CTLDTroopManager:disableLoadableGroup / enableLoadableGroup
-- Module  : Feature D (src/CTLD_troop.lua)
-- ============================================================

do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")
local mgr = dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/_fd_setup.lua")

ctld_test.start("U-80", "disableLoadableGroup / enableLoadableGroup")

-- All templates start enabled
for _, tmpl in ipairs(mgr._templates) do
    ctld_test.assert(tmpl.disabled == false,
        "init: '" .. tmpl.name .. "' disabled=false")
end

-- Disable a standard template
local ok1, e1 = mgr:disableLoadableGroup("Standard Group")
ctld_test.assert(ok1 == true,  "disable standard: returns true")
ctld_test.assertNil(e1,        "disable standard: no error")
local ts = mgr:_findTemplate("Standard Group")
ctld_test.assert(ts.disabled == true, "disable standard: disabled=true")

-- Template still in list (not removed)
ctld_test.assertEqual(#mgr._templates, 2, "disable: template count unchanged")

-- Disable a custom template
mgr:createLoadableGroup({ name = "Custom Charlie", composition = { inf = 3 } })
local ok2 = mgr:disableLoadableGroup("Custom Charlie")
ctld_test.assert(ok2 == true, "disable custom: returns true")
local tc = mgr:_findTemplate("Custom Charlie")
ctld_test.assert(tc.disabled == true, "disable custom: disabled=true")

-- Re-enable the standard template
local ok3, e3 = mgr:enableLoadableGroup("Standard Group")
ctld_test.assert(ok3 == true,  "enable standard: returns true")
ctld_test.assertNil(e3,        "enable standard: no error")
ctld_test.assert(ts.disabled == false, "enable standard: disabled=false")

-- Error: disable unknown
local ok4, e4 = mgr:disableLoadableGroup("Ghost")
ctld_test.assert(ok4 == false, "disable unknown: returns false")
ctld_test.assertNotNil(e4,     "disable unknown: error message returned")

-- Error: enable unknown
local ok5, e5 = mgr:enableLoadableGroup("Ghost")
ctld_test.assert(ok5 == false, "enable unknown: returns false")
ctld_test.assertNotNil(e5,     "enable unknown: error message returned")

ctld_test.finish()
