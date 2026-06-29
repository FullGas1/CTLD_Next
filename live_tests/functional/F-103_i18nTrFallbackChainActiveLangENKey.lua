---@diagnostic disable
-- ============================================================
-- F-103 : CTLDi18n — ctld.tr() fallback chain (active lang → EN → key)
-- Module  : src/CTLD_i18n.lua
-- ============================================================

do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_i18n_fr.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_i18n_es.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_i18n_ko.lua")

ctld_test.start("F-103", "CTLDi18n — ctld.tr() fallback chain (active lang → EN → key)")

-- Find a key that has an FR translation different from EN
local testKey = nil
local frTranslation = nil
for k, enVal in pairs(ctld.i18n["en"]) do
    if k ~= "translation_version" then
        local frVal = ctld.i18n["fr"][k]
        if frVal ~= nil and frVal ~= enVal then
            testKey     = k
            frTranslation = frVal
            break
        end
    end
end
ctld_test.assertNotNil(testKey, "found a properly-translated FR key to test")

-- 1. Active lang = fr → returns FR translation
local _origLang = ctld.i18n_lang
ctld.i18n_lang = "fr"
ctld_test.assertEqual(ctld.tr(testKey), frTranslation, "fr lang: ctld.tr returns FR value")

-- 2. Active lang = en → returns EN value (= the key itself for EN)
ctld.i18n_lang = "en"
ctld_test.assertEqual(ctld.tr(testKey), ctld.i18n["en"][testKey], "en lang: ctld.tr returns EN value")

-- 3. Active lang = unknown → fallback to EN value
ctld.i18n_lang = "xx"
ctld_test.assertEqual(ctld.tr(testKey), ctld.i18n["en"][testKey], "unknown lang: ctld.tr falls back to EN")

-- 4. Completely unknown key → fallback to key itself
ctld.i18n_lang = "fr"
local unknownKey = "__CTLD_RECETTE_NO_SUCH_KEY__"
ctld_test.assertEqual(ctld.tr(unknownKey), unknownKey, "unknown key: ctld.tr returns the key itself")

-- 5. Parameter substitution
ctld.i18n["en"]["__TEST_PARAM__"] = "Hello %1, you have %2 items"
ctld.i18n["fr"]["__TEST_PARAM__"] = "Bonjour %1, tu as %2 éléments"
ctld.i18n_lang = "fr"
local translated = ctld.tr("__TEST_PARAM__", "Alice", 3)
ctld_test.assertEqual(translated, "Bonjour Alice, tu as 3 éléments", "parameter substitution works in FR")

-- Restore
ctld.i18n["en"]["__TEST_PARAM__"] = nil
ctld.i18n["fr"]["__TEST_PARAM__"] = nil
ctld.i18n_lang = _origLang

ctld_test.finish()
