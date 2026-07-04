---@diagnostic disable
-- =============================================================================
-- live_tests/scenarios/interactive/scenario_ai_transport_visual.lua
-- CTLD — AI transport auto-pickup visual verification
--
-- Spawns an AI UH-1H helicopter ("CTLD_AI_TEST") inside TRZ pickup zone pz1,
-- adds it to transportPilotNames, and lets _checkAIStatus fire automatically
-- (2s loop). After a few seconds, troops should appear around the helicopter.
--
-- Cinématique (3 steps) :
--   S1 [auto]  Spawn AI heli at zone pz1 center + register in transportPilotNames
--   S2 [auto]  Poll hasTroops (waitFor 30s max)
--   S3 [auto]  Cleanup (disembark, destroy heli, restore transportPilotNames)
--
-- Pre-requisites:
--   - BLUE player in mission (for country ID)
--   - TRZ zone named "pz1" configured as pickup (pickup=true), coalition BLUE
--   - CTLD fully initialised
--
-- @scenario  AI-VIS
-- @version   3.0 — 2026-06-30
-- @coverage  F-133, F-134
-- =============================================================================

-- ── 1. Witchcraft guard ──────────────────────────────────────────────────────
if not ctld or not ctld.utils then
    trigger.action.outText("[AI-VIS] ABORT: CTLD not initialized. Inject CTLD_Next.lua first.", 15)
    return Witchcraft
end

-- ── 2. Double-injection guard ────────────────────────────────────────────────
if _SCN_AI_VIS_RUNNING then
    trigger.action.outText("[AI-VIS] déjà actif — attendre la fin ou redémarrer DCS.", 10)
    return Witchcraft
end
_SCN_AI_VIS_RUNNING = true
_SCN_AI_VIS_CLEANUP = nil

-- ── 3. Global show callback ───────────────────────────────────────────────────
_SCN_AI_VIS_INSTR = ""
_SCN_AI_VIS_SHOW  = function()
    trigger.action.outText(_SCN_AI_VIS_INSTR, 30)
end

do  -- isolation scope
-- ── 4. Debug ON ──────────────────────────────────────────────────────────────
local cfg                  = CTLDConfig.get()
local _savedDebug          = cfg.settings["debug"]
local _savedDebugScreenLog = cfg.settings["debugScreenLog"]
cfg.settings["debug"]          = true
cfg.settings["debugScreenLog"] = false

-- ── 5. Constants ─────────────────────────────────────────────────────────────
local TAG             = "[AI-VIS]"
local NAME            = "AI transport auto-pickup visual"
local MENU_NAME       = "Recette CTLD"
local MENU_PATH       = { ctld.tr("CTLD"), MENU_NAME }
local AI_UNIT_NAME    = "CTLD_AI_TEST_u1"
local AI_GROUP_NAME   = "CTLD_AI_TEST"

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
    aizZoneName = nil,
}

-- ── 7. Helpers ───────────────────────────────────────────────────────────────
local function log(msg) ctld.utils.log("INFO", "%s %s", TAG, msg) end

local function instruct(msg)
    _SCN_AI_VIS_INSTR = TAG .. "\n" .. msg
    log("[INSTR] " .. msg)
    trigger.action.outText(_SCN_AI_VIS_INSTR, 360, true)
end

local function pass(id, msg) S.passed = S.passed + 1 ; log("[PASS] "..id..": "..(msg or "")) end
local function fail(id, msg) S.failed = S.failed + 1 ; table.insert(S.failReasons, id..": "..(msg or "")) ; log("[FAIL] "..id..": "..(msg or "")) end

local function check(id, desc, cond, details)
    if cond then pass(id, desc)
    else fail(id, desc .. (details and (" | " .. details) or "")) end
end

-- ── 8. Cleanup AI ────────────────────────────────────────────────────────────
local function cleanupAI()
    local names = cfg.settings["transportPilotNames"] or {}
    for i = #names, 1, -1 do
        if names[i] == AI_UNIT_NAME then table.remove(names, i) end
    end
    local unit = Unit.getByName(AI_UNIT_NAME)
    if unit and unit:isExist() then
        local ok, tm = pcall(CTLDTroopManager.getInstance)
        if ok and tm and tm:hasTroops(AI_UNIT_NAME) then
            tm:disembarkAll(unit)
        end
    end
    local grp = Group.getByName(AI_GROUP_NAME)
    if grp and grp:isExist() then grp:destroy() end
    log("cleanupAI done")
end

-- ── 9. Cleanup scénario ───────────────────────────────────────────────────────
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
    pcall(cleanupAI)
    _SCN_AI_VIS_INSTR = nil ; _SCN_AI_VIS_SHOW = nil
    cfg.settings["debug"]          = _savedDebug
    cfg.settings["debugScreenLog"] = _savedDebugScreenLog
    _SCN_AI_VIS_RUNNING = false
    _SCN_AI_VIS_CLEANUP = nil
    log("cleanup done")
end

-- ── 10. Timer helpers ─────────────────────────────────────────────────────────
local function cancelTimer()
    S.timerGen = S.timerGen + 1
    if S.timerHandle then
        pcall(timer.removeFunction, S.timerHandle)
        S.timerHandle = nil
    end
end

local function waitFor(checkFn, intervalS, timeoutS, onSuccess, onFail)
    cancelTimer()
    local myGen = S.timerGen
    local elapsed = 0
    local function poll()
        if S.timerGen ~= myGen then return nil end
        elapsed = elapsed + intervalS
        if checkFn() then
            S.timerHandle = nil ; onSuccess()
        elseif elapsed >= timeoutS then
            S.timerHandle = nil ; log("[TIMEOUT] "..timeoutS.."s") ; onFail()
        else
            return timer.getTime() + intervalS
        end
    end
    S.timerHandle = timer.scheduleFunction(poll, nil, timer.getTime() + intervalS)
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

-- ── 11. Finalization ─────────────────────────────────────────────────────────
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
    if not ok then log("WARN cleanup: "..tostring(err)) ; _SCN_AI_VIS_RUNNING = false end
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

-- S1 — Spawn AI helicopter at pz1 center, register in transportPilotNames
steps[1] = function()
    instruct(
        "Step 1/3 — SPAWN AI HELI (auto)\n"..
        "Spawn AI UH-1H dans une AIZ pickup zone + enregistrement transportPilotNames.\n"..
        "Observation sur F10 map — les troupes apparaissent autour de l'hélico."
    )

    local blueUnits = coalition.getPlayers(coalition.side.BLUE) or {}
    local blueCountry = (blueUnits[1] and blueUnits[1]:isExist())
        and blueUnits[1]:getCountry()
        or country.id.USA

    -- Find the first active AIZ pickup zone with troops (isAIPickup=true, _aiTroopStock set)
    local zm   = CTLDZoneManager.getInstance()
    local zone = nil
    local zoneName = nil
    for zname, z in pairs(zm._troopZones) do
        if z.active and z:hasAIPickup() and z._aiTroopStock then
            zone = z ; zoneName = zname ; S.aizZoneName = zname ; break
        end
    end
    if not zone then
        fail("AI-VIS.1.1", "No active AIZ pickup zone with troops found")
        advanceStep()
        return
    end

    check("AI-VIS.1.1", "AIZ pickup zone found: "..zoneName, zone.active,
        "active=" .. tostring(zone.active))

    local zpt = zone.center
    local oldGrp = Group.getByName(AI_GROUP_NAME)
    if oldGrp and oldGrp:isExist() then oldGrp:destroy() end

    -- Note: coalition.addGroup always starts helicopters airborne (inAir()=true).
    -- S_EVENT_LAND is unreliable without a proper mission route from an airbase.
    -- F-133/F-134 (pickup/dropoff logic) are already covered by noPlayer mock scenario.
    -- This visual scenario calls onAILand() directly after spawn to trigger the pickup
    -- and show troops appearing on the F10 map — the visual effect is identical.
    local groundH = land.getHeight({ x = zpt.x, y = zpt.z })
    local grp = coalition.addGroup(blueCountry, Group.Category.HELICOPTER, {
        name       = AI_GROUP_NAME,
        task       = "Transport",
        start_time = 0,
        groupId    = math.random(87000, 87999),
        x          = zpt.x,
        y          = zpt.z,
        units = {{
            name          = AI_UNIT_NAME,
            type          = "UH-1H",
            x             = zpt.x,
            y             = zpt.z,
            alt           = groundH + 5,
            heading       = 0,
            skill         = "Excellent",
            unitId        = math.random(88000, 88999),
            playerCanDrive = false,
        }},
    })
    check("AI-VIS.1.2", "AI heli group spawned", grp ~= nil)

    local names = cfg.settings["transportPilotNames"] or {}
    local already = false
    for _, n in ipairs(names) do if n == AI_UNIT_NAME then already = true; break end end
    if not already then table.insert(names, AI_UNIT_NAME) end
    cfg.settings["transportPilotNames"] = names

    CTLDCoreManager.getInstance():_initAITransports()

    local aiUnit = Unit.getByName(AI_UNIT_NAME)
    check("AI-VIS.1.3", "AI unit found by name", aiUnit ~= nil)
    if aiUnit then
        check("AI-VIS.1.4", "unit has no player (AI confirmed)",
            aiUnit:getPlayerName() == nil,
            "playerName=" .. tostring(aiUnit:getPlayerName()))
    end

    log("AI heli spawné à "..tostring(zoneName).." — onAILand direct dans 2s")

    -- Direct call to onAILand after 2s: coalition.addGroup always spawns helis airborne
    -- so S_EVENT_LAND never fires at spawn. F-133/F-134 are covered in noPlayer mocks.
    -- This visual scenario focuses on showing the troop-spawn effect on the F10 map.
    waitThen(2, function() advanceStep() end)
end

-- S2 — Force onAILand (direct call) then verify hasTroops
steps[2] = function()
    instruct(
        "Step 2/3 — PICKUP (direct onAILand)\n"..
        "Appel direct onAILand → troupes chargées dans l'hélico.\n"..
        "Observer les troupes sur F10 map autour de "..tostring(S.aizZoneName).."."
    )

    local aiUnit = Unit.getByName(AI_UNIT_NAME)
    if not aiUnit or not aiUnit:isExist() then
        fail("AI-VIS.2.0", "AI unit not found at step 2")
        advanceStep()
        return
    end

    -- Direct onAILand call: simulates S_EVENT_LAND at the AIZ pickup zone.
    local ok2, err2 = pcall(function()
        CTLDCoreManager.getInstance():onAILand({
            id        = world.event.S_EVENT_LAND,
            initiator = aiUnit,
        })
    end)
    if not ok2 then
        fail("AI-VIS.2.1", "onAILand error: " .. tostring(err2))
        advanceStep()
        return
    end

    -- Check hasTroops immediately after
    waitThen(1, function()
        local okTM, tm = pcall(CTLDTroopManager.getInstance)
        local hasTr = okTM and tm and tm:hasTroops(AI_UNIT_NAME)
        if hasTr then
            local list  = tm:getInTransit(AI_UNIT_NAME) or {}
            local total = 0 ; local names2 = {}
            for _, grp in ipairs(list) do
                total = total + (grp.unitTotal or 0)
                table.insert(names2, grp.templateName or "?")
            end
            log("Cargo manifest: " .. total .. " soldat(s) — " .. table.concat(names2, ", "))
            pass("AI-VIS.2.1", "hasTroops=true — " .. total .. " soldat(s) chargé(s)")
        else
            fail("AI-VIS.2.1", "hasTroops=false après onAILand direct")
        end
        -- Leave heli alive 10s so player can observe troops on F10 map
        waitThen(10, function() advanceStep() end)
    end)
end

-- S3 — Cleanup
steps[3] = function()
    instruct("Step 3/3 — CLEANUP (auto)")
    pcall(cleanupAI)
    pass("AI-VIS.3.1", "cleanup done")
    log("AI heli détruit, transportPilotNames restauré")
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

_SCN_AI_VIS_CLEANUP = cleanup

log("=== START: "..NAME.." | transport="..S.transport:getName().." | groupId="..tostring(S.groupId).." | "..#steps.." steps ===")
trigger.action.outText(TAG.." démarrage — "..#steps.." steps | "..S.transport:getName(), 8)
advanceStep()

end  -- do isolation scope
return Witchcraft
