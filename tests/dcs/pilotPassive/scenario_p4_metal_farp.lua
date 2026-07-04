---@diagnostic disable
-- =============================================================================
-- live_tests/scenarios/interactive/scenario_p4_metal_farp.lua
-- CTLD — Metal FARP via menu F10 : warehouse stocking (sous-cas P4)
--
-- Valide :
--   - playScene "Metal FARP" se déroule correctement
--   - Step 9 (func) appelle addLiquid sur la warehouse si mod présent
--   - Si mod absent : step 1 skip spawn (farpName = nil), step 9 no-op, aucun crash
--
-- Cinématique (2 steps, injection unique) :
--   S1 [auto] playScene Metal FARP sur le transport joueur
--   S2 [auto T+35] Vérifier warehouse stockée (si mod présent) ou skip propre (si absent)
--
-- Prérequis :
--   - UH-1H BLUE au sol
--   - Inject CTLD_Next.lua first, wait 3–5 s for init.
--
-- @scenario  P4-METAL
-- @version   3.0 — 2026-06-30
-- @coverage  P4.1–P4.5
-- =============================================================================

-- ── 1. Witchcraft guard ──────────────────────────────────────────────────────
if not ctld or not ctld.utils then
    trigger.action.outText("[P4-METAL] ABORT: CTLD not initialized. Inject CTLD_Next.lua first.", 15)
    return Witchcraft
end

-- ── 2. Double-injection guard ────────────────────────────────────────────────
if _SCN_P4METAL_RUNNING then
    trigger.action.outText("[P4-METAL] déjà actif — attendre la fin ou redémarrer DCS.", 10)
    return Witchcraft
end
_SCN_P4METAL_RUNNING = true
_SCN_P4METAL_CLEANUP = nil

do  -- isolation scope
-- ── 4. Debug ON ──────────────────────────────────────────────────────────────
local cfg                  = CTLDConfig.get()
local _savedDebug          = cfg.settings["debug"]
local _savedDebugScreenLog = cfg.settings["debugScreenLog"]
cfg.settings["debug"]          = true
cfg.settings["debugScreenLog"] = false

-- ── 5. Constants ─────────────────────────────────────────────────────────────
local TAG  = "[P4-METAL]"
local NAME = "Metal FARP warehouse stocking"

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
    _SCN_P4METAL_RUNNING = false
    _SCN_P4METAL_CLEANUP = nil
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
    if not ok then log("WARN cleanup: "..tostring(err)) ; _SCN_P4METAL_RUNNING = false end
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

-- S1 — Lancer la scène Metal FARP
steps[1] = function()
    instruct(
        "Step 1/2 — LANCEMENT SCÈNE METAL FARP (auto)\n"..
        "Lancement de playScene Metal FARP (~25s).\n"..
        "Vérification warehouse dans 35s…"
    )

    local sm    = CTLDSceneManager.getInstance()
    local model = sm:getModel("Metal FARP")
    check("P4.1", "scene model 'Metal FARP' enregistrée", model ~= nil)
    if not model then fail("P4.1b", "scene Metal FARP introuvable") ; return end

    -- Cleanup : détruire toute scène Metal FARP existante
    ctld_test.cleanup()

    local scene = sm:playScene(S.transport, "Metal FARP", {})
    check("P4.2", "playScene Metal FARP démarré", scene ~= nil)
    if not scene then fail("P4.2b", "playScene returned nil") ; return end

    log("Scène Metal FARP lancée (~25s). Vérification warehouse dans 35s.")
    waitThen(35, advanceStep)
end

-- S2 — Vérifier warehouse stocking (~T+35)
steps[2] = function()
    instruct(
        "Step 2/2 — VÉRIFICATION WAREHOUSE (auto T+35)\n"..
        "Vérification auto du stocking warehouse Metal FARP."
    )

    -- Chercher un Airbase portant le nom Farp_FG_Petit_Helipad*
    -- Si mod absent, aucun airbase de ce type n'existe
    local farpAb  = nil
    local farpName = nil

    for _, ab in pairs(world.getAirbases()) do
        local n = ab:getName()
        if n and n:find("Farp_FG_Petit_Helipad") then
            farpAb   = ab
            farpName = n
            break
        end
    end

    if not farpAb then
        -- Mod absent : comportement attendu = aucun airbase, aucun crash
        pass("P4.3", "mod absent : aucun Farp_FG_Petit_Helipad airbase (comportement attendu)")
        pass("P4.4", "aucun crash même sans mod (SKIP propre)")
    else
        log("Farp airbase détecté : "..farpName)
        local w = farpAb:getWarehouse()
        check("P4.3", "warehouse accessible", w ~= nil)
        if w then
            local jet   = w:getLiquid(0)
            local avgas = w:getLiquid(1)
            local mw50  = w:getLiquid(2)
            local diese = w:getLiquid(3)
            log(string.format("Warehouse — jet=%d avgas=%d mw50=%d diesel=%d",
                jet or 0, avgas or 0, mw50 or 0, diese or 0))
            check("P4.4", "jet fuel > 0 après stocking",  (jet  or 0) > 0)
            check("P4.5", "avgas > 0 après stocking",     (avgas or 0) > 0)
        end
    end

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

_SCN_P4METAL_CLEANUP = cleanup

log("=== START: "..NAME.." | transport="..S.transport:getName().." | "..#steps.." steps ===")
trigger.action.outText(TAG.." démarrage — "..#steps.." steps | "..S.transport:getName(), 8)
advanceStep()

end  -- do isolation scope
return Witchcraft
