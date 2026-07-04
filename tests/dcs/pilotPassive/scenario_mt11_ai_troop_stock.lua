---@diagnostic disable
-- =============================================================================
-- live_tests/scenarios/interactive/scenario_mt11_ai_troop_stock.lua
-- CTLD — AI auto-pickup avec 2 troopTemplates assignés à une AIZ_P (Feature T)
--
-- Mini-application de recette interactive : injection unique, avance
-- automatiquement (waitFor) pour détecter le pickup et le dropoff.
--
-- Prérequis :
--   - Héli BLUE nommé "heliai_mt11" (UH-1H), sans pilote humain
--   - Route : WP1 = posé sur AIZ_mt11_B_P_T → WP3 = posé sur AIZ_mt11_B_D
--   - Zone DCS trigger "AIZ_mt11_B_P_T" (rayon ~200 m)
--   - Zone DCS trigger "AIZ_mt11_B_D"   (rayon ~200 m)
--   - troopStock = { ["Standard Group"]=3, ["Anti Tank"]=2 } dans la config zone
--   - Slot BLUE occupé (joueur humain pour MenuManager)
--   - CTLD_Next.lua injecté avant ce script (attendre 3-5 s)
--
-- Cinématique (4 steps, injection unique) :
--   S1 [auto]  Init + vérification zones + stocks initiaux
--   S2 [auto]  Attente pickup (hasTroops=true + template + stock décrémenté) via waitFor
--   S3 [auto]  Attente dropoff (hasTroops=false) via waitFor
--   S4 [auto]  Finalisation
--
-- @scenario  MT-11
-- @version   4.0 — 2026-07-01
-- @coverage  AI pickup troopStock, AI dropoff troopStock (clone spawn, repeatable)
-- =============================================================================

-- ── 1. Witchcraft guard ──────────────────────────────────────────────────────
if not ctld or not ctld.utils then
    trigger.action.outText("[MT-11] ABORT: CTLD not initialized. Inject CTLD_Next.lua first.", 15)
    return Witchcraft
end

-- ── 2. Double-injection guard ────────────────────────────────────────────────
if _SCN_MT11_RUNNING then
    trigger.action.outText("[MT-11] déjà actif — attendre la fin ou redémarrer DCS.", 10)
    return Witchcraft
end
_SCN_MT11_RUNNING = true
_SCN_MT11_CLEANUP = nil

-- ── 3. Global show callback ──────────────────────────────────────────────────
_SCN_MT11_INSTR = ""
_SCN_MT11_SHOW  = function()
    trigger.action.outText(_SCN_MT11_INSTR, 30)
end

do  -- isolation scope
-- ── 4. Debug ON ──────────────────────────────────────────────────────────────
local cfg                  = CTLDConfig.get()
local _savedDebug          = cfg.settings["debug"]
local _savedDebugScreenLog = cfg.settings["debugScreenLog"]
cfg.settings["debug"]          = true
cfg.settings["debugScreenLog"] = false

-- ── 5. Constants ─────────────────────────────────────────────────────────────
local TAG       = "[MT-11]"
local NAME      = "AI troop stock: 2 troopTemplates avec stock"
local MENU_NAME = "Recette CTLD"
local MENU_PATH = { ctld.tr("CTLD"), MENU_NAME }

local AI_SRC  = "heliai_mt11"      -- source late-activation dans le .miz (jamais activé)
local AI_UNIT = "heliai_mt11_run"  -- clone temporaire (spawné + détruit en cleanup)
local AIZ_P   = "AIZ_mt11_B_P_T"
local AIZ_D   = "AIZ_mt11_B_D"

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

-- Clone helpers (ctld.utils.deepCopy retourne nil — deepCopy locale obligatoire)
local function deepCopy(orig)
    local copy
    if type(orig) == "table" then
        copy = {}
        for k, v in pairs(orig) do copy[deepCopy(k)] = deepCopy(v) end
        setmetatable(copy, getmetatable(orig))
    else copy = orig end
    return copy
end

local function findGrpInMission(name)
    for _, cData in pairs(env.mission.coalition or {}) do
        for _, country in ipairs(cData.country or {}) do
            for _, cat in ipairs({"helicopter","plane","vehicle","ship"}) do
                for _, grp in ipairs((country[cat] or {}).group or {}) do
                    if grp.name == name then return grp, country.id end
                end
            end
        end
    end
    return nil, nil
end

local function spawnClone(srcName, cloneName)
    local tmpl, ctryId = findGrpInMission(srcName)
    if not tmpl then return nil, "not found in env.mission: " .. srcName end
    local clone = deepCopy(tmpl)
    clone.name            = cloneName
    clone.units[1].name   = cloneName
    clone.groupId         = nil
    clone.units[1].unitId = nil
    clone.lateActivation  = false
    local ok, _ = pcall(coalition.addGroup, ctryId, Group.Category.HELICOPTER, clone)
    if not ok then return nil, "coalition.addGroup failed for " .. cloneName end
    local g = Group.getByName(cloneName)
    if not g then return nil, "group not found after spawn: " .. cloneName end
    return g, nil
end

local function destroyClone(cloneName)
    local g = Group.getByName(cloneName)
    if g and g:isExist() then pcall(function() g:destroy() end) ; log("clone destroyed: "..cloneName) end
end

local function instruct(msg)
    _SCN_MT11_INSTR = TAG .. "\n" .. msg
    log("[INSTR] " .. msg)
    trigger.action.outText(_SCN_MT11_INSTR, 360, true)
end

local function pass(id, msg) S.passed = S.passed + 1 ; log("[PASS] "..id..": "..(msg or "")) end
local function fail(id, msg) S.failed = S.failed + 1 ; table.insert(S.failReasons, id..": "..(msg or "")) ; log("[FAIL] "..id..": "..(msg or "")) end

local function check(id, desc, cond, details)
    if cond then pass(id, desc)
    else fail(id, desc .. (details and (" | "..details) or "")) end
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
    local names = cfg.settings["transportPilotNames"] or {}
    for i = #names, 1, -1 do
        if names[i] == AI_UNIT then table.remove(names, i) end
    end
    local unit = Unit.getByName(AI_UNIT)
    if unit and unit:isExist() then
        local ok, tm = pcall(CTLDTroopManager.getInstance)
        if ok and tm and tm:hasTroops(AI_UNIT) then tm:disembarkAll(unit) end
    end
    destroyClone(AI_UNIT)
    local ok3, tm3 = pcall(CTLDTroopManager.getInstance)
    if ok3 and tm3 and tm3._droppedGroups then
        for _, grpName in ipairs(tm3._droppedGroups[2] or {}) do
            local tg = Group.getByName(grpName)
            if tg and tg:isExist() then pcall(function() tg:destroy() end) end
        end
        tm3._droppedGroups[2] = {}
        log("dropped troops destroyed")
    end
    _SCN_MT11_INSTR = nil ; _SCN_MT11_SHOW = nil
    cfg.settings["debug"]          = _savedDebug
    cfg.settings["debugScreenLog"] = _savedDebugScreenLog
    _SCN_MT11_RUNNING = false
    _SCN_MT11_CLEANUP = nil
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
    if not ok then log("WARN cleanup: "..tostring(err)) ; _SCN_MT11_RUNNING = false end
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

-- S1 — Init + vérification zones + stocks initiaux [auto]
steps[1] = function()
    instruct(
        "Step 1/4 — INIT AI TROOP STOCK (MT-11)\n"..
        "Initialisation des transports AI + vérification stocks…"
    )
    waitThen(1, function()
        cfg.settings["transportPilotNames"] = { AI_UNIT }
        CTLDCoreManager.getInstance():_initAITransports()

        local zm = CTLDZoneManager.getInstance()
        local zP = zm._troopZones[AIZ_P]
        local zD = zm._troopZones[AIZ_D]
        check("MT-11.1.1", "AIZ_P trouvée : "..AIZ_P, zP ~= nil)
        check("MT-11.1.2", "AIZ_D trouvée : "..AIZ_D, zD ~= nil)
        if zP then
            check("MT-11.1.3", "AIZ_P.isAIPickup=true",          zP.isAIPickup == true)
            check("MT-11.1.4", "AIZ_P._aiTroopStock non-nil",     zP._aiTroopStock ~= nil)
            if zP._aiTroopStock then
                local ts = zP._aiTroopStock
                check("MT-11.1.5", "_aiTroopStock.isAll=false",   ts.isAll == false)
                check("MT-11.1.6", "init[Standard Group]=3",
                      ts.init["Standard Group"] == 3, tostring(ts.init["Standard Group"]))
                check("MT-11.1.7", "init[Anti Tank]=2",
                      ts.init["Anti Tank"] == 2, tostring(ts.init["Anti Tank"]))
                check("MT-11.1.8", "current[Standard Group]=3 (init)",
                      ts.current["Standard Group"] == 3, tostring(ts.current["Standard Group"]))
                check("MT-11.1.9", "pickMaxStock=0 (gate illimitée)",
                      zP.pickMaxStock == 0, tostring(zP.pickMaxStock))
            end
        end

        local cloneG, cloneErr = spawnClone(AI_SRC, AI_UNIT)
        check("MT-11.1.10", "Clone '"..AI_UNIT.."' spawné depuis '"..AI_SRC.."'",
              cloneG ~= nil, tostring(cloneErr))

        local unit = Unit.getByName(AI_UNIT)
        if unit then
            check("MT-11.1.11", "Clone sans pilote humain", unit:getPlayerName() == nil)
        end

        local tm = CTLDTroopManager.getInstance()
        check("MT-11.1.12", "Pas encore de troupes à bord (état initial)", not tm:hasTroops(AI_UNIT))

        log("STEP 1 OK — Héli activé, attente pickup sur "..AIZ_P)
        advanceStep()
    end)
end

-- S2 — Attente pickup (hasTroops=true + vérifications) [waitFor]
steps[2] = function()
    instruct(
        "Step 2/4 — ATTENTE PICKUP STOCK (MT-11)\n"..
        "L'héli "..AI_UNIT.." doit se poser sur "..AIZ_P..".\n"..
        "Détection automatique du pickup. Timeout : 300 s."
    )
    waitFor(
        function()
            local tm = CTLDTroopManager.getInstance()
            return tm:hasTroops(AI_UNIT)
        end,
        3, 300,
        function()
            local tm   = CTLDTroopManager.getInstance()
            local hasTr = tm:hasTroops(AI_UNIT)
            check("MT-11.2.1", "hasTroops=true après auto-pickup sur "..AIZ_P, hasTr)

            local list = tm:getInTransit(AI_UNIT) or {}
            check("MT-11.2.2", "1 groupe en transit", #list >= 1, "#list="..tostring(#list))

            local total = 0
            local tmplName = nil
            for _, grp in ipairs(list) do
                total = total + (grp.unitTotal or 0)
                tmplName = grp.templateName or tmplName
            end
            log("Cargo: "..total.." soldat(s) — template: "..tostring(tmplName))

            local validTemplates = { ["Standard Group"] = true, ["Anti Tank"] = true }
            check("MT-11.2.3", "template chargé reconnu (Standard Group ou Anti Tank)",
                  tmplName ~= nil and validTemplates[tmplName] == true,
                  tostring(tmplName))

            local zm = CTLDZoneManager.getInstance()
            local zP = zm._troopZones[AIZ_P]
            if zP and zP._aiTroopStock and tmplName then
                local cur = zP._aiTroopStock.current[tmplName]
                local ini = zP._aiTroopStock.init[tmplName]
                check("MT-11.2.4", "stock courant décrémenté pour '"..tmplName.."'",
                      cur ~= nil and cur < ini,
                      "current="..tostring(cur).." init="..tostring(ini))
                log("Stock "..tmplName..": "..tostring(cur).."/"..tostring(ini))
            end

            if zP and zP._aiTroopStock and tmplName == "Standard Group" then
                check("MT-11.2.5", "Standard Group (stock max=3) choisi au 1er pickup",
                      zP._aiTroopStock.current["Standard Group"] == 2,
                      tostring(zP._aiTroopStock.current["Standard Group"]))
            end

            log("STEP 2 OK — cargo chargé, attente dropoff sur "..AIZ_D)
            advanceStep()
        end,
        function()
            fail("MT-11.2.1", "timeout 300s — pas de pickup sur "..AIZ_P)
            advanceStep()
        end
    )
end

-- S3 — Attente dropoff (hasTroops=false) [waitFor]
steps[3] = function()
    instruct(
        "Step 3/4 — ATTENTE DROPOFF (MT-11)\n"..
        "L'héli "..AI_UNIT.." doit se poser sur "..AIZ_D..".\n"..
        "Détection automatique du dropoff. Timeout : 600 s."
    )
    waitFor(
        function()
            local tm = CTLDTroopManager.getInstance()
            return not tm:hasTroops(AI_UNIT)
        end,
        3, 600,
        function()
            local tm   = CTLDTroopManager.getInstance()
            local hasTr = tm:hasTroops(AI_UNIT)
            check("MT-11.3.1", "hasTroops=false après auto-dropoff sur "..AIZ_D, not hasTr)
            log("Disembark confirmé — groupes apparus près de "..AIZ_D)
            advanceStep()
        end,
        function()
            fail("MT-11.3.1", "timeout 600s — pas de dropoff sur "..AIZ_D)
            advanceStep()
        end
    )
end

-- S4 — Finalisation [auto]
steps[4] = function()
    instruct("Step 4/4 — FINALISATION")
    waitThen(1, function()
        log("MT-11 ALL SUCCESS — 2 troopTemplates avec stock, pickup + stock décrémenté + dropoff confirmés")
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

_SCN_MT11_CLEANUP = cleanup

log("=== START: "..NAME.." | transport="..S.transport:getName().." | groupId="..tostring(S.groupId).." | "..#steps.." steps ===")
trigger.action.outText(TAG.." démarrage — "..#steps.." steps | "..S.transport:getName(), 8)
advanceStep()

end  -- do isolation scope
return Witchcraft
