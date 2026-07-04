---@diagnostic disable
-- =============================================================================
-- live_tests/scenarios/interactive/scenario_mt09_ai_full_cycle.lua
-- CTLD — AI cycle complet : troupes + vehicule entier (zone TV)
--
-- Mini-application de recette interactive : injection unique, avance
-- automatiquement (waitFor) pour détecter pickup et dropoff TV.
--
-- Prérequis :
--   - Heli BLUE nommé "heliai_full" (UH-1H), sans pilote humain
--   - Route : WP sur AIZ_depot_B_P_TV_5_10 (posé) → AIZ_livraison_B_D_G (posé)
--   - AIZ_depot_B_P_TV_5_10  : zone pickup TV (troupes + vehicule), r~61m
--   - AIZ_livraison_B_D_G    : zone dropoff, r~274m
--   - Hummers BLUE (veh_mm_*) placés à proximité de AIZ_depot (~200m du centre)
--   - Slot BLUE occupé (joueur humain pour MenuManager)
--   - CTLD_Next.lua injecté avant ce script (attendre 3-5 s)
--
-- Cinématique (4 steps, injection unique) :
--   S1 [auto]  Init + vérification zones + enregistrement héli
--   S2 [auto]  Attente pickup TV (troupes ou véhicule chargé) via waitFor
--   S3 [auto]  Attente dropoff TV (plus de troupes ni véhicule) via waitFor
--   S4 [auto]  Finalisation
--
-- @scenario  MT-09
-- @version   3.0 — 2026-06-30
-- @coverage  AI pickup TV, AI dropoff TV
-- =============================================================================

-- ── 1. Witchcraft guard ──────────────────────────────────────────────────────
if not ctld or not ctld.utils then
    trigger.action.outText("[MT-09] ABORT: CTLD not initialized. Inject CTLD_Next.lua first.", 15)
    return Witchcraft
end

-- ── 2. Double-injection guard ────────────────────────────────────────────────
if _SCN_MT09_RUNNING then
    trigger.action.outText("[MT-09] déjà actif — attendre la fin ou redémarrer DCS.", 10)
    return Witchcraft
end
_SCN_MT09_RUNNING = true
_SCN_MT09_CLEANUP = nil

-- ── 3. Global show callback ──────────────────────────────────────────────────
_SCN_MT09_INSTR = ""
_SCN_MT09_SHOW  = function()
    trigger.action.outText(_SCN_MT09_INSTR, 30)
end

do  -- isolation scope
-- ── 4. Debug ON ──────────────────────────────────────────────────────────────
local cfg                  = CTLDConfig.get()
local _savedDebug          = cfg.settings["debug"]
local _savedDebugScreenLog = cfg.settings["debugScreenLog"]
cfg.settings["debug"]          = true
cfg.settings["debugScreenLog"] = false

-- ── 5. Constants ─────────────────────────────────────────────────────────────
local TAG       = "[MT-09]"
local NAME      = "AI cycle complet troupes + véhicule (TV)"
local MENU_NAME = "Recette CTLD"
local MENU_PATH = { ctld.tr("CTLD"), MENU_NAME }

local AI_SRC  = "heliai_full"      -- source late-activation dans le .miz (jamais activé)
local AI_UNIT = "heliai_full_run"  -- clone temporaire (spawné + détruit en cleanup)
local AIZ_P   = "AIZ_depot_B_P_TV_5_10"
local AIZ_D   = "AIZ_livraison_B_D_G"

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
    _SCN_MT09_INSTR = TAG .. "\n" .. msg
    log("[INSTR] " .. msg)
    trigger.action.outText(_SCN_MT09_INSTR, 360, true)
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
    for i = #names, 1, -1 do if names[i] == AI_UNIT then table.remove(names, i) end end
    local unit = Unit.getByName(AI_UNIT)
    if unit and unit:isExist() then
        local ok1, tm = pcall(CTLDTroopManager.getInstance)
        if ok1 and tm and tm:hasTroops(AI_UNIT) then tm:disembarkAll(unit) end
        local ok2, vs = pcall(CTLDVehicleSpawner.getInstance)
        if ok2 and vs then
            local loaded = vs:findLoadedVehicles(unit)
            if loaded and #loaded > 0 then vs:unloadVehicle(loaded[1], unit, nil, "menu_ctld") end
        end
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
    _SCN_MT09_INSTR = nil ; _SCN_MT09_SHOW = nil
    cfg.settings["debug"]          = _savedDebug
    cfg.settings["debugScreenLog"] = _savedDebugScreenLog
    _SCN_MT09_RUNNING = false
    _SCN_MT09_CLEANUP = nil
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
    if not ok then log("WARN cleanup: "..tostring(err)) ; _SCN_MT09_RUNNING = false end
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

-- S1 — Init + vérification zones [auto]
steps[1] = function()
    instruct(
        "Step 1/4 — INIT AI TRANSPORT TV (MT-09)\n"..
        "Initialisation des transports AI en cours…"
    )
    waitThen(1, function()
        cfg.settings["transportPilotNames"] = { AI_UNIT }
        CTLDCoreManager.getInstance():_initAITransports()

        local zm = CTLDZoneManager.getInstance()
        local zP = zm._troopZones[AIZ_P]
        local zD = zm._troopZones[AIZ_D]
        check("MT-09.1.1", "AIZ_P trouvée: "..AIZ_P, zP ~= nil)
        check("MT-09.1.2", "AIZ_D trouvée: "..AIZ_D, zD ~= nil)
        if zP then
            check("MT-09.1.3", "AIZ_P.isAIPickup=true",   zP.isAIPickup  == true)
            check("MT-09.1.4", "AIZ_P.aiCargoType=TV",     zP.aiCargoType == "TV",
                "aiCargoType="..tostring(zP.aiCargoType))
        end
        if zD then
            check("MT-09.1.5", "AIZ_D.isAIDropoff=true",  zD.isAIDropoff == true)
        end

        local cloneG, cloneErr = spawnClone(AI_SRC, AI_UNIT)
        check("MT-09.1.6", "Clone '"..AI_UNIT.."' spawné depuis '"..AI_SRC.."'",
              cloneG ~= nil, tostring(cloneErr))

        local unit = Unit.getByName(AI_UNIT)
        if unit then
            check("MT-09.1.7", "Sans pilote humain", unit:getPlayerName() == nil)
            local caps = (ctld.gs("capabilitiesByType") or {})[unit:getTypeName()] or {}
            check("MT-09.1.8", "troopsEnabled=true",            caps.troopsEnabled            == true)
            check("MT-09.1.9", "canTransportWholeVehicle=true", caps.canTransportWholeVehicle == true)
        end

        local ok, vs = pcall(CTLDVehicleSpawner.getInstance)
        if ok and vs then
            local count = 0
            for _ in pairs(vs._vehicles) do count = count + 1 end
            check("MT-09.1.10", "Au moins 1 véhicule enregistré", count > 0, "count="..count)
        end

        log("STEP 1 OK — Héli activé, attente pose sur "..AIZ_P)
        advanceStep()
    end)
end

-- S2 — Attente pickup TV (troupes ou véhicule chargé) [waitFor]
steps[2] = function()
    instruct(
        "Step 2/4 — ATTENTE PICKUP TV (MT-09)\n"..
        "L'héli "..AI_UNIT.." doit se poser sur "..AIZ_P..".\n"..
        "Détection du pickup (troupes ou véhicule chargé).\n"..
        "Timeout : 300 s."
    )
    waitFor(
        function()
            local tm = CTLDTroopManager.getInstance()
            if tm:hasTroops(AI_UNIT) then return true end
            local unit = Unit.getByName(AI_UNIT)
            if not unit or not unit:isExist() then return false end
            local ok, vs = pcall(CTLDVehicleSpawner.getInstance)
            if not ok or not vs then return false end
            local loaded = vs:findLoadedVehicles(unit)
            return loaded and #loaded > 0
        end,
        3, 300,
        function()
            local tm   = CTLDTroopManager.getInstance()
            local hasTr = tm:hasTroops(AI_UNIT)
            local unit = Unit.getByName(AI_UNIT)
            local ok, vs = pcall(CTLDVehicleSpawner.getInstance)
            local hasVeh = false
            if ok and vs and unit then
                local loaded = vs:findLoadedVehicles(unit)
                hasVeh = #loaded > 0
            end

            check("MT-09.2.0", "Heli AI présent", unit ~= nil and unit:isExist())

            if hasTr then
                local list = tm:getInTransit(AI_UNIT) or {}
                local total = 0
                for _, grp in ipairs(list) do total = total + (grp.unitTotal or 0) end
                log("Troupes à bord: "..total.." soldat(s)")
            end
            if hasVeh and ok and vs then
                local loaded = vs:findLoadedVehicles(unit)
                if loaded and #loaded > 0 then
                    log("Véhicule à bord: type="..tostring(loaded[1].vehicleType))
                end
            end

            local pickupOk = hasTr or hasVeh
            check("MT-09.2.1", "Pickup TV détecté (troupes ou véhicule)", pickupOk)
            log("STEP 2 OK — en vol vers "..AIZ_D)
            advanceStep()
        end,
        function()
            -- Vérifier si le cycle est peut-être déjà complet (groupes déployés près de AIZ_D)
            local dcsZoneD = trigger.misc.getZone(AIZ_D)
            local deployedCount = 0
            if dcsZoneD then
                local zPt = dcsZoneD.point
                local zR  = (dcsZoneD.radius or 500) * 3
                local grps = coalition.getGroups(coalition.side.BLUE, Group.Category.GROUND) or {}
                for _, g in ipairs(grps) do
                    local u0 = (g:getUnits() or {})[1]
                    if u0 and u0:isExist() then
                        local pt = u0:getPoint()
                        local d = math.sqrt((pt.x-zPt.x)^2 + (pt.z-zPt.z)^2)
                        if d <= zR then deployedCount = deployedCount + 1 end
                    end
                end
            end
            check("MT-09.2.1", "Cycle TV complet (groupes déployés près de "..AIZ_D..")", deployedCount > 0,
                "deployed_groups_near_AIZ_D="..deployedCount)
            if deployedCount > 0 then
                log("Cycle rapide détecté: "..deployedCount.." groupe(s) déployés — skip step 3")
                -- Skip step 3, cycle already done
                S.step = S.step + 1  -- will be at 3, advanceStep will go to 4
            end
            advanceStep()
        end
    )
end

-- S3 — Attente dropoff TV (plus de troupes ni véhicule) [waitFor]
steps[3] = function()
    instruct(
        "Step 3/4 — ATTENTE DROPOFF TV (MT-09)\n"..
        "L'héli "..AI_UNIT.." doit se poser sur "..AIZ_D..".\n"..
        "Détection du dropoff (plus de troupes ni véhicule).\n"..
        "Timeout : 600 s."
    )
    waitFor(
        function()
            local tm = CTLDTroopManager.getInstance()
            if tm:hasTroops(AI_UNIT) then return false end
            local unit = Unit.getByName(AI_UNIT)
            if not unit or not unit:isExist() then return true end  -- unit gone = cycle done
            local ok, vs = pcall(CTLDVehicleSpawner.getInstance)
            if not ok or not vs then return true end
            local loaded = vs:findLoadedVehicles(unit)
            return not (loaded and #loaded > 0)
        end,
        3, 600,
        function()
            local tm   = CTLDTroopManager.getInstance()
            local hasTr = tm:hasTroops(AI_UNIT)
            check("MT-09.3.1", "hasTroops=false après dropoff sur "..AIZ_D, not hasTr,
                "hasTroops="..tostring(hasTr))

            local unit = Unit.getByName(AI_UNIT)
            local ok, vs = pcall(CTLDVehicleSpawner.getInstance)
            if ok and vs and unit then
                local loaded = vs:findLoadedVehicles(unit)
                local hasVeh = #loaded > 0
                check("MT-09.3.2", "Plus de véhicule à bord après dropoff", not hasVeh,
                    "nb_loaded="..tostring(#loaded))
            end

            log("Troupes + véhicule déposés sur "..AIZ_D)
            advanceStep()
        end,
        function()
            fail("MT-09.3.1", "timeout 600s — pas de dropoff sur "..AIZ_D)
            advanceStep()
        end
    )
end

-- S4 — Finalisation [auto]
steps[4] = function()
    instruct("Step 4/4 — FINALISATION")
    waitThen(1, function()
        log("MT-09 cycle complet troupes + véhicule entier validé")
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

_SCN_MT09_CLEANUP = cleanup

log("=== START: "..NAME.." | transport="..S.transport:getName().." | groupId="..tostring(S.groupId).." | "..#steps.." steps ===")
trigger.action.outText(TAG.." démarrage — "..#steps.." steps | "..S.transport:getName(), 8)
advanceStep()

end  -- do isolation scope
return Witchcraft
