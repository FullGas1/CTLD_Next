---@diagnostic disable
-- =============================================================================
-- diag_mt15_vehicle_menu_visual.lua
-- Visual test — Request Vehicle pur via F10 menu (MT-15 complement)
--
-- Ce diag configure l'UH-1H pour transporter un HMMWV entier, puis reconstruit
-- le menu F10. Le joueur valide manuellement les 3 actions :
--
--   1. F10 > Request Equipment > "HMMWV Armament" → HMMWV apparaît au sol près de l'hélico
--   2. F10 > Load Vehicle > "HMMWV Armament"     → HMMWV chargé (disparaît de la carte)
--   3. F10 > Unload Vehicle                      → HMMWV déployé derrière l'hélico
--
-- Re-injecter ce script pour RESET (restaure config + détruit le HMMWV éventuel).
--
-- Prérequis :
--   - Slot "Batumi_UH-1H_0-1" occupé
--   - CTLD_Next.lua injecté (≥3 s avant ce script)
-- =============================================================================

local PLAYER_SLOT = "Batumi_UH-1H_0-1"
local HMMWV_TYPE  = "M1043 HMMWV Armament"
local TAG         = "[DIAG-VEH-MENU]"
local SETUP_KEY   = "_diag_veh_menu_active"

local cfg = CTLDConfig.get()

-- ── RESET si déjà actif ────────────────────────────────────────────────────────
if _G[SETUP_KEY] then
    -- Restaure config
    cfg.settings["capabilitiesByType"] = _G[SETUP_KEY].savedCaps
    cfg.settings["maximumDistancePackableUnitsSearch"] = _G[SETUP_KEY].savedDist

    -- Détruit tout HMMWV résiduel dans le spawner
    local vs = CTLDVehicleSpawner.getInstance()
    for id, veh in pairs(vs._vehicles) do
        if veh.vehicleType == HMMWV_TYPE then
            if veh.unit and veh.unit:isExist() then
                local g = veh.unit:getGroup()
                if g then pcall(function() g:destroy() end) end
            end
            if veh.spawnData then vs._unitToVehicle[veh.spawnData.unitName] = nil end
            vs._vehicles[id] = nil
        end
    end

    _G[SETUP_KEY] = nil
    trigger.action.outText(TAG .. " RESET — config restaurée, HMMWV supprimé.", 10)
    return TAG .. " RESET OK"
end

-- ── SETUP ─────────────────────────────────────────────────────────────────────
local playerUnit = Unit.getByName(PLAYER_SLOT)
if not playerUnit or not playerUnit:isExist() then
    trigger.action.outText(TAG .. " ERREUR : slot '" .. PLAYER_SLOT .. "' introuvable.", 15)
    return TAG .. " ABORT: player not found"
end

-- Sauvegarder et surcharger capabilitiesByType pour UH-1H
local savedCaps = cfg.settings["capabilitiesByType"]
local savedDist = cfg.settings["maximumDistancePackableUnitsSearch"]

local caps = {}
for k, v in pairs(savedCaps or {}) do caps[k] = v end
caps["UH-1H"] = {
    cratesEnabled            = true,
    canTransportWholeVehicle = true,
    maxWholeVehiclesOnboard  = 1,
    loadableVehiclesBLUE     = { HMMWV_TYPE },
    loadableVehiclesRED      = {},
}
cfg.settings["capabilitiesByType"]               = caps
cfg.settings["maximumDistancePackableUnitsSearch"] = 300

_G[SETUP_KEY] = { savedCaps = savedCaps, savedDist = savedDist }

-- Reconstruire le menu F10 du joueur pour refléter la nouvelle config
local pm = CTLDPlayerManager.getInstance()
local pObj = pm._players[playerUnit:getName()]
if pObj then
    pm:buildMenu(pObj)
    trigger.action.outText(
        TAG .. " Setup OK — menu F10 reconstruit.\n" ..
        "1. F10 > Request Equipment > HMMWV Armament\n" ..
        "2. F10 > Load Vehicle > HMMWV Armament\n" ..
        "3. F10 > Unload Vehicle\n" ..
        "Re-injecter ce script pour RESET.", 30)
else
    trigger.action.outText(
        TAG .. " WARN : joueur non enregistré dans PlayerManager — " ..
        "config appliquée mais menu non reconstruit (re-entrer dans l'appareil).", 20)
end

return TAG .. " SETUP OK — UH-1H configuré pour HMMWV whole-vehicle transport"
