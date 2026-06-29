---@diagnostic disable
-- =============================================================================
-- diag_parachute_csfarp_setup.lua
-- Setup test : parachutage d'une crate Countryside FARP depuis UH-1H
--
-- Ce script :
--   1. Force cratesRequired=1 pour la scène Countryside FARP
--   2. Ajoute la Countryside FARP crate dans les capacités de l'UH-1H
--   3. Spawne 1 crate Countryside FARP à 30 m devant le slot PLAYER_SLOT
--   4. Reconstruit le menu du joueur
--
-- Re-injecter pour RESET (restaure config).
-- =============================================================================

local TAG         = "[DIAG-PARA-SETUP]"
local KEY         = "_diag_para_setup"
local PLAYER_SLOT = "Batumi_UH-1H_312-1"
local CRATE_WEIGHT = 1001.24               -- Countryside FARP crate weight

-- ── RESET ─────────────────────────────────────────────────────────────────────
if _G[KEY] then
    local saved = _G[KEY]
    -- Restore cratesRequired
    local smgr = CTLDSceneManager.getInstance()
    local model = smgr:getModel("Countryside FARP")
    if model and model.crate then
        model.crate.cratesRequired = saved.origRequired
    end
    -- Restore descriptor cratesRequired in weight index
    local cmgr = CTLDCrateManager.getInstance()
    local desc = cmgr:findDescriptorByWeight(CRATE_WEIGHT)
    if desc then desc.cratesRequired = saved.origRequired end
    -- Restore capabilities + min altitude
    local cfg = CTLDConfig.get()
    cfg.settings["capabilitiesByType"]        = saved.origCaps
    cfg.settings["parachuteMinAltitudeCrates"] = saved.origMinAlt
    -- Rebuild player menu
    local pm  = CTLDPlayerManager.getInstance()
    local pObj = pm._players[PLAYER_SLOT]
    if pObj then pm:buildMenu(pObj) end
    _G[KEY] = nil
    trigger.action.outText(TAG .. " RESET OK — config restaurée.", 10)
    return TAG .. " RESET"
end

-- ── Find player ───────────────────────────────────────────────────────────────
local playerUnit = Unit.getByName(PLAYER_SLOT)
if not playerUnit or not playerUnit:isExist() then
    trigger.action.outText(TAG .. " ABORT: slot '" .. PLAYER_SLOT .. "' introuvable.", 15)
    return TAG .. " ABORT"
end

-- ── Force cratesRequired=1 ────────────────────────────────────────────────────
local smgr = CTLDSceneManager.getInstance()
local model = smgr:getModel("Countryside FARP")
if not model then
    trigger.action.outText(TAG .. " ABORT: scène 'Countryside FARP' introuvable.", 15)
    return TAG .. " ABORT"
end
local origRequired = model.crate.cratesRequired
model.crate.cratesRequired = 1

local cmgr = CTLDCrateManager.getInstance()
local desc  = cmgr:findDescriptorByWeight(CRATE_WEIGHT)
if not desc then
    trigger.action.outText(TAG .. " ABORT: descriptor weight " .. CRATE_WEIGHT .. " introuvable.", 15)
    return TAG .. " ABORT"
end
desc.cratesRequired = 1

-- ── Enable canParachuteDrop + lower min altitude for UH-1H ───────────────────
local cfg       = CTLDConfig.get()
local origCaps  = cfg.settings["capabilitiesByType"]
local origMinAlt = cfg.settings["parachuteMinAltitudeCrates"]
local newCaps   = {}
for k, v in pairs(origCaps) do newCaps[k] = v end
local uh1hCaps = {}
for k, v in pairs(origCaps["UH-1H"] or {}) do uh1hCaps[k] = v end
uh1hCaps.canParachuteDrop  = true   -- enable "Parachute Crates" menu entry
uh1hCaps.maxCratesOnboard  = 1
newCaps["UH-1H"] = uh1hCaps
cfg.settings["capabilitiesByType"]        = newCaps
cfg.settings["parachuteMinAltitudeCrates"] = 30   -- lower to 30 m for easier testing

-- ── Spawn 1 crate 30 m devant le joueur ──────────────────────────────────────
local hdg     = ctld.utils.getHeadingInRadians("setup", playerUnit, true)
local pos     = playerUnit:getPoint()
local cratePos = {
    x = pos.x + 30 * math.cos(hdg),
    y = pos.y,
    z = pos.z + 30 * math.sin(hdg),
}
local crate = cmgr:spawnCrate(desc, cratePos, playerUnit:getCoalition(),
    "diag_script", CTLDCrate.SPAWN_METHOD.CRATE_SPAWN, nil, nil)
if not crate then
    trigger.action.outText(TAG .. " ERROR: spawnCrate failed.", 15)
    return TAG .. " ERROR"
end

-- ── Rebuild player menu ───────────────────────────────────────────────────────
local pm   = CTLDPlayerManager.getInstance()
local pObj = pm._players[PLAYER_SLOT]
if pObj then pm:buildMenu(pObj) end

_G[KEY] = { origRequired = origRequired, origCaps = origCaps, origMinAlt = origMinAlt }

trigger.action.outText(
    TAG .. " SETUP OK\n" ..
    "cratesRequired=1, canParachuteDrop=true, minAlt=30m.\n" ..
    "Crate Countryside FARP spawnée 30m devant.\n\n" ..
    "PROTOCOLE :\n" ..
    "1. F10 > Crate Commands > Load Crate > 'Countryside FARP Crate'\n" ..
    "2. Décoller (≥ 30 m AGL)\n" ..
    "3. F10 > Crate Commands > Parachute Crates\n" ..
    "4. Observer : la scène Countryside FARP doit se déployer au sol.\n" ..
    "5. Vérifier CTLD.log : 'auto-unpack (parachute) SCENE'\n\n" ..
    "Re-injecter ce script pour RESET.", 30)

return TAG .. " SETUP OK — crate spawnée, menu reconstruit"
