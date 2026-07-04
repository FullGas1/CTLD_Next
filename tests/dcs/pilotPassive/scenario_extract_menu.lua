---@diagnostic disable
-- =============================================================================
-- live_tests/scenarios/interactive/scenario_extract_menu.lua
-- CTLD — Extract-from-field menu logic (single vs multi-group)
--
-- Test cases:
--   F-145 : 1 dropped group nearby → direct "Extract: <name>" command (no subMenu)
--   F-146 : 2+ dropped groups nearby → "Extract from field" subMenu
--           with distance-annotated entries for each group
--
-- Cinématique (1 step auto) :
--   S1 [auto]  Toutes les vérifications menu F-145/F-146
--
-- Pre-requisites:
--   - CTLD fully initialised (inject CTLD_Next.lua + 5s wait)
--
-- @scenario  EXTRACT-MENU
-- @version   3.0 — 2026-06-30
-- @coverage  F-145, F-146
-- =============================================================================

-- ── 1. Witchcraft guard ──────────────────────────────────────────────────────
if not ctld or not ctld.utils then
    trigger.action.outText("[EXTRACT-MENU] ABORT: CTLD not initialized. Inject CTLD_Next.lua first.", 15)
    return Witchcraft
end

-- ── 2. Double-injection guard ────────────────────────────────────────────────
if _SCN_EXTRACT_MENU_RUNNING then
    trigger.action.outText("[EXTRACT-MENU] déjà actif — attendre la fin ou redémarrer DCS.", 10)
    return Witchcraft
end
_SCN_EXTRACT_MENU_RUNNING = true
_SCN_EXTRACT_MENU_CLEANUP = nil

-- ── 3. Global show callback ───────────────────────────────────────────────────
_SCN_EXTRACT_MENU_INSTR = ""
_SCN_EXTRACT_MENU_SHOW  = function()
    trigger.action.outText(_SCN_EXTRACT_MENU_INSTR, 30)
end

do  -- isolation scope
-- ── 4. Debug ON ──────────────────────────────────────────────────────────────
local cfg                  = CTLDConfig.get()
local _savedDebug          = cfg.settings["debug"]
local _savedDebugScreenLog = cfg.settings["debugScreenLog"]
cfg.settings["debug"]          = true
cfg.settings["debugScreenLog"] = false

-- ── 5. Constants ─────────────────────────────────────────────────────────────
local TAG             = "[EXTRACT-MENU]"
local NAME            = "Extract-from-field menu logic"
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
    _SCN_EXTRACT_MENU_INSTR = TAG .. "\n" .. msg
    log("[INSTR] " .. msg)
    trigger.action.outText(_SCN_EXTRACT_MENU_INSTR, 360, true)
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
    _SCN_EXTRACT_MENU_INSTR = nil ; _SCN_EXTRACT_MENU_SHOW = nil
    cfg.settings["debug"]          = _savedDebug
    cfg.settings["debugScreenLog"] = _savedDebugScreenLog
    _SCN_EXTRACT_MENU_RUNNING = false
    _SCN_EXTRACT_MENU_CLEANUP = nil
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
    if not ok then log("WARN cleanup: "..tostring(err)) ; _SCN_EXTRACT_MENU_RUNNING = false end
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

local function hasCmdWithPrefix(mlog, parentPath, prefix)
    local pathPfx = parentPath .. "/"
    for _, c in ipairs(mlog.commands) do
        if c:sub(1, #pathPfx) == pathPfx then
            local label = c:sub(#pathPfx + 1)
            -- Only match direct children (no "/" in the remaining label)
            if not label:find("/", 1, true) and label:sub(1, #prefix) == prefix then return true end
        end
    end
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

local TEST_UNIT = "_em_test_unit"
local TEST_TYPE = "_em_test_type"
local TEST_GID  = 77777

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

local function captureMenuRefresh(tm, nearbyGroups)
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
                     getName  = function() return TEST_UNIT end }
        end
        return _origGetByName(name)
    end
    tm._isInAir = function(self2, unit) return false end
    tm._findAllNearbyDropped = function(self2, unit, coa)
        return nearbyGroups
    end
    CTLDZoneManager.getInstance = function()
        return { getTroopZonesForCoalition = function() return {} end }
    end
    cfg.settings["capabilitiesByType"] = { [TEST_TYPE] = { troopsEnabled = true, cratesEnabled = false, canParachuteDrop = false, canSlingload = false } }

    tm._inTransit[TEST_UNIT] = nil

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

-- S1 — F-145 / F-146 : extract-from-field menu structure
steps[1] = function()
    instruct("Step 1/1 — F-145/F-146: structure menu extract-from-field (auto)")

    local tm = CTLDTroopManager.getInstance()

    local root       = ctld.tr("CTLD")
    local troopSub   = ctld.tr("Troop Commands")
    local embarkSub  = ctld.tr("Embark / Extract Troops")
    local extractSub = ctld.tr("Extract from field")

    local rootTroopEmbark = root .. "/" .. troopSub .. "/" .. embarkSub

    -- F-145 : 1 nearby group → direct "Extract: <name>" command
    local nearby1 = { { groupName = "Dropped Alpha", distM = 50 } }
    local mlog1 = captureMenuRefresh(tm, nearby1)

    local hasDirectExtract = hasCmdWithPrefix(mlog1, rootTroopEmbark, "Extract")

    check("F-145.1", "1 nearby group: direct Extract command exists",
        hasDirectExtract)
    check("F-145.2", "1 nearby group: no 'Extract from field' subMenu",
        not hasSub(mlog1, rootTroopEmbark, extractSub))

    -- F-146 : 2 nearby groups → "Extract from field" subMenu
    local nearby2 = {
        { groupName = "Dropped Alpha", distM = 45 },
        { groupName = "Dropped Bravo", distM = 80 },
    }
    local mlog2 = captureMenuRefresh(tm, nearby2)

    local extractSubPath = rootTroopEmbark .. "/" .. extractSub

    check("F-146.1", "2 nearby groups: 'Extract from field' subMenu exists",
        hasSub(mlog2, rootTroopEmbark, extractSub))
    check("F-146.2", "2 nearby groups: no direct Extract command at embark level",
        not hasCmdWithPrefix(mlog2, rootTroopEmbark, "Extract"))
    check("F-146.3", "2 nearby groups: 2 entries in Extract subMenu",
        cmdCountUnder(mlog2, extractSubPath) == 2,
        "count=" .. tostring(cmdCountUnder(mlog2, extractSubPath)))

    local hasAlphaDist = false
    local hasBravoDist = false
    local alphaDist = string.format("%d", math.floor(45))
    local bravoDist = string.format("%d", math.floor(80))
    for _, c in ipairs(mlog2.commands) do
        if c:sub(1, #extractSubPath + 1) == extractSubPath .. "/" then
            local label = c:sub(#extractSubPath + 2)
            if label:find("Alpha", 1, true) and label:find(alphaDist, 1, true) then
                hasAlphaDist = true
            end
            if label:find("Bravo", 1, true) and label:find(bravoDist, 1, true) then
                hasBravoDist = true
            end
        end
    end
    check("F-146.4", "entry 'Dropped Alpha' has distance annotation (45m)", hasAlphaDist)
    check("F-146.5", "entry 'Dropped Bravo' has distance annotation (80m)", hasBravoDist)

    log("S1 done — finalisation")
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

_SCN_EXTRACT_MENU_CLEANUP = cleanup

log("=== START: "..NAME.." | transport="..S.transport:getName().." | groupId="..tostring(S.groupId).." | "..#steps.." steps ===")
trigger.action.outText(TAG.." démarrage — "..#steps.." steps | "..S.transport:getName(), 8)
advanceStep()

end  -- do isolation scope
return Witchcraft
