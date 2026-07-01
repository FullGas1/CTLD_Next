---@diagnostic disable
-- =============================================================================
-- live_tests/scenarios/_template_interactive_auto.lua
-- CTLD Interactive Auto Scenario Template
--
-- Timer-driven scenario: single injection, progresses automatically via
-- waitFor / waitThen. No human OUI/NON feedback, no F10 menu.
-- Screen used for instructions only (instruct() calls).
--
-- Prerequisites:
--   - Inject CTLD_Next.lua first, wait 3-5 s for init.
--   - BLUE slot occupied if the scenario needs a player unit.
--   - Appropriate CTLD config for the tested features.
--
-- Sequence (3 example steps):
--   S1 [auto]  Setup / initial assertions      (waitThen 1s)
--   S2 [auto]  DCS condition detected          (waitFor poll)
--   S3 [auto]  Deferred auto-verification      (waitThen 2s)
--
-- @scenario  SCN-XXX
-- @version   1.0 — 2026-06-30
-- @coverage  F-XXX, F-YYY
-- =============================================================================

-- ── 1. Witchcraft guard ──────────────────────────────────────────────────────
if not ctld or not ctld.utils then
    trigger.action.outText("[SCN-XXX] ABORT: CTLD not initialized. Inject CTLD_Next.lua first.", 15)
    return Witchcraft
end

-- ── 2. Double-injection guard ────────────────────────────────────────────────
if _SCN_XXX_RUNNING then
    trigger.action.outText("[SCN-XXX] already running — wait for completion or restart DCS.", 10)
    return Witchcraft
end
_SCN_XXX_RUNNING = true
_SCN_XXX_CLEANUP = nil   -- exposed for external reset script

do  -- isolation scope
-- ── 3. Debug ON ──────────────────────────────────────────────────────────────
local cfg                  = CTLDConfig.get()
local _savedDebug          = cfg.settings["debug"]
local _savedDebugScreenLog = cfg.settings["debugScreenLog"]
cfg.settings["debug"]          = true
cfg.settings["debugScreenLog"] = false   -- traces via log() only, screen = instructions only

-- ── 4. Constants ─────────────────────────────────────────────────────────────
local TAG  = "[SCN-XXX]"
local NAME = "Description of the scenario"

-- ── 5. State ─────────────────────────────────────────────────────────────────
local S = {
    step        = 0,
    passed      = 0,
    failed      = 0,
    failReasons = {},
    timerHandle = nil,
    timerGen    = 0,     -- generation counter: invalidates stale timers
    transport   = nil,   -- set in Start block; remove if not needed
}

-- ── 6. Helpers ───────────────────────────────────────────────────────────────
local function log(msg) ctld.utils.log("INFO", "%s %s", TAG, msg) end

local function instruct(msg)
    log("[INSTR] " .. msg)
    trigger.action.outText(TAG .. "\n" .. msg, 360, true)
end

local function pass(id, msg) S.passed = S.passed + 1 ; log("[PASS] "..id..": "..(msg or "")) end
local function fail(id, msg) S.failed = S.failed + 1 ; table.insert(S.failReasons, id..": "..(msg or "")) ; log("[FAIL] "..id..": "..(msg or "")) end

-- ── 7. Cleanup ───────────────────────────────────────────────────────────────
local function cleanup()
    if S.timerHandle then timer.removeFunction(S.timerHandle) ; S.timerHandle = nil end
    cfg.settings["debug"]          = _savedDebug
    cfg.settings["debugScreenLog"] = _savedDebugScreenLog
    _SCN_XXX_RUNNING = false
    _SCN_XXX_CLEANUP = nil
    log("cleanup done")
end

-- ── 8. Timer helpers ─────────────────────────────────────────────────────────
local function cancelTimer()
    S.timerGen = S.timerGen + 1
    if S.timerHandle then
        pcall(timer.removeFunction, S.timerHandle)
        S.timerHandle = nil
    end
end

local function waitFor(checkFn, intervalS, timeoutS, onSuccess, onFail)
    cancelTimer()
    local myGen = S.timerGen
    local elapsed = 0
    local function poll()
        if S.timerGen ~= myGen then return nil end
        elapsed = elapsed + intervalS
        if checkFn() then
            S.timerHandle = nil ; onSuccess()
        elseif elapsed >= timeoutS then
            S.timerHandle = nil ; log("[TIMEOUT] "..timeoutS.."s") ; onFail()
        else
            return timer.getTime() + intervalS
        end
    end
    S.timerHandle = timer.scheduleFunction(poll, nil, timer.getTime() + intervalS)
end

-- Execute callback once after delayS seconds (one-shot timer, honours timerGen).
local function waitThen(delayS, callback)
    cancelTimer()
    local myGen = S.timerGen
    S.timerHandle = timer.scheduleFunction(function()
        if S.timerGen ~= myGen then return nil end
        S.timerHandle = nil
        callback()
    end, nil, timer.getTime() + delayS)
end

-- ── 9. Finalization ──────────────────────────────────────────────────────────
local function finalizeScenario()
    cancelTimer()
    local total = S.passed + S.failed
    local summary
    if S.failed == 0 then
        summary = TAG.." [OK] "..NAME.." — "..S.passed.."/"..total.." PASS"
    else
        summary = TAG.." [KO] "..NAME.." — "..S.failed.." FAIL: "..
            table.concat(S.failReasons, " | ")
    end
    log(summary)
    trigger.action.outText(summary, 360, true)
    local ok, err = pcall(cleanup)
    if not ok then log("WARN cleanup: "..tostring(err)) ; _SCN_XXX_RUNNING = false end
end

-- ── 10. Step runner ──────────────────────────────────────────────────────────
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
        trigger.action.outText(TAG.." WARNING S"..S.step.." error: "..tostring(err), 15, false)
        advanceStep()
    end
end

-- ── 11. Steps ────────────────────────────────────────────────────────────────

-- S1 — Setup / initial assertions
steps[1] = function()
    instruct(
        "Step 1/3 — SETUP (F-XXX)\n"..
        "Running automatic assertions…"
    )
    waitThen(1, function()
        -- Replace with actual setup and assertions.
        local ok = true
        if ok then
            pass("F-XXX", "setup OK")
        else
            fail("F-XXX", "setup KO")
        end
        advanceStep()
    end)
end

-- S2 — DCS condition auto-detected [waitFor]
steps[2] = function()
    instruct(
        "Step 2/3 — AUTO DETECTION (S2)\n"..
        "Perform the DCS action (e.g. take off, approach zone...).\n"..
        "Scenario advances automatically on detection."
    )
    waitFor(
        function()
            -- Replace with the real DCS condition (e.g.: S.transport:inAir())
            return S.transport and S.transport:isExist() and S.transport:inAir()
        end,
        3, 300,
        function() pass("S2", "condition detected") ; advanceStep() end,
        function() fail("S2", "timeout condition")  ; advanceStep() end
    )
end

-- S3 — Deferred auto-verification [waitThen]
steps[3] = function()
    instruct(
        "Step 3/3 — DEFERRED AUTO-CHECK (F-YYY)\n"..
        "Automatic verification in progress (2s)…"
    )
    waitThen(2, function()
        -- Replace with actual automatic assertions.
        local ok = true
        if ok then
            pass("F-YYY", "deferred check OK")
        else
            fail("F-YYY", "deferred check KO")
        end
        advanceStep()
    end)
end

-- ── 12. Start ────────────────────────────────────────────────────────────────
-- Player transport lookup (remove this block if the scenario does not need it).
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
    trigger.action.outText(TAG.." ABORT: no BLUE player. Occupy a slot before injection.", 20)
    cleanup()
    return Witchcraft
end

_SCN_XXX_CLEANUP = cleanup   -- exposed for external reset

log("=== START: "..NAME.." | transport="..S.transport:getName().." | "..#steps.." steps ===")
trigger.action.outText(TAG.." starting — "..#steps.." steps | "..S.transport:getName(), 8)
advanceStep()

end  -- do isolation scope
return Witchcraft
