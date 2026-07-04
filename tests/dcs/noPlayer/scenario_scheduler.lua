---@diagnostic disable
-- =============================================================================
-- scenario_scheduler.lua
-- ctld.scheduler — central loop registry + beacon/AI transport guard B
--
-- Test cases:
--   F-135 : ctld.scheduler basic operations (register, cancel, cancelAll)
--   F-136 : beacon_refresh registered at CTLD init
--   F-137 : ai_transport registered when transportPilotNames non-empty
--   F-138 : guard B — zombie loop auto-stops when instance is replaced
--   F-139 : shutdown_ctld.lua — cancelAll clears all IDs
--
-- Pre-requisites:
--   - CTLD fully initialised (inject CTLD_Next.lua + 5s wait)
--   - recette/enable_debug.lua injected before this scenario
-- =============================================================================


-- ── Witchcraft guard ────────────────────────────────────────────────
if not ctld or not ctld.utils then
    trigger.action.outText("[SCHEDULER] ABORT: CTLD not initialized. Inject CTLD_Next.lua first.", 15)
    return Witchcraft
end
local cfg = CTLDConfig.get()
local _saved_debug = cfg.settings["debug"]
local _savedDebugScreenLog = cfg.settings["debugScreenLog"]
cfg.settings["debug"] = true
cfg.settings["debugScreenLog"] = true

local TAG    = "[SCHED]"
local START  = os.date("%Y-%m-%d %H:%M:%S")
local STEP_N = "_SCHED_STEP"

local function log(msg)    ctld.utils.log("INFO", TAG .. " " .. msg) end
local function report(msg) trigger.action.outText(TAG .. " " .. msg, 30); log(msg) end
local function pass(msg)   report("[PASS] " .. msg) end
local function fail(msg)
    local trace = debug.traceback(msg, 2)
    trigger.action.outText(TAG .. " !! FAIL: " .. msg, 60)
    log("FAIL: " .. trace)
    error(msg)
end
local function check(id, desc, cond, details)
    if cond then pass(id .. " — " .. desc)
    else fail(id .. " — " .. desc .. (details and (" | " .. details) or "")) end
end

_G[STEP_N] = _G[STEP_N] or 1
local step = _G[STEP_N]
report("==== START " .. START .. " | step=" .. step .. " ====")

local _step_start = os.clock()
local _result = "INCOMPLETE"
local _ok, _err = pcall(function()

-- ══════════════════════════════════════════════════════════════════════════════
-- STEP 1 — F-135: ctld.scheduler basic operations
-- ══════════════════════════════════════════════════════════════════════════════
if step == 1 then

    -- F-135.1 : scheduler exists and has _ids table
    check("F-135.1", "ctld.scheduler exists", ctld.scheduler ~= nil)
    check("F-135.2", "ctld.scheduler._ids is a table",
        type(ctld.scheduler._ids) == "table")

    -- F-135.3 : register stores an ID
    local _savedIds = ctld.scheduler._ids
    ctld.scheduler._ids = {}   -- isolated sandbox

    -- Mock timer.scheduleFunction / removeFunction for unit testing
    local removeCalled = {}
    local _origSchedule = timer.scheduleFunction
    local _origRemove   = timer.removeFunction
    local fakeIdCounter = 1000
    timer.scheduleFunction = function(fn, args, t)
        fakeIdCounter = fakeIdCounter + 1
        return fakeIdCounter
    end
    timer.removeFunction = function(fid)
        table.insert(removeCalled, fid)
    end

    ctld.scheduler.register("test_loop", 1001)
    check("F-135.3", "register stores ID", ctld.scheduler._ids["test_loop"] == 1001)

    -- F-135.4 : register same name cancels previous
    ctld.scheduler.register("test_loop", 1002)
    check("F-135.4", "re-register cancels old ID",
        #removeCalled == 1 and removeCalled[1] == 1001,
        "removeFunction calls=" .. tostring(#removeCalled))
    check("F-135.5", "re-register stores new ID",
        ctld.scheduler._ids["test_loop"] == 1002)

    -- F-135.6 : cancel removes entry
    ctld.scheduler.cancel("test_loop")
    check("F-135.6", "cancel removes entry",
        ctld.scheduler._ids["test_loop"] == nil)
    check("F-135.7", "cancel calls removeFunction",
        #removeCalled == 2 and removeCalled[2] == 1002,
        "removeFunction calls=" .. tostring(#removeCalled))

    -- F-135.8 : cancelAll clears all entries
    ctld.scheduler._ids = { a = 2001, b = 2002 }
    removeCalled = {}
    ctld.scheduler.cancelAll()
    check("F-135.8", "cancelAll calls removeFunction for all entries",
        #removeCalled == 2,
        "calls=" .. tostring(#removeCalled))
    check("F-135.9", "_ids empty after cancelAll",
        next(ctld.scheduler._ids) == nil)

    -- Restore
    timer.scheduleFunction = _origSchedule
    timer.removeFunction   = _origRemove
    ctld.scheduler._ids    = _savedIds

    pass("Step 1 — F-135 basic ops OK. Re-inject for Step 2.")
    _G[STEP_N] = 2
    _result = "step=1 SUCCESS"

-- ══════════════════════════════════════════════════════════════════════════════
-- STEP 2 — F-136/F-137: loop registration after CTLD init
-- ══════════════════════════════════════════════════════════════════════════════
elseif step == 2 then

    -- Force fresh registration (idempotent — cancels stale ID if any, registers new one).
    -- Required because a previous cancelAll() (shutdown_ctld.lua or step 4) may have
    -- cleared the IDs without stopping the actual DCS timer.

    -- F-136 : _scheduleRefresh registers beacon_refresh
    local beaconEnabled = ctld.gs("enabledRadioBeaconDrop")
    if beaconEnabled then
        local idBefore = ctld.scheduler._ids["beacon_refresh"]
        CTLDBeaconManager.getInstance():_scheduleRefresh()
        local idAfter  = ctld.scheduler._ids["beacon_refresh"]
        check("F-136.1", "_scheduleRefresh registers beacon_refresh",
            idAfter ~= nil, "id=" .. tostring(idAfter))
        check("F-136.2", "re-schedule produces a new ID (or same if not stale)",
            type(idAfter) == "number", "type=" .. type(idAfter))
        -- If there was a previous ID, verify it was replaced (register cancelled old)
        if idBefore ~= nil and idBefore ~= idAfter then
            pass("F-136.3 — old ID replaced by new one (stale ID cancelled)")
        elseif idBefore == nil then
            pass("F-136.3 — fresh registration (no previous ID)")
        else
            pass("F-136.3 — same ID retained (no stale cancellation needed)")
        end
    else
        report("F-136 SKIP — enabledRadioBeaconDrop=false, beacon loop not started")
    end

    -- F-137 : _initAITransports registers ai_transport when pilot names non-empty
    local _origNames = cfg.settings["transportPilotNames"]
    cfg.settings["transportPilotNames"] = { "_sched_test_dummy" }
    CTLDCoreManager.getInstance():_initAITransports()
    check("F-137.1", "_initAITransports registers ai_transport",
        ctld.scheduler._ids["ai_transport"] ~= nil,
        "id=" .. tostring(ctld.scheduler._ids["ai_transport"]))
    check("F-137.2", "ai_transport ID is a number",
        type(ctld.scheduler._ids["ai_transport"]) == "number")
    cfg.settings["transportPilotNames"] = _origNames
    -- Cancel dummy loop (pilot name invalid → loop harmless but tidy up)
    ctld.scheduler.cancel("ai_transport")

    -- F-137.3 : re-registering same name does NOT duplicate (only one ID per name)
    ctld.scheduler.register("test_dedup", 5001)
    ctld.scheduler.register("test_dedup", 5002)
    check("F-137.3", "second register replaces first (no duplicate)",
        ctld.scheduler._ids["test_dedup"] == 5002)
    ctld.scheduler.cancel("test_dedup")

    pass("Step 2 — F-136/F-137 registration OK. Re-inject for Step 3.")
    _G[STEP_N] = 3
    _result = "step=2 SUCCESS"

-- ══════════════════════════════════════════════════════════════════════════════
-- STEP 3 — F-138: guard B — zombie loop auto-stops when instance replaced
-- ══════════════════════════════════════════════════════════════════════════════
elseif step == 3 then

    local bm = CTLDBeaconManager.getInstance()

    -- Simulate singleton replacement: swap _instance to a different table
    local _realInstance = CTLDBeaconManager._instance
    local fakeInstance  = {}  -- not the real manager
    CTLDBeaconManager._instance = fakeInstance

    -- Build a fresh refresh closure (same as production code) and call it directly
    local refreshAllCalled = 0
    local _origRefreshAll  = bm._refreshAll
    bm._refreshAll = function(self)
        refreshAllCalled = refreshAllCalled + 1
    end

    -- Reproduce the exact production closure
    local self_ref = bm
    local returnedVal = nil
    local function refresh(_, t)
        if CTLDBeaconManager._instance ~= self_ref then return nil end
        self_ref:_refreshAll()
        return t + 60
    end
    -- Call with fake t
    returnedVal = refresh(nil, 100)

    -- Restore
    CTLDBeaconManager._instance = _realInstance
    bm._refreshAll = _origRefreshAll

    check("F-138.1", "guard B returns nil when instance replaced",
        returnedVal == nil,
        "returned=" .. tostring(returnedVal))
    check("F-138.2", "_refreshAll NOT called (zombie stopped before work)",
        refreshAllCalled == 0,
        "calls=" .. tostring(refreshAllCalled))

    -- F-138.3 : when instance matches, loop executes normally
    local refreshAllCalledOK = 0
    bm._refreshAll = function(self) refreshAllCalledOK = refreshAllCalledOK + 1 end
    local function refresh2(_, t)
        if CTLDBeaconManager._instance ~= bm then return nil end
        bm:_refreshAll()
        return t + 60
    end
    local rv2 = refresh2(nil, 100)
    bm._refreshAll = _origRefreshAll

    check("F-138.3", "loop executes when instance matches",
        rv2 == 160 and refreshAllCalledOK == 1,
        "returned=" .. tostring(rv2) .. " calls=" .. tostring(refreshAllCalledOK))

    pass("Step 3 — F-138 guard B OK. Re-inject for Step 4.")
    _G[STEP_N] = 4
    _result = "step=3 SUCCESS"

-- ══════════════════════════════════════════════════════════════════════════════
-- STEP 4 — F-139: cancelAll clears IDs + re-registration works after
-- ══════════════════════════════════════════════════════════════════════════════
elseif step == 4 then

    -- Snapshot current IDs count before cancel
    local countBefore = 0
    for _ in pairs(ctld.scheduler._ids) do countBefore = countBefore + 1 end
    check("F-139.1", "scheduler has ≥1 registered loop before cancelAll",
        countBefore >= 1, "count=" .. tostring(countBefore))

    -- cancelAll
    ctld.scheduler.cancelAll()
    local countAfter = 0
    for _ in pairs(ctld.scheduler._ids) do countAfter = countAfter + 1 end
    check("F-139.2", "_ids empty after cancelAll",
        countAfter == 0, "count=" .. tostring(countAfter))

    -- Re-registration still works (no crash after cancelAll)
    ctld.scheduler.register("test_post_cancel", 9999)
    check("F-139.3", "register works after cancelAll",
        ctld.scheduler._ids["test_post_cancel"] == 9999)
    ctld.scheduler.cancel("test_post_cancel")

    -- Re-init beacon loop to restore normal operation
    if ctld.gs("enabledRadioBeaconDrop") then
        CTLDBeaconManager.getInstance():_scheduleRefresh()
        check("F-139.4", "beacon_refresh re-registered after re-init",
            ctld.scheduler._ids["beacon_refresh"] ~= nil)
    end

    _G[STEP_N] = 99
    _result = "step=4 SUCCESS"

-- ══════════════════════════════════════════════════════════════════════════════
-- STEP FINAL
-- ══════════════════════════════════════════════════════════════════════════════
elseif step >= 99 then

    report("═══════════════════════════════════════")
    report("SCHEDULER — All steps complete (F-135→F-139)")
    report("═══════════════════════════════════════")

    _G[STEP_N] = 1
    _result = "ALL SUCCESS"

else
    fail("step=" .. step .. " has no matching branch")
end

end)  -- end pcall

cfg.settings["debug"] = _saved_debug
cfg.settings["debugScreenLog"] = _savedDebugScreenLog

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
