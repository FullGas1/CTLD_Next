---@diagnostic disable
-- ============================================================
-- U-86 : CTLDConfig — getSetting() default values
-- Module  : src/CTLD_config.lua
-- ============================================================

do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")

ctld_test.start("U-86", "CTLDConfig getSetting() — default values")

local cfg = CTLDConfig.get()

-- [1] System
ctld_test.assertEqual(cfg:getSetting("addPlayerAircraftByType"), true,  "addPlayerAircraftByType default true")
ctld_test.assertEqual(cfg:getSetting("disableAllSmoke"),         false, "disableAllSmoke default false")

-- [3] Crates
ctld_test.assertEqual(cfg:getSetting("maximumDistanceLogistic"), 200,   "maximumDistanceLogistic default 200")
ctld_test.assertEqual(cfg:getSetting("minimumHoverHeight"),      7.5,   "minimumHoverHeight default 7.5")
ctld_test.assertEqual(cfg:getSetting("hoverTime"),               10,    "hoverTime default 10")

-- [4] Troops
ctld_test.assertEqual(cfg:getSetting("numberOfTroops"),          10,    "numberOfTroops default 10")
ctld_test.assertEqual(cfg:getSetting("maxExtractDistance"),      125,   "maxExtractDistance default 125")

-- [6] FOB
ctld_test.assertEqual(cfg:getSetting("cratesRequiredForFOB"),    3,     "cratesRequiredForFOB default 3")
ctld_test.assertEqual(cfg:getSetting("buildTimeFOB"),            120,   "buildTimeFOB default 120")

-- [9] JTAC
ctld_test.assertEqual(cfg:getSetting("JTAC_maxDistance"),        10000, "JTAC_maxDistance default 10000")

ctld_test.finish()
