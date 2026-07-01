---@diagnostic disable
-- =============================================================================
-- live_tests/scenarios/_template_auto.lua
-- CTLD Auto Scenario Template — v1.0 [2026-06-30]
--
-- Usage:
--   1. Inject CTLD_Next.lua first, wait 3-5 s for init.
--   2. Inject this scenario (Witchcraft).
--   3. Result appears on DCS screen + Witchcraft terminal.
--   4. Re-inject to restart.
--
-- Pattern:
--   Single pcall — all assertions run synchronously.
--   No human interaction, no timers, no F10 menu.
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
    trigger.action.outText("[SCN-XXX] already running — wait or restart DCS.", 10)
    return Witchcraft
end
_SCN_XXX_RUNNING = true

do  -- isolation scope
-- ── 3. Debug ON ──────────────────────────────────────────────────────────────
local cfg                  = CTLDConfig.get()
local _savedDebug          = cfg.settings["debug"]
local _savedDebugScreenLog = cfg.settings["debugScreenLog"]
cfg.settings["debug"]          = true
cfg.settings["debugScreenLog"] = true

-- ── 4. Constants ─────────────────────────────────────────────────────────────
local TAG = "[SCN-XXX]"
local _t0 = os.clock()

-- ── 5. Helpers ───────────────────────────────────────────────────────────────
local function log(msg) ctld.utils.log("INFO", "%s %s", TAG, msg) end

local passed, failed, failReasons = 0, 0, {}

local function pass(id, msg)
    passed = passed + 1
    log("[PASS] " .. id .. ": " .. (msg or ""))
end

local function fail(id, msg)
    failed = failed + 1
    table.insert(failReasons, id .. ": " .. (msg or ""))
    log("[FAIL] " .. id .. ": " .. (msg or ""))
    error(id)  -- stops pcall, jumps to result block
end

local function check(id, desc, cond, detail)
    if cond then pass(id, desc)
    else fail(id, desc .. (detail and (" | " .. detail) or "")) end
end

-- ── 6. Cleanup ───────────────────────────────────────────────────────────────
local function cleanup()
    -- add scenario-specific state resets here
    cfg.settings["debug"]          = _savedDebug
    cfg.settings["debugScreenLog"] = _savedDebugScreenLog
end

-- ── 7. Test logic (pcall) ────────────────────────────────────────────────────
local _ok, _err = pcall(function()

    -- check("F-XXX.1", "description", condition, "detail_on_fail")
    -- check("F-XXX.2", "description", condition)

end)

-- ── 8. Result ────────────────────────────────────────────────────────────────
local _ms = math.floor((os.clock() - _t0) * 1000)
pcall(cleanup)
_SCN_XXX_RUNNING = false

if not _ok then
    trigger.action.outText(TAG .. " ❌ FAIL: " .. tostring(_err), 60, true)
    return TAG .. " FAIL: " .. tostring(_err)
end

local total   = passed + failed
local summary = TAG .. " ✅ " .. passed .. "/" .. total .. " PASS (" .. _ms .. "ms)"
trigger.action.outText(summary, 30, true)
return summary

end  -- do isolation scope
return Witchcraft
