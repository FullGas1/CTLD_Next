---@diagnostic disable
-- =============================================================================
-- live_tests/scenarios/interactive/scenario_multigroup_transport.lua
-- CTLD — Multi-group transport + disembark menu logic
--
-- Test cases:
--   F-140 : single group onboard → "Disembark Troops" is a direct command (no subMenu)
--   F-141 : two groups onboard  → "Disembark Troops" becomes a subMenu
--           with entries: Disembark All + [1] <name1> + [2] <name2>
--   F-142 : disembarkAll removes all groups from _inTransit
--   F-143 : disembarkIndex(2) disembarks group 2 first; group 1 remains
--   F-144 : _menuCheckCargo with 2 groups → multi-line format with TOTAL line
--
-- Cinématique (3 steps auto) :
--   S1 [auto]  F-140/F-141 structure menu single vs multi-group
--   S2 [auto]  F-142/F-143 disembark operations
--   S3 [auto]  F-144 _menuCheckCargo
--
-- Pre-requisites:
--   - CTLD fully initialised (inject CTLD_Next.lua + 5s wait)
--   - multiGroupTransport must be true in config
--
-- @scenario  MG-TRANSPORT
-- @version   3.0 — 2026-06-30
-- @coverage  F-140, F-141, F-142, F-143, F-144
-- =============================================================================

-- ── 1. Witchcraft guard ──────────────────────────────────────────────────────
if not ctld or not ctld.utils then
    trigger.action.outText("[MG-TRANSPORT] ABORT: CTLD not initialized. Inject CTLD_Next.lua first.", 15)
    return Witchcraft
end

-- ── 2. Double-injection guard ────────────────────────────────────────────────
if _SCN_MG_TRANSPORT_RUNNING then
    trigger.action.outText("[MG-TRANSPORT] déjà actif — attendre la fin ou redémarrer DCS.", 10)
    return Witchcraft
end
_SCN_MG_TRANSPORT_RUNNING = true
_SCN_MG_TRANSPORT_CLEANUP = nil

-- ── 3. Global show callback ───────────────────────────────────────────────────
_SCN_MG_TRANSPORT_INSTR = ""
_SCN_MG_TRANSPORT_SHOW  = function()
    trigger.action.outText(_SCN_MG_TRANSPORT_INSTR, 30)
end

do  -- isolation scope
-- ── 4. Debug ON ──────────────────────────────────────────────────────────────
local cfg                  = CTLDConfig.get()
local _savedDebug          = cfg.settings["debug"]
local _savedDebugScreenLog = cfg.settings["debugScreenLog"]
cfg.settings["debug"]          = true
cfg.settings["debugScreenLog"] = false

-- ── 5. Constants ─────────────────────────────────────────────────────────────
local TAG             = "[MG-TRANSPORT]"
local NAME            = "Multi-group transport + disembark menu"
local MENU_NAME       = "Recette CTLD"
local MENU_PATH       = { ctld.tr("CTLD"), MENU_NAME }

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
    _SCN_MG_TRANSPORT_INSTR = TAG .. "\n" .. msg
    log("[INSTR] " .. msg)
    trigger.action.outText(_SCN_MG_TRANSPORT_INSTR, 360, true)
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
    if S.groupId then
        local mm = ctld.MenuManager:getInstance()
        local menu = mm and mm:getMenuByGroupId(S.groupId)
        if menu then
            pcall(function()
                menu:clearBranch(MENU_PATH)
                menu:setBranchEnabled(MENU_PATH, false)
                menu:refresh()
            end)
        end
    end
    _SCN_MG_TRANSPORT_INSTR = nil ; _SCN_MG_TRANSPORT_SHOW = nil
    cfg.settings["debug"]          = _savedDebug
    cfg.settings["debugScreenLog"] = _savedDebugScreenLog
    _SCN_MG_TRANSPORT_RUNNING = false
    _SCN_MG_TRANSPORT_CLEANUP = nil
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

-- ── 10. Finalization ─────────────────────────────────────────────────────────
local function finalizeScenario()
    cancelTimer()
    if S.groupId then
        local mm = ctld.MenuManager:getInstance()
        local menu = mm and mm:getMenuByGroupId(S.groupId)
        if menu then
            pcall(function()
                menu:clearBranch(MENU_PATH)
                menu:setBranchEnabled(MENU_PATH, false)
                menu:refresh()
            end)
        end
    end
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
    if not ok then log("WARN cleanup: "..tostring(err)) ; _SCN_MG_TRANSPORT_RUNNING = false end
end

-- ── 11. Mock menu helpers ─────────────────────────────────────────────────────
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
        refresh          = function() end,
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

local function captureMenuRefresh(tm, nearbyGroupsOverride)
    local mockMenu, mlog = newMenuMock()
    local _origMMGet   = ctld.MenuManager.getInstance
    local _origIsAir   = tm._isInAir
    local _origFindAll = tm._findAllNearbyDropped
    local _origZMGet      = CTLDZoneManager.getInstance
    local _savedCaps      = cfg.settings["capabilitiesByType"]
    local _origGetByName  = Unit.getByName

    ctld.MenuManager.getInstance = function(self2)
        return { getMenuByGroupId = function(self3, gid) return mockMenu end }
    end
    Unit.getByName = function(name)
        if name == TEST_UNIT then
            return { getPoint = function() return { x = 0, y = 0, z = 0 } end,
                     getName  = function() return TEST_UNIT end,
                     inAir    = function() return false end }
        end
        return _origGetByName(name)
    end
    tm._isInAir          = function(self2, unit) return false end
    tm._findAllNearbyDropped = function(self2, unit, coa)
        return nearbyGroupsOverride or {}
    end
    CTLDZoneManager.getInstance = function()
        return { getTroopZonesForCoalition = function() return {} end }
    end
    cfg.settings["capabilitiesByType"] = { [TEST_TYPE] = { troopsEnabled = true, cratesEnabled = false, canParachuteDrop = false, canSlingload = false } }

    local ok, err = pcall(function() tm:refreshMenuSection(playerObj) end)

    cfg.settings["capabilitiesByType"] = _savedCaps
    CTLDZoneManager.getInstance  = _origZMGet
    tm._findAllNearbyDropped     = _origFindAll
    tm._isInAir                  = _origIsAir
    Unit.getByName               = _origGetByName
    ctld.MenuManager.getInstance = _origMMGet

    if not ok then error(err) end
    return mlog
end

-- ── 12. Step runner ───────────────────────────────────────────────────────────
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

-- S1 — F-140 / F-141 : disembark menu structure (single vs multi-group)
steps[1] = function()
    instruct("Step 1/3 — F-140/F-141: structure menu disembark (auto)")

    local tm = CTLDTroopManager.getInstance()
    local root   = ctld.tr("CTLD")
    local troopSub = ctld.tr("Troop Commands")
    local disLbl = ctld.tr("Disembark Troops")
    local disAll = ctld.tr("Disembark All")
    local rootTroop = root .. "/" .. troopSub

    -- F-140 : single group → direct command, no sub-menu
    tm._inTransit[TEST_UNIT] = { fakeTG("Squad Alpha", 6, 480) }
    local mlog1 = captureMenuRefresh(tm)

    check("F-140.1", "single group: no Disembark subMenu",
        not hasSub(mlog1, rootTroop, disLbl))
    check("F-140.2", "single group: direct Disembark command",
        hasCmd(mlog1, rootTroop, disLbl))

    -- F-141 : two groups → sub-menu with All + [1] / [2] entries
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
    check("F-141.5", "two groups: disembark subMenu has exactly 3 entries (All + 2 groups)",
        cmdCountUnder(mlog2, disSub) == 3,
        "count=" .. tostring(cmdCountUnder(mlog2, disSub)))

    tm._inTransit[TEST_UNIT] = nil
    log("S1 done")
    advanceStep()
end

-- S2 — F-142 / F-143 : disembark operations
steps[2] = function()
    instruct("Step 2/3 — F-142/F-143: disembark operations (auto)")

    local tm = CTLDTroopManager.getInstance()
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

    -- F-142 : disembarkAll removes all groups
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

    -- F-143 : disembarkIndex(2) unloads group 2 first, group 1 remains
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

    tm._inTransit[TEST_UNIT] = nil
    tm.disembark = _origDisembark
    log("S2 done")
    advanceStep()
end

-- S3 — F-144 : _menuCheckCargo with 2 groups
steps[3] = function()
    instruct("Step 3/3 — F-144: _menuCheckCargo multi-line (auto)")

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

    check("F-144.1", "Check Cargo: message received", capturedMsg ~= nil, "msg=nil")
    check("F-144.2", "Check Cargo: TOTAL line present",
        capturedMsg ~= nil and capturedMsg:find("TOTAL", 1, true) ~= nil,
        "msg=" .. tostring(capturedMsg))
    check("F-144.3", "Check Cargo: [1] index listed",
        capturedMsg ~= nil and capturedMsg:find("[1]", 1, true) ~= nil)
    check("F-144.4", "Check Cargo: [2] index listed",
        capturedMsg ~= nil and capturedMsg:find("[2]", 1, true) ~= nil)

    log("S3 done — finalisation")
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

local pm_start = CTLDPlayerManager.getInstance()
local playerObjStart
if pm_start and pm_start._players then
    for _, p in pairs(pm_start._players) do
        if p.unitName == S.transport:getName() then
            playerObjStart = p ; break
        end
    end
    if not playerObjStart then
        for _, p in pairs(pm_start._players) do playerObjStart = p ; break end
    end
end
if not playerObjStart then
    trigger.action.outText(TAG.." ABORT : no CTLD playerObj for transport.", 20)
    cleanup() ; return Witchcraft
end

S.groupId = playerObjStart.groupId

local mm_init   = ctld.MenuManager:getInstance()
local menu_init = mm_init and mm_init:getMenuByGroupId(S.groupId)
if not menu_init then
    trigger.action.outText(TAG.." ABORT : no CTLD MenuManager menu for player group.", 20)
    cleanup() ; return Witchcraft
end
menu_init:addSubMenu({ ctld.tr("CTLD") }, MENU_NAME, { order = 0 })
local _rNode = menu_init:_getNode(MENU_PATH)
if _rNode then _rNode.order = 0 ; _rNode.enabled = true end
menu_init:refresh()

_SCN_MG_TRANSPORT_CLEANUP = cleanup

log("=== START: "..NAME.." | transport="..S.transport:getName().." | groupId="..tostring(S.groupId).." | "..#steps.." steps ===")
trigger.action.outText(TAG.." démarrage — "..#steps.." steps | "..S.transport:getName(), 8)
advanceStep()

end  -- do isolation scope
return Witchcraft
