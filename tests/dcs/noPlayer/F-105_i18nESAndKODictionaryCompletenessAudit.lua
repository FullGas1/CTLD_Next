---@diagnostic disable
-- ============================================================
-- F-105 : CTLDi18n — ES and KO dictionary completeness audit
-- Module  : src/CTLD_i18n.lua + src/CTLD_i18n_es.lua + src/CTLD_i18n_ko.lua
-- ============================================================

do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_i18n_es.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_i18n_ko.lua")

ctld_test.start("F-105", "CTLDi18n — ES and KO dictionary completeness audit")

for _, lang in ipairs({"es", "ko"}) do
    local result, err = ctld.i18n_audit(lang)

    ctld_test.assertNil(err, lang .. ": no error")
    ctld_test.assert(type(result) == "table", lang .. ": audit returns a table")

    -- Version match (informational + assertion)
    ctld_test.assertEqual(result.version_match, true,
        string.format("%s version matches EN (EN=%s, %s=%s)",
            lang, result.en_version, lang, result.lang_version))

    -- Log gaps
    if #result.missing > 0 then
        env.info(string.format("[CTLD_TEST] F-105 %s MISSING (%d):", lang, #result.missing))
        for _, k in ipairs(result.missing) do
            env.info("  - " .. k)
        end
    end
    if #result.untranslated > 0 then
        env.info(string.format("[CTLD_TEST] F-105 %s UNTRANSLATED (%d):", lang, #result.untranslated))
        for _, k in ipairs(result.untranslated) do
            env.info("  ~ " .. k)
        end
    end

    ctld_test.assert(#result.missing == 0,
        string.format("%s has no missing keys (%d found)", lang, #result.missing))
    ctld_test.assert(#result.untranslated == 0,
        string.format("%s has no untranslated keys (%d found)", lang, #result.untranslated))
end

ctld_test.finish()
