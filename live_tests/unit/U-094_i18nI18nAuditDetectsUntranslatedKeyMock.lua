---@diagnostic disable
-- ============================================================
-- U-94 : CTLDi18n — ctld.i18n_audit() detects untranslated key (mock)
-- Module  : src/CTLD_i18n.lua
-- ============================================================

do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_i18n_fr.lua")

ctld_test.start("U-94", "CTLDi18n — ctld.i18n_audit() detects untranslated key in FR (mock)")

-- Pick a key that exists in EN AND has a real FR translation (value differs from EN)
local testKey = nil
for k, enVal in pairs(ctld.i18n["en"]) do
    if k ~= "translation_version" then
        local frVal = ctld.i18n["fr"][k]
        if frVal ~= nil and frVal ~= enVal then
            testKey = k
            break
        end
    end
end
ctld_test.assertNotNil(testKey, "found a translated FR key to use as mock target")

-- Save and set FR key = EN value (simulate untranslated)
local _origFR = ctld.i18n["fr"][testKey]
local enVal   = ctld.i18n["en"][testKey]
ctld.i18n["fr"][testKey] = enVal

local result, err = ctld.i18n_audit("fr")

-- No error
ctld_test.assertNil(err, "no error returned")

-- Key appears in untranslated list
local found = false
for _, k in ipairs(result.untranslated) do
    if k == testKey then found = true break end
end
ctld_test.assert(found, "untranslated list contains the mocked key '" .. tostring(testKey) .. "'")

-- Key NOT in missing list
local foundM = false
for _, k in ipairs(result.missing) do
    if k == testKey then foundM = true break end
end
ctld_test.assert(not foundM, "mocked key NOT in missing list")

-- Restore
ctld.i18n["fr"][testKey] = _origFR

ctld_test.finish()
