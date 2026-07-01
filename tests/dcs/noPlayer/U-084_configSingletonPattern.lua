---@diagnostic disable
-- ============================================================
-- U-84 : CTLDConfig — singleton pattern
-- Module  : src/CTLD_config.lua
-- ============================================================

do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")

ctld_test.start("U-84", "CTLDConfig singleton pattern")

-- Two calls return the same table reference
local a = CTLDConfig.get()
local b = CTLDConfig.get()
ctld_test.assert(a == b,           "get() × 2 → same instance (rawequal)")
ctld_test.assertNotNil(a,          "instance is not nil")
ctld_test.assertNotNil(a.settings, "instance.settings table exists")

-- isLoaded is true (setup.lua already called :load())
ctld_test.assertEqual(a.isLoaded, true, "isLoaded == true after setup load")

-- Mutating via one reference is visible through the other
local _orig = a.settings["numberOfTroops"]
a.settings["numberOfTroops"] = 999
ctld_test.assertEqual(b.settings["numberOfTroops"], 999, "mutation via 'a' visible on 'b'")
a.settings["numberOfTroops"] = _orig  -- restore

ctld_test.finish()
