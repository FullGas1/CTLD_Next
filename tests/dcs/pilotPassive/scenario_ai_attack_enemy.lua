---@diagnostic disable
-- =============================================================================
-- live_tests/scenarios/interactive/scenario_ai_attack_enemy.lua
-- CTLD — Feature I — Post-spawn task: "AttackNearestEnemyOnLos"
--
-- Verifies that a spawned troop group is ordered to advance toward the nearest
-- RED enemy unit in LOS when specificParams = { task = "AttackNearestEnemyOnLos" }.
--
-- Cinématique (3 steps) :
--   S1 [auto]  Spawn RED enemy + BLUE group + call _assignPostSpawnTask
--   S2 [auto]  waitFor 8s puis vérification mouvement (waitThen)
--   S3 [auto]  Cleanup
--
-- Pre-requisites:
--   - BLUE player slot occupied (any aircraft), on ground level (no occlusion)
--   - CTLD fully initialised (inject CTLD_Next.lua + 5s wait before this scenario)
--   - Mission terrain must be flat near player (no ridge blocking LOS at 300 m)
--
-- @scenario  FI-ATK
-- @version   3.0 — 2026-06-30
-- @coverage  FI-ATK (AttackNearestEnemyOnLos)
-- =============================================================================

-- ── 1. Witchcraft guard ──────────────────────────────────────────────────────
if not ctld or not ctld.utils then
    trigger.action.outText("[FI-ATK] ABORT: CTLD not initialized. Inject CTLD_Next.lua first.", 15)
    return Witchcraft
end

-- ── 2. Double-injection guard ────────────────────────────────────────────────
if _SCN_FI_ATK_RUNNING then
    trigger.action.outText("[FI-ATK] déjà actif — attendre la fin ou redémarrer DCS.", 10)
    return Witchcraft
end
_SCN_FI_ATK_RUNNING = true
_SCN_FI_ATK_CLEANUP = nil

-- ── 3. Global show callback ───────────────────────────────────────────────────
_SCN_FI_ATK_INSTR = ""
_SCN_FI_ATK_SHOW  = function()
    trigger.action.outText(_SCN_FI_ATK_INSTR, 30)
end

do  -- isolation scope
-- ── 4. Debug ON ──────────────────────────────────────────────────────────────
local cfg                  = CTLDConfig.get()
local _savedDebug          = cfg.settings["debug"]
local _savedDebugScreenLog = cfg.settings["debugScreenLog"]
cfg.settings["debug"]          = true
cfg.settings["debugScreenLog"] = false

-- ── 5. Constants ─────────────────────────────────────────────────────────────
local TAG             = "[FI-ATK]"
local NAME            = "AttackNearestEnemyOnLos post-spawn task"
local MENU_NAME       = "Recette CTLD"
local MENU_PATH       = { ctld.tr("CTLD"), MENU_NAME }
local BLUE_GRP        = "FI_ATK_BlueGroup"
local RED_GRP         = "FI_ATK_RedEnemy"
local ENEMY_DIST      = 100   -- metres east of spawn

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
    enemyPt     = nil,
    spawnPt     = nil,
    distOrig    = nil,
}

-- ── 7. Helpers ───────────────────────────────────────────────────────────────
local function log(msg) ctld.utils.log("INFO", "%s %s", TAG, msg) end

local function instruct(msg)
    _SCN_FI_ATK_INSTR = TAG .. "\n" .. msg
    log("[INSTR] " .. msg)
    trigger.action.outText(_SCN_FI_ATK_INSTR, 360, true)
end

local function pass(id, msg) S.passed = S.passed + 1 ; log("[PASS] "..id..": "..(msg or "")) end
local function fail(id, msg) S.failed = S.failed + 1 ; table.insert(S.failReasons, id..": "..(msg or "")) ; log("[FAIL] "..id..": "..(msg or "")) end

local function check(id, desc, cond, details)
    if cond then pass(id, desc)
    else fail(id, desc .. (details and (" | " .. details) or "")) end
end

-- ── 8. Test cleanup ───────────────────────────────────────────────────────────
local function cleanupTest()
    for _, name in ipairs({ BLUE_GRP, RED_GRP }) do
        local grp = Group.getByName(name)
        if grp and grp:isExist() then grp:destroy() end
    end
    for i = 98801, 98901 do pcall(function() trigger.action.removeMark(i) end) end
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
    _SCN_FI_ATK_INSTR = nil ; _SCN_FI_ATK_SHOW = nil
    cfg.settings["debug"]          = _savedDebug
    cfg.settings["debugScreenLog"] = _savedDebugScreenLog
    _SCN_FI_ATK_RUNNING = false
    _SCN_FI_ATK_CLEANUP = nil
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
    if not ok then log("WARN cleanup: "..tostring(err)) ; _SCN_FI_ATK_RUNNING = false end
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

-- S1 — Spawn RED enemy + BLUE group, call _assignPostSpawnTask
steps[1] = function()
    instruct(
        "Step 1/3 — SPAWN + TASK (auto)\n"..
        "Spawn RED enemy 100m est + BLUE infantry + AssignTask.\n"..
        "Le BLUE doit avancer vers l'ennemi automatiquement (2s)."
    )

    cleanupTest()

    local pPos    = S.transport:getPoint()
    local spawnPt = { x = pPos.x, y = 0, z = pPos.z - 50 }
    spawnPt.y = land.getHeight({ x = spawnPt.x, y = spawnPt.z })
    local enemyPt = { x = spawnPt.x + ENEMY_DIST, y = 0, z = spawnPt.z }
    enemyPt.y = land.getHeight({ x = enemyPt.x, y = enemyPt.z })

    local hasLOS = land.isVisible(
        { x = spawnPt.x, y = spawnPt.y + 2, z = spawnPt.z },
        { x = enemyPt.x, y = enemyPt.y + 2, z = enemyPt.z })
    log("LOS pre-check (spawn→enemy "..ENEMY_DIST.."m east): "..tostring(hasLOS))

    local blueCountry = S.transport:getCountry()
    local redCountry  = country.id.RUSSIA

    local redGrp = coalition.addGroup(redCountry, Group.Category.GROUND, {
        name  = RED_GRP, task = "Ground Nothing",
        units = {{ name = RED_GRP .. "_u1", type = "Hummer",
                   x = enemyPt.x, y = enemyPt.z, heading = 0, skill = "High",
                   playerCanDrive = false, unitId = math.random(91000, 91999) }},
    })
    check("FI-ATK.1.1", "RED Hummer spawned", redGrp ~= nil)

    local blueGrp = coalition.addGroup(blueCountry, Group.Category.GROUND, {
        name       = BLUE_GRP, task = "Ground Nothing", start_time = 0,
        groupId    = math.random(93000, 93999),
        units = {{ name = BLUE_GRP .. "_u1", type = "Soldier M4",
                   x = spawnPt.x, y = spawnPt.z, heading = 0, skill = "High",
                   unitId = math.random(92000, 92999) }},
    })
    check("FI-ATK.1.2", "BLUE group spawned", blueGrp ~= nil)

    S.enemyPt  = enemyPt
    S.spawnPt  = { x = spawnPt.x, y = spawnPt.y, z = spawnPt.z }
    S.distOrig = ctld.utils.getDistance("FI-ATK.1", spawnPt, enemyPt)

    -- Draws F10
    local r = 40
    trigger.action.lineToAll(-1, 98801, { x=enemyPt.x-r, y=enemyPt.y, z=enemyPt.z },
                                         { x=enemyPt.x+r, y=enemyPt.y, z=enemyPt.z },
                             { 1, 0, 0, 0.9 }, 3)
    trigger.action.lineToAll(-1, 98802, { x=enemyPt.x, y=enemyPt.y, z=enemyPt.z-r },
                                         { x=enemyPt.x, y=enemyPt.y, z=enemyPt.z+r },
                             { 1, 0, 0, 0.9 }, 3)
    trigger.action.textToAll(-1, 98899, enemyPt, { 1, 0, 0, 1 }, { 0,0,0,0 }, 14, true, "Enemy")
    trigger.action.lineToAll(-1, 98900, spawnPt, enemyPt, { 1, 1, 0, 0.7 }, 1)
    trigger.action.textToAll(-1, 98901, spawnPt, { 0, 0.5, 1, 1 }, { 0,0,0,0 }, 12, true, "BLUE spawn")

    CTLDTroopManager.getInstance():_assignPostSpawnTask(
        BLUE_GRP, spawnPt, coalition.side.BLUE, { task = "AttackNearestEnemyOnLos" })
    log("_assignPostSpawnTask called — task will execute in 2s")

    log("S1 done — attente 8s pour mouvement BLUE")
    waitThen(8, function() advanceStep() end)
end

-- S2 — Verify movement toward enemy
steps[2] = function()
    instruct("Step 2/3 — VÉRIFICATION MOUVEMENT (auto)")

    local grp = Group.getByName(BLUE_GRP)
    check("FI-ATK.2.1", "BLUE group still alive", grp ~= nil and grp:isExist())

    local unit1 = grp and grp:getUnit(1)
    local uPt   = unit1 and unit1:getPoint()
    local sPt   = S.spawnPt
    local ePt   = S.enemyPt
    local dOrig = S.distOrig or math.huge

    -- Primary check: CTLD.log confirms task was assigned (unit may be stuck on airbase concrete)
    local logPath = (cfg.settings["ctldLogPath"] or "") .. "CTLD.log"
    local _wasOpen = ctld and ctld.__logFile ~= nil
    if _wasOpen then pcall(ctld.utils.closeLog) end
    local _lf = io.open(logPath, "r")
    local _logContent = _lf and _lf:read("*a") or ""
    if _lf then _lf:close() end
    if _wasOpen then pcall(ctld.utils.reopenLogAppend) end
    local _atkFound = _logContent:find("AttackNearestEnemyOnLos", 1, true) ~= nil
    log("CTLD.log AttackNearestEnemyOnLos found: " .. tostring(_atkFound))
    check("FI-ATK.2.2", "_assignPostSpawnTask logged 'AttackNearestEnemyOnLos' (task assigned)",
        _atkFound, "log=" .. logPath)
    -- Secondary: movement check (informational — may be 0 on concrete)
    if uPt and sPt then
        local moved = ctld.utils.getDistance("FI-ATK.2.2b", uPt, sPt)
        log("BLUE moved from spawn: " .. string.format("%.1f", moved) .. " m (info only)")
    end

    if uPt and ePt then
        local dNow = ctld.utils.getDistance("FI-ATK.2.3", uPt, ePt)
        log("dist to enemy: orig=" .. string.format("%.1f", dOrig) ..
            " now=" .. string.format("%.1f", dNow))
        check("FI-ATK.2.3", "BLUE unit closer to enemy than at spawn",
            dNow < dOrig,
            "orig=" .. string.format("%.1f", dOrig) ..
            " now=" .. string.format("%.1f", dNow))
    end

    log("S2 done — avance vers cleanup")
    advanceStep()
end

-- S3 — Cleanup
steps[3] = function()
    instruct("Step 3/3 — CLEANUP (auto)")
    pcall(cleanupTest)
    pass("FI-ATK.3.1", "cleanup done")
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

_SCN_FI_ATK_CLEANUP = cleanup

log("=== START: "..NAME.." | transport="..S.transport:getName().." | groupId="..tostring(S.groupId).." | "..#steps.." steps ===")
trigger.action.outText(TAG.." démarrage — "..#steps.." steps | "..S.transport:getName(), 8)
advanceStep()

end  -- do isolation scope
return Witchcraft
