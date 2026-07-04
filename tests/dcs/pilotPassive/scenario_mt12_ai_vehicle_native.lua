---@diagnostic disable
-- =============================================================================
-- live_tests/scenarios/interactive/scenario_mt12_ai_vehicle_native.lua
-- CTLD — AI auto-pickup d'un véhicule DCS natif via vehicleStock (Feature T)
--
-- Mini-application de recette interactive : injection unique, avance
-- automatiquement (waitFor) pour détecter pickup et dropoff virtuels.
--
-- Prérequis :
--   - Héli BLUE nommé "heliai_mt12" (UH-60L ou canTransportWholeVehicle=true)
--   - Route : WP1 = posé sur AIZ_mt12_B_P_V → WP3 = posé sur AIZ_mt12_B_D
--   - Zone DCS trigger "AIZ_mt12_B_P_V" (rayon ~200 m)
--   - Zone DCS trigger "AIZ_mt12_B_D"   (rayon ~200 m)
--   - AUCUN groupe DCS véhicule dans AIZ_mt12_B_P_V (sinon C1 prend le dessus sur C2)
--   - vehicleStock = { ["Hummer"] = 2 } dans la config zone
--   - Slot BLUE occupé (joueur humain pour MenuManager)
--   - CTLD_Next.lua injecté avant ce script (attendre 3-5 s)
--
-- Cinématique (4 steps, injection unique) :
--   S1 [auto]  Init + vérification zones + vehicleStock initial
--   S2 [auto]  Attente pickup virtuel (_aiTransportVehicle peuplé) via waitFor
--   S3 [auto]  Attente dropoff (_aiTransportVehicle vidé = spawn DCS) via waitFor
--   S4 [auto]  Finalisation
--
-- @scenario  MT-12
-- @version   4.0 — 2026-07-01
-- @coverage  AI vehicle native pickup, AI vehicle dropoff spawn DCS (clone spawn, repeatable)
-- =============================================================================

-- ── 1. Witchcraft guard ──────────────────────────────────────────────────────
if not ctld or not ctld.utils then
    trigger.action.outText("[MT-12] ABORT: CTLD not initialized. Inject CTLD_Next.lua first.", 15)
    return Witchcraft
end

-- ── 2. Double-injection guard ────────────────────────────────────────────────
if _SCN_MT12_RUNNING then
    trigger.action.outText("[MT-12] déjà actif — attendre la fin ou redémarrer DCS.", 10)
    return Witchcraft
end
_SCN_MT12_RUNNING = true
_SCN_MT12_CLEANUP = nil

-- ── 3. Global show callback ──────────────────────────────────────────────────
_SCN_MT12_INSTR = ""
_SCN_MT12_SHOW  = function()
    trigger.action.outText(_SCN_MT12_INSTR, 30)
end

do  -- isolation scope
-- ── 4. Debug ON ──────────────────────────────────────────────────────────────
local cfg                  = CTLDConfig.get()
local _savedDebug          = cfg.settings["debug"]
local _savedDebugScreenLog = cfg.settings["debugScreenLog"]
cfg.settings["debug"]          = true
cfg.settings["debugScreenLog"] = false

-- ── 5. Constants ─────────────────────────────────────────────────────────────
local TAG       = "[MT-12]"
local NAME      = "AI vehicle natif pickup/dropoff via vehicleStock"
local MENU_NAME = "Recette CTLD"
local MENU_PATH = { ctld.tr("CTLD"), MENU_NAME }

local AI_SRC   = "heliai_mt12"      -- source late-activation dans le .miz (jamais activé)
local AI_UNIT  = "heliai_mt12_run"  -- clone temporaire (spawné + détruit en cleanup)
local AIZ_P    = "AIZ_mt12_B_P_V"
local AIZ_D    = "AIZ_mt12_B_D"
local VEH_TYPE = "Hummer"

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
    _SCN_MT12_INSTR = TAG .. "\n" .. msg
    log("[INSTR] " .. msg)
    trigger.action.outText(_SCN_MT12_INSTR, 360, true)
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
    local cm = CTLDCoreManager.getInstance()
    if cm._aiTransportVehicle then cm._aiTransportVehicle[AI_UNIT] = nil end
    destroyClone(AI_UNIT)
    _SCN_MT12_INSTR = nil ; _SCN_MT12_SHOW = nil
    cfg.settings["debug"]          = _savedDebug
    cfg.settings["debugScreenLog"] = _savedDebugScreenLog
    _SCN_MT12_RUNNING = false
    _SCN_MT12_CLEANUP = nil
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
    if not ok then log("WARN cleanup: "..tostring(err)) ; _SCN_MT12_RUNNING = false end
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

-- S1 — Init + vérification zones + vehicleStock initial [auto]
steps[1] = function()
    instruct(
        "Step 1/4 — INIT AI VEHICLE NATIVE (MT-12)\n"..
        "Vérification vehicleStock Hummer (isScene=false)…"
    )
    waitThen(1, function()
        cfg.settings["transportPilotNames"] = { AI_UNIT }
        CTLDCoreManager.getInstance():_initAITransports()

        local zm = CTLDZoneManager.getInstance()
        local zP = zm._troopZones[AIZ_P]
        local zD = zm._troopZones[AIZ_D]
        check("MT-12.1.1", "AIZ_P trouvée : "..AIZ_P, zP ~= nil)
        check("MT-12.1.2", "AIZ_D trouvée : "..AIZ_D, zD ~= nil)
        if zP then
            check("MT-12.1.3", "AIZ_P.isAIPickup=true",        zP.isAIPickup == true)
            check("MT-12.1.4", "AIZ_P.aiCargoType='V'",         zP.aiCargoType == "V",
                  tostring(zP.aiCargoType))
            check("MT-12.1.5", "AIZ_P._aiVehicleStock non-nil", zP._aiVehicleStock ~= nil)
            check("MT-12.1.6", "AIZ_P._aiTroopStock=nil",       zP._aiTroopStock == nil)
            if zP._aiVehicleStock then
                local vs = zP._aiVehicleStock
                check("MT-12.1.7", "_aiVehicleStock.isAll=false",  vs.isAll == false)
                check("MT-12.1.8", "init[Hummer]=2",
                      vs.init[VEH_TYPE] == 2, tostring(vs.init[VEH_TYPE]))
                check("MT-12.1.9", "current[Hummer]=2 (init)",
                      vs.current[VEH_TYPE] == 2, tostring(vs.current[VEH_TYPE]))
                check("MT-12.1.10", "pickMaxStock=0 (gate illimitée)",
                      zP.pickMaxStock == 0, tostring(zP.pickMaxStock))
            end
        end

        local sm = CTLDSceneManager.getInstance()
        check("MT-12.1.11", "Hummer n'est pas une scène CTLDSceneManager",
              sm:getScene(VEH_TYPE) == nil)

        local cloneG, cloneErr = spawnClone(AI_SRC, AI_UNIT)
        check("MT-12.1.12", "Clone '"..AI_UNIT.."' spawné depuis '"..AI_SRC.."'",
              cloneG ~= nil, tostring(cloneErr))

        local unit = Unit.getByName(AI_UNIT)

        local cm = CTLDCoreManager.getInstance()
        check("MT-12.1.13", "_aiTransportVehicle["..AI_UNIT.."] vide initialement",
              cm._aiTransportVehicle[AI_UNIT] == nil)

        log("STEP 1 OK — C1 (physique) absent → C2 (virtuel Hummer) s'applique")
        log("Attente pose sur "..AIZ_P)
        advanceStep()
    end)
end

-- S2 — Attente pickup virtuel (_aiTransportVehicle peuplé) [waitFor]
steps[2] = function()
    instruct(
        "Step 2/4 — ATTENTE PICKUP VIRTUEL (MT-12)\n"..
        "L'héli "..AI_UNIT.." doit se poser sur "..AIZ_P..".\n"..
        "Détection de _aiTransportVehicle peuplé (C2 Hummer). Timeout : 300 s."
    )
    waitFor(
        function()
            local cm = CTLDCoreManager.getInstance()
            return cm._aiTransportVehicle[AI_UNIT] ~= nil
        end,
        3, 300,
        function()
            local cm = CTLDCoreManager.getInstance()
            local vEntry = cm._aiTransportVehicle[AI_UNIT]
            check("MT-12.2.1", "_aiTransportVehicle peuplé au pickup", vEntry ~= nil)
            if vEntry then
                check("MT-12.2.2", "type='Hummer'", vEntry.type == VEH_TYPE,
                      tostring(vEntry.type))
                check("MT-12.2.3", "isScene=false (DCS natif, pas de scène)",
                      vEntry.isScene == false, tostring(vEntry.isScene))
                log("En transit : "..tostring(vEntry.type).." | isScene="..tostring(vEntry.isScene))
            end

            local zm = CTLDZoneManager.getInstance()
            local zP = zm._troopZones[AIZ_P]
            if zP and zP._aiVehicleStock then
                local cur = zP._aiVehicleStock.current[VEH_TYPE]
                check("MT-12.2.4", "stock Hummer décrémenté (1 consommé → current=1)",
                      cur == 1, "current="..tostring(cur))
            end
            advanceStep()
        end,
        function()
            -- Diagnostic C1/C2
            local ok, vs = pcall(CTLDVehicleSpawner.getInstance)
            if ok and vs then
                local u = Unit.getByName(AI_UNIT)
                local loaded = u and u:isExist() and vs:findLoadedVehicles(u) or {}
                if #loaded > 0 then
                    fail("MT-12.2.0", "C1 (physique) a pris le dessus : retirer le groupe DCS de "..AIZ_P)
                else
                    fail("MT-12.2.1", "timeout 300s — _aiTransportVehicle pas peuplé sur "..AIZ_P)
                end
            else
                fail("MT-12.2.1", "timeout 300s — pickup non détecté sur "..AIZ_P)
            end
            advanceStep()
        end
    )
end

-- S3 — Attente dropoff (_aiTransportVehicle vidé) [waitFor]
steps[3] = function()
    instruct(
        "Step 3/4 — ATTENTE DROPOFF (MT-12)\n"..
        "L'héli "..AI_UNIT.." doit se poser sur "..AIZ_D..".\n"..
        "Détection du spawn DCS Hummer (_aiTransportVehicle=nil). Timeout : 600 s."
    )
    waitFor(
        function()
            local cm = CTLDCoreManager.getInstance()
            return cm._aiTransportVehicle[AI_UNIT] == nil
        end,
        3, 600,
        function()
            local cm = CTLDCoreManager.getInstance()
            local vEntry = cm._aiTransportVehicle[AI_UNIT]
            check("MT-12.3.1", "_aiTransportVehicle vidé après dropoff", vEntry == nil)
            log("Dropoff confirmé — Hummer apparu près de "..AIZ_D)
            log("Message coalition attendu : 'AI "..AI_UNIT.." delivered vehicle: "..VEH_TYPE.."'")
            advanceStep()
        end,
        function()
            fail("MT-12.3.1", "timeout 600s — dropoff non détecté sur "..AIZ_D)
            advanceStep()
        end
    )
end

-- S4 — Finalisation [auto]
steps[4] = function()
    instruct("Step 4/4 — FINALISATION")
    waitThen(1, function()
        log("MT-12 ALL SUCCESS — pickup virtuel Hummer (isScene=false) + stock décrément + spawn DCS confirmés")
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

_SCN_MT12_CLEANUP = cleanup

log("=== START: "..NAME.." | transport="..S.transport:getName().." | groupId="..tostring(S.groupId).." | "..#steps.." steps ===")
trigger.action.outText(TAG.." démarrage — "..#steps.." steps | "..S.transport:getName(), 8)
advanceStep()

end  -- do isolation scope
return Witchcraft
