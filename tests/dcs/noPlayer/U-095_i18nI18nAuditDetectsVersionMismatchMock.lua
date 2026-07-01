---@diagnostic disable
-- ============================================================
-- U-95 : CTLDi18n — ctld.i18n_audit() detects version mismatch (mock)
-- Module  : src/CTLD_i18n.lua
-- ============================================================

do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_i18n_fr.lua")

ctld_test.start("U-95", "CTLDi18n — ctld.i18n_audit() detects version mismatch (mock)")

-- Save original FR version
local _origVersion = ctld.i18n["fr"].translation_version

-- Set FR version to a clearly different value
ctld.i18n["fr"].translation_version = "0.0"

local result, err = ctld.i18n_audit("fr")

-- No error (language exists)
ctld_test.assertNil(err, "no error for known language")

-- version_match is false
ctld_test.assertEqual(result.version_match, false, "version_match is false when FR version differs from EN")

-- en_version and lang_version captured correctly
ctld_test.assertEqual(result.en_version,   "1.8", "en_version captured correctly")
ctld_test.assertEqual(result.lang_version, "0.0", "lang_version reflects mocked value")

-- Restore
ctld.i18n["fr"].translation_version = _origVersion

-- Verify restore: version_match should be true again
local r2, _ = ctld.i18n_audit("fr")
ctld_test.assertEqual(r2.version_match, true, "version_match restored to true after mock removed")

ctld_test.finish()
