---@diagnostic disable
-- =============================================================================
-- scenario_weight_aggregation.lua
-- Validates ctld.utils.updateTransportWeight aggregates all cargo sources
--
-- Flow (single step, 4 sequential phases):
--   Phase 1 — Inject troops (320 kg)                  → weight == 320
--   Phase 2 — Inject Hummer crate (2500 kg) in CTLD   → weight == 2820
--   Phase 3 — Disembark troops                         → weight == 2500
--   Phase 4 — Unload crate                             → weight == 0
--
-- Uses direct state injection (no TRZ zone / menu flow needed).
-- Tests the aggregator, not individual load/unload paths.
--
-- Prérequis: slot BLUE UH-1H occupé.
-- =============================================================================


-- ── Witchcraft guard ────────────────────────────────────────────────
if not ctld or not ctld.utils then
    trigger.action.outText("[WEIGHT] ABORT: CTLD not initialized. Inject CTLD_Next.lua first.", 15)
    return Witchcraft
end
local cfg = CTLDConfig.get()
local _saved_debug = cfg.settings["debug"]
local _savedDebugScreenLog = cfg.settings["debugScreenLog"]
cfg.settings["debug"] = true
cfg.settings["debugScreenLog"] = true

local TAG    = "[WGT]"
local START  = os.date("%Y-%m-%d %H:%M:%S")
local STEP_N = "_WGT_STEP"

local function log(msg)    ctld.utils.log("INFO", TAG .. " " .. msg) end
local function report(msg) trigger.action.outText(TAG .. " " .. msg, 40); log(msg) end
local function fail(msg)
    local trace = debug.traceback(msg, 2)
    trigger.action.outText(TAG .. " !! FAIL: " .. msg, 60)
    log("FAIL: " .. trace)
    error(msg)
end
local function check(id, desc, cond, details)
    if cond then report("[PASS] " .. id .. " — " .. desc)
    else fail(id .. " — " .. desc .. (details and (" | " .. details) or "")) end
end

-- ── Player ────────────────────────────────────────────────────────────────────
local playerUnit = (coalition.getPlayers(coalition.side.BLUE) or {})[1]
if not playerUnit or not playerUnit:isExist() then
    cfg.settings["debug"] = _saved_debug
cfg.settings["debugScreenLog"] = _savedDebugScreenLog
    return "ABORT: no BLUE player"
end
local playerName = playerUnit:getName()
local pPos       = playerUnit:getPoint()

-- ── Constants ─────────────────────────────────────────────────────────────────
local CRATE_NAME  = "SCN_WGT_HUMMER_CRATE"
local TROOP_W     = 320   -- 4 soldiers × 80 kg
local CRATE_W     = 2500  -- Hummer

-- ── Helper: capture the weight value written by updateTransportWeight ──────────
local function captureWeight(unitName)
    local captured = nil
    local _orig = trigger.action.setUnitInternalCargo
    trigger.action.setUnitInternalCargo = function(n, v)
        if n == unitName then captured = v end
        return _orig(n, v)
    end
    ctld.utils.updateTransportWeight(unitName)
    trigger.action.setUnitInternalCargo = _orig
    return captured or 0
end

-- ── State machine ─────────────────────────────────────────────────────────────
_G[STEP_N] = _G[STEP_N] or 1
local step = _G[STEP_N]
report("==== START " .. START .. " | step=" .. step .. " ====")

if step == 1 then
    pcall(function()
        ctld.utils.closeLog()
        local f = io.open((cfg.settings["ctldLogPath"] or "") .. "CTLD.log", "w")
        if f then f:write("[" .. START .. "] === LOG RESET ===\n"); f:close() end
        ctld.utils.reopenLogAppend()
    end)
end

local _step_start = os.clock()
local _result = "INCOMPLETE"

local tm = CTLDTroopManager.getInstance()
local cm = CTLDCrateManager.getInstance()

-- Cleanup stale state from previous runs
tm._inTransit[playerName]   = nil
cm.crates[CRATE_NAME]       = nil

local _ok, _err = pcall(function()

-- ══════════════════════════════════════════════════════════════════════════════
-- STEP 1 — All 4 phases (single injection, sequential)
-- ══════════════════════════════════════════════════════════════════════════════
if step == 1 then

    -- ── Phase 1 : troops only ────────────────────────────────────────────────
    -- Inject troops directly into TroopManager state (weight only — no TRZ needed)
    tm._inTransit[playerName] = { weight = TROOP_W }

    local w1 = captureWeight(playerName)
    report(string.format("Phase 1 (troops only): %d kg  [expected %d]", w1, TROOP_W))
    check("F-WGT.1", "troops weight = " .. TROOP_W .. " kg", w1 == TROOP_W,
        "got=" .. w1)

    -- ── Phase 2 : troops + CTLD crate ────────────────────────────────────────
    -- Inject a CTLDCrate in LOADED state (CTLD-managed: dcsStatic=nil)
    local crate = CTLDCrate:new({
        crateName   = CRATE_NAME,
        descriptor  = { weight = CRATE_W, desc = "Hummer" },
        spawnMethod = CTLDCrate.SPAWN_METHOD.MENU_CTLD,
        position    = pPos,
        coalition   = coalition.side.BLUE,
    })
    -- crate:load() sets state=LOADED, loadedBy=transport, fromParachute=false
    crate:load(playerUnit)
    -- dcsStatic stays nil → isLoadedByCTLD() returns true ✅
    cm.crates[CRATE_NAME] = crate

    local w2 = captureWeight(playerName)
    local expected2 = TROOP_W + CRATE_W
    report(string.format("Phase 2 (troops+crate): %d kg  [expected %d]", w2, expected2))
    check("F-WGT.2", "troops+crate weight = " .. expected2 .. " kg", w2 == expected2,
        "got=" .. w2)

    -- ── Phase 3 : crate only (troops disembarked) ─────────────────────────────
    tm._inTransit[playerName] = nil

    local w3 = captureWeight(playerName)
    report(string.format("Phase 3 (crate only):   %d kg  [expected %d]", w3, CRATE_W))
    check("F-WGT.3", "crate only weight = " .. CRATE_W .. " kg", w3 == CRATE_W,
        "got=" .. w3)

    -- ── Phase 4 : empty (crate unloaded) ─────────────────────────────────────
    -- Transition crate to LANDED (simulates unload, clears LOADED state)
    crate:unload(pPos)
    -- isLoadedByCTLD() is now false → getLoadedCrateWeight returns 0

    local w4 = captureWeight(playerName)
    report(string.format("Phase 4 (empty):          %d kg  [expected 0]", w4))
    check("F-WGT.4", "empty transport weight = 0 kg", w4 == 0,
        "got=" .. w4)

    -- ── Summary ───────────────────────────────────────────────────────────────
    report(string.format(
        "═══ WEIGHT AGGREGATION 4/4 PASS | 320→2820→2500→0 kg ═══"))

    _G[STEP_N] = 1  -- single-step scenario, reset for re-run
    _result = "ALL SUCCESS"

else
    fail("step=" .. step .. " has no matching branch")
end

end)  -- end pcall

-- ── Cleanup guaranteed ────────────────────────────────────────────────────────
tm._inTransit[playerName] = nil
cm.crates[CRATE_NAME]     = nil
-- Reset transport weight to 0 after test (best effort)
pcall(trigger.action.setUnitInternalCargo, playerName, 0)

cfg.settings["debug"] = _saved_debug
local _ms = math.floor((os.clock() - _step_start) * 1000)
if not _ok then
    trigger.action.outText(TAG .. " ❌ step=" .. step .. " FAIL", 60, true)
    return TAG .. " step=" .. step .. " FAIL: " .. tostring(_err)
end
if _result == "ALL SUCCESS" then
    trigger.action.outText(TAG .. " ✅ ALL SUCCESS (" .. _ms .. "ms)", 30, true)
    return TAG .. " " .. _result .. " (" .. _ms .. "ms)"
end
return TAG .. " " .. _result:gsub("SUCCESS", "SUCCESS (" .. _ms .. "ms)")
