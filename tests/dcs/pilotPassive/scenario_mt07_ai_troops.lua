---@diagnostic disable
-- =============================================================================
-- scenario_mt07_ai_troops.lua  [INTERACTIVE]
-- MT-07 — AI auto-pickup / auto-dropoff : troupes seules
--
-- PRÉREQUIS MISSION :
--   - Héli BLUE nommé "heliai_troops" (UH-1H), sans pilote humain
--   - Route : WP1 = sur AIZ_base_B_P_5 (posé) → WP2 = vol → WP3 = sur AIZ_front_B_D (posé)
--   - Zone DCS trigger "AIZ_base_B_P_5"  (rayon ~200 m, centré sur WP1)
--   - Zone DCS trigger "AIZ_front_B_D"   (rayon ~200 m, centré sur WP3)
--   - enable_debug.lua injecté avant ce script
--   - ctldLogPath défini dans le .miz (trigger MISSION START)
--
-- USE CASE : AI pickup troupes en AIZ_P → vol → disembark en AIZ_D sol
--
-- PROTOCOL :
--   Step 1 — Enregistre heliai_troops dans transportPilotNames + vérifie init zones
--   Step 2 — Vérifie que l'héli a chargé des troupes (hasTroops=true)
--             Re-injecter après que l'héli soit posé sur AIZ_base_B_P_5 (~2s)
--   Step 3 — Vérifie disembarkAll exécuté (hasTroops=false)
--             Re-injecter après que l'héli soit posé sur AIZ_front_B_D
--   Step 4 — Cleanup
-- =============================================================================

-- ── Witchcraft guard ─────────────────────────────────────────────────────────
if not ctld or not ctld.utils then
    trigger.action.outText("[MT-07] ABORT: CTLD not initialized. Inject CTLD_Next.lua first.", 15)
    return Witchcraft
end

local cfg = CTLDConfig.get()
local _saved_debug = cfg.settings["debug"]
local _savedDebugScreenLog = cfg.settings["debugScreenLog"]
cfg.settings["debug"] = true
cfg.settings["debugScreenLog"] = false

local TAG    = "[MT-07]"
local START  = os.date("%Y-%m-%d %H:%M:%S")
local STEP_N = "_MT07_STEP"

local AI_SRC  = "heliai_troops"      -- source late-activation dans le .miz (jamais activé)
local AI_UNIT = "heliai_troops_run"  -- clone temporaire (spawné + détruit en cleanup)
local AIZ_P   = "AIZ_base_B_P_5"
local AIZ_D   = "AIZ_front_B_D"

local function log(msg)    ctld.utils.log("INFO",  TAG .. " " .. msg) end
local function report(msg) trigger.action.outText(TAG .. " " .. msg, 30); log(msg) end

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

local function cleanup()
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
    log("cleanup done")
end

-- ── STATE MACHINE ─────────────────────────────────────────────────────────────
_G[STEP_N] = _G[STEP_N] or 1
local step = _G[STEP_N]
report("==== START " .. START .. " | step=" .. step .. " ====")

if step == 1 then
    pcall(function()
        ctld.utils.closeLog()
        local f = io.open((cfg.settings["ctldLogPath"] or "") .. "CTLD.log", "w")
        if f then f:write("[" .. START .. "] === MT-07 LOG RESET ===\n"); f:close() end
        ctld.utils.reopenLogAppend()
    end)
end

local _step_start = os.clock()
local _result = "INCOMPLETE"
local _ok, _err = pcall(function()

-- ══════════════════════════════════════════════════════════════════════════════
-- STEP 1 — Enregistrement + vérification zones AIZ_
-- ══════════════════════════════════════════════════════════════════════════════
if step == 1 then

    -- Remplacer transportPilotNames par ce pilot UNIQUEMENT (evite contamination inter-scenarios)
    cfg.settings["transportPilotNames"] = { AI_UNIT }

    -- Initialiser les transports AI (debug mode: charge zones; pilots via transportPilotNames)
    CTLDCoreManager.getInstance():_initAITransports()

    -- Vérifier que les zones AIZ_ sont bien découvertes
    local zm = CTLDZoneManager.getInstance()
    local zP = zm._troopZones[AIZ_P]
    local zD = zm._troopZones[AIZ_D]
    check("MT-07.1.1", "AIZ_P zone trouvée : " .. AIZ_P, zP ~= nil)
    check("MT-07.1.2", "AIZ_D zone trouvée : " .. AIZ_D, zD ~= nil)
    if zP then check("MT-07.1.3", "AIZ_P.isAIPickup=true",  zP.isAIPickup  == true) end
    if zD then check("MT-07.1.4", "AIZ_D.isAIDropoff=true", zD.isAIDropoff == true) end

    -- Spawn clone depuis la source late-activation (répétable sans redémarrage DCS)
    local cloneG, cloneErr = spawnClone(AI_SRC, AI_UNIT)
    check("MT-07.1.5", "Clone '" .. AI_UNIT .. "' spawné depuis '" .. AI_SRC .. "'",
          cloneG ~= nil, tostring(cloneErr))

    local unit = Unit.getByName(AI_UNIT)
    if unit then
        check("MT-07.1.6", "Clone sans pilote humain", unit:getPlayerName() == nil)
    end

    local tm = CTLDTroopManager.getInstance()
    check("MT-07.1.7", "Pas encore de troupes à bord (état initial)", not tm:hasTroops(AI_UNIT))

    report("⬛ STEP 1 OK — Pose l'héli sur " .. AIZ_P .. ", attends 3s, re-injecte pour STEP 2")
    _G[STEP_N] = 2
    _result = "step=1 SUCCESS"

-- ══════════════════════════════════════════════════════════════════════════════
-- STEP 2 — Vérifier pickup automatique (héli posé sur AIZ_P)
-- ══════════════════════════════════════════════════════════════════════════════
elseif step == 2 then

    local tm   = CTLDTroopManager.getInstance()
    local hasTr = tm:hasTroops(AI_UNIT)
    check("MT-07.2.1", "hasTroops=true après auto-pickup sur AIZ_P", hasTr,
        "hasTroops=" .. tostring(hasTr))

    if hasTr then
        local list  = tm:getInTransit(AI_UNIT) or {}
        local total = 0
        local names = {}
        for _, grp in ipairs(list) do
            total = total + (grp.unitTotal or 0)
            table.insert(names, grp.templateName or "?")
        end
        report("📦 Cargo: " .. total .. " soldat(s) — " .. table.concat(names, ", "))

        -- Vérifier consommation stock AIZ_P
        local zm = CTLDZoneManager.getInstance()
        local zP = zm._troopZones[AIZ_P]
        if zP and zP.pickMaxStock ~= 0 then
            check("MT-07.2.2", "Stock AIZ_P décrémenté", zP.pickCurrentStock < zP.pickMaxStock,
                "current=" .. tostring(zP.pickCurrentStock) .. " max=" .. tostring(zP.pickMaxStock))
        end

        report("⬛ STEP 2 OK — Envoie l'héli sur " .. AIZ_D .. " (posé), re-injecte pour STEP 3")
        _G[STEP_N] = 3
        _result = "step=2 SUCCESS"
    else
        report("⚠️  Pas encore de troupes — l'héli est-il bien posé dans " .. AIZ_P .. " ?")
        report("   Attends 2s de plus et re-injecte STEP 2.")
        _result = "step=2 WAITING"
    end

-- ══════════════════════════════════════════════════════════════════════════════
-- STEP 3 — Vérifier disembarkAll (héli posé sur AIZ_D)
-- ══════════════════════════════════════════════════════════════════════════════
elseif step == 3 then

    local tm   = CTLDTroopManager.getInstance()
    local hasTr = tm:hasTroops(AI_UNIT)
    check("MT-07.3.1", "hasTroops=false après auto-dropoff sur AIZ_D", not hasTr,
        "hasTroops=" .. tostring(hasTr))

    if not hasTr then
        report("✅ Disembark confirmé — vérifie sur F10 map que des groupes sont apparus près de " .. AIZ_D)
        report("⬛ Re-injecte pour STEP 4 (cleanup)")
        _G[STEP_N] = 4
        _result = "step=3 SUCCESS"
    else
        report("⚠️  Troupes encore à bord — l'héli est-il bien posé dans " .. AIZ_D .. " ?")
        report("   aiDropMode doit être G ou GP et l'héli doit être au sol (inAir=false).")
        _result = "step=3 WAITING"
    end

-- ══════════════════════════════════════════════════════════════════════════════
-- STEP 4 — Cleanup
-- ══════════════════════════════════════════════════════════════════════════════
elseif step == 4 then

    cleanup()
    report("✅ MT-07 ALL SUCCESS — AI troops cycle complet (pickup AIZ_P → disembark AIZ_D)")
    _G[STEP_N] = 1
    _result = "ALL SUCCESS"

else
    fail("step=" .. step .. " sans branche — réinitialise avec _G['" .. STEP_N .. "']=1")
end

end)  -- end pcall

cfg.settings["debug"] = _saved_debug

local _ms = math.floor((os.clock() - _step_start) * 1000)
if not _ok then
    pcall(cleanup)
    trigger.action.outText(TAG .. " ❌ step=" .. step .. " FAIL", 60, true)
    return TAG .. " step=" .. step .. " FAIL: " .. tostring(_err)
end
if _result == "ALL SUCCESS" then
    trigger.action.outText(TAG .. " ✅ ALL SUCCESS (" .. _ms .. "ms)", 30, true)
    return TAG .. " " .. _result .. " (" .. _ms .. "ms)"
end
return TAG .. " " .. _result:gsub("SUCCESS", "SUCCESS (" .. _ms .. "ms)")
                             :gsub("WAITING", "WAITING (" .. _ms .. "ms)")
