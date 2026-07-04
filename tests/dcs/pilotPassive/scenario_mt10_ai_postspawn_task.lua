---@diagnostic disable
-- =============================================================================
-- tests/dcs/pilotPassive/scenario_mt10_ai_postspawn_task.lua
-- CTLD — AI post-spawn task assignment: gotoNearestWPZ + AttackNearestEnemyOnLos
--
-- Chaque run spawne des clones des groupes IA via env.mission + coalition.addGroup,
-- puis les détruit en cleanup. Les groupes late-activation du .miz (heliai_mt10a/b)
-- ne sont jamais activés : répétable sans redémarrage de mission.
--
-- Prérequis mission :
--   - heliai_mt10a : UH-1H BLUE, AI, activation retardée (jamais activé, template seul)
--   - heliai_mt10b : UH-1H BLUE, AI, activation retardée (jamais activé, template seul)
--   - AIZ_depot_B_P_T_10   : zone pickup T, stock=10, r~60m
--   - AIZ_mt10d_B_D_G      : zone dropoff G (sol), r~274m
--   - WPZ_mt10_B           : zone waypoint BLUE (clé parsée "mt10")
--   - mt10_enemy_RED       : groupe sol RED, <3 km de AIZ_livraison, LOS dégagée
--   - ctldLogPath défini dans le .miz (trigger MISSION START)
--   - Slot BLUE occupé (joueur humain pour MenuManager)
--   - CTLD_Next.lua injecté avant ce script (attendre 3-5 s)
--
-- Cinématique (6 steps, injection unique) :
--   S1 [auto]  Setup A : vérifie prérequis, spawne clone mt10a_run, force template WPZ
--   S2 [auto]  Attente cycle complet A (pickup → dropoff) via waitFor deux-phases
--   S3 [auto]  Vérification A : CTLD.log contient gotoNearestWPZ → 'mt10'
--   S4 [auto]  Setup B : reset stock, spawne clone mt10b_run, force template Attack
--   S5 [auto]  Attente cycle complet B (pickup → dropoff) via waitFor deux-phases
--   S6 [auto]  Vérification B : CTLD.log contient AttackNearestEnemyOnLos avec coords
--
-- @scenario  MT-10
-- @version   4.0 — 2026-07-01
-- @coverage  AI gotoNearestWPZ, AI AttackNearestEnemyOnLos
-- =============================================================================

-- ── 1. Witchcraft guard ──────────────────────────────────────────────────────
if not ctld or not ctld.utils then
    trigger.action.outText("[MT-10] ABORT: CTLD not initialized. Inject CTLD_Next.lua first.", 15)
    return Witchcraft
end

-- ── 2. Double-injection guard ────────────────────────────────────────────────
if _SCN_MT10_RUNNING then
    trigger.action.outText("[MT-10] déjà actif — attendre la fin ou redémarrer DCS.", 10)
    return Witchcraft
end
_SCN_MT10_RUNNING = true
_SCN_MT10_CLEANUP = nil

-- ── 3. Global show callback ──────────────────────────────────────────────────
_SCN_MT10_INSTR = ""
_SCN_MT10_SHOW  = function()
    trigger.action.outText(_SCN_MT10_INSTR, 30)
end

do  -- isolation scope
-- ── 4. Debug ON ──────────────────────────────────────────────────────────────
local cfg                  = CTLDConfig.get()
local _savedDebug          = cfg.settings["debug"]
local _savedDebugScreenLog = cfg.settings["debugScreenLog"]
cfg.settings["debug"]          = true
cfg.settings["debugScreenLog"] = false

-- ── 5. Constants ─────────────────────────────────────────────────────────────
local TAG       = "[MT-10]"
local NAME      = "AI post-spawn task: gotoNearestWPZ + AttackNearestEnemyOnLos"
local MENU_NAME = "Recette CTLD"
local MENU_PATH = { ctld.tr("CTLD"), MENU_NAME }

-- Sources dans la mission (late-activation, jamais activés — servent de templates)
local AI_SRC_A  = "heliai_mt10a"
local AI_SRC_B  = "heliai_mt10b"
-- Noms des clones spawned dynamiquement (utilisés dans tous les checks CTLD)
local AI_UNIT_A = "mt10a_run"
local AI_UNIT_B = "mt10b_run"

local AIZ_P     = "AIZ_depot_B_P_T_10"
local AIZ_D     = "AIZ_mt10d_B_D_G"
local WPZ_KEY   = "mt10"
local ENEMY_GRP = "mt10_enemy_RED"

-- ── 6. State ─────────────────────────────────────────────────────────────────
local S = {
    step           = 0,
    passed         = 0,
    failed         = 0,
    failReasons    = {},
    groupId        = nil,
    timerHandle    = nil,
    timerGen       = 0,
    transport      = nil,
    forcedTmplKey  = nil,
    savedSP        = nil,
}

-- ── 7. Helpers ───────────────────────────────────────────────────────────────
local function log(msg) ctld.utils.log("INFO", "%s %s", TAG, msg) end

local function instruct(msg)
    _SCN_MT10_INSTR = TAG .. "\n" .. msg
    log("[INSTR] " .. msg)
    trigger.action.outText(_SCN_MT10_INSTR, 360, true)
end

local function pass(id, msg) S.passed = S.passed + 1 ; log("[PASS] "..id..": "..(msg or "")) end
local function fail(id, msg) S.failed = S.failed + 1 ; table.insert(S.failReasons, id..": "..(msg or "")) ; log("[FAIL] "..id..": "..(msg or "")) end

local function check(id, desc, cond, details)
    if cond then pass(id, desc)
    else fail(id, desc .. (details and (" | "..details) or "")) end
end

-- Deep copy de table (env.mission retourne des tables non copiables par ctld.utils.deepCopy)
local function deepCopy(orig)
    local copy
    if type(orig) == "table" then
        copy = {}
        for k, v in pairs(orig) do copy[deepCopy(k)] = deepCopy(v) end
        setmetatable(copy, getmetatable(orig))
    else
        copy = orig
    end
    return copy
end

-- Cherche un groupe par nom dans env.mission ; retourne (groupData, countryId) ou (nil, nil)
local function findGrpInMission(name)
    for _, cData in pairs(env.mission.coalition or {}) do
        for _, country in ipairs(cData.country or {}) do
            for _, cat in ipairs({"helicopter", "plane", "vehicle", "ship"}) do
                for _, grp in ipairs((country[cat] or {}).group or {}) do
                    if grp.name == name then return grp, country.id end
                end
            end
        end
    end
    return nil, nil
end

-- Spawne un clone du groupe srcName nommé cloneName ; retourne (group, nil) ou (nil, errMsg)
-- L'unité du clone est nommée cloneName pour compatibilité CTLD transportPilotNames.
local function spawnClone(srcName, cloneName)
    local tmpl, ctryId = findGrpInMission(srcName)
    if not tmpl then return nil, "not found in env.mission: " .. srcName end
    local clone = deepCopy(tmpl)
    clone.name            = cloneName
    clone.units[1].name   = cloneName   -- nom unité = nom groupe → Unit.getByName(cloneName) OK
    clone.groupId         = nil
    clone.units[1].unitId = nil
    clone.lateActivation  = false       -- forcer activation immédiate au spawn
    local ok, _ = pcall(coalition.addGroup, ctryId, Group.Category.HELICOPTER, clone)
    if not ok then return nil, "coalition.addGroup failed for " .. cloneName end
    local g = Group.getByName(cloneName)
    if not g then return nil, "group not found after spawn: " .. cloneName end
    return g, nil
end

-- Scan CTLD.log for a keyword; return last matching line found AFTER startMarker line.
-- If startMarker is nil, scans the whole file (fallback).
local function scanLogAfter(startMarker, keyword)
    pcall(ctld.utils.closeLog)
    local logPath = (cfg.settings["ctldLogPath"] or "") .. "CTLD.log"
    local f = io.open(logPath, "r")
    pcall(ctld.utils.reopenLogAppend)
    if not f then return nil end
    local afterMarker = (startMarker == nil)
    local lastMatch = nil
    for line in f:lines() do
        if not afterMarker and string.find(line, startMarker, 1, true) then
            afterMarker = true
        end
        if afterMarker and string.find(line, keyword, 1, true) then
            lastMatch = line
        end
    end
    f:close()
    return lastMatch
end

-- Find first non-JTAC template fitting within AIZ_P stock and transport capacity.
local function findBaseTemplate(tm, typeName)
    local zm  = CTLDZoneManager.getInstance()
    local zP  = zm._troopZones[AIZ_P]
    local rawStock = (zP and zP.pickMaxStock) or 0
    local caps = (ctld.gs("capabilitiesByType") or {})[typeName or ""] or {}
    local transportLimit = caps.maxTroopsOnboard or ctld.gs("numberOfTroops") or 10
    local maxStock = (rawStock > 0) and rawStock or transportLimit
    local effectiveMax = math.min(maxStock, transportLimit)
    for _, t in ipairs(tm._templates) do
        if not t.disabled and not t.hasJtac and (t.total or 0) <= effectiveMax and (t.total or 0) > 0 then
            return t
        end
    end
    return nil
end

-- Force _aiTeams[2] to a single template with a given task.
local function forceAITeam(core, tm, taskName, unitName)
    local u2 = Unit.getByName(unitName)
    local typeName = u2 and u2:getTypeName() or ""
    if typeName == "" then
        local g2 = Group.getByName(unitName)
        local u3 = g2 and g2:getUnit(1)
        typeName = u3 and u3:getTypeName() or ""
    end
    local baseTmpl = findBaseTemplate(tm, typeName)
    if not baseTmpl then return nil, "no base template found (total<=transportLimit)" end
    S.forcedTmplKey = baseTmpl._dbKey or baseTmpl.name
    S.savedSP       = baseTmpl.specificParams
    baseTmpl.specificParams = { task = taskName }
    core._aiTeams[2] = { baseTmpl }
    local names = cfg.settings["transportPilotNames"] or {}
    local alreadyIn = false
    for _, n in ipairs(names) do if n == unitName then alreadyIn = true; break end end
    if not alreadyIn then table.insert(names, unitName) end
    cfg.settings["transportPilotNames"] = names
    return baseTmpl, nil
end

-- Détruit un clone spawned si existant
local function destroyClone(cloneName)
    local g = Group.getByName(cloneName)
    if g and g:isExist() then
        pcall(function() g:destroy() end)
        log("clone destroyed: " .. cloneName)
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
    -- Retirer les clones de transportPilotNames
    local names = cfg.settings["transportPilotNames"] or {}
    for i = #names, 1, -1 do
        if names[i] == AI_UNIT_A or names[i] == AI_UNIT_B then table.remove(names, i) end
    end
    -- Restaurer specificParams du template forcé
    if S.forcedTmplKey then
        local ok2, tm2 = pcall(CTLDTroopManager.getInstance)
        if ok2 and tm2 then
            for _, t in ipairs(tm2._templates) do
                if (t._dbKey or t.name) == S.forcedTmplKey then
                    t.specificParams = S.savedSP
                    break
                end
            end
        end
    end
    S.forcedTmplKey = nil ; S.savedSP = nil
    -- Détruire les clones spawned
    destroyClone(AI_UNIT_A)
    destroyClone(AI_UNIT_B)
    -- Détruire les troupes déposées pendant le scénario
    local ok3, tm3 = pcall(CTLDTroopManager.getInstance)
    if ok3 and tm3 and tm3._droppedGroups then
        for _, grpName in ipairs(tm3._droppedGroups[2] or {}) do
            local tg = Group.getByName(grpName)
            if tg and tg:isExist() then pcall(function() tg:destroy() end) end
        end
        tm3._droppedGroups[2] = {}
        log("dropped troops destroyed")
    end
    local ok, core = pcall(CTLDCoreManager.getInstance)
    if ok and core then core:_initAITransports() end
    _SCN_MT10_INSTR = nil ; _SCN_MT10_SHOW = nil
    cfg.settings["debug"]          = _savedDebug
    cfg.settings["debugScreenLog"] = _savedDebugScreenLog
    _SCN_MT10_RUNNING = false
    _SCN_MT10_CLEANUP = nil
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
    if not ok then log("WARN cleanup: "..tostring(err)) ; _SCN_MT10_RUNNING = false end
end

-- ── 11. Step runner ──────────────────────────────────────────────────────────
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

-- Marqueurs de début de cycle pour scanLogAfter (écrits dans le log au début de chaque setup)
local MARKER_A = "MT10_CYCLE_A_START"
local MARKER_B = "MT10_CYCLE_B_START"

-- S1 — Setup A : vérifie prérequis, spawne clone mt10a_run, force template WPZ [auto]
steps[1] = function()
    instruct(
        "Step 1/6 — SETUP A : WPZ TASK (MT-10)\n"..
        "Spawn clone "..AI_UNIT_A.." et configuration gotoNearestWPZ…"
    )
    waitThen(1, function()
        log(MARKER_A)   -- marqueur début cycle A pour scanLogAfter
        cfg.settings["transportPilotNames"] = { AI_UNIT_A }
        CTLDCoreManager.getInstance():_initAITransports()

        local zm   = CTLDZoneManager.getInstance()
        local tm   = CTLDTroopManager.getInstance()
        local core = CTLDCoreManager.getInstance()

        local zP = zm._troopZones[AIZ_P]
        local zD = zm._troopZones[AIZ_D]
        check("MT-10.1.1", "AIZ_P trouvée: "..AIZ_P, zP ~= nil)
        check("MT-10.1.2", "AIZ_D trouvée: "..AIZ_D, zD ~= nil)
        if zP then
            check("MT-10.1.3", "AIZ_P.isAIPickup=true",  zP.isAIPickup == true)
            check("MT-10.1.4", "AIZ_P.aiCargoType=T",    zP.aiCargoType == "T")
            if zP.pickMaxStock and zP.pickMaxStock > 0 then
                zP.pickCurrentStock = zP.pickMaxStock
                log("Step 1: AIZ_P stock reset to " .. zP.pickMaxStock)
            end
        end
        if zD then
            check("MT-10.1.5", "AIZ_D.isAIDropoff=true", zD.isAIDropoff == true)
        end

        local wpzZone = zm._troopZones[WPZ_KEY]
        check("MT-10.1.6", "WPZ trouvée (clé='"..WPZ_KEY.."')", wpzZone ~= nil)
        if wpzZone then
            check("MT-10.1.7", "WPZ.isWaypoint=true", wpzZone.isWaypoint == true,
                "isWaypoint="..tostring(wpzZone.isWaypoint))
        end

        local enemyGrp = Group.getByName(ENEMY_GRP)
        check("MT-10.1.8", "Groupe ennemi RED: "..ENEMY_GRP, enemyGrp ~= nil)

        -- Spawn clone A depuis env.mission (ne jamais activer le groupe source)
        local cloneA, errA = spawnClone(AI_SRC_A, AI_UNIT_A)
        check("MT-10.1.11", "Clone "..AI_UNIT_A.." spawné depuis "..AI_SRC_A, cloneA ~= nil, errA)

        local tmplWPZ, errT = forceAITeam(core, tm, "gotoNearestWPZ", AI_UNIT_A)
        check("MT-10.1.9",  "Template WPZ créé (total<=transportLimit)", tmplWPZ ~= nil, errT)
        check("MT-10.1.10", "_aiTeams[2] forcé sur 1 template", #core._aiTeams[2] == 1)
        if tmplWPZ then
            log("Template: '"..tmplWPZ.name.."' total="..tmplWPZ.total.." task="..tmplWPZ.specificParams.task)
        end

        log("STEP 1 OK — clone "..AI_UNIT_A.." spawné, attente cycle complet (pickup + dropoff)")
        advanceStep()
    end)
end

-- S2 — Attente cycle complet A : phase 1 pickup, phase 2 dropoff [waitFor deux-phases]
steps[2] = function()
    instruct(
        "Step 2/6 — ATTENTE PICKUP A (MT-10)\n"..
        "Attente que "..AI_UNIT_A.." charge les troupes (hasTroops=true).\n"..
        "Timeout : 900 s."
    )
    -- Phase 1 : attente pickup (hasTroops=true)
    waitFor(
        function()
            local tm = CTLDTroopManager.getInstance()
            return tm:hasTroops(AI_UNIT_A)
        end,
        5, 900,
        function()
            log("Cycle A : pickup OK — hasTroops=true, attente dropoff...")
            instruct(
                "Step 2/6 — ATTENTE DROPOFF A (MT-10)\n"..
                "Troupes chargées. Attente dépôt (hasTroops=false).\n"..
                "Timeout : 900 s."
            )
            -- Phase 2 : attente dropoff (hasTroops=false)
            waitFor(
                function()
                    local tm = CTLDTroopManager.getInstance()
                    return not tm:hasTroops(AI_UNIT_A)
                end,
                5, 900,
                function()
                    local tm    = CTLDTroopManager.getInstance()
                    local hasTr = tm:hasTroops(AI_UNIT_A)
                    check("MT-10.2.1", "hasTroops=false (cycle complet)", not hasTr,
                        "hasTroops="..tostring(hasTr))
                    local deployed = {}
                    local tm2 = CTLDTroopManager.getInstance()
                    for _, grpName in ipairs(tm2._droppedGroups[2] or {}) do
                        deployed[#deployed + 1] = grpName
                    end
                    check("MT-10.2.4", "Au moins 1 groupe BLUE déposé", #deployed > 0, "count="..#deployed)
                    log("Cycle A terminé — attente 3s pour lecture log")
                    waitThen(3, function() advanceStep() end)
                end,
                function()
                    fail("MT-10.2.1", "timeout 900s — dropoff cycle A pas terminé")
                    advanceStep()
                end
            )
        end,
        function()
            fail("MT-10.2.1", "timeout 900s — pickup cycle A pas commencé (hasTroops jamais true)")
            advanceStep()
        end
    )
end

-- S3 — Vérification A : CTLD.log contient gotoNearestWPZ [auto]
steps[3] = function()
    instruct(
        "Step 3/6 — VÉRIF LOG A (MT-10)\n"..
        "Lecture du CTLD.log pour gotoNearestWPZ → '"..WPZ_KEY.."'…"
    )
    waitThen(3, function()  -- délai 3s pour flush log
        local logLine = scanLogAfter(MARKER_A, "_assignPostSpawnTask")
        check("MT-10.2.2", "CTLD.log contient '_assignPostSpawnTask' (cycle A)",
            logLine ~= nil, logLine or "aucune ligne après "..MARKER_A)
        if logLine then
            trigger.action.outText(TAG.." Log A: "..logLine, 30)
            check("MT-10.2.3", "Tâche = 'gotoNearestWPZ'",
                string.find(logLine, "gotoNearestWPZ", 1, true) ~= nil, "ligne="..logLine)
            check("MT-10.2.4b", "Cible = WPZ '"..WPZ_KEY.."'",
                string.find(logLine, WPZ_KEY, 1, true) ~= nil, "ligne="..logLine)
        end
        -- Détruire le clone A maintenant que le cycle est terminé
        destroyClone(AI_UNIT_A)
        log("STEP 3 OK — Sub-test A WPZ validé, passage au setup B")
        advanceStep()
    end)
end

-- S4 — Setup B : reset stock, spawne clone mt10b_run, force template Attack [auto]
steps[4] = function()
    instruct(
        "Step 4/6 — SETUP B : ATTACK TASK (MT-10)\n"..
        "Spawn clone "..AI_UNIT_B.." et configuration AttackNearestEnemyOnLos…"
    )
    waitThen(1, function()
        log(MARKER_B)   -- marqueur début cycle B pour scanLogAfter
        local zm   = CTLDZoneManager.getInstance()
        local tm   = CTLDTroopManager.getInstance()
        local core = CTLDCoreManager.getInstance()

        -- Reset stock AIZ_P
        local zP = zm._troopZones[AIZ_P]
        if zP and zP.pickMaxStock and zP.pickMaxStock > 0 then
            zP.pickCurrentStock = zP.pickMaxStock
            log("Stock AIZ_P reset: cur="..zP.pickCurrentStock)
        end

        -- Restaurer specificParams du template forcé de la phase A
        if S.forcedTmplKey then
            for _, t in ipairs(tm._templates) do
                if (t._dbKey or t.name) == S.forcedTmplKey then
                    t.specificParams = S.savedSP ; break
                end
            end
            S.forcedTmplKey = nil ; S.savedSP = nil
        end

        -- Spawn clone B depuis env.mission
        local cloneB, errB = spawnClone(AI_SRC_B, AI_UNIT_B)
        check("MT-10.3.4", "Clone "..AI_UNIT_B.." spawné depuis "..AI_SRC_B, cloneB ~= nil, errB)

        local tmplAttack, errT = forceAITeam(core, tm, "AttackNearestEnemyOnLos", AI_UNIT_B)
        core._aiPilotNames[AI_UNIT_B] = true
        check("MT-10.3.1", "Template Attack créé (total<=transportLimit)", tmplAttack ~= nil, errT)
        check("MT-10.3.2", "_aiTeams[2] forcé sur 1 template", #core._aiTeams[2] == 1)
        if tmplAttack then
            log("Template: '"..tmplAttack.name.."' total="..tmplAttack.total.." task="..tmplAttack.specificParams.task)
        end

        local enemyGrp = Group.getByName(ENEMY_GRP)
        local alive = enemyGrp ~= nil and enemyGrp:getSize() > 0
        check("MT-10.3.3", "Ennemi RED vivant pour LOS", alive)

        log("STEP 4 OK — clone "..AI_UNIT_B.." spawné, attente cycle complet")
        advanceStep()
    end)
end

-- S5 — Attente cycle complet B : phase 1 pickup, phase 2 dropoff [waitFor deux-phases]
steps[5] = function()
    instruct(
        "Step 5/6 — ATTENTE PICKUP B (MT-10)\n"..
        "Attente que "..AI_UNIT_B.." charge les troupes (hasTroops=true).\n"..
        "Timeout : 900 s."
    )
    -- Phase 1 : attente pickup (hasTroops=true)
    waitFor(
        function()
            local tm = CTLDTroopManager.getInstance()
            return tm:hasTroops(AI_UNIT_B)
        end,
        5, 900,
        function()
            log("Cycle B : pickup OK — hasTroops=true, attente dropoff...")
            instruct(
                "Step 5/6 — ATTENTE DROPOFF B (MT-10)\n"..
                "Troupes chargées. Attente dépôt (hasTroops=false).\n"..
                "Timeout : 900 s."
            )
            -- Phase 2 : attente dropoff (hasTroops=false)
            waitFor(
                function()
                    local tm = CTLDTroopManager.getInstance()
                    return not tm:hasTroops(AI_UNIT_B)
                end,
                5, 900,
                function()
                    local tm    = CTLDTroopManager.getInstance()
                    local hasTr = tm:hasTroops(AI_UNIT_B)
                    check("MT-10.4.1", "hasTroops=false (cycle complet)", not hasTr,
                        "hasTroops="..tostring(hasTr))
                    log("Cycle B terminé — attente 3s pour lecture log")
                    waitThen(3, function() advanceStep() end)
                end,
                function()
                    fail("MT-10.4.1", "timeout 900s — dropoff cycle B pas terminé")
                    advanceStep()
                end
            )
        end,
        function()
            fail("MT-10.4.1", "timeout 900s — pickup cycle B pas commencé (hasTroops jamais true)")
            advanceStep()
        end
    )
end

-- S6 — Vérification B : CTLD.log contient AttackNearestEnemyOnLos [auto]
steps[6] = function()
    instruct(
        "Step 6/6 — VÉRIF LOG B (MT-10)\n"..
        "Lecture du CTLD.log pour AttackNearestEnemyOnLos…"
    )
    waitThen(3, function()  -- délai 3s pour flush log
        local logLine = scanLogAfter(MARKER_B, "_assignPostSpawnTask")
        if logLine and not string.find(logLine, "AttackNearestEnemyOnLos", 1, true) then
            logLine = nil
        end
        if not logLine then
            local enemyGrp = Group.getByName(ENEMY_GRP)
            local diagInfo = "groupe="..ENEMY_GRP.." present="..tostring(enemyGrp ~= nil)
            if enemyGrp then
                local u0 = enemyGrp:getUnit(1)
                if u0 then
                    local ePos = u0:getPoint()
                    local zm2  = CTLDZoneManager.getInstance()
                    local zD2  = zm2._troopZones[AIZ_D]
                    if zD2 then
                        local dist = ctld.utils.getDistance("mt10diag", zD2:getCenter(), ePos)
                        local maxDist = ctld.gs("maximumSearchDistance") or 4000
                        diagInfo = diagInfo.." dist="..math.floor(dist).."m maxDist="..maxDist
                    end
                end
            end
            log("DIAG ennemi: "..diagInfo)
        end
        check("MT-10.4.2", "CTLD.log contient 'AttackNearestEnemyOnLos'", logLine ~= nil,
            logLine or "ennemi hors portée ou pas en LOS")
        if logLine then
            trigger.action.outText(TAG.." Log B: "..logLine, 30)
            local hasCoords = string.find(logLine, "%d+%.%d") ~= nil
            check("MT-10.4.3", "Coordonnées cible loggées (ennemi en LOS)", hasCoords,
                "ligne="..logLine)
        end
        log("MT-10 ALL — gotoNearestWPZ + AttackNearestEnemyOnLos validés")
        advanceStep()
    end)
end

-- ── 13. Start ────────────────────────────────────────────────────────────────
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

_SCN_MT10_CLEANUP = cleanup

log("=== START: "..NAME.." | transport="..S.transport:getName().." | groupId="..tostring(S.groupId).." | "..#steps.." steps ===")
trigger.action.outText(TAG.." démarrage — "..#steps.." steps | "..S.transport:getName(), 8)
advanceStep()

end  -- do isolation scope
return Witchcraft
