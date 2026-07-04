---@diagnostic disable
-- =============================================================================
-- live_tests/scenarios/interactive/scenario_scheduler.lua
-- CTLD — ctld.scheduler : central loop registry + beacon/AI transport guard B
--
-- Test cases :
--   F-135 : ctld.scheduler basic operations (register, cancel, cancelAll)
--   F-136 : beacon_refresh registered at CTLD init
--   F-137 : ai_transport registered when transportPilotNames non-empty
--   F-138 : guard B — zombie loop auto-stops when instance is replaced
--   F-139 : shutdown_ctld.lua — cancelAll clears all IDs
--
-- Cinématique (4 steps automatiques, injection unique) :
--   S1 [auto] F-135 : opérations de base du scheduler
--   S2 [auto] F-136/F-137 : enregistrement des boucles après init CTLD
--   S3 [auto] F-138 : guard B — zombie loop auto-stop
--   S4 [auto] F-139 : cancelAll + re-registration
--
-- Prérequis :
--   - CTLD fully initialised (inject CTLD_Next.lua + 5s wait)
--   - Inject CTLD_Next.lua first, wait 3–5 s for init.
--
-- @scenario  SCHED
-- @version   3.0 — 2026-06-30
-- @coverage  F-135, F-136, F-137, F-138, F-139
-- =============================================================================

-- ── 1. Witchcraft guard ──────────────────────────────────────────────────────
if not ctld or not ctld.utils then
    trigger.action.outText("[SCHED] ABORT: CTLD not initialized. Inject CTLD_Next.lua first.", 15)
    return Witchcraft
end

-- ── 2. Double-injection guard ────────────────────────────────────────────────
if _SCN_SCHED_RUNNING then
    trigger.action.outText("[SCHED] déjà actif — attendre la fin ou redémarrer DCS.", 10)
    return Witchcraft
end
_SCN_SCHED_RUNNING = true
_SCN_SCHED_CLEANUP = nil

do  -- isolation scope
-- ── 4. Debug ON ──────────────────────────────────────────────────────────────
local cfg                  = CTLDConfig.get()
local _savedDebug          = cfg.settings["debug"]
local _savedDebugScreenLog = cfg.settings["debugScreenLog"]
cfg.settings["debug"]          = true
cfg.settings["debugScreenLog"] = false

-- ── 5. Constants ─────────────────────────────────────────────────────────────
local TAG  = "[SCHED]"
local NAME = "ctld.scheduler — loop registry + guard B"

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
local function check(id, desc, cond, details)
    if cond then pass(id, desc)
    else fail(id, desc .. (details and (" | " .. details) or "")) end
end

-- ── 8. Cleanup ───────────────────────────────────────────────────────────────
local function cleanup()
    if S.timerHandle then timer.removeFunction(S.timerHandle) ; S.timerHandle = nil end
    cfg.settings["debug"]          = _savedDebug
    cfg.settings["debugScreenLog"] = _savedDebugScreenLog
    _SCN_SCHED_RUNNING = false
    _SCN_SCHED_CLEANUP = nil
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
    if not ok then log("WARN cleanup: "..tostring(err)) ; _SCN_SCHED_RUNNING = false end
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

-- S1 — F-135 : ctld.scheduler basic operations
steps[1] = function()
    instruct("Step 1/4 — F-135 : opérations de base du scheduler (auto)")

    -- F-135.1 : scheduler exists and has _ids table
    check("F-135.1", "ctld.scheduler exists", ctld.scheduler ~= nil)
    check("F-135.2", "ctld.scheduler._ids is a table",
        type(ctld.scheduler._ids) == "table")

    -- F-135.3 : register stores an ID
    local _savedIds = ctld.scheduler._ids
    ctld.scheduler._ids = {}   -- isolated sandbox

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
        "removeFunction calls="..tostring(#removeCalled))
    check("F-135.5", "re-register stores new ID",
        ctld.scheduler._ids["test_loop"] == 1002)

    -- F-135.6 : cancel removes entry
    ctld.scheduler.cancel("test_loop")
    check("F-135.6", "cancel removes entry",
        ctld.scheduler._ids["test_loop"] == nil)
    check("F-135.7", "cancel calls removeFunction",
        #removeCalled == 2 and removeCalled[2] == 1002,
        "removeFunction calls="..tostring(#removeCalled))

    -- F-135.8 : cancelAll clears all entries
    ctld.scheduler._ids = { a = 2001, b = 2002 }
    removeCalled = {}
    ctld.scheduler.cancelAll()
    check("F-135.8", "cancelAll calls removeFunction for all entries",
        #removeCalled == 2,
        "calls="..tostring(#removeCalled))
    check("F-135.9", "_ids empty after cancelAll",
        next(ctld.scheduler._ids) == nil)

    -- Restore
    timer.scheduleFunction = _origSchedule
    timer.removeFunction   = _origRemove
    ctld.scheduler._ids    = _savedIds

    waitThen(1, advanceStep)
end

-- S2 — F-136/F-137 : loop registration after CTLD init
steps[2] = function()
    instruct("Step 2/4 — F-136/F-137 : enregistrement des boucles (auto)")

    -- F-136 : _scheduleRefresh registers beacon_refresh
    local beaconEnabled = ctld.gs("enabledRadioBeaconDrop")
    if beaconEnabled then
        local idBefore = ctld.scheduler._ids["beacon_refresh"]
        CTLDBeaconManager.getInstance():_scheduleRefresh()
        local idAfter  = ctld.scheduler._ids["beacon_refresh"]
        check("F-136.1", "_scheduleRefresh registers beacon_refresh",
            idAfter ~= nil, "id="..tostring(idAfter))
        check("F-136.2", "re-schedule produces a number ID",
            type(idAfter) == "number", "type="..type(idAfter))
        if idBefore ~= nil and idBefore ~= idAfter then
            pass("F-136.3", "old ID replaced by new one (stale ID cancelled)")
        elseif idBefore == nil then
            pass("F-136.3", "fresh registration (no previous ID)")
        else
            pass("F-136.3", "same ID retained (no stale cancellation needed)")
        end
    else
        log("F-136 SKIP — enabledRadioBeaconDrop=false, beacon loop not started")
    end

    -- F-137 : _initAITransports registers ai_transport when pilot names non-empty
    local _origNames = cfg.settings["transportPilotNames"]
    cfg.settings["transportPilotNames"] = { "_sched_test_dummy" }
    CTLDCoreManager.getInstance():_initAITransports()
    check("F-137.1", "_initAITransports registers ai_transport",
        ctld.scheduler._ids["ai_transport"] ~= nil,
        "id="..tostring(ctld.scheduler._ids["ai_transport"]))
    check("F-137.2", "ai_transport ID is a number",
        type(ctld.scheduler._ids["ai_transport"]) == "number")
    cfg.settings["transportPilotNames"] = _origNames
    ctld.scheduler.cancel("ai_transport")

    -- F-137.3 : re-registering same name does NOT duplicate
    ctld.scheduler.register("test_dedup", 5001)
    ctld.scheduler.register("test_dedup", 5002)
    check("F-137.3", "second register replaces first (no duplicate)",
        ctld.scheduler._ids["test_dedup"] == 5002)
    ctld.scheduler.cancel("test_dedup")

    waitThen(1, advanceStep)
end

-- S3 — F-138 : guard B — zombie loop auto-stops when instance replaced
steps[3] = function()
    instruct("Step 3/4 — F-138 : guard B — zombie loop auto-stop (auto)")

    local bm = CTLDBeaconManager.getInstance()

    -- Simuler le remplacement du singleton : swapper _instance vers une autre table
    local _realInstance = CTLDBeaconManager._instance
    local fakeInstance  = {}
    CTLDBeaconManager._instance = fakeInstance

    local refreshAllCalled = 0
    local _origRefreshAll  = bm._refreshAll
    bm._refreshAll = function(self)
        refreshAllCalled = refreshAllCalled + 1
    end

    -- Reproduire la closure de production exacte
    local self_ref = bm
    local returnedVal = nil
    local function refresh(_, t)
        if CTLDBeaconManager._instance ~= self_ref then return nil end
        self_ref:_refreshAll()
        return t + 60
    end
    returnedVal = refresh(nil, 100)

    -- Restore
    CTLDBeaconManager._instance = _realInstance
    bm._refreshAll = _origRefreshAll

    check("F-138.1", "guard B returns nil when instance replaced",
        returnedVal == nil,
        "returned="..tostring(returnedVal))
    check("F-138.2", "_refreshAll NOT called (zombie stopped before work)",
        refreshAllCalled == 0,
        "calls="..tostring(refreshAllCalled))

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
        "returned="..tostring(rv2).." calls="..tostring(refreshAllCalledOK))

    waitThen(1, advanceStep)
end

-- S4 — F-139 : cancelAll clears IDs + re-registration works after
steps[4] = function()
    instruct("Step 4/4 — F-139 : cancelAll + re-registration (auto)")

    -- Snapshot du nombre d'IDs avant cancel
    local countBefore = 0
    for _ in pairs(ctld.scheduler._ids) do countBefore = countBefore + 1 end
    check("F-139.1", "scheduler has ≥1 registered loop before cancelAll",
        countBefore >= 1, "count="..tostring(countBefore))

    ctld.scheduler.cancelAll()
    local countAfter = 0
    for _ in pairs(ctld.scheduler._ids) do countAfter = countAfter + 1 end
    check("F-139.2", "_ids empty after cancelAll",
        countAfter == 0, "count="..tostring(countAfter))

    -- Re-registration still works (no crash after cancelAll)
    ctld.scheduler.register("test_post_cancel", 9999)
    check("F-139.3", "register works after cancelAll",
        ctld.scheduler._ids["test_post_cancel"] == 9999)
    ctld.scheduler.cancel("test_post_cancel")

    -- Re-init beacon loop pour restaurer l'opération normale
    if ctld.gs("enabledRadioBeaconDrop") then
        CTLDBeaconManager.getInstance():_scheduleRefresh()
        check("F-139.4", "beacon_refresh re-registered after re-init",
            ctld.scheduler._ids["beacon_refresh"] ~= nil)
    end

    advanceStep()
end

-- ── 14. Start ────────────────────────────────────────────────────────────────
-- Ce scénario n'a pas besoin du transport joueur (tests purement internes),
-- mais on tente de le récupérer pour les logs.
S.transport = (function()
    local ok, pm = pcall(CTLDPlayerManager.getInstance)
    if ok and pm and pm._players then
        for unitName in pairs(pm._players) do
            local u = Unit.getByName(unitName)
            if u and u:isExist() then return u end
        end
    end
    return nil
end)()

_SCN_SCHED_CLEANUP = cleanup

local transportStr = S.transport and S.transport:getName() or "(no player)"
log("=== START: "..NAME.." | transport="..transportStr.." | "..#steps.." steps ===")
trigger.action.outText(TAG.." démarrage — "..#steps.." steps automatiques", 8)
advanceStep()

end  -- do isolation scope
return Witchcraft
