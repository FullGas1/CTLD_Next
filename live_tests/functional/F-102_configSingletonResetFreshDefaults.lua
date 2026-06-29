---@diagnostic disable
-- ============================================================
-- F-102 : CTLDConfig — singleton reset + fresh defaults
-- Module  : src/CTLD_config.lua
-- ============================================================

do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")

ctld_test.start("F-102", "CTLDConfig singleton reset + fresh defaults")

-- Save current state
local _origInstance      = CTLDConfig._instance
local _origYamlConfigDatas = ctld.yamlConfigDatas
ctld.yamlConfigDatas = nil  -- no user override for this test

-- Mutate a setting on the current instance
CTLDConfig.get().settings["numberOfTroops"] = 99

-- Verify mutation visible
ctld_test.assertEqual(ctld.gs("numberOfTroops"), 99, "pre-reset: mutation is 99")

-- Reset singleton
CTLDConfig._instance = nil

-- Fresh get() + load() → should restore defaults
local fresh = CTLDConfig.get()
fresh:load()

ctld_test.assertEqual(fresh:getSetting("numberOfTroops"),          10,  "post-reset: numberOfTroops restored to default 10")
ctld_test.assertEqual(fresh:getSetting("maximumDistanceLogistic"), 200, "post-reset: maximumDistanceLogistic restored to 200")
ctld_test.assertEqual(fresh:getSetting("buildTimeFOB"),            120, "post-reset: buildTimeFOB restored to 120")
ctld_test.assertEqual(fresh.isLoaded, true,                             "fresh instance isLoaded == true after load()")

-- Restore
CTLDConfig._instance  = _origInstance
ctld.yamlConfigDatas  = _origYamlConfigDatas

ctld_test.finish()
