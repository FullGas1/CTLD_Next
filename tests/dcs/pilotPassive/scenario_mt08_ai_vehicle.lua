---@diagnostic disable
-- =============================================================================
-- live_tests/scenarios/interactive/scenario_mt08_ai_vehicle.lua
-- CTLD — AI auto-pickup / auto-dropoff : véhicule entier seul (posé → posé)
--
-- Mini-application de recette interactive : injection unique, avance
-- automatiquement (waitFor) pour détecter le loadVehicle et l'unloadVehicle.
--
-- Prérequis :
--   - Héli BLUE nommé "heliai_vehicle" (UH-1H), sans pilote humain
--   - Route : WP posé sur AIZ_depot_B_P_V_10 → vol → WP posé sur AIZ_livraison_B_D_G
--   - Zone DCS trigger "AIZ_depot_B_P_V_10"  (rayon ~200 m, V=vehicles only, stock=10)
--   - Zone DCS trigger "AIZ_livraison_B_D_G" (rayon ~200 m, LZ de livraison)
--   - M1045 HMMWV BLUE nommé "hmmwv_cargo" positionné dans AIZ_depot_B_P
--   - capabilitiesByType UH-1H : canTransportWholeVehicle=true
--   - Slot BLUE occupé (joueur humain pour MenuManager)
--   - CTLD_Next.lua injecté avant ce script (attendre 3-5 s)
--
-- Cinématique (4 steps, injection unique) :
--   S1 [auto]  Init + activation héli AI
--   S2 [auto]  Attente loadVehicle (véhicule chargé) via waitFor
--   S3 [auto]  Attente unloadVehicle (véhicule déchargé) via waitFor
--   S4 [auto]  Finalisation
--
-- @scenario  MT-08
-- @version   3.0 — 2026-06-30
-- @coverage  AI vehicle load, AI vehicle unload
-- =============================================================================

-- ── 1. Witchcraft guard ──────────────────────────────────────────────────────
if not ctld or not ctld.utils then
    trigger.action.outText("[MT-08] ABORT: CTLD not initialized. Inject CTLD_Next.lua first.", 15)
    return Witchcraft
end

-- ── 2. Double-injection guard ────────────────────────────────────────────────
if _SCN_MT08_RUNNING then
    trigger.action.outText("[MT-08] déjà actif — attendre la fin ou redémarrer DCS.", 10)
    return Witchcraft
end
_SCN_MT08_RUNNING = true
_SCN_MT08_CLEANUP = nil

-- ── 3. Global show callback ──────────────────────────────────────────────────
_SCN_MT08_INSTR = ""
_SCN_MT08_SHOW  = function()
    trigger.action.outText(_SCN_MT08_INSTR, 30)
end

do  -- isolation scope
-- ── 4. Debug ON ──────────────────────────────────────────────────────────────
local cfg                  = CTLDConfig.get()
local _savedDebug          = cfg.settings["debug"]
local _savedDebugScreenLog = cfg.settings["debugScreenLog"]
cfg.settings["debug"]          = true
cfg.settings["debugScreenLog"] = false

-- ── 5. Constants ─────────────────────────────────────────────────────────────
local TAG       = "[MT-08]"
local NAME      = "AI auto-pickup/dropoff véhicule entier"
local MENU_NAME = "Recette CTLD"
local MENU_PATH = { ctld.tr("CTLD"), MENU_NAME }

local AI_SRC  = "heliai_vehicle"      -- source late-activation dans le .miz (jamais activé)
local AI_UNIT = "heliai_vehicle_run"  -- clone temporaire (spawné + détruit en cleanup)
local AIZ_P   = "AIZ_depot_B_P_V_10"
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
    _SCN_MT08_INSTR = TAG .. "\n" .. msg
    log("[INSTR] " .. msg)
    trigger.action.outText(_SCN_MT08_INSTR, 360, true)
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
        local ok, vs = pcall(CTLDVehicleSpawner.getInstance)
        if ok and vs then
            local loaded = vs:findLoadedVehicles(unit)
            if loaded and #loaded > 0 then
                vs:unloadVehicle(loaded[1], unit, nil, "menu_ctld")
            end
        end
    end
    destroyClone(AI_UNIT)
    _SCN_MT08_INSTR = nil ; _SCN_MT08_SHOW = nil
    cfg.settings["debug"]          = _savedDebug
    cfg.settings["debugScreenLog"] = _savedDebugScreenLog
    _SCN_MT08_RUNNING = false
    _SCN_MT08_CLEANUP = nil
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
    if not ok then log("WARN cleanup: "..tostring(err)) ; _SCN_MT08_RUNNING = false end
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

-- S1 — Init + activation héli AI [auto]
steps[1] = function()
    instruct(
        "Step 1/4 — INIT AI TRANSPORT VÉHICULE (MT-08)\n"..
        "Initialisation des transports AI en cours…"
    )
    waitThen(1, function()
        cfg.settings["transportPilotNames"] = { AI_UNIT }
        CTLDCoreManager.getInstance():_initAITransports()

        local zm = CTLDZoneManager.getInstance()
        local zP = zm._troopZones[AIZ_P]
        local zD = zm._troopZones[AIZ_D]
        check("MT-08.1.1", "AIZ_P zone trouvée : "..AIZ_P, zP ~= nil)
        if zP then check("MT-08.1.2", "AIZ_P.isAIPickup=true", zP.isAIPickup == true) end
        check("MT-08.1.3", "AIZ_D zone trouvée : "..AIZ_D, zD ~= nil)
        if zD then
            check("MT-08.1.4", "AIZ_D.isAIDropoff=true", zD.isAIDropoff == true)
            check("MT-08.1.5", "AIZ_D.aiDropMode='G'", zD.aiDropMode == "G",
                "aiDropMode="..tostring(zD.aiDropMode))
        end

        local cloneG, cloneErr = spawnClone(AI_SRC, AI_UNIT)
        check("MT-08.1.6", "Clone '"..AI_UNIT.."' spawné depuis '"..AI_SRC.."'",
              cloneG ~= nil, tostring(cloneErr))

        local unit = Unit.getByName(AI_UNIT)
        if unit then
            check("MT-08.1.7", "Sans pilote humain", unit:getPlayerName() == nil)
            local caps = (ctld.gs("capabilitiesByType") or {})[unit:getTypeName()] or {}
            check("MT-08.1.8", "canTransportWholeVehicle configuré", caps.canTransportWholeVehicle == true)
        end

        local okVS, vs = pcall(CTLDVehicleSpawner.getInstance)
        if okVS and vs then
            local dcsZone = trigger.misc.getZone(AIZ_P)
            local vehInZone = 0
            if dcsZone then
                local zPt = dcsZone.point
                local zR  = dcsZone.radius
                for _, veh in pairs(vs._vehicles) do
                    if veh:getState() == CTLDVehicle.STATE.WAITING and veh.unit and veh.unit:isExist() then
                        local d = ctld.utils.getDistance("MT-08.1.9", zPt, veh.unit:getPoint())
                        if d <= zR then vehInZone = vehInZone + 1 end
                    end
                end
            end
            check("MT-08.1.9", "Au moins 1 véhicule WAITING dans la zone "..AIZ_P, vehInZone > 0,
                "count_in_zone="..vehInZone)
        end

        local lv = cfg.settings["loadableVehiclesBLUE"] or {}
        local hvFound = false
        for _, t in ipairs(lv) do if t == "Hummer" then hvFound = true; break end end
        if not hvFound then table.insert(lv, "Hummer"); cfg.settings["loadableVehiclesBLUE"] = lv end

        log("STEP 1 OK — Héli activé, attente pose sur "..AIZ_P)
        advanceStep()
    end)
end

-- S2 — Attente loadVehicle (véhicule chargé) [waitFor]
steps[2] = function()
    instruct(
        "Step 2/4 — ATTENTE CHARGE VÉHICULE (MT-08)\n"..
        "L'héli "..AI_UNIT.." doit se poser sur "..AIZ_P.." avec le HMMWV.\n"..
        "Détection automatique du chargement.\n"..
        "Timeout : 300 s."
    )
    waitFor(
        function()
            local unit = Unit.getByName(AI_UNIT)
            if not unit or not unit:isExist() then return false end
            local ok, vs = pcall(CTLDVehicleSpawner.getInstance)
            if not ok or not vs then return false end
            local loaded = vs:findLoadedVehicles(unit)
            return loaded and #loaded > 0
        end,
        3, 300,
        function()
            local unit = Unit.getByName(AI_UNIT)
            local ok, vs = pcall(CTLDVehicleSpawner.getInstance)
            if not ok or not vs then
                fail("MT-08.2.1", "CTLDVehicleSpawner indisponible")
                advanceStep() ; return
            end
            local loaded = vs:findLoadedVehicles(unit)
            local hasVeh = loaded and #loaded > 0
            check("MT-08.2.1", "Véhicule chargé à bord après posé sur "..AIZ_P, hasVeh,
                "nb_loaded="..tostring(loaded and #loaded or 0))
            if hasVeh then
                local veh = loaded[1]
                log("Véhicule chargé: id="..tostring(veh.id).." type="..tostring(veh.vehicleType))
                local vehDcsUnit = veh.unit
                check("MT-08.2.2", "Véhicule DCS masqué (état LOADED)",
                    vehDcsUnit == nil or not vehDcsUnit:isExist() or veh:getState() == CTLDVehicle.STATE.LOADED)
            end
            advanceStep()
        end,
        function()
            fail("MT-08.2.1", "timeout 300s — pas de chargement sur "..AIZ_P)
            advanceStep()
        end
    )
end

-- S3 — Attente unloadVehicle (véhicule déchargé) [waitFor]
steps[3] = function()
    instruct(
        "Step 3/4 — ATTENTE DÉCHARGE VÉHICULE (MT-08)\n"..
        "L'héli "..AI_UNIT.." doit se poser sur "..AIZ_D..".\n"..
        "Détection automatique du déchargement.\n"..
        "Timeout : 600 s."
    )
    waitFor(
        function()
            local unit = Unit.getByName(AI_UNIT)
            if not unit or not unit:isExist() then return false end
            local ok, vs = pcall(CTLDVehicleSpawner.getInstance)
            if not ok or not vs then return false end
            local loaded = vs:findLoadedVehicles(unit)
            return not (loaded and #loaded > 0)
        end,
        3, 600,
        function()
            local unit = Unit.getByName(AI_UNIT)
            local ok, vs = pcall(CTLDVehicleSpawner.getInstance)
            if not ok or not vs then
                fail("MT-08.3.1", "CTLDVehicleSpawner indisponible")
                advanceStep() ; return
            end
            local loaded = vs:findLoadedVehicles(unit)
            local hasVeh = loaded and #loaded > 0
            check("MT-08.3.1", "Véhicule déchargé après posé sur "..AIZ_D, not hasVeh,
                "nb_loaded="..tostring(loaded and #loaded or 0))
            log("Unload confirmé — HMMWV apparu près de "..AIZ_D)
            advanceStep()
        end,
        function()
            fail("MT-08.3.1", "timeout 600s — pas de déchargement sur "..AIZ_D)
            advanceStep()
        end
    )
end

-- S4 — Finalisation [auto]
steps[4] = function()
    instruct("Step 4/4 — FINALISATION")
    waitThen(1, function()
        log("MT-08 cycle complet (pickup "..AIZ_P.." → unload "..AIZ_D..")")
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

_SCN_MT08_CLEANUP = cleanup

log("=== START: "..NAME.." | transport="..S.transport:getName().." | groupId="..tostring(S.groupId).." | "..#steps.." steps ===")
trigger.action.outText(TAG.." démarrage — "..#steps.." steps | "..S.transport:getName(), 8)
advanceStep()

end  -- do isolation scope
return Witchcraft
