---@diagnostic disable
-- ============================================================
-- U-89 : CTLDConfig.parseYAML() — simple k/v + dotted keys + types
-- Module  : src/CTLD_config.lua
-- ============================================================

do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")

ctld_test.start("U-89", "CTLDConfig.parseYAML() — k/v, types, dotted keys")

-- Simple string value
local t1 = CTLDConfig.parseYAML("myKey: hello")
ctld_test.assertEqual(t1["myKey"], "hello", "simple string value parsed")

-- Integer value coerced
local t2 = CTLDConfig.parseYAML("count: 42")
ctld_test.assertEqual(t2["count"], 42, "integer value coerced to number")

-- Boolean value coerced
local t3 = CTLDConfig.parseYAML("flag: true")
ctld_test.assertEqual(t3["flag"], true, "boolean value coerced")

-- Float value
local t4 = CTLDConfig.parseYAML("ratio: 0.5")
ctld_test.assertEqual(t4["ratio"], 0.5, "float value coerced")

-- Dotted key preserved as-is (ctld.key format used by userConfig)
local t5 = CTLDConfig.parseYAML("ctld.numberOfTroops: 25")
ctld_test.assertNotNil(t5["ctld.numberOfTroops"], "dotted key 'ctld.numberOfTroops' preserved")
ctld_test.assertEqual(t5["ctld.numberOfTroops"], 25, "dotted key value coerced to number")

-- Multiple keys
local t6 = CTLDConfig.parseYAML("ctld.buildTimeFOB: 60\nctld.cratesRequiredForFOB: 5")
ctld_test.assertEqual(t6["ctld.buildTimeFOB"],         60, "multi-line: first key parsed")
ctld_test.assertEqual(t6["ctld.cratesRequiredForFOB"],  5, "multi-line: second key parsed")

-- Empty input → empty table
local t7 = CTLDConfig.parseYAML("")
ctld_test.assert(type(t7) == "table", "empty input → empty table (not nil)")

ctld_test.finish()
