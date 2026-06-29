---@diagnostic disable
-- ============================================================
-- F-104 : CTLDi18n — FR dictionary completeness audit
-- Module  : src/CTLD_i18n.lua + src/CTLD_i18n_fr.lua
--
-- Hard fail : missing keys (present in EN, absent in FR)
-- Soft log  : untranslated keys (FR value == EN value)
--             Some entries are intentionally kept in English
--             (e.g. "CTLD", "Actions", "Anti Tank") — not a failure.
-- ============================================================

do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_i18n_fr.lua")

ctld_test.start("F-104", "CTLDi18n — FR dictionary completeness audit")

local result, err = ctld.i18n_audit("fr")

ctld_test.assertNil(err, "no error for 'fr' language")
ctld_test.assert(type(result) == "table", "audit returns a table")

-- Version match (hard fail)
ctld_test.assertEqual(result.version_match, true,
    string.format("FR version matches EN (EN=%s, FR=%s)", result.en_version, result.lang_version))

-- Log untranslated entries (informational — NOT a hard failure)
if #result.untranslated > 0 then
    env.info(string.format("[CTLD_TEST] F-104 FR UNTRANSLATED (%d — informational, not a failure):",
        #result.untranslated))
    for _, k in ipairs(result.untranslated) do
        env.info("  ~ " .. k)
    end
end

-- Log missing entries (informational)
if #result.missing > 0 then
    env.info(string.format("[CTLD_TEST] F-104 FR MISSING (%d):", #result.missing))
    for _, k in ipairs(result.missing) do
        env.info("  - " .. k)
    end
end

-- Hard fail: missing keys only
ctld_test.assert(#result.missing == 0,
    string.format("FR has no missing keys (%d found)", #result.missing))

ctld_test.finish()
