---@diagnostic disable
-- =============================================================================
-- live_tests/scenarios/interactive/scenario_ai_transport.lua
-- CTLD — AI transport auto-pickup / auto-dropoff
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
--   - At least one loadableGroups entry defined in config
--
-- @scenario  AI-TRANSPORT
-- @version   3.0 — 2026-06-30
-- @coverage  F-133, F-134
-- =============================================================================

-- ── 1. Witchcraft guard ──────────────────────────────────────────────────────
if not ctld or not ctld.utils then
    trigger.action.outText("[AI-TRANSPORT] ABORT: CTLD not initialized. Inject CTLD_Next.lua first.", 15)
    return Witchcraft
end

-- ── 2. Double-injection guard ────────────────────────────────────────────────
if _SCN_AI_TRANSPORT_RUNNING then
    trigger.action.outText("[AI-TRANSPORT] déjà actif — attendre la fin ou redémarrer DCS.", 10)
    return Witchcraft
end
_SCN_AI_TRANSPORT_RUNNING = true
_SCN_AI_TRANSPORT_CLEANUP = nil

-- ── 3. Global show callback ───────────────────────────────────────────────────
_SCN_AI_TRANSPORT_INSTR = ""
_SCN_AI_TRANSPORT_SHOW  = function()
    trigger.action.outText(_SCN_AI_TRANSPORT_INSTR, 30)
end

do  -- isolation scope
-- ── 4. Debug ON ──────────────────────────────────────────────────────────────
local cfg                  = CTLDConfig.get()
local _savedDebug          = cfg.settings["debug"]
local _savedDebugScreenLog = cfg.settings["debugScreenLog"]
cfg.settings["debug"]          = true
cfg.settings["debugScreenLog"] = false

-- ── 5. Constants ─────────────────────────────────────────────────────────────
local TAG             = "[AI-TRANSPORT]"
local NAME            = "AI transport auto-pickup / auto-dropoff"
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
    _SCN_AI_TRANSPORT_INSTR = TAG .. "\n" .. msg
    log("[INSTR] " .. msg)
    trigger.action.outText(_SCN_AI_TRANSPORT_INSTR, 360, true)
end

local function pass(id, msg) S.passed = S.passed + 1 ; log("[PASS] "..id..": "..(msg or "")) end
local function fail(id, msg) S.failed = S.failed + 1 ; table.insert(S.failReasons, id..": "..(msg or "")) ; log("[FAIL] "..id..": "..(msg or "")) end

local function check(id, desc, cond, details)
    if cond then
        pass(id, desc)
    else
        fail(id, desc .. (details and (" | " .. details) or ""))
    end
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
    _SCN_AI_TRANSPORT_INSTR = nil ; _SCN_AI_TRANSPORT_SHOW = nil
    cfg.settings["debug"]          = _savedDebug
    cfg.settings["debugScreenLog"] = _savedDebugScreenLog
    _SCN_AI_TRANSPORT_RUNNING = false
    _SCN_AI_TRANSPORT_CLEANUP = nil
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
    if not ok then log("WARN cleanup: "..tostring(err)) ; _SCN_AI_TRANSPORT_RUNNING = false end
end

-- ── 11. Step runner ───────────────────────────────────────────────────────────
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

-- ── 12. Steps ────────────────────────────────────────────────────────────────

-- S1 — Verify _aiTeams population (F-133)
steps[1] = function()
    instruct("Step 1/3 — F-133: vérification _aiTeams (auto)")

    local core = CTLDCoreManager.getInstance()

    check("F-133.1", "_aiTeams exists on core instance",
        core._aiTeams ~= nil)
    check("F-133.2", "_aiTeams[BLUE=2] has ≥1 template",
        core._aiTeams ~= nil and core._aiTeams[2] ~= nil and #core._aiTeams[2] > 0,
        "got " .. tostring(core._aiTeams and #(core._aiTeams[2] or {}) or "nil"))
    check("F-133.3", "_aiTeams[RED=1] has ≥1 template",
        core._aiTeams ~= nil and core._aiTeams[1] ~= nil and #core._aiTeams[1] > 0,
        "got " .. tostring(core._aiTeams and #(core._aiTeams[1] or {}) or "nil"))

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

    log("S1 done — avance vers S2")
    advanceStep()
end

-- S2 — Pickup branch (F-134)
steps[2] = function()
    instruct("Step 2/3 — F-134: pickup branch (auto)")

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
        getGroup       = function()
            return { getID = function() return 9999 end }
        end,
        getCountry     = function() return 2 end,
    }
    local fakePickupZone = { _isFakePickup = true }

    local _origGBN   = Unit.getByName
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
        if name == FAKE_NAME then return false end
        return _origHas(self, name)
    end

    local embarkCalled = 0
    local embarkGotUnit, embarkGotZone, embarkGotTmpl = nil, nil, nil
    tm.embarkFromTroopZone = function(self, unit, zone, tmpl)
        if unit == fakeUnit then
            embarkCalled = embarkCalled + 1
            embarkGotUnit = unit
            embarkGotZone = zone
            embarkGotTmpl = tmpl
        end
        return true
    end

    local _origNames = cfg.settings["transportPilotNames"]
    cfg.settings["transportPilotNames"] = { FAKE_NAME }

    core:_checkAIStatus()

    Unit.getByName             = _origGBN
    zm.getTroopZoneForUnit     = _origGTZFU
    tm.embarkFromTroopZone     = _origEmbark
    tm.hasTroops               = _origHas
    cfg.settings["transportPilotNames"] = _origNames

    check("F-134.1", "embarkFromTroopZone called exactly once", embarkCalled == 1,
        "called=" .. tostring(embarkCalled))
    check("F-134.2", "correct zone passed to embark", embarkGotZone == fakePickupZone)
    check("F-134.3", "template from _aiTeams[BLUE] passed",
        embarkGotTmpl ~= nil and embarkGotTmpl.name ~= nil,
        "tmpl=" .. tostring(embarkGotTmpl and embarkGotTmpl.name or "nil"))

    -- F-134.4 — human pilot should be skipped
    local humanUnit = {
        isExist       = function() return true end,
        getPlayerName = function() return "TestPlayer" end,
        getCoalition  = function() return coalition.side.BLUE end,
        getPoint      = function() return { x = 0, y = 0, z = 0 } end,
        getTypeName   = function() return "UH-1H" end,
        getName       = function() return FAKE_NAME end,
        getGroup      = function() return { getID = function() return 9999 end } end,
        getCountry    = function() return 2 end,
    }
    local _origGBN2   = Unit.getByName
    local _origGTZFU2 = zm.getTroopZoneForUnit
    local _origEmbark2 = tm.embarkFromTroopZone
    local _origHas2   = tm.hasTroops
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

    log("S2 done — avance vers S3")
    advanceStep()
end

-- S3 — Dropoff branch (F-134 continued)
steps[3] = function()
    instruct("Step 3/3 — F-134: dropoff branch (auto)")

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

    local _origGBN    = Unit.getByName
    local _origGTZFU  = zm.getTroopZoneForUnit
    local _origGDZA   = zm.getDropoffZoneAt
    local _origHas    = tm.hasTroops
    local _origDisemAll = tm.disembarkAll

    Unit.getByName = function(name)
        if name == FAKE_NAME then return fakeUnit end
        return _origGBN(name)
    end
    zm.getTroopZoneForUnit = function(self, name)
        if name == FAKE_NAME then return nil end
        return _origGTZFU(self, name)
    end
    zm.getDropoffZoneAt = function(self, point, coa)
        return fakeDropZone
    end
    tm.hasTroops = function(self, name)
        if name == FAKE_NAME then return true end
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
    local _origGBN2    = Unit.getByName
    local _origGTZFU2  = zm.getTroopZoneForUnit
    local _origGDZA2   = zm.getDropoffZoneAt
    local _origHas2    = tm.hasTroops
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
        if name == FAKE_NAME then return false end
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

    log("S3 done — finalisation")
    advanceStep()
end

-- ── 13. Start ────────────────────────────────────────────────────────────────
-- Ce scénario ne nécessite pas de joueur humain mais on le recherche quand même
-- pour S.groupId (MenuManager). Si absent, on procède sans menu.
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

if S.transport then
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
    if playerObjStart then
        S.groupId = playerObjStart.groupId
        local mm_init   = ctld.MenuManager:getInstance()
        local menu_init = mm_init and mm_init:getMenuByGroupId(S.groupId)
        if menu_init then
            menu_init:addSubMenu({ ctld.tr("CTLD") }, MENU_NAME, { order = 0 })
            local _rNode = menu_init:_getNode(MENU_PATH)
            if _rNode then _rNode.order = 0 ; _rNode.enabled = true end
            menu_init:refresh()
        end
    end
end

_SCN_AI_TRANSPORT_CLEANUP = cleanup

log("=== START: "..NAME.." | "..#steps.." steps ===")
trigger.action.outText(TAG.." démarrage — "..#steps.." steps (auto)", 8)
advanceStep()

end  -- do isolation scope
return Witchcraft
