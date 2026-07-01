---@diagnostic disable
-- ============================================================
-- F-101 : CTLDConfig — userConfig override via ctld.yamlConfigDatas
-- Module  : src/CTLD_config.lua
-- ============================================================

do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")

ctld_test.start("F-101", "CTLDConfig userConfig override via ctld.yamlConfigDatas")

-- Save current singleton and yamlConfigDatas (restore at end)
local _origInstance      = CTLDConfig._instance
local _origYamlConfigDatas = ctld.yamlConfigDatas

-- Reset singleton so a fresh load() will run
CTLDConfig._instance = nil

-- Inject a YAML user config overriding three settings
ctld.yamlConfigDatas = [[
ctld.numberOfTroops: 25
ctld.maximumDistanceLogistic: 350
ctld.buildTimeFOB: 60
]]

-- Fresh load — must process yamlConfigDatas
local cfg = CTLDConfig.get()
local ok, msg = cfg:load()

ctld_test.assertEqual(ok, true, "load() with yamlConfigDatas returns true")
ctld_test.assertNotNil(msg,     "load() returns a report string")

-- Overridden values must reflect YAML
ctld_test.assertEqual(cfg:getSetting("numberOfTroops"),          25,  "numberOfTroops overridden to 25")
ctld_test.assertEqual(cfg:getSetting("maximumDistanceLogistic"), 350, "maximumDistanceLogistic overridden to 350")
ctld_test.assertEqual(cfg:getSetting("buildTimeFOB"),            60,  "buildTimeFOB overridden to 60")

-- Non-overridden setting still holds its default
ctld_test.assertEqual(cfg:getSetting("hoverTime"), 10, "hoverTime not overridden → still default 10")

-- Restore
CTLDConfig._instance  = _origInstance
ctld.yamlConfigDatas  = _origYamlConfigDatas

ctld_test.finish()
