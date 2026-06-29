---@diagnostic disable
-- diag_boot.lua : diagnostic d'initialisation CTLD pas à pas
-- Injecte via Witchcraft dans une mission DCS avec CTLD chargé.
-- Détecte à quelle étape de ctld.initialize() le crash se produit.

do local f = io.open(((ctld and ctld.path or "") .. "CTLD.log"),"w") if f then f:close() end end

local results = {}
local function log(msg)
    env.info("[CTLD-BOOT] " .. tostring(msg))
    local f = io.open(((ctld and ctld.path or "") .. "CTLD.log"),"a")
    if f then f:write("[BOOT] " .. tostring(msg) .. "\n") f:close() end
    table.insert(results, msg)
end

local function try(label, fn)
    local ok, err = pcall(fn)
    if ok then
        log("OK   " .. label)
    else
        log("FAIL " .. label .. " — " .. tostring(err))
    end
    return ok
end

log("=== CTLD BOOT DIAGNOSTIC ===")

-- Vérifie que les classes existent (chargées par la mission)
try("CTLDConfig exists",        function() assert(CTLDConfig ~= nil) end)
try("CTLDPlayerManager exists", function() assert(CTLDPlayerManager ~= nil) end)
try("CTLDZoneManager exists",   function() assert(CTLDZoneManager ~= nil) end)
try("CTLDTroopManager exists",  function() assert(CTLDTroopManager ~= nil) end)
try("CTLDCoreManager exists",   function() assert(CTLDCoreManager ~= nil) end)
try("ctld.initialize exists",   function() assert(type(ctld.initialize) == "function") end)

-- Reset singletons pour pouvoir re-booter proprement
log("--- resetting singletons ---")
EventDispatcher._instance          = nil
CTLDDCSEventBridge._instance       = nil
CTLDPlayerManager._instance        = nil
CTLDZoneManager._instance          = nil
CTLDTroopManager._instance         = nil
CTLDCrateManager._instance         = nil
CTLDVehicleSpawner._instance       = nil
CTLDFOBManager._instance           = nil
CTLDBeaconManager._instance        = nil
CTLDReconManager._instance         = nil
if CTLDJTACManager then CTLDJTACManager._instance = nil end
CTLDCrateAssemblyManager._instance = nil
CTLDCoreManager._instance          = nil

-- Active le debug pour capturer tous les logs CTLD
log("--- activating debug mode ---")
try("CTLDConfig.get():load()", function()
    CTLDConfig.get():load()
end)
try("ctld.utils.initLog()", function()
    ctld.utils.initLog()
end)

-- Boot pas à pas
log("--- booting singletons step by step ---")
try("CTLDPlayerManager.getInstance()",      function() CTLDPlayerManager.getInstance() end)
try("CTLDZoneManager.getInstance()",        function() CTLDZoneManager.getInstance() end)
try("CTLDTroopManager.getInstance()",       function() CTLDTroopManager.getInstance() end)
try("CTLDCrateManager.getInstance()",       function() CTLDCrateManager.getInstance() end)
try("CTLDVehicleSpawner.getInstance()",     function() CTLDVehicleSpawner.getInstance() end)
try("CTLDFOBManager.getInstance()",         function() CTLDFOBManager.getInstance() end)
try("CTLDBeaconManager.getInstance()",      function() CTLDBeaconManager.getInstance() end)
try("CTLDReconManager.getInstance()",       function() CTLDReconManager.getInstance() end)
try("CTLDJTACManager.get()",                function() CTLDJTACManager.get() end)
try("CTLDCrateAssemblyManager.getInstance()", function() CTLDCrateAssemblyManager.getInstance() end)
try("CTLDCoreManager.getInstance()",        function() CTLDCoreManager.getInstance() end)
try("_scanExistingPlayers()",               function()
    CTLDPlayerManager.getInstance():_scanExistingPlayers()
end)

-- Résumé
log("--- final state ---")
log("PlayerManager : " .. tostring(CTLDPlayerManager._instance ~= nil))
log("ZoneManager   : " .. tostring(CTLDZoneManager._instance ~= nil))
log("TroopManager  : " .. tostring(CTLDTroopManager._instance ~= nil))
log("CoreManager   : " .. tostring(CTLDCoreManager._instance ~= nil))

local pm = CTLDPlayerManager._instance
if pm then
    local n = 0
    for _ in pairs(pm._players or {}) do n = n + 1 end
    log("players tracked: " .. n)
    log("menu sections  : " .. #(pm._menuSections or {}))
end

log("=== END BOOT DIAGNOSTIC ===")
