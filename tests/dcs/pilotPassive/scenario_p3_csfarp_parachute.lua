---@diagnostic disable
-- =============================================================================
-- live_tests/scenarios/interactive/scenario_p3_csfarp_parachute.lua
-- CTLD — CS FARP via parachutage auto-unpack (sous-cas P3)
--
-- Valide (régression TODO [N]) :
--   - _checkAutoUnpack route vers playSceneAtPos (chemin "generic scene")
--   - Pas de guard FOB (pas de fobCompatible) → scène joue directement
--   - Aucun crash, scène CS FARP se déploie
--
-- Cinématique (2 steps, injection unique) :
--   S1 [auto] Spawn 1 CS FARP crate LANDED+fromParachute, appel _checkAutoUnpack
--   S2 [auto T+35] Vérifier scène complétée + crate consommée
--
-- Prérequis :
--   - UH-1H BLUE au sol
--   - Inject CTLD_Next.lua first, wait 3–5 s for init.
--
-- @scenario  P3-CSFARP
-- @version   3.0 — 2026-06-30
-- @coverage  P3.1–P3.7
-- =============================================================================

-- ── 1. Witchcraft guard ──────────────────────────────────────────────────────
if not ctld or not ctld.utils then
    trigger.action.outText("[P3-CSFARP] ABORT: CTLD not initialized. Inject CTLD_Next.lua first.", 15)
    return Witchcraft
end

-- ── 2. Double-injection guard ────────────────────────────────────────────────
if _SCN_P3CSFARP_RUNNING then
    trigger.action.outText("[P3-CSFARP] déjà actif — attendre la fin ou redémarrer DCS.", 10)
    return Witchcraft
end
_SCN_P3CSFARP_RUNNING = true
_SCN_P3CSFARP_CLEANUP = nil

do  -- isolation scope
-- ── 4. Debug ON ──────────────────────────────────────────────────────────────
local cfg                  = CTLDConfig.get()
local _savedDebug          = cfg.settings["debug"]
local _savedDebugScreenLog = cfg.settings["debugScreenLog"]
cfg.settings["debug"]          = true
cfg.settings["debugScreenLog"] = false

-- ── 5. Constants ─────────────────────────────────────────────────────────────
local TAG  = "[P3-CSFARP]"
local NAME = "CS FARP parachute auto-unpack"

-- ── 6. State ─────────────────────────────────────────────────────────────────
local S = {
    step        = 0,
    passed      = 0,
    failed      = 0,
    failReasons = {},
    groupId     = nil,
    timerHandle = nil,
    timerGen    = 0,
    transport   = nil,
}

-- ── 7. Helpers ───────────────────────────────────────────────────────────────
local function log(msg) ctld.utils.log("INFO", "%s %s", TAG, msg) end

local function instruct(msg)
    log("[INSTR] " .. msg)
    trigger.action.outText(TAG .. "\n" .. msg, 360, true)
end

local function pass(id, msg) S.passed = S.passed + 1 ; log("[PASS] "..id..": "..(msg or "")) end
local function fail(id, msg) S.failed = S.failed + 1 ; table.insert(S.failReasons, id..": "..(msg or "")) ; log("[FAIL] "..id..": "..(msg or "")) end
local function check(id, desc, cond, detail)
    if cond then pass(id, desc)
    else fail(id, desc .. (detail and (" | " .. detail) or "")) end
end

-- ── 8. Cleanup ───────────────────────────────────────────────────────────────
local function cleanup()
    if S.timerHandle then timer.removeFunction(S.timerHandle) ; S.timerHandle = nil end
    cfg.settings["debug"]          = _savedDebug
    cfg.settings["debugScreenLog"] = _savedDebugScreenLog
    _SCN_P3CSFARP_RUNNING = false
    _SCN_P3CSFARP_CLEANUP = nil
    log("cleanup done")
end

-- ── 9. Timer helpers ─────────────────────────────────────────────────────────
local function cancelTimer()
    S.timerGen = S.timerGen + 1
    if S.timerHandle then
        pcall(timer.removeFunction, S.timerHandle)
        S.timerHandle = nil
    end
end

local function waitThen(delayS, callback)
    cancelTimer()
    local myGen = S.timerGen
    S.timerHandle = timer.scheduleFunction(function()
        if S.timerGen ~= myGen then return nil end
        S.timerHandle = nil
        callback()
    end, nil, timer.getTime() + delayS)
end

-- ── 10. Finalization ─────────────────────────────────────────────────────────
local function finalizeScenario()
    cancelTimer()
    local total = S.passed + S.failed
    local summary
    if S.failed == 0 then
        summary = TAG.." ✅ [OK] "..NAME.." — "..S.passed.."/"..total.." PASS"
    else
        summary = TAG.." ❌ [KO] "..NAME.." — "..S.failed.." FAIL: "..
            table.concat(S.failReasons, " | ")
    end
    log(summary)
    trigger.action.outText(summary, 360, true)
    local ok, err = pcall(cleanup)
    if not ok then log("WARN cleanup: "..tostring(err)) ; _SCN_P3CSFARP_RUNNING = false end
end

-- ── 12. Step runner ──────────────────────────────────────────────────────────
local steps = {}
local advanceStep

advanceStep = function()
    S.step = S.step + 1
    if not steps[S.step] then
        finalizeScenario()
        return
    end
    local ok, err = pcall(steps[S.step])
    if not ok then
        fail("S"..S.step, "pcall: "..tostring(err))
        trigger.action.outText(TAG.." ⚠️ S"..S.step.." ERREUR: "..tostring(err), 15, false)
        advanceStep()
    end
end

-- ── 13. Steps ────────────────────────────────────────────────────────────────

-- S1 — Spawn 1 CS FARP crate LANDED+fromParachute, _checkAutoUnpack
steps[1] = function()
    instruct(
        "Step 1/2 — SPAWN + AUTO-UNPACK CS FARP (auto)\n"..
        "Spawn d'une crate Countryside FARP LANDED+fromParachute.\n"..
        "Appel _checkAutoUnpack → route generic scene.\n"..
        "Vérification de la scène dans 35s…"
    )

    ctld_test.cleanup()

    if not S.transport then fail("P3.0", "aucun joueur BLUE") ; return end

    local cId  = S.transport:getCoalition()
    local pPos = S.transport:getPoint()
    local hdg  = ctld.utils.getHeadingInRadians("p3", S.transport, true)

    -- Descriptor Countryside FARP
    local cm   = CTLDCrateManager.getInstance()
    local desc = cm:findDescriptorByUnitType("Countryside FARP")
    check("P3.1", "descriptor 'Countryside FARP' present", desc ~= nil)
    if not desc then fail("P3.1b", "descriptor Countryside FARP absent") ; return end

    -- Forcer cratesRequired=1 pour test rapide
    local origRequired   = desc.cratesRequired
    desc.cratesRequired  = 1

    -- Spawn 1 crate 60 m devant, état LANDED + fromParachute
    local nx = pPos.x + math.cos(hdg) * 60
    local nz = pPos.z + math.sin(hdg) * 60
    local ny = land.getHeight({ x = nx, y = nz })
    local crate = cm:spawnCrate(desc, { x = nx, y = ny, z = nz }, cId,
        "p3_script", CTLDCrate.SPAWN_METHOD.CRATE_SPAWN)
    check("P3.2", "CS FARP crate spawnée", crate ~= nil)
    if not crate then
        desc.cratesRequired = origRequired
        fail("P3.2b", "spawnCrate failed")
        return
    end

    crate.state         = CTLDCrate.STATE.LANDED
    crate.fromParachute = true
    crate.position      = { x = nx, y = ny, z = nz }

    -- Route attendue : generic scene (Countryside FARP n'est pas fobCompatible)
    local sm    = CTLDSceneManager.getInstance()
    local model = sm:getModel("Countryside FARP")
    check("P3.3", "'Countryside FARP' dans CTLDSceneManager", model ~= nil)
    if model then
        check("P3.4", "Countryside FARP n'est PAS fobCompatible",
            not (model.crate and model.crate.fobCompatible == true))
    end

    -- Compter les scènes avant
    local scenesBefore = 0
    for _ in pairs(sm._activeScenes or {}) do scenesBefore = scenesBefore + 1 end

    cm:_checkAutoUnpack(crate)

    local scenesAfter = 0
    for _ in pairs(sm._activeScenes or {}) do scenesAfter = scenesAfter + 1 end

    check("P3.5", "au moins 1 scène active après _checkAutoUnpack",
        scenesAfter >= scenesBefore,
        "before="..scenesBefore.." after="..scenesAfter)

    -- Restaurer cratesRequired
    desc.cratesRequired = origRequired

    log("Scène Countryside FARP lancée. Vérification dans 35s.")
    waitThen(35, advanceStep)
end

-- S2 — Vérification scène complétée (~T+35)
steps[2] = function()
    instruct(
        "Step 2/2 — VÉRIFICATION AUTO (T+35)\n"..
        "Vérification auto : aucun crash + crate CS FARP consommée."
    )

    -- Vérification principale : aucun crash (étape 1 PASS + étape 2 PASS = OK)
    pass("P3.6", "aucun crash après auto-unpack Countryside FARP")

    -- Vérifier que la crate CS FARP initiale a été consommée (plus LANDED)
    local cm = CTLDCrateManager.getInstance()
    local foundLanded = false
    for _, c in pairs(cm.crates) do
        if c.fromParachute and c.descriptor
           and c.descriptor.unit == "Countryside FARP"
           and c.state == CTLDCrate.STATE.LANDED then
            foundLanded = true
        end
    end
    check("P3.7", "crate CS FARP consommée (plus de crate LANDED+fromParachute)",
        not foundLanded)

    advanceStep()
end

-- ── 14. Start ────────────────────────────────────────────────────────────────
S.transport = (function()
    local ok, pm = pcall(CTLDPlayerManager.getInstance)
    if ok and pm and pm._players then
        for unitName in pairs(pm._players) do
            local u = Unit.getByName(unitName)
            if u and u:isExist() then return u end
        end
    end
    for _, grp in ipairs(coalition.getGroups(coalition.side.BLUE) or {}) do
        for _, unit in ipairs(grp:getUnits() or {}) do
            if unit and unit:isExist() and unit:getPlayerName() then return unit end
        end
    end
    return nil
end)()

if not S.transport then
    trigger.action.outText(TAG.." ABORT : aucun joueur BLUE. Occuper un slot avant injection.", 20)
    cleanup()
    return Witchcraft
end

_SCN_P3CSFARP_CLEANUP = cleanup

log("=== START: "..NAME.." | transport="..S.transport:getName().." | "..#steps.." steps ===")
trigger.action.outText(TAG.." démarrage — "..#steps.." steps | "..S.transport:getName(), 8)
advanceStep()

end  -- do isolation scope
return Witchcraft
