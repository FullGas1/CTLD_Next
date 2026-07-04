---@diagnostic disable
-- =============================================================================
-- scenario_ai_transport.lua
-- INIT-A — AI transport auto-pickup / auto-dropoff
--
-- Verifies that _initAITransports() builds coalition team lists correctly, and
-- that _checkAIStatus() triggers embarkFromTroopZone (pickup branch) or
-- disembarkAll (dropoff branch) for AI units in the appropriate zones.
--
-- All DCS unit/zone calls are mocked via save/restore pattern — no human
-- action required (auto scenario).
--
-- Test cases:
--   F-133 : _aiTeams population after init
--   F-134 : pickup / dropoff branch decision logic
--
-- Pre-requisites:
--   - CTLD fully initialised (inject CTLD_Next.lua + 5s wait)
--   - recette/enable_debug.lua injected before this scenario
--   - At least one loadableGroups entry defined in config
-- =============================================================================

-- ── Witchcraft guard ─────────────────────────────────────────────────────────
if not ctld or not ctld.utils then
    trigger.action.outText("[AI-TRANSPORT] ABORT: CTLD not initialized. Inject CTLD_Next.lua first.", 15)
    return Witchcraft
end

local cfg = CTLDConfig.get()
local _saved_debug = cfg.settings["debug"]
local _savedDebugScreenLog = cfg.settings["debugScreenLog"]
cfg.settings["debug"] = true
cfg.settings["debugScreenLog"] = true

local TAG    = "[AI-TRANSPORT]"
local START  = os.date("%Y-%m-%d %H:%M:%S")
local STEP_N = "_AI_TRANSPORT_STEP"

local function log(msg)   ctld.utils.log("INFO", TAG .. " " .. msg) end
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

-- ── STATE MACHINE ─────────────────────────────────────────────────────────────

_G[STEP_N] = _G[STEP_N] or 1
local step = _G[STEP_N]
report("==== START " .. START .. " | step=" .. step .. " ====")

local _step_start = os.clock()
local _result = "INCOMPLETE"
local _ok, _err = pcall(function()

-- ══════════════════════════════════════════════════════════════════════════════
-- STEP 1 — Verify _aiTeams population (F-133)
-- Expected: CTLDCoreManager._aiTeams[1] and [2] each have at least one entry
-- ══════════════════════════════════════════════════════════════════════════════
if step == 1 then

    local core = CTLDCoreManager.getInstance()

    check("F-133.1", "_aiTeams exists on core instance",
        core._aiTeams ~= nil)

    check("F-133.2", "_aiTeams[BLUE=2] has ≥1 template",
        core._aiTeams ~= nil and core._aiTeams[2] ~= nil and #core._aiTeams[2] > 0,
        "got " .. tostring(core._aiTeams and #(core._aiTeams[2] or {}) or "nil"))

    check("F-133.3", "_aiTeams[RED=1] has ≥1 template",
        core._aiTeams ~= nil and core._aiTeams[1] ~= nil and #core._aiTeams[1] > 0,
        "got " .. tostring(core._aiTeams and #(core._aiTeams[1] or {}) or "nil"))

    -- Verify every entry is a non-disabled template with a name
    local allOk = true
    if core._aiTeams then
        for _, coa in ipairs({ 1, 2 }) do
            for _, tmpl in ipairs(core._aiTeams[coa] or {}) do
                if tmpl.disabled then allOk = false end
                if not tmpl.name then allOk = false end
            end
        end
    end
    check("F-133.4", "all _aiTeams entries are enabled and named", allOk)

    pass("Step 1 — _aiTeams OK. Re-inject for Step 2.")
    _G[STEP_N] = 2
    _result = "step=1 SUCCESS"

-- ══════════════════════════════════════════════════════════════════════════════
-- STEP 2 — Pickup branch (F-134)
-- Mocks: Unit.getByName, getTroopZoneForUnit, embarkFromTroopZone, hasTroops
-- Expected: embarkFromTroopZone called once for AI unit in pickup zone
-- ══════════════════════════════════════════════════════════════════════════════
elseif step == 2 then

    local core = CTLDCoreManager.getInstance()
    local zm   = CTLDZoneManager.getInstance()
    local tm   = CTLDTroopManager.getInstance()

    -- ── Fake unit (AI, BLUE coalition) ────────────────────────────────────────
    local FAKE_NAME = "_ctld_test_ai_unit"
    local fakeUnit = {
        isExist        = function() return true end,
        getPlayerName  = function() return nil end,         -- AI
        getCoalition   = function() return coalition.side.BLUE end,
        getPoint       = function() return { x = 0, y = 0, z = 0 } end,
        getTypeName    = function() return "UH-1H" end,
        getName        = function() return FAKE_NAME end,
        getGroup       = function()
            return { getID = function() return 9999 end }
        end,
        getCountry     = function() return 2 end,   -- USA
    }
    -- Fake zone (truthy sentinel — embark is mocked)
    local fakePickupZone = { _isFakePickup = true }

    -- ── Mocks ─────────────────────────────────────────────────────────────────
    local _origGBN  = Unit.getByName
    local _origGTZFU = zm.getTroopZoneForUnit
    local _origEmbark = tm.embarkFromTroopZone
    local _origHas   = tm.hasTroops

    Unit.getByName = function(name)
        if name == FAKE_NAME then return fakeUnit end
        return _origGBN(name)
    end
    zm.getTroopZoneForUnit = function(self, name)
        if name == FAKE_NAME then return fakePickupZone end
        return _origGTZFU(self, name)
    end
    tm.hasTroops = function(self, name)
        if name == FAKE_NAME then return false end   -- no troops yet
        return _origHas(self, name)
    end

    local embarkCalled = 0
    local embarkGotUnit, embarkGotZone, embarkGotTmpl = nil, nil, nil
    tm.embarkFromTroopZone = function(self, unit, zone, tmpl)
        if unit == fakeUnit then
            embarkCalled = embarkCalled + 1
            embarkGotUnit  = unit
            embarkGotZone  = zone
            embarkGotTmpl  = tmpl
        end
        return true
    end

    -- ── Add fake unit to config ────────────────────────────────────────────────
    local _origNames = cfg.settings["transportPilotNames"]
    cfg.settings["transportPilotNames"] = { FAKE_NAME }

    -- ── Execute ───────────────────────────────────────────────────────────────
    core:_checkAIStatus()

    -- ── Restore ───────────────────────────────────────────────────────────────
    Unit.getByName             = _origGBN
    zm.getTroopZoneForUnit     = _origGTZFU
    tm.embarkFromTroopZone     = _origEmbark
    tm.hasTroops               = _origHas
    cfg.settings["transportPilotNames"] = _origNames

    -- ── Assertions ────────────────────────────────────────────────────────────
    check("F-134.1", "embarkFromTroopZone called exactly once", embarkCalled == 1,
        "called=" .. tostring(embarkCalled))
    check("F-134.2", "correct zone passed to embark", embarkGotZone == fakePickupZone)
    check("F-134.3", "template from _aiTeams[BLUE] passed",
        embarkGotTmpl ~= nil and embarkGotTmpl.name ~= nil,
        "tmpl=" .. tostring(embarkGotTmpl and embarkGotTmpl.name or "nil"))

    -- F-134.4 — human pilot should be skipped
    local humanUnit = {
        isExist       = function() return true end,
        getPlayerName = function() return "TestPlayer" end,   -- human
        getCoalition  = function() return coalition.side.BLUE end,
        getPoint      = function() return { x = 0, y = 0, z = 0 } end,
        getTypeName   = function() return "UH-1H" end,
        getName       = function() return FAKE_NAME end,
        getGroup      = function() return { getID = function() return 9999 end } end,
        getCountry    = function() return 2 end,
    }
    local _origGBN2  = Unit.getByName
    local _origGTZFU2 = zm.getTroopZoneForUnit
    local _origEmbark2 = tm.embarkFromTroopZone
    local _origHas2  = tm.hasTroops
    Unit.getByName = function(name)
        if name == FAKE_NAME then return humanUnit end
        return _origGBN2(name)
    end
    zm.getTroopZoneForUnit = function(self, name)
        if name == FAKE_NAME then return fakePickupZone end
        return _origGTZFU2(self, name)
    end
    tm.hasTroops = function(self, name)
        if name == FAKE_NAME then return false end
        return _origHas2(self, name)
    end
    local embarkCalledHuman = 0
    tm.embarkFromTroopZone = function(self, unit, zone, tmpl)
        embarkCalledHuman = embarkCalledHuman + 1
        return true
    end
    cfg.settings["transportPilotNames"] = { FAKE_NAME }
    core:_checkAIStatus()
    Unit.getByName             = _origGBN2
    zm.getTroopZoneForUnit     = _origGTZFU2
    tm.embarkFromTroopZone     = _origEmbark2
    tm.hasTroops               = _origHas2
    cfg.settings["transportPilotNames"] = _origNames

    check("F-134.4", "human pilot NOT embarked", embarkCalledHuman == 0,
        "embark calls=" .. tostring(embarkCalledHuman))

    pass("Step 2 — pickup branch OK. Re-inject for Step 3.")
    _G[STEP_N] = 3
    _result = "step=2 SUCCESS"

-- ══════════════════════════════════════════════════════════════════════════════
-- STEP 3 — Dropoff branch (F-134 continued)
-- Mocks: Unit.getByName, getDropoffZoneAt, disembarkAll, hasTroops
-- Expected: disembarkAll called for AI unit with troops in dropoff zone
-- ══════════════════════════════════════════════════════════════════════════════
elseif step == 3 then

    local core = CTLDCoreManager.getInstance()
    local zm   = CTLDZoneManager.getInstance()
    local tm   = CTLDTroopManager.getInstance()

    local FAKE_NAME = "_ctld_test_ai_unit"
    local fakeUnit = {
        isExist        = function() return true end,
        getPlayerName  = function() return nil end,
        getCoalition   = function() return coalition.side.BLUE end,
        getPoint       = function() return { x = 0, y = 0, z = 0 } end,
        getTypeName    = function() return "UH-1H" end,
        getName        = function() return FAKE_NAME end,
        getGroup       = function() return { getID = function() return 9999 end } end,
        getCountry     = function() return 2 end,
    }
    local fakeDropZone = { _isFakeDropoff = true }

    local _origGBN   = Unit.getByName
    local _origGTZFU = zm.getTroopZoneForUnit
    local _origGDZA  = zm.getDropoffZoneAt
    local _origHas   = tm.hasTroops
    local _origDisemAll = tm.disembarkAll

    Unit.getByName = function(name)
        if name == FAKE_NAME then return fakeUnit end
        return _origGBN(name)
    end
    zm.getTroopZoneForUnit = function(self, name)
        -- NOT in pickup zone
        if name == FAKE_NAME then return nil end
        return _origGTZFU(self, name)
    end
    zm.getDropoffZoneAt = function(self, point, coa)
        return fakeDropZone   -- always "in" dropoff zone
    end
    tm.hasTroops = function(self, name)
        if name == FAKE_NAME then return true end   -- has troops
        return _origHas(self, name)
    end

    local disembarkAllCalled = 0
    tm.disembarkAll = function(self, unit)
        if unit == fakeUnit then disembarkAllCalled = disembarkAllCalled + 1 end
        return true
    end

    local _origNames = cfg.settings["transportPilotNames"]
    cfg.settings["transportPilotNames"] = { FAKE_NAME }

    core:_checkAIStatus()

    Unit.getByName             = _origGBN
    zm.getTroopZoneForUnit     = _origGTZFU
    zm.getDropoffZoneAt        = _origGDZA
    tm.hasTroops               = _origHas
    tm.disembarkAll            = _origDisemAll
    cfg.settings["transportPilotNames"] = _origNames

    check("F-134.5", "disembarkAll called for AI unit in dropoff zone",
        disembarkAllCalled == 1,
        "called=" .. tostring(disembarkAllCalled))

    -- F-134.6 — AI unit with NO troops in dropoff zone must NOT trigger disembark
    local _origGBN2   = Unit.getByName
    local _origGTZFU2 = zm.getTroopZoneForUnit
    local _origGDZA2  = zm.getDropoffZoneAt
    local _origHas2   = tm.hasTroops
    local _origDisemAll2 = tm.disembarkAll
    Unit.getByName = function(name)
        if name == FAKE_NAME then return fakeUnit end
        return _origGBN2(name)
    end
    zm.getTroopZoneForUnit = function(self, name)
        if name == FAKE_NAME then return nil end
        return _origGTZFU2(self, name)
    end
    zm.getDropoffZoneAt = function(self, point, coa)
        return fakeDropZone
    end
    tm.hasTroops = function(self, name)
        if name == FAKE_NAME then return false end   -- no troops
        return _origHas2(self, name)
    end
    local disembarkAllCalledNoTroops = 0
    tm.disembarkAll = function(self, unit)
        if unit == fakeUnit then disembarkAllCalledNoTroops = disembarkAllCalledNoTroops + 1 end
        return true
    end
    cfg.settings["transportPilotNames"] = { FAKE_NAME }
    core:_checkAIStatus()
    Unit.getByName             = _origGBN2
    zm.getTroopZoneForUnit     = _origGTZFU2
    zm.getDropoffZoneAt        = _origGDZA2
    tm.hasTroops               = _origHas2
    tm.disembarkAll            = _origDisemAll2
    cfg.settings["transportPilotNames"] = _origNames

    check("F-134.6", "disembarkAll NOT called when no troops onboard",
        disembarkAllCalledNoTroops == 0,
        "called=" .. tostring(disembarkAllCalledNoTroops))

    _G[STEP_N] = 99
    _result = "step=3 SUCCESS"

-- ══════════════════════════════════════════════════════════════════════════════
-- STEP FINAL
-- ══════════════════════════════════════════════════════════════════════════════
elseif step >= 99 then

    report("═══════════════════════════════════════")
    report("AI-TRANSPORT — All steps complete (F-133/F-134)")
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
