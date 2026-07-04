---@diagnostic disable
-- =============================================================================
-- live_tests/scenarios/_template_scenario.lua
-- CTLD Scenario Template — v2.0 [2026-06-30]
--
-- Usage:
--   1. Inject CTLD_Next.lua first, wait 3-5 s for init.
--   2. Inject this scenario (Claude via Witchcraft).
--   3. For human steps: use the "CTLD Recette" F10 menu to respond.
--   4. Re-inject to restart (cleanup is automatic at end of run).
--
-- Step types:
--   Auto        — advanceStep() immediately
--   Delayed     — waitThen(seconds, fn)
--   Polled      — waitFor(checkFn, interval, timeout, onSuccess, onFail)
--   Human/F10   — setHumanStep(title, options)  [max 3 options]
--
-- @scenario  SCN-XXX
-- @version   1.0 — YYYY-MM-DD
-- @coverage  F-XXX, F-YYY
-- @result    expected: [OK]
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

do  -- isolation scope (prevents global pollution)
-- ── 3. Debug ON (save previous state) ───────────────────────────────────────
local cfg                  = CTLDConfig.get()
local _savedDebug          = cfg.settings["debug"]
local _savedDebugScreenLog = cfg.settings["debugScreenLog"]
cfg.settings["debug"]          = true
cfg.settings["debugScreenLog"] = false   -- traces via log() only, screen = instructions only

-- ── 4. Constants ─────────────────────────────────────────────────────────────
local TAG              = "[SCN-XXX]"
local NAME             = "Description of this scenario"
local HUMAN_TIMEOUT_S  = 300   -- 5 min before auto-SKIP on human steps
local MENU_ROOT        = "CTLD Recette"

-- ── 5. State ─────────────────────────────────────────────────────────────────
local S = {
    step        = 0,
    passed      = 0,
    failed      = 0,
    failReasons = {},
    spawned     = {},   -- { type="group"|"mark"|"static", id=... }
    menuHandle  = nil,
    timerHandle = nil,
}

-- ── 6. Helpers ────────────────────────────────────────────────────────────────
-- log: trace (short display, goes to CTLD.log + screen)
local function log(msg)
    ctld.utils.log("INFO", "%s %s", TAG, msg)
    trigger.action.outText(TAG .. " " .. msg, 12)
end

-- instruct: user instruction (long display, prominent)
local function instruct(msg)
    ctld.utils.log("INFO", "%s [INSTR] %s", TAG, msg)
    trigger.action.outText(TAG .. "\n" .. msg, 30)
end

local function pass(id, msg)
    S.passed = S.passed + 1
    log("[PASS] " .. id .. ": " .. (msg or ""))
end

local function fail(id, msg)
    S.failed = S.failed + 1
    table.insert(S.failReasons, id .. ": " .. (msg or ""))
    log("[FAIL] " .. id .. ": " .. (msg or ""))
end

local function trackGroup(name)  table.insert(S.spawned, { type = "group",  id = name }) end
local function trackMark(id)     table.insert(S.spawned, { type = "mark",   id = id   }) end
local function trackStatic(name) table.insert(S.spawned, { type = "static", id = name }) end

-- ── 7. Cleanup + Debug OFF ────────────────────────────────────────────────────
local function cleanup()
    -- cancel pending timer
    if S.timerHandle then
        timer.removeFunction(S.timerHandle)
        S.timerHandle = nil
    end
    -- remove F10 menu
    if S.menuHandle then
        missionCommands.removeItem(S.menuHandle)
        S.menuHandle = nil
    end
    -- destroy tracked spawns
    for _, item in ipairs(S.spawned) do
        if item.type == "group" then
            local g = Group.getByName(item.id)
            if g then g:destroy() end
        elseif item.type == "mark" then
            trigger.action.removeMark(item.id)
        elseif item.type == "static" then
            local u = StaticObject.getByName(item.id)
            if u then u:destroy() end
        end
    end
    S.spawned = {}
    -- ── scenario-specific CTLD state reset (add here) ──
    -- e.g.: CTLDCrateManager._instance = nil
    -- e.g.: ctld._crateFlightMap = {}
    -- ── Debug OFF (restore previous state) ─────────────
    cfg.settings["debug"]          = _savedDebug
    cfg.settings["debugScreenLog"] = _savedDebugScreenLog
    -- release running guard
    _SCN_XXX_RUNNING = false
    log("Cleanup done — re-injection ready.")
end

-- ── 8. Timer helpers ──────────────────────────────────────────────────────────
local function cancelTimer()
    if S.timerHandle then
        timer.removeFunction(S.timerHandle)
        S.timerHandle = nil
    end
end

-- waitThen: advance after a fixed delay
local function waitThen(seconds, fn)
    cancelTimer()
    S.timerHandle = fn
    timer.scheduleFunction(fn, nil, timer.getTime() + seconds)
end

-- waitFor: poll until condition or timeout
local function waitFor(checkFn, intervalS, timeoutS, onSuccess, onFail)
    local elapsed = { v = 0 }
    local function poll()
        elapsed.v = elapsed.v + intervalS
        if checkFn() then
            S.timerHandle = nil
            onSuccess()
        elseif elapsed.v >= timeoutS then
            S.timerHandle = nil
            log("[TIMEOUT] condition not met after " .. timeoutS .. "s")
            onFail()
        else
            -- reschedule (timer loop pattern)
            return timer.getTime() + intervalS
        end
    end
    cancelTimer()
    S.timerHandle = poll
    timer.scheduleFunction(poll, nil, timer.getTime() + intervalS)
end

-- ── 9. F10 menu (human steps, max 3 options) ─────────────────────────────────
local advanceStep  -- forward declaration

local function setHumanStep(title, options)
    -- rebuild menu from scratch
    if S.menuHandle then missionCommands.removeItem(S.menuHandle) end
    S.menuHandle = missionCommands.addSubMenu(MENU_ROOT, nil)
    -- info item (re-displays the instruction on click)
    missionCommands.addCommand(
        "Step " .. S.step .. ": " .. title,
        S.menuHandle,
        function() trigger.action.outText(TAG .. " " .. title, 20) end
    )
    -- answer buttons
    for _, opt in ipairs(options) do
        missionCommands.addCommand(opt.label, S.menuHandle, function()
            cancelTimer()
            opt.fn()
        end)
    end
    -- 5 min auto-SKIP timeout
    local function onTimeout()
        S.timerHandle = nil
        log("[TIMEOUT] Step " .. S.step .. " auto-SKIP after " .. HUMAN_TIMEOUT_S .. "s")
        advanceStep()
    end
    cancelTimer()
    S.timerHandle = onTimeout
    timer.scheduleFunction(onTimeout, nil, timer.getTime() + HUMAN_TIMEOUT_S)
end

-- ── 10. Step runner ───────────────────────────────────────────────────────────
local steps = {}

advanceStep = function()
    S.step = S.step + 1
    if not steps[S.step] then
        -- end of scenario
        cancelTimer()
        if S.menuHandle then
            missionCommands.removeItem(S.menuHandle)
            S.menuHandle = nil
        end
        local total = S.passed + S.failed
        local summary
        if S.failed == 0 then
            summary = TAG .. " ✅ [OK] " .. NAME .. " — " .. S.passed .. "/" .. total .. " PASS"
        else
            summary = TAG .. " ❌ [KO] " .. NAME .. " — " .. S.failed .. " FAIL: " ..
                table.concat(S.failReasons, " | ")
        end
        ctld.utils.log("INFO", "%s", summary)
        trigger.action.outText(summary, 30, true)  -- clearview: purge intermediate traces
        local ok, err = pcall(cleanup)
        if not ok then
            ctld.utils.log("WARN", "%s cleanup error: %s", TAG, tostring(err))
            _SCN_XXX_RUNNING = false
        end
        return
    end
    local ok, err = pcall(steps[S.step])
    if not ok then
        fail("S" .. S.step, "pcall: " .. tostring(err))
        advanceStep()
    end
end

-- ── 11. Steps ─────────────────────────────────────────────────────────────────
-- Define STEP_COUNT after all steps[] are declared (see bottom of section).

-- Example AUTO step
steps[1] = function()
    log("Step 1/" .. "N" .. ": [description of auto step]")
    -- ... CTLD logic / assertions ...
    pass("S1", "condition met")
    advanceStep()  -- immediate advance
end

-- Example DELAYED step (wait 5s then advance)
steps[2] = function()
    log("Step 2/N: spawn X — waiting 5s for DCS to settle...")
    -- ... spawn something ...
    waitThen(5, function()
        -- check condition after delay
        pass("S2-auto", "condition after delay")
        advanceStep()
    end)
    -- no advanceStep() here — waitThen handles it
end

-- Example POLLED step (poll every 2s for up to 60s)
steps[3] = function()
    log("Step 3/N: waiting for AI to reach dropzone...")
    waitFor(
        function()  -- check function
            local g = Group.getByName("ai-transport")
            return g and g:getSize() > 0  -- condition
        end,
        2,   -- check every 2s
        60,  -- timeout after 60s
        function()  -- onSuccess
            pass("S3", "AI reached dropzone")
            advanceStep()
        end,
        function()  -- onFail (timeout)
            fail("S3", "AI did not reach dropzone within 60s")
            advanceStep()
        end
    )
end

-- Example HUMAN step (F10 menu, max 3 options)
steps[4] = function()
    instruct("Step 4/N: Fly helicopter to Zone Z1.\nDoes the F10 menu show 'Request Equipment' ?")
    setHumanStep("F10 menu shows 'Request Equipment' ?", {
        { label = "YES — menu visible and correct",   fn = function() pass("S4", "F10 menu OK") ; advanceStep() end },
        { label = "NO  — menu absent or incorrect",   fn = function() fail("S4", "F10 menu KO") ; advanceStep() end },
        { label = "SKIP — cannot observe",            fn = function() log("[SKIP] S4")           ; advanceStep() end },
    })
    -- no advanceStep() here — waits for F10 menu click or timeout
end

local STEP_COUNT = #steps  -- defined AFTER all steps to get accurate count

-- ── 12. Start ─────────────────────────────────────────────────────────────────
log("=== START: " .. NAME .. " (" .. STEP_COUNT .. " steps) ===")
advanceStep()

end  -- do isolation scope
return Witchcraft
