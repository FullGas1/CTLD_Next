---@diagnostic disable
-- =============================================================================
-- live_tests/scenarios/interactive/scenario_farp_metal_spawn.lua
-- CTLD — Spawn scène "Metal FARP" à la position du static coord_farp-1
--
-- Exécute playSceneAtPos "Metal FARP" au point du static "coord_farp-1".
-- Le helipad spawne 58 m au nord du anchor par design de la scène (step 1 polar offset).
-- Scénario d'utilité ponctuelle : injection unique, pas de steps humains.
--
-- Prérequis :
--   - Static object "coord_farp-1" présent dans la mission
--   - Inject CTLD_Next.lua first, wait 3–5 s for init.
--
-- @scenario  METAL-FARP-SPAWN
-- @version   3.0 — 2026-06-30
-- =============================================================================

-- ── 1. Witchcraft guard ──────────────────────────────────────────────────────
if not ctld or not ctld.utils then
    trigger.action.outText("[METAL-FARP-SPAWN] ABORT: CTLD not initialized. Inject CTLD_Next.lua first.", 15)
    return Witchcraft
end

-- ── 2. Double-injection guard ────────────────────────────────────────────────
if _SCN_METALFARPSPAWN_RUNNING then
    trigger.action.outText("[METAL-FARP-SPAWN] déjà actif — attendre la fin ou redémarrer DCS.", 10)
    return Witchcraft
end
_SCN_METALFARPSPAWN_RUNNING = true

do  -- isolation scope
-- ── 4. Debug ON ──────────────────────────────────────────────────────────────
local cfg                  = CTLDConfig.get()
local _savedDebug          = cfg.settings["debug"]
local _savedDebugScreenLog = cfg.settings["debugScreenLog"]
cfg.settings["debug"]          = true
cfg.settings["debugScreenLog"] = false

-- ── 5. Constants ─────────────────────────────────────────────────────────────
local TAG  = "[METAL-FARP-SPAWN]"
local NAME = "Metal FARP spawn at coord"

-- ── 7. Helpers ───────────────────────────────────────────────────────────────
local function log(msg) ctld.utils.log("INFO", "%s %s", TAG, msg) end

-- ── 8. Cleanup ───────────────────────────────────────────────────────────────
local function cleanup()
    cfg.settings["debug"]          = _savedDebug
    cfg.settings["debugScreenLog"] = _savedDebugScreenLog
    _SCN_METALFARPSPAWN_RUNNING = false
    log("cleanup done")
end

-- ── 13. Exécution principale ─────────────────────────────────────────────────
log("=== START: "..NAME.." ===")

local ok, err = pcall(function()
    local anchor = StaticObject.getByName("coord_farp-1")
    if not anchor or not anchor:isExist() then
        trigger.action.outText(TAG.." [FAIL] static 'coord_farp-1' not found", 15)
        log("[FAIL] static 'coord_farp-1' not found")
        return
    end

    local pos         = anchor:getPoint()
    local coalitionId = anchor:getCoalition()
    local countryId   = anchor:getCountry()

    log(string.format("anchor pos=(%.1f, %.1f, %.1f) coa=%d cty=%d",
        pos.x, pos.y, pos.z, coalitionId, countryId))

    local scene = CTLDSceneManager.getInstance():playSceneAtPos(
        "Metal FARP", pos, coalitionId, countryId)

    if scene then
        local msg = TAG..string.format(" ✅ [OK] %s — Metal FARP scene started at (%.0f, %.0f)", NAME, pos.x, pos.z)
        log(msg)
        trigger.action.outText(msg, 15)
    else
        local msg = TAG.." ❌ [KO] "..NAME.." — playSceneAtPos returned nil"
        log(msg)
        trigger.action.outText(msg, 15)
    end
end)

if not ok then
    local msg = TAG.." ❌ [KO] "..NAME.." — ERREUR: "..tostring(err)
    log(msg)
    trigger.action.outText(msg, 15)
end

cleanup()

end  -- do isolation scope
return Witchcraft
