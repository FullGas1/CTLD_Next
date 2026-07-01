---@diagnostic disable
-- =============================================================================
-- scenario_multigroup_transport.lua
-- CTLDTroopManager — multi-group transport + disembark menu logic
--
-- Test cases:
--   F-140 : single group onboard → "Disembark Troops" is a direct command (no subMenu)
--   F-141 : two groups onboard  → "Disembark Troops" becomes a subMenu
--           with entries: Disembark All + [1] <name1> + [2] <name2>
--   F-142 : disembarkAll removes all groups from _inTransit
--   F-143 : disembarkIndex(2) disembarks group 2 first; group 1 remains
--   F-144 : _menuCheckCargo with 2 groups → multi-line format with TOTAL line
--
-- Pre-requisites:
--   - CTLD fully initialised (inject CTLD_Next.lua + 5s wait)
--   - recette/enable_debug.lua injected before this scenario
--   - multiGroupTransport must be true in config (or set here — handled in Step 1)
-- =============================================================================


-- ── Witchcraft guard ────────────────────────────────────────────────
if not ctld or not ctld.utils then
    trigger.action.outText("[MULTIGRP] ABORT: CTLD not initialized. Inject CTLD_Next.lua first.", 15)
    return Witchcraft
end
local cfg = CTLDConfig.get()
local _saved_debug = cfg.settings["debug"]
local _savedDebugScreenLog = cfg.settings["debugScreenLog"]
cfg.settings["debug"] = true
cfg.settings["debugScreenLog"] = true

local TAG    = "[MG-TRANSPORT]"
local START  = os.date("%Y-%m-%d %H:%M:%S")
local STEP_N = "_MG_TRANSPORT_STEP"

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

-- ── HELPERS ───────────────────────────────────────────────────────────────────

-- Build a minimal mock menu that logs addSubMenu / addCommand calls.
-- Returns (mockMenu, log) where log.subMenus and log.commands are lists of
-- "path1/path2/.../name" strings.
local function newMenuMock()
    local mlog = { subMenus = {}, commands = {} }
    local mock = {
        addSubMenu = function(self2, path, name, _opts)
            table.insert(mlog.subMenus, table.concat(path, "/") .. "/" .. name)
        end,
        addCommand = function(self2, path, label, _fn, _args, _opts)
            table.insert(mlog.commands, table.concat(path, "/") .. "/" .. label)
        end,
        clearBranch      = function() end,
        setBranchEnabled = function() end,
    }
    return mock, mlog
end

local function hasSub(mlog, parentPath, name)
    local key = parentPath .. "/" .. name
    for _, s in ipairs(mlog.subMenus) do if s == key then return true end end
    return false
end

local function hasCmd(mlog, parentPath, label)
    local key = parentPath .. "/" .. label
    for _, c in ipairs(mlog.commands) do if c == key then return true end end
    return false
end

-- Count commands whose path starts with parentPath (direct children only).
local function cmdCountUnder(mlog, parentPath)
    local pathPfx = parentPath .. "/"
    local n = 0
    for _, c in ipairs(mlog.commands) do
        if c:sub(1, #pathPfx) == pathPfx then n = n + 1 end
    end
    return n
end

local function fakeTG(name, count, weight)
    return { templateName = name, unitTotal = count, weight = weight }
end

-- Fake unit / playerObj (purely used for getName / getGroup:getID / getPoint)
local TEST_UNIT = "_mg_test_unit"
local TEST_TYPE = "_mg_test_type"
local TEST_GID  = 88888

local fakeUnit = {
    getName      = function() return TEST_UNIT end,
    getGroup     = function() return { getID = function() return TEST_GID end } end,
    getCoalition = function() return 2 end,
    getPoint     = function() return { x = 0, y = 0, z = 0 } end,
    getTypeName  = function() return TEST_TYPE end,
}

local playerObj = {
    unitName    = TEST_UNIT,
    typeName    = TEST_TYPE,
    coalition   = 2,
    groupId     = TEST_GID,
    isTransport = true,
}

-- Run refreshMenuSection with full mock isolation.
-- Returns the captured menu log.
-- nearbyGroupsOverride: optional list returned by _findAllNearbyDropped (default {})
local function captureMenuRefresh(tm, nearbyGroupsOverride)
    local mockMenu, mlog = newMenuMock()

    local _origMMGet  = ctld.MenuManager.getInstance
    local _origIsAir  = tm._isInAir
    local _origFindAll = tm._findAllNearbyDropped
    local _origZMGet  = CTLDZoneManager.getInstance
    local _savedUA    = cfg.settings["unitActions"]

    ctld.MenuManager.getInstance = function(self2)
        return { getMenuByGroupId = function(self3, gid) return mockMenu end }
    end
    tm._isInAir          = function(self2, unit) return false end
    tm._findAllNearbyDropped = function(self2, unit, coa)
        return nearbyGroupsOverride or {}
    end
    CTLDZoneManager.getInstance = function()
        return { getTroopZonesForCoalition = function() return {} end }
    end
    cfg.settings["unitActions"] = { [TEST_TYPE] = { troops = true } }

    local ok, err = pcall(function() tm:refreshMenuSection(playerObj) end)

    cfg.settings["unitActions"] = _savedUA
    CTLDZoneManager.getInstance  = _origZMGet
    tm._findAllNearbyDropped     = _origFindAll
    tm._isInAir                  = _origIsAir
    ctld.MenuManager.getInstance = _origMMGet

    if not ok then error(err) end
    return mlog
end

-- ── STATE MACHINE ─────────────────────────────────────────────────────────────

_G[STEP_N] = _G[STEP_N] or 1
local step = _G[STEP_N]
report("==== START " .. START .. " | step=" .. step .. " ====")

local _step_start = os.clock()
local _result = "INCOMPLETE"
local _ok, _err = pcall(function()

-- ══════════════════════════════════════════════════════════════════════════════
-- STEP 1 — F-140 / F-141 : disembark menu structure (single vs multi-group)
-- ══════════════════════════════════════════════════════════════════════════════
if step == 1 then

    local tm = CTLDTroopManager.getInstance()

    -- Translation keys used as path components
    local root     = ctld.tr("CTLD")
    local troopSub = ctld.tr("Troop Commands")
    local disLbl   = ctld.tr("Disembark Troops")
    local disAll   = ctld.tr("Disembark All")

    -- ── F-140 : single group → direct command, no sub-menu ───────────────────
    tm._inTransit[TEST_UNIT] = { fakeTG("Squad Alpha", 6, 480) }

    local mlog1 = captureMenuRefresh(tm)

    local rootTroop = root .. "/" .. troopSub

    check("F-140.1", "single group: no Disembark subMenu",
        not hasSub(mlog1, rootTroop, disLbl))
    check("F-140.2", "single group: direct Disembark command",
        hasCmd(mlog1, rootTroop, disLbl))

    -- ── F-141 : two groups → sub-menu with All + [1] / [2] entries ───────────
    tm._inTransit[TEST_UNIT] = {
        fakeTG("Squad Alpha", 6, 480),
        fakeTG("Squad Bravo", 4, 320),
    }

    local mlog2 = captureMenuRefresh(tm)

    local disSub = rootTroop .. "/" .. disLbl

    check("F-141.1", "two groups: Disembark subMenu exists",
        hasSub(mlog2, rootTroop, disLbl))
    check("F-141.2", "two groups: Disembark All entry",
        hasCmd(mlog2, disSub, disAll))
    check("F-141.3", "two groups: [1] Squad Alpha entry",
        hasCmd(mlog2, disSub, "[1] Squad Alpha"))
    check("F-141.4", "two groups: [2] Squad Bravo entry",
        hasCmd(mlog2, disSub, "[2] Squad Bravo"))
    -- Disembark subMenu must have exactly 3 commands: Disembark All + [1] + [2]
    check("F-141.5", "two groups: disembark subMenu has exactly 3 entries (All + 2 groups)",
        cmdCountUnder(mlog2, disSub) == 3,
        "count=" .. tostring(cmdCountUnder(mlog2, disSub)))

    -- Cleanup
    tm._inTransit[TEST_UNIT] = nil

    pass("Step 1 — F-140/F-141 menu structure OK. Re-inject for Step 2.")
    _G[STEP_N] = 2
    _result = "step=1 SUCCESS"

-- ══════════════════════════════════════════════════════════════════════════════
-- STEP 2 — F-142 / F-143 : disembark operations (disembarkAll / disembarkIndex)
-- ══════════════════════════════════════════════════════════════════════════════
elseif step == 2 then

    local tm = CTLDTroopManager.getInstance()

    -- Mock disembark to avoid DCS spawn — records which group was disembarked
    -- (list[1] at call time) then removes it from _inTransit.
    local disembarkedNames = {}
    local _origDisembark   = tm.disembark
    tm.disembark = function(self2, unit)
        local list = self2._inTransit[unit:getName()]
        if not list or #list == 0 then return false end
        table.insert(disembarkedNames, list[1].templateName)
        table.remove(list, 1)
        if #list == 0 then self2._inTransit[unit:getName()] = nil end
        return true
    end

    -- ── F-142 : disembarkAll removes all groups ───────────────────────────────
    tm._inTransit[TEST_UNIT] = {
        fakeTG("Squad Alpha", 6, 480),
        fakeTG("Squad Bravo", 4, 320),
    }
    disembarkedNames = {}

    tm:disembarkAll(fakeUnit)

    check("F-142.1", "disembarkAll: _inTransit is nil after",
        tm._inTransit[TEST_UNIT] == nil)
    check("F-142.2", "disembarkAll: both groups disembarked (2 calls)",
        #disembarkedNames == 2,
        "calls=" .. tostring(#disembarkedNames))

    -- ── F-143 : disembarkIndex(2) unloads group 2 first, group 1 remains ─────
    tm._inTransit[TEST_UNIT] = {
        fakeTG("Squad Alpha", 6, 480),
        fakeTG("Squad Bravo", 4, 320),
    }
    disembarkedNames = {}

    tm:disembarkIndex(fakeUnit, 2)

    check("F-143.1", "disembarkIndex(2): group 2 disembarked first",
        disembarkedNames[1] == "Squad Bravo",
        "got=" .. tostring(disembarkedNames[1]))
    check("F-143.2", "disembarkIndex(2): group 1 still onboard",
        tm._inTransit[TEST_UNIT] ~= nil
        and tm._inTransit[TEST_UNIT][1] ~= nil
        and tm._inTransit[TEST_UNIT][1].templateName == "Squad Alpha",
        "remaining=" .. tostring(
            tm._inTransit[TEST_UNIT] and tm._inTransit[TEST_UNIT][1]
            and tm._inTransit[TEST_UNIT][1].templateName))

    -- Cleanup + restore
    tm._inTransit[TEST_UNIT] = nil
    tm.disembark = _origDisembark

    pass("Step 2 — F-142/F-143 disembark ops OK. Re-inject for Step 3.")
    _G[STEP_N] = 3
    _result = "step=2 SUCCESS"

-- ══════════════════════════════════════════════════════════════════════════════
-- STEP 3 — F-144 : _menuCheckCargo with 2 groups → multi-line with TOTAL
-- ══════════════════════════════════════════════════════════════════════════════
elseif step == 3 then

    local tm = CTLDTroopManager.getInstance()

    tm._inTransit[TEST_UNIT] = {
        fakeTG("Squad Alpha", 6, 480),
        fakeTG("Squad Bravo", 4, 320),
    }

    local capturedMsg = nil
    local _origOutText = trigger.action.outTextForGroup
    trigger.action.outTextForGroup = function(gid, msg, dur) capturedMsg = msg end

    tm:_menuCheckCargo(fakeUnit)

    trigger.action.outTextForGroup = _origOutText
    tm._inTransit[TEST_UNIT] = nil

    check("F-144.1", "Check Cargo: message received",
        capturedMsg ~= nil, "msg=nil")
    check("F-144.2", "Check Cargo: TOTAL line present",
        capturedMsg ~= nil and capturedMsg:find("TOTAL", 1, true) ~= nil,
        "msg=" .. tostring(capturedMsg))
    check("F-144.3", "Check Cargo: [1] index listed",
        capturedMsg ~= nil and capturedMsg:find("[1]", 1, true) ~= nil)
    check("F-144.4", "Check Cargo: [2] index listed",
        capturedMsg ~= nil and capturedMsg:find("[2]", 1, true) ~= nil)

    _G[STEP_N] = 99
    _result = "step=3 SUCCESS"

-- ══════════════════════════════════════════════════════════════════════════════
-- STEP FINAL
-- ══════════════════════════════════════════════════════════════════════════════
elseif step >= 99 then

    report("═══════════════════════════════════════")
    report("MG-TRANSPORT — All steps complete (F-140→F-144)")
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
