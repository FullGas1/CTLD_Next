---@diagnostic disable
-- =============================================================================
-- scenario_extract_menu.lua
-- CTLDTroopManager — extract-from-field menu logic (single vs multi-group)
--
-- Test cases:
--   F-145 : 1 dropped group nearby → direct "Extract: <name>" command (no subMenu)
--   F-146 : 2+ dropped groups nearby → "Extract from field" subMenu
--           with distance-annotated entries for each group
--
-- Pre-requisites:
--   - CTLD fully initialised (inject CTLD_Next.lua + 5s wait)
--   - recette/enable_debug.lua injected before this scenario
-- =============================================================================

local cfg = CTLDConfig.get()
local _saved_debug = cfg.settings["debug"]
cfg.settings["debug"] = true

local TAG    = "[EXTRACT-MENU]"
local START  = os.date("%Y-%m-%d %H:%M:%S")
local STEP_N = "_EXTRACT_MENU_STEP"

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

-- Returns true if any command label under parentPath starts with prefix.
local function hasCmdWithPrefix(mlog, parentPath, prefix)
    local pathPfx = parentPath .. "/"
    for _, c in ipairs(mlog.commands) do
        if c:sub(1, #pathPfx) == pathPfx then
            local label = c:sub(#pathPfx + 1)
            if label:sub(1, #prefix) == prefix then return true end
        end
    end
    return false
end

-- Returns count of commands whose path starts with parentPath.
local function cmdCountUnder(mlog, parentPath)
    local pathPfx = parentPath .. "/"
    local n = 0
    for _, c in ipairs(mlog.commands) do
        if c:sub(1, #pathPfx) == pathPfx then n = n + 1 end
    end
    return n
end

-- Fake unit / playerObj — no troops onboard (extract tests require hasTroops=false)
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

-- Run refreshMenuSection with controlled nearbyGroups and no troops onboard.
local function captureMenuRefresh(tm, nearbyGroups)
    local mockMenu, mlog = newMenuMock()

    local _origMMGet   = ctld.MenuManager.getInstance
    local _origIsAir   = tm._isInAir
    local _origFindAll = tm._findAllNearbyDropped
    local _origZMGet   = CTLDZoneManager.getInstance
    local _savedUA     = cfg.settings["unitActions"]

    ctld.MenuManager.getInstance = function(self2)
        return { getMenuByGroupId = function(self3, gid) return mockMenu end }
    end
    tm._isInAir = function(self2, unit) return false end
    tm._findAllNearbyDropped = function(self2, unit, coa)
        return nearbyGroups
    end
    CTLDZoneManager.getInstance = function()
        return { getTroopZonesForCoalition = function() return {} end }
    end
    cfg.settings["unitActions"] = { [TEST_TYPE] = { troops = true } }

    -- No troops onboard → extract section is shown
    tm._inTransit[TEST_UNIT] = nil

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
-- STEP 1 — F-145 / F-146 : extract-from-field menu structure
-- ══════════════════════════════════════════════════════════════════════════════
if step == 1 then

    local tm = CTLDTroopManager.getInstance()

    local root     = ctld.tr("CTLD")
    local troopSub = ctld.tr("Troop Commands")
    local embarkSub = ctld.tr("Embark / Extract Troops")
    local extractSub = ctld.tr("Extract from field")

    local rootTroopEmbark = root .. "/" .. troopSub .. "/" .. embarkSub

    -- ── F-145 : 1 nearby group → direct "Extract: <name>" command ────────────
    local nearby1 = { { groupName = "Dropped Alpha", distM = 50 } }
    local mlog1 = captureMenuRefresh(tm, nearby1)

    -- Expected: a command whose label starts with "Extract:" under Embark / Extract Troops
    local extractPrefix = ctld.tr("Extract: %1", ""):gsub("%%1", ""):gsub(" $", "")
    -- Fallback: just look for "Extract" in the command label under embarkSub path
    local hasDirectExtract = hasCmdWithPrefix(mlog1, rootTroopEmbark, "Extract")

    check("F-145.1", "1 nearby group: direct Extract command exists",
        hasDirectExtract)
    check("F-145.2", "1 nearby group: no 'Extract from field' subMenu",
        not hasSub(mlog1, rootTroopEmbark, extractSub))

    -- ── F-146 : 2 nearby groups → "Extract from field" subMenu ───────────────
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

    -- Distance annotation: entry label should contain the distance value
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
    check("F-146.4", "entry 'Dropped Alpha' has distance annotation (45m)",
        hasAlphaDist)
    check("F-146.5", "entry 'Dropped Bravo' has distance annotation (80m)",
        hasBravoDist)

    _G[STEP_N] = 99
    _result = "step=1 SUCCESS"

-- ══════════════════════════════════════════════════════════════════════════════
-- STEP FINAL
-- ══════════════════════════════════════════════════════════════════════════════
elseif step >= 99 then

    report("═══════════════════════════════════════")
    report("EXTRACT-MENU — All steps complete (F-145→F-146)")
    report("═══════════════════════════════════════")

    _G[STEP_N] = 1
    _result = "ALL SUCCESS"

else
    fail("step=" .. step .. " has no matching branch")
end

end)  -- end pcall

cfg.settings["debug"] = _saved_debug

local _ms = math.floor((os.clock() - _step_start) * 1000)
if not _ok then
    return TAG .. " step=" .. step .. " FAIL: " .. tostring(_err)
end
if _result == "ALL SUCCESS" then
    return TAG .. " " .. _result .. " (" .. _ms .. "ms)"
end
return TAG .. " " .. _result:gsub("SUCCESS", "SUCCESS (" .. _ms .. "ms)")
