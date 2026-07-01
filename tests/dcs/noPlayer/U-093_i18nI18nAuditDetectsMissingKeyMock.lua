---@diagnostic disable
-- ============================================================
-- U-93 : CTLDi18n — ctld.i18n_audit() detects missing key (mock)
-- Module  : src/CTLD_i18n.lua
-- ============================================================

do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_i18n_fr.lua")

ctld_test.start("U-93", "CTLDi18n — ctld.i18n_audit() detects missing key in FR (mock)")

-- Pick a key that exists in EN (any non-version key)
local testKey = nil
for k, _ in pairs(ctld.i18n["en"]) do
    if k ~= "translation_version" then
        testKey = k
        break
    end
end
ctld_test.assertNotNil(testKey, "at least one EN key found for mock")

-- Save and remove key from FR
local _origFR = ctld.i18n["fr"][testKey]
ctld.i18n["fr"][testKey] = nil

local result, err = ctld.i18n_audit("fr")

-- No error
ctld_test.assertNil(err, "no error returned")

-- Missing list contains the removed key
local found = false
for _, k in ipairs(result.missing) do
    if k == testKey then found = true break end
end
ctld_test.assert(found, "missing list contains the removed key '" .. tostring(testKey) .. "'")

-- Not in untranslated list
local foundU = false
for _, k in ipairs(result.untranslated) do
    if k == testKey then foundU = true break end
end
ctld_test.assert(not foundU, "removed key NOT in untranslated list")

-- Restore
ctld.i18n["fr"][testKey] = _origFR

ctld_test.finish()
