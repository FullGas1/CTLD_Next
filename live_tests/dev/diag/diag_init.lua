---@diagnostic disable
-- diag_init.lua : charge CTLD complet puis exécute ctld.initialize() pas à pas
do local f = io.open(((ctld and ctld.path or "") .. "CTLD.log"),"w") if f then f:close() end end

local BASE = ((ctld and ctld.path or "") .. "src/")

local function log(msg)
    env.info("[CTLD-INIT] " .. tostring(msg))
    local f = io.open(((ctld and ctld.path or "") .. "CTLD.log"),"a")
    if f then f:write("[INIT] " .. tostring(msg) .. "\n") f:close() end
end

local function try(label, fn)
    local ok, err = pcall(fn)
    if ok then log("OK   " .. label)
    else       log("FAIL " .. label .. " — " .. tostring(err)) end
    return ok
end

-- Charger tous les fichiers
for _, p in ipairs({
    "lib/class.lua","CTLD_config.lua","CTLD_i18n.lua","CTLD_i18n_en.lua",
    "CTLD_i18n_fr.lua","CTLD_i18n_es.lua","CTLD_i18n_ko.lua","CTLD_utils.lua",
    "CTLD_menu.lua","lib/CTLD_objectRegistry.lua","lib/CTLDParachuteEffect.lua",
    "CTLD_sceneManager.lua","CTLD_zone.lua","CTLD_troop.lua","CTLD_crate.lua",
    "CTLD_vehicle.lua","CTLD_fob.lua","CTLD_aasystem.lua","CTLD_beacon.lua",
    "CTLD_recon.lua","CTLD_jtac.lua","CTLD_player.lua","CTLD_core.lua",
    "scenes/CTLD_farpScene.lua","scenes/CTLD_fobScene.lua",
    "scenes/CTLD_mineFieldScene.lua","compat/legacy_api.lua",
}) do
    local ok, err = pcall(dofile, BASE .. p)
    if not ok then log("LOAD FAIL " .. p .. " — " .. tostring(err)) end
end

log("=== INIT STEP BY STEP ===")

-- Étape 1 : config
try("CTLDConfig.get():load()", function() CTLDConfig.get():load() end)
try("ctld.utils.initLog()",    function() ctld.utils.initLog() end)

-- Étape 2 : singletons
try("CTLDPlayerManager.getInstance()",         function() CTLDPlayerManager.getInstance() end)
try("CTLDZoneManager.getInstance()",           function() CTLDZoneManager.getInstance() end)
try("CTLDTroopManager.getInstance()",          function() CTLDTroopManager.getInstance() end)
try("CTLDCrateManager.getInstance()",          function() CTLDCrateManager.getInstance() end)
try("CTLDVehicleSpawner.getInstance()",        function() CTLDVehicleSpawner.getInstance() end)
try("CTLDFOBManager.getInstance()",            function() CTLDFOBManager.getInstance() end)
try("CTLDBeaconManager.getInstance()",         function() CTLDBeaconManager.getInstance() end)
try("CTLDReconManager.getInstance()",          function() CTLDReconManager.getInstance() end)
try("CTLDJTACManager.get()",                   function() CTLDJTACManager.get() end)
try("CTLDCrateAssemblyManager.getInstance()",  function() CTLDCrateAssemblyManager.getInstance() end)
try("CTLDCoreManager.getInstance()",           function() CTLDCoreManager.getInstance() end)
try("_scanExistingPlayers()",                  function()
    CTLDPlayerManager.getInstance():_scanExistingPlayers()
end)

-- Bilan
local pm = CTLDPlayerManager and CTLDPlayerManager._instance
if pm then
    local n = 0; for _ in pairs(pm._players or {}) do n = n + 1 end
    log("players tracked: " .. n)
    log("menu sections  : " .. #(pm._menuSections or {}))
    for i,s in ipairs(pm._menuSections or {}) do
        log("  section[" .. i .. "] " .. tostring(s.key))
    end
end

log("=== END INIT ===")
