---@diagnostic disable
-- ============================================================
-- U-87 : CTLDConfig — ctld.gs() shortcut
-- Module  : src/CTLD_config.lua
-- ============================================================

do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")

ctld_test.start("U-87", "ctld.gs() shortcut")

-- ctld.gs() delegates to CTLDConfig.get():getSetting()
ctld_test.assertEqual(ctld.gs("numberOfTroops"),          10,    "gs('numberOfTroops') == 10")
ctld_test.assertEqual(ctld.gs("maximumDistanceLogistic"), 200,   "gs('maximumDistanceLogistic') == 200")
ctld_test.assertEqual(ctld.gs("buildTimeFOB"),            120,   "gs('buildTimeFOB') == 120")

-- Unknown key returns nil
ctld_test.assertNil(ctld.gs("__nonexistent_key_xyz__"), "unknown key → nil")

ctld_test.finish()
