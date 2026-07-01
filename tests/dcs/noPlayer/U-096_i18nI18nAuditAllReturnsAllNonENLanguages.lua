---@diagnostic disable
-- ============================================================
-- U-96 : CTLDi18n — ctld.i18n_auditAll() returns all non-EN languages
-- Module  : src/CTLD_i18n.lua
-- ============================================================

do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_i18n_fr.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_i18n_es.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_i18n_ko.lua")

ctld_test.start("U-96", "CTLDi18n — ctld.i18n_auditAll() returns all non-EN languages")

local results = ctld.i18n_auditAll()

-- Returns a table
ctld_test.assert(type(results) == "table", "auditAll() returns a table")

-- Contains fr, es, ko entries
ctld_test.assertNotNil(results["fr"], "auditAll result contains 'fr'")
ctld_test.assertNotNil(results["es"], "auditAll result contains 'es'")
ctld_test.assertNotNil(results["ko"], "auditAll result contains 'ko'")

-- Does NOT contain "en" entry
ctld_test.assertNil(results["en"], "auditAll result does NOT contain 'en'")

-- Each entry has the expected structure
for _, lang in ipairs({"fr", "es", "ko"}) do
    local r = results[lang]
    ctld_test.assert(r.version_match  ~= nil, lang .. ": version_match present")
    ctld_test.assert(type(r.missing)  == "table", lang .. ": missing is a table")
    ctld_test.assert(type(r.untranslated) == "table", lang .. ": untranslated is a table")
end

ctld_test.finish()
