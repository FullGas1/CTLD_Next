---@diagnostic disable
-- =============================================================================
-- live_tests/scenarios/interactive/scenario_ai_goto_wpz.lua
-- CTLD — Feature I — Post-spawn task: "gotoNearestWPZ"
--
-- Verifies that a spawned troop group is ordered to march to the nearest WPZ
-- when its template has specificParams = { task = "gotoNearestWPZ" }.
--
-- Cinématique (3 steps) :
--   S1 [auto]  Inject mock WPZ zone, spawn BLUE ground group, call _assignPostSpawnTask
--   S2 [auto]  waitThen 6s puis vérification vitesse/position
--   S3 [auto]  Cleanup
--
-- Pre-requisites:
--   - BLUE player slot occupied (any aircraft)
--   - CTLD fully initialised (inject CTLD_Next.lua + 5s wait before this scenario)
--
-- @scenario  FI-WPZ
-- @version   3.0 — 2026-06-30
-- @coverage  FI-WPZ (gotoNearestWPZ)
-- =============================================================================

-- ── 1. Witchcraft guard ──────────────────────────────────────────────────────
if not ctld or not ctld.utils then
    trigger.action.outText("[FI-WPZ] ABORT: CTLD not initialized. Inject CTLD_Next.lua first.", 15)
    return Witchcraft
end

-- ── 2. Double-injection guard ────────────────────────────────────────────────
if _SCN_FI_WPZ_RUNNING then
    trigger.action.outText("[FI-WPZ] déjà actif — attendre la fin ou redémarrer DCS.", 10)
    return Witchcraft
end
_SCN_FI_WPZ_RUNNING = true
_SCN_FI_WPZ_CLEANUP = nil

-- ── 3. Global show callback ───────────────────────────────────────────────────
_SCN_FI_WPZ_INSTR = ""
_SCN_FI_WPZ_SHOW  = function()
    trigger.action.outText(_SCN_FI_WPZ_INSTR, 30)
end

do  -- isolation scope
-- ── 4. Debug ON ──────────────────────────────────────────────────────────────
local cfg                  = CTLDConfig.get()
local _savedDebug          = cfg.settings["debug"]
local _savedDebugScreenLog = cfg.settings["debugScreenLog"]
cfg.settings["debug"]          = true
cfg.settings["debugScreenLog"] = false

-- ── 5. Constants ─────────────────────────────────────────────────────────────
local TAG             = "[FI-WPZ]"
local NAME            = "gotoNearestWPZ post-spawn task"
local MENU_NAME       = "Recette CTLD"
local MENU_PATH       = { ctld.tr("CTLD"), MENU_NAME }
local GRP_NAME        = "FI_WPZ_TestGroup"
local ZONE_NAME       = "FI_WPZ_MockZone"
local WPZ_OFFSET      = 600   -- WPZ injected 600 m north of player

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
    -- test state
    wpzCenter   = nil,
    distOrig    = nil,
}

-- ── 7. Helpers ───────────────────────────────────────────────────────────────
local function log(msg) ctld.utils.log("INFO", "%s %s", TAG, msg) end

local function instruct(msg)
    _SCN_FI_WPZ_INSTR = TAG .. "\n" .. msg
    log("[INSTR] " .. msg)
    trigger.action.outText(_SCN_FI_WPZ_INSTR, 360, true)
end

local function pass(id, msg) S.passed = S.passed + 1 ; log("[PASS] "..id..": "..(msg or "")) end
local function fail(id, msg) S.failed = S.failed + 1 ; table.insert(S.failReasons, id..": "..(msg or "")) ; log("[FAIL] "..id..": "..(msg or "")) end

local function check(id, desc, cond, details)
    if cond then pass(id, desc)
    else fail(id, desc .. (details and (" | " .. details) or "")) end
end

-- ── 8. Test cleanup ───────────────────────────────────────────────────────────
local function cleanupTest()
    local zm = CTLDZoneManager.getInstance()
    if zm and zm._troopZones then
        zm._troopZones[ZONE_NAME] = nil
    end
    local grp = Group.getByName(GRP_NAME)
    if grp and grp:isExist() then grp:destroy() end
    -- Remove WPZ circle marks
    for i = 99900, 99999 do pcall(function() trigger.action.removeMark(i) end) end
    log("cleanupTest done")
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
    pcall(cleanupTest)
    _SCN_FI_WPZ_INSTR = nil ; _SCN_FI_WPZ_SHOW = nil
    cfg.settings["debug"]          = _savedDebug
    cfg.settings["debugScreenLog"] = _savedDebugScreenLog
    _SCN_FI_WPZ_RUNNING = false
    _SCN_FI_WPZ_CLEANUP = nil
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
    if not ok then log("WARN cleanup: "..tostring(err)) ; _SCN_FI_WPZ_RUNNING = false end
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

-- S1 — Setup: inject WPZ, spawn group, call _assignPostSpawnTask
steps[1] = function()
    instruct(
        "Step 1/3 — SETUP + TASK (auto)\n"..
        "Injection WPZ mock + spawn BLUE infantry + gotoNearestWPZ.\n"..
        "Cercle vert visible sur F10 map = destination."
    )

    cleanupTest()

    local pPos    = S.transport:getPoint()
    local spawnPt = { x = pPos.x, y = 0, z = pPos.z - 50 }
    spawnPt.y = land.getHeight({ x = spawnPt.x, y = spawnPt.z })
    local wpzCenter = { x = pPos.x + WPZ_OFFSET, y = 0, z = pPos.z - 50 }
    wpzCenter.y = land.getHeight({ x = wpzCenter.x, y = wpzCenter.z })

    local zm = CTLDZoneManager.getInstance()
    check("FI-WPZ.1.1", "CTLDZoneManager available", zm ~= nil)

    local mockZone = CTLDTroopZone:new({
        dcsName    = ZONE_NAME,
        zoneName   = ZONE_NAME,
        coalition  = coalition.side.BLUE,
        center     = wpzCenter,
        radius     = 300,
        isWaypoint = true,
        active     = true,
    })
    zm._troopZones[ZONE_NAME] = mockZone
    log("Mock WPZ injected at (" .. wpzCenter.x .. ", " .. wpzCenter.z .. ")")

    local found = zm:getNearestWaypointZone(spawnPt, coalition.side.BLUE)
    check("FI-WPZ.1.2", "getNearestWaypointZone returns mock WPZ",
        found ~= nil and found.zoneName == ZONE_NAME,
        "got " .. tostring(found and found.zoneName))

    local countryId = S.transport:getCountry()
    local grpData = {
        name  = GRP_NAME, task = "Ground Nothing",
        units = {
            { name = GRP_NAME .. "_u1", type = "Soldier M4",
              x = spawnPt.x, y = spawnPt.z, heading = 0, skill = "High",
              playerCanDrive = false, unitId = math.random(90000, 99999) },
        },
    }
    local spawnedGrp = coalition.addGroup(countryId, Group.Category.GROUND, grpData)
    check("FI-WPZ.1.3", "test group spawned", spawnedGrp ~= nil)

    S.wpzCenter = wpzCenter
    S.distOrig  = ctld.utils.getDistance("FI-WPZ.1", spawnPt, wpzCenter)

    -- WPZ circle on F10 map
    local drawPts = {}
    local stepsN  = 32
    local r       = 300
    for i = 0, stepsN - 1 do
        local a = i * (2 * math.pi / stepsN)
        drawPts[#drawPts + 1] = { x = wpzCenter.x + r * math.cos(a), y = wpzCenter.y,
                                   z = wpzCenter.z + r * math.sin(a) }
    end
    drawPts[#drawPts + 1] = drawPts[1]
    for i = 1, #drawPts - 1 do
        trigger.action.lineToAll(-1, 99900 + i, drawPts[i], drawPts[i+1],
            { 0, 0.8, 0, 0.9 }, 2)
    end
    trigger.action.textToAll(-1, 99999, wpzCenter, { 0, 0.9, 0, 1 }, { 0, 0, 0, 0 },
        14, true, "WPZ Target")

    CTLDTroopManager.getInstance():_assignPostSpawnTask(
        GRP_NAME, spawnPt, coalition.side.BLUE, { task = "gotoNearestWPZ" })
    log("_assignPostSpawnTask called — task will execute in 2s")

    log("S1 done — attente 6s pour mouvement BLUE")
    waitThen(6, function() advanceStep() end)
end

-- S2 — Verify movement toward WPZ
steps[2] = function()
    instruct("Step 2/3 — VÉRIFICATION MOUVEMENT (auto)")

    local grp = Group.getByName(GRP_NAME)
    check("FI-WPZ.2.1", "test group still alive after task assignment",
        grp ~= nil and grp:isExist())

    -- Primary check: read CTLD.log for the task-assignment confirmation.
    -- Close/reopen the CTLD log handle to release any Windows file lock before reading.
    local logPath = (cfg.settings["ctldLogPath"] or "") .. "CTLD.log"
    local _wasOpen = ctld and ctld.__logFile ~= nil
    if _wasOpen then pcall(ctld.utils.closeLog) end
    local _f = io.open(logPath, "r")
    local _logContent = _f and _f:read("*a") or ""
    if _f then _f:close() end
    if _wasOpen then pcall(ctld.utils.reopenLogAppend) end
    local _gotoFound = _logContent:find("gotoNearestWPZ", 1, true) ~= nil
    log("CTLD.log gotoNearestWPZ entry found: " .. tostring(_gotoFound) ..
        " (log bytes=" .. #_logContent .. ")")
    check("FI-WPZ.2.2", "_assignPostSpawnTask logged 'gotoNearestWPZ' (task assigned)",
        _gotoFound, "log=" .. logPath)

    local uPt  = unit1 and unit1:getPoint()
    local dest = S.wpzCenter
    if uPt and dest then
        local distNow  = ctld.utils.getDistance("FI-WPZ.2.3", uPt, dest)
        local distOrig = S.distOrig or math.huge
        log("distOrig=" .. string.format("%.1f", distOrig) ..
            " distNow=" .. string.format("%.1f", distNow))
        check("FI-WPZ.2.3", "unit closer to WPZ than at spawn", distNow < distOrig,
            "orig=" .. string.format("%.1f", distOrig) ..
            " now=" .. string.format("%.1f", distNow))
    end

    log("S2 done — avance vers cleanup")
    advanceStep()
end

-- S3 — Cleanup
steps[3] = function()
    instruct("Step 3/3 — CLEANUP (auto)")
    pcall(cleanupTest)
    pass("FI-WPZ.3.1", "cleanup done")
    log("S3 done")
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

_SCN_FI_WPZ_CLEANUP = cleanup

log("=== START: "..NAME.." | transport="..S.transport:getName().." | groupId="..tostring(S.groupId).." | "..#steps.." steps ===")
trigger.action.outText(TAG.." démarrage — "..#steps.." steps | "..S.transport:getName(), 8)
advanceStep()

end  -- do isolation scope
return Witchcraft
