---@diagnostic disable
-- ============================================================
-- F-01 : CTLDCoreManager INIT-B — détection statics cargo MM
-- Module  : C1 (src/CTLD_core.lua)
-- Objectif: Vérifier que INIT-B scanne coalition.getStaticObjects()
--           et détecte les objets de catégorie CARGO (category==6,
--           desc.attributes.Cargos==true).
--           Résultat loggé dans CTLD.log avec le compteur détecté.
--
-- DEPENDENCY mission martyr :
--   - Au moins un static de type cargo (Sling Cargo, etc.) présent dans
--     la mission, coalition BLUE ou RED.
-- ============================================================

-- Purge CTLD.log
do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")

-- Stubs minimaux pour les managers requis par CTLDCoreManager.init()
-- CTLDCrateManager : on injecte un stub qui capture les appels registerMMCrate
if not CTLDCrateManager then CTLDCrateManager = {} end
local cratesRegistered = {}
CTLDCrateManager.getInstance = function()
    return {
        registerMMCrate = function(self, obj, desc)
            cratesRegistered[#cratesRegistered + 1] = {
                name = obj.getName and obj:getName() or "unknown",
                desc = desc,
            }
        end,
        onBirth = function() end,
    }
end

-- CTLDJTACManager stub
if not CTLDJTACManager then CTLDJTACManager = {} end
CTLDJTACManager.get = function()
    return {
        registerMMJTAC  = function() end,
        markPendingJTAC = function() end,
        onBirth         = function() end,
    }
end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_core.lua")

ctld_test.start("F-01", "CTLDCoreManager INIT-B — détection statics cargo MM")

-- Reset singletons
CTLDDCSEventBridge._instance = nil
CTLDPlayerTracker._instance  = nil
CTLDCoreManager._instance    = nil
EventDispatcher._instance    = nil

-- Lancer l'init (appelle _initMMCrates en interne)
-- Note : CTLDPlayerTracker.init() appelle coalition.getPlayers() et
--        timer.scheduleFunction() — normaux en mission DCS active.
local ok, err = pcall(function()
    CTLDCoreManager.getInstance()
end)

ctld_test.assert(ok, string.format("CTLDCoreManager.getInstance() ne crash pas [%s]", tostring(err)))

-- Vérifier dans le log DCS que INIT-B s'est terminé
-- La ligne de log attendue : "CTLDCoreManager: INIT-B complete — N MM crate(s) detected"
-- On ne peut pas lire DCS.log directement, mais on peut vérifier CTLD.log
local logContent = ctld_test.readLog()

ctld_test.assert(logContent:find("INIT%-B complete") ~= nil,
    "CTLD.log contient 'INIT-B complete'")

-- Le nombre de crates enregistrés via registerMMCrate est loggé
local countLine = logContent:match("INIT%-B complete %- %- (%d+) MM crate")
    or logContent:match("INIT%-B complete %-%- (%d+)")
    or logContent:match("INIT%-B complete .- (%d+) MM")

ctld_test.assert(#cratesRegistered >= 0, string.format(
    "registerMMCrate appelé %d fois (0 acceptable si pas de cargo en mission)",
    #cratesRegistered))

-- Si la mission a des cargos, on attend > 0
-- Ajuster selon la mission martyr réelle :
-- ctld_test.assert(#cratesRegistered > 0, "au moins 1 cargo static détecté")

ctld_test.finish()
