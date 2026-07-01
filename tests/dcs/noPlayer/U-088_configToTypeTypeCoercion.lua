---@diagnostic disable
-- ============================================================
-- U-88 : CTLDConfig.to_type() — type coercion
-- Module  : src/CTLD_config.lua
-- ============================================================

do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")

ctld_test.start("U-88", "CTLDConfig.to_type() — type coercion")

-- Booleans
ctld_test.assertEqual(CTLDConfig.to_type("true"),  true,  "to_type('true') == true")
ctld_test.assertEqual(CTLDConfig.to_type("false"), false, "to_type('false') == false")

-- Numbers
ctld_test.assertEqual(CTLDConfig.to_type("42"),    42,    "to_type('42') == 42")
ctld_test.assertEqual(CTLDConfig.to_type("3.14"),  3.14,  "to_type('3.14') == 3.14")
ctld_test.assertEqual(CTLDConfig.to_type("0"),     0,     "to_type('0') == 0")

-- Strings — single quotes stripped
ctld_test.assertEqual(CTLDConfig.to_type("'hello'"), "hello", "to_type(\"'hello'\") strips single quotes")
-- Strings — double quotes stripped
ctld_test.assertEqual(CTLDConfig.to_type('"world"'),  "world", 'to_type(\'"world"\') strips double quotes')
-- Plain string preserved
ctld_test.assertEqual(CTLDConfig.to_type("beacon.ogg"), "beacon.ogg", "to_type('beacon.ogg') preserved as string")

ctld_test.finish()
