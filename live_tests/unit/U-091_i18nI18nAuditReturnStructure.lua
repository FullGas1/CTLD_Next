---@diagnostic disable
-- ============================================================
-- U-91 : CTLDi18n — ctld.i18n_audit() return structure
-- Module  : src/CTLD_i18n.lua
-- ============================================================

do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_i18n_fr.lua")

ctld_test.start("U-91", "CTLDi18n — ctld.i18n_audit() return structure (fr)")

local result, err = ctld.i18n_audit("fr")

-- No error returned
ctld_test.assertNil(err, "no error for known language 'fr'")

-- Result is a table
ctld_test.assert(type(result) == "table", "result is a table")

-- Required fields present
ctld_test.assert(result.version_match ~= nil, "result.version_match field present")
ctld_test.assert(type(result.en_version)   == "string", "result.en_version is a string")
ctld_test.assert(type(result.lang_version) == "string", "result.lang_version is a string")
ctld_test.assert(type(result.missing)      == "table",  "result.missing is a table")
ctld_test.assert(type(result.untranslated) == "table",  "result.untranslated is a table")

-- EN version known value
ctld_test.assertEqual(result.en_version, "1.8", "EN version is 1.8")

ctld_test.finish()
