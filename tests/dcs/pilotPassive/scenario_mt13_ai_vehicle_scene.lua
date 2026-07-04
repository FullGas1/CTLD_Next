---@diagnostic disable
-- =============================================================================
-- scenario_mt13_ai_vehicle_scene.lua  [INTERACTIVE]
-- MT-13 — AI auto-pickup d'une scène CTLDSceneManager via vehicleStock (Feature T)
--
-- PRÉREQUIS MISSION :
--   - Héli BLUE nommé "heliai_mt13" (UH-60L ou tout appareil canTransportWholeVehicle=true)
--   - Route : WP1 = posé sur AIZ_mt13_B_P_V → WP2 = vol → WP3 = posé sur AIZ_mt13_B_D
--   - Zone DCS trigger "AIZ_mt13_B_P_V" (rayon ~200 m, centré sur WP1)
--   - Zone DCS trigger "AIZ_mt13_B_D"   (rayon ~200 m, centré sur WP3)
--   - AUCUN groupe DCS véhicule dans AIZ_mt13_B_P_V — le scan physique (C1) prendrait
--     le dessus sur le stock virtuel (C2) et _aiTransportVehicle ne serait pas peuplé.
--   - Espace dégagé près de AIZ_mt13_B_D (la scène FARP Alpha déploie plusieurs statics)
--   - enable_debug.lua injecté avant ce script
--   - ctldLogPath défini dans le .miz (trigger MISSION START)
--
-- USE CASE :
--   Zone AIZ_mt13_B_P_V : vehicleStock = { ["FARP Alpha"] = 1 }
--   C1 : scan physique DCS — aucun véhicule présent → pas de loadVehicle()
--   C2 : aiPickVehicleEntry() → { type="FARP Alpha", isScene=true }
--        CTLDSceneManager:getScene("FARP Alpha") != nil → isScene=true
--        → _aiTransportVehicle[unitName] peuplé + aiConsumeVehicleStock → current=0
--   Au dropoff : CTLDSceneManager:playScene(u, "FARP Alpha", nil, nil)
--                Déploie les statics FARP à la position de l'AIZ_D
--                Message coalition "AI heliai_mt13 delivered vehicle: FARP Alpha"
--   IMPORTANT : vehicleStock=nil bloquerait le pickup (règle A).
--
-- PROTOCOL :
--   Step 1 — Enregistre heliai_mt13 + vérifie vehicleStock + isScene=true
--   Step 2 — Vérifie pickup virtuel (isScene=true + stock 1→0)
--             Re-injecter après que l'héli soit posé sur AIZ_mt13_B_P_V (~2s)
--   Step 3 — Vérifie dropoff (playScene déclenché = statics FARP visibles + _aiTransportVehicle vidé)
--             Re-injecter après que l'héli soit posé sur AIZ_mt13_B_D
--   Step 4 — Cleanup
-- =============================================================================


-- ── Witchcraft guard ────────────────────────────────────────────────
if not ctld or not ctld.utils then
    trigger.action.outText("[MT-13] ABORT: CTLD not initialized. Inject CTLD_Next.lua first.", 15)
    return Witchcraft
end
local cfg = CTLDConfig.get()
local _saved_debug = cfg.settings["debug"]
local _savedDebugScreenLog = cfg.settings["debugScreenLog"]
cfg.settings["debug"] = true
cfg.settings["debugScreenLog"] = false

local TAG    = "[MT-13]"
local START  = os.date("%Y-%m-%d %H:%M:%S")
local STEP_N = "_MT13_STEP"

local AI_SRC     = "heliai_mt13"      -- source late-activation dans le .miz (jamais activé)
local AI_UNIT    = "heliai_mt13_run"  -- clone temporaire (spawné + détruit en cleanup)
local AIZ_P      = "AIZ_mt13_B_P_V"
local AIZ_D      = "AIZ_mt13_B_D"
local SCENE_NAME = "FARP Alpha"

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
    trigger.action.outText(TAG .. " !! FAIL: " .. msg, 60)
    log("FAIL: " .. msg)
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
    local cm = CTLDCoreManager.getInstance()
    if cm._aiTransportVehicle then cm._aiTransportVehicle[AI_UNIT] = nil end
    destroyClone(AI_UNIT)
    log("cleanup done")
end

-- ── STATE MACHINE ─────────────────────────────────────────────────────────────
_G[STEP_N] = _G[STEP_N] or 1
local step = _G[STEP_N]
report("==== START " .. START .. " | step=" .. step .. " ====")

local _step_start = os.clock()
local _result = "INCOMPLETE"
local _ok, _err = pcall(function()

-- ══════════════════════════════════════════════════════════════════════════════
-- STEP 1 — Init zones + vérification vehicleStock + isScene
-- ══════════════════════════════════════════════════════════════════════════════
if step == 1 then

    cfg.settings["transportPilotNames"] = { AI_UNIT }
    CTLDCoreManager.getInstance():_initAITransports()

    -- Vérifier que "FARP Alpha" est bien une scène enregistrée
    local sm = CTLDSceneManager.getInstance()
    local scene = sm:getScene(SCENE_NAME)
    check("MT-13.1.1", "'FARP Alpha' enregistrée dans CTLDSceneManager", scene ~= nil,
          "'FARP Alpha' not found in _models")

    local zm = CTLDZoneManager.getInstance()
    local zP = zm._troopZones[AIZ_P]
    local zD = zm._troopZones[AIZ_D]
    check("MT-13.1.2", "AIZ_P trouvée : " .. AIZ_P, zP ~= nil)
    check("MT-13.1.3", "AIZ_D trouvée : " .. AIZ_D, zD ~= nil)
    if zP then
        check("MT-13.1.4", "AIZ_P.isAIPickup=true",        zP.isAIPickup == true)
        check("MT-13.1.5", "AIZ_P.aiCargoType='V'",         zP.aiCargoType == "V",
              tostring(zP.aiCargoType))
        check("MT-13.1.6", "AIZ_P._aiVehicleStock non-nil", zP._aiVehicleStock ~= nil)
        if zP._aiVehicleStock then
            local vs = zP._aiVehicleStock
            check("MT-13.1.7", "_aiVehicleStock.isAll=false", vs.isAll == false)
            check("MT-13.1.8", "init['FARP Alpha']=1",
                  vs.init[SCENE_NAME] == 1, tostring(vs.init[SCENE_NAME]))
            check("MT-13.1.9", "current['FARP Alpha']=1 (init)",
                  vs.current[SCENE_NAME] == 1, tostring(vs.current[SCENE_NAME]))
        end
    end

    -- Vérifier que aiPickVehicleEntry detecte bien isScene=true pour "FARP Alpha"
    if zP then
        local entry = zP:aiPickVehicleEntry()
        check("MT-13.1.10", "aiPickVehicleEntry retourne non-nil", entry ~= nil)
        if entry then
            check("MT-13.1.11", "entry.type='FARP Alpha'",
                  entry.type == SCENE_NAME, tostring(entry.type))
            check("MT-13.1.12", "entry.isScene=true (scène CTLDSceneManager)",
                  entry.isScene == true, tostring(entry.isScene))
        end
    end

    -- Spawn clone depuis la source late-activation (répétable sans redémarrage DCS)
    local cloneG, cloneErr = spawnClone(AI_SRC, AI_UNIT)
    check("MT-13.1.13", "Clone '" .. AI_UNIT .. "' spawné depuis '" .. AI_SRC .. "'",
          cloneG ~= nil, tostring(cloneErr))

    local unit = Unit.getByName(AI_UNIT)

    local cm = CTLDCoreManager.getInstance()
    check("MT-13.1.14", "_aiTransportVehicle[heliai_mt13] vide initialement",
          cm._aiTransportVehicle[AI_UNIT] == nil)

    report("⬛ STEP 1 OK — Pose l'héli sur " .. AIZ_P .. ", attends 3s, re-injecte pour STEP 2")
    report("   C1 (physique) = aucun véhicule DCS dans la zone → C2 (FARP Alpha isScene=true) s'applique")
    _G[STEP_N] = 2
    _result = "step=1 SUCCESS"

-- ══════════════════════════════════════════════════════════════════════════════
-- STEP 2 — Vérifier pickup virtuel C2 (isScene=true + stock décrémenté)
-- ══════════════════════════════════════════════════════════════════════════════
elseif step == 2 then

    local cm = CTLDCoreManager.getInstance()
    local vEntry = cm._aiTransportVehicle[AI_UNIT]

    if vEntry == nil then
        -- Diagnostic C1/C2 : vérifier si un véhicule physique a été chargé à la place
        local ok, vs = pcall(CTLDVehicleSpawner.getInstance)
        if ok and vs then
            local u = Unit.getByName(AI_UNIT)
            local loaded = u and u:isExist() and vs:findLoadedVehicles(u) or {}
            if #loaded > 0 then
                fail("MT-13.2.0 — C1 (physique) a pris le dessus : un véhicule DCS est chargé — retirer tout groupe DCS de " .. AIZ_P)
            end
        end
        report("⚠️  _aiTransportVehicle[" .. AI_UNIT .. "]=nil — l'héli est-il bien posé dans " .. AIZ_P .. " ?")
        report("   Attends 2s de plus et re-injecte STEP 2.")
        _result = "step=2 WAITING"
        return
    end

    check("MT-13.2.1", "_aiTransportVehicle peuplé au pickup", vEntry ~= nil)
    check("MT-13.2.2", "type='FARP Alpha'",
          vEntry.type == SCENE_NAME, tostring(vEntry.type))
    check("MT-13.2.3", "isScene=true (scène CTLDSceneManager, pas DCS natif)",
          vEntry.isScene == true, tostring(vEntry.isScene))
    report("🏕️ En transit : " .. tostring(vEntry.type) .. " | isScene=" .. tostring(vEntry.isScene))

    -- Vérifier stock décrémenté (1→0)
    local zm = CTLDZoneManager.getInstance()
    local zP = zm._troopZones[AIZ_P]
    if zP and zP._aiVehicleStock then
        local cur = zP._aiVehicleStock.current[SCENE_NAME]
        check("MT-13.2.4", "stock 'FARP Alpha' décrémenté (1→0)",
              cur == 0, "current=" .. tostring(cur))
    end

    report("⬛ STEP 2 OK — Envoie l'héli sur " .. AIZ_D .. " (posé), re-injecte pour STEP 3")
    report("   La scène FARP Alpha va se déployer à la position de " .. AIZ_D)
    _G[STEP_N] = 3
    _result = "step=2 SUCCESS"

-- ══════════════════════════════════════════════════════════════════════════════
-- STEP 3 — Vérifier dropoff (playScene + _aiTransportVehicle vidé)
-- ══════════════════════════════════════════════════════════════════════════════
elseif step == 3 then

    local cm = CTLDCoreManager.getInstance()
    local vEntry = cm._aiTransportVehicle[AI_UNIT]

    if vEntry ~= nil then
        report("⚠️  _aiTransportVehicle encore peuplé — l'héli est-il bien posé dans " .. AIZ_D .. " ?")
        _result = "step=3 WAITING"
        return
    end

    check("MT-13.3.1", "_aiTransportVehicle vidé après dropoff (playScene appelé)", vEntry == nil)
    report("🏕️ Dropoff scène confirmé — vérifie sur F10 map que les statics FARP Alpha sont apparus près de " .. AIZ_D)
    report("   Éléments attendus : tente FARP, stockage munitions, générateur, personnel sécurité, etc.")
    report("   Message coalition attendu : 'AI heliai_mt13 delivered vehicle: FARP Alpha'")
    report("⬛ Re-injecte pour STEP 4 (cleanup)")
    _G[STEP_N] = 4
    _result = "step=3 SUCCESS"

-- ══════════════════════════════════════════════════════════════════════════════
-- STEP 4 — Cleanup
-- ══════════════════════════════════════════════════════════════════════════════
elseif step == 4 then

    cleanup()
    report("✅ MT-13 ALL SUCCESS — pickup scène 'FARP Alpha' (isScene=true) + stock 1→0 + playScene confirmés")
    _G[STEP_N] = 1
    _result = "ALL SUCCESS"

else
    fail("step=" .. step .. " sans branche — réinitialise avec _G['" .. STEP_N .. "']=1")
end

end)  -- end pcall

cfg.settings["debug"] = _saved_debug
cfg.settings["debugScreenLog"] = _savedDebugScreenLog

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
