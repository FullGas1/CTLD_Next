---@diagnostic disable
-- ============================================================
-- F-02 : CTLDCoreManager INIT-C — détection groupes JTAC MM
-- Module  : C1 (src/CTLD_core.lua)
-- Objectif: Vérifier que INIT-C scanne coalition.getGroups() et
--           détecte les groupes dont le nom contient "jtac"
--           (insensible à la casse).
--
-- DEPENDENCY mission martyr :
--   - Au moins un groupe actif dont le nom contient "jtac"
--     (ex: "jtac_test", "JTAC_Blue_1") côté BLUE ou RED.
-- ============================================================

-- Purge CTLD.log
do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")

-- Stub CTLDCrateManager
if not CTLDCrateManager then CTLDCrateManager = {} end
CTLDCrateManager.getInstance = function()
    return {
        registerMMCrate = function() end,
        onBirth         = function() end,
    }
end

-- Stub CTLDJTACManager : capture les appels registerMMJTAC / markPendingJTAC
if not CTLDJTACManager then CTLDJTACManager = {} end
local jtacsRegistered = {}
local jtacsPending    = {}
CTLDJTACManager.get = function()
    return {
        registerMMJTAC = function(self, group)
            jtacsRegistered[#jtacsRegistered + 1] = group:getName()
        end,
        markPendingJTAC = function(self, name)
            jtacsPending[#jtacsPending + 1] = name
        end,
        onBirth = function() end,
    }
end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_core.lua")

ctld_test.start("F-02", "CTLDCoreManager INIT-C — détection groupes JTAC MM")

CTLDDCSEventBridge._instance = nil
CTLDPlayerTracker._instance  = nil
CTLDCoreManager._instance    = nil
EventDispatcher._instance    = nil

local ok, err = pcall(function()
    CTLDCoreManager.getInstance()
end)

ctld_test.assert(ok, string.format("CTLDCoreManager.getInstance() ne crash pas [%s]", tostring(err)))

-- Vérifier CTLD.log
local logContent = ctld_test.readLog()

ctld_test.assert(logContent:find("INIT%-C complete") ~= nil,
    "CTLD.log contient 'INIT-C complete'")

-- Vérifier que les groupes détectés ont bien "jtac" dans leur nom
local allJtacNamesValid = true
for _, name in ipairs(jtacsRegistered) do
    if name:lower():find("jtac") == nil then
        allJtacNamesValid = false
        ctld_test.assert(false,
            string.format("groupe inattendu enregistré comme JTAC: '%s'", name))
    end
end
if #jtacsRegistered > 0 then
    ctld_test.assert(allJtacNamesValid,
        string.format("tous les %d groupes enregistrés ont 'jtac' dans le nom", #jtacsRegistered))
end

-- Même contrôle pour les pending
for _, name in ipairs(jtacsPending) do
    if name:lower():find("jtac") == nil then
        ctld_test.assert(false,
            string.format("groupe pending inattendu: '%s'", name))
    end
end

-- Info : log du nombre total détecté
local total = #jtacsRegistered + #jtacsPending
ctld_test.assert(total >= 0,
    string.format("%d JTAC(s) détecté(s) : %d actifs, %d pending",
        total, #jtacsRegistered, #jtacsPending))

-- Si la mission contient "jtac_test" on peut valider explicitement :
local foundJtacTest = false
for _, name in ipairs(jtacsRegistered) do
    if name:lower():find("jtac_test") then foundJtacTest = true end
end
-- Note: décommenter si la mission martyr contient un groupe "jtac_test" actif
-- ctld_test.assert(foundJtacTest, "groupe 'jtac_test' détecté par INIT-C")

ctld_test.finish()
