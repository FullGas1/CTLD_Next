---@diagnostic disable
-- diag_loader.lua : charge les fichiers src/ un par un et détecte le crash
do local f = io.open(((ctld and ctld.path or "") .. "CTLD.log"),"w") if f then f:close() end end

local BASE = ((ctld and ctld.path or "") .. "src/")

local function log(msg)
    env.info("[CTLD-LOADER] " .. tostring(msg))
    local f = io.open(((ctld and ctld.path or "") .. "CTLD.log"),"a")
    if f then f:write("[LOADER] " .. tostring(msg) .. "\n") f:close() end
end

local function load(path)
    local ok, err = pcall(dofile, BASE .. path)
    if ok then
        log("OK   " .. path)
    else
        log("FAIL " .. path .. " — " .. tostring(err))
    end
    return ok
end

log("=== SEQUENTIAL LOADER DIAGNOSTIC ===")

load("lib/class.lua")
load("CTLD_config.lua")
load("CTLD_i18n.lua")
load("CTLD_i18n_en.lua")
load("CTLD_i18n_fr.lua")
load("CTLD_i18n_es.lua")
load("CTLD_i18n_ko.lua")
load("CTLD_utils.lua")
load("CTLD_menu.lua")
load("lib/CTLD_objectRegistry.lua")
load("lib/CTLDParachuteEffect.lua")
load("CTLD_sceneManager.lua")
load("CTLD_zone.lua")
load("CTLD_troop.lua")
load("CTLD_crate.lua")
load("CTLD_vehicle.lua")
load("CTLD_fob.lua")
load("CTLD_aasystem.lua")
load("CTLD_beacon.lua")
load("CTLD_recon.lua")
load("CTLD_jtac.lua")
load("CTLD_player.lua")
load("CTLD_core.lua")
load("scenes/CTLD_farpScene.lua")
load("scenes/CTLD_fobScene.lua")
load("scenes/CTLD_mineFieldScene.lua")
load("compat/legacy_api.lua")
-- Ne pas charger userConfig ici (il appelle ctld.initialize())

log("CTLDPlayerManager : " .. type(CTLDPlayerManager))
log("EventDispatcher   : " .. type(EventDispatcher))
log("ctld.gs           : " .. type(ctld.gs))
log("=== END LOADER DIAGNOSTIC ===")
