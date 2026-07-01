---@diagnostic disable
-- =============================================================================
-- scenario_mt08_ai_vehicle.lua  [INTERACTIVE]
-- MT-08 — AI auto-pickup / auto-dropoff : véhicule entier seul (posé → posé)
--
-- PRÉREQUIS MISSION :
--   - Héli BLUE nommé "heliai_vehicle" (UH-1H), sans pilote humain
--   - Route : WP1 départ → WP2 posé sur AIZ_depot_B_P (pickup) → WP3 vol → WP4 posé sur AIZ_livraison_B_D_G (dropoff)
--   - Zone DCS trigger "AIZ_depot_B_P_V_10"  (rayon ~200 m, autour du HMMWV — V=vehicles only, stock=10)
--   - Zone DCS trigger "AIZ_livraison_B_D_G" (rayon ~200 m, LZ de livraison)
--   - M1045 HMMWV BLUE nommé "hmmwv_cargo" positionné dans AIZ_depot_B_P
--   - capabilitiesByType UH-1H : canTransportWholeVehicle=true (config Do Script)
--   - enable_debug.lua injecté avant ce script
--   - ctldLogPath défini dans le .miz (trigger MISSION START)
--
-- USE CASE : AI se pose sur AIZ_P (S_EVENT_LAND) → loadVehicle HMMWV →
--            vol → posé sur AIZ_D → unloadVehicle sol
--
-- PROTOCOL :
--   Step 1 — Enregistre heliai_vehicle, vérifie zones AIZ_P/AIZ_D et HMMWV
--   Step 2 — Vérifie loadVehicle déclenché (véhicule chargé)
--             Re-injecter après que l'héli soit posé sur AIZ_depot_B_P
--   Step 3 — Vérifie unloadVehicle déclenché (plus de véhicule chargé)
--             Re-injecter après que l'héli soit posé sur AIZ_livraison_B_D_G
--   Step 4 — Cleanup
-- =============================================================================


-- ── Witchcraft guard ────────────────────────────────────────────────
if not ctld or not ctld.utils then
    trigger.action.outText("[MT-08] ABORT: CTLD not initialized. Inject CTLD_Next.lua first.", 15)
    return Witchcraft
end
local cfg = CTLDConfig.get()
local _saved_debug = cfg.settings["debug"]
local _savedDebugScreenLog = cfg.settings["debugScreenLog"]
cfg.settings["debug"] = true
cfg.settings["debugScreenLog"] = true

local TAG    = "[MT-08]"
local START  = os.date("%Y-%m-%d %H:%M:%S")
local STEP_N = "_MT08_STEP"

local AI_UNIT = "heliai_vehicle"
local AIZ_P   = "AIZ_depot_B_P_V_10"
local AIZ_D   = "AIZ_livraison_B_D_G"

local function log(msg)    ctld.utils.log("INFO",  TAG .. " " .. msg) end
local function report(msg) trigger.action.outText(TAG .. " " .. msg, 30); log(msg) end
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
        local ok, vs = pcall(CTLDVehicleSpawner.getInstance)
        if ok and vs then
            local loaded = vs:findLoadedVehicles(unit)
            if loaded and #loaded > 0 then
                vs:unloadVehicle(loaded[1], unit, nil, "menu_ctld")
            end
        end
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
        if f then f:write("[" .. START .. "] === MT-08 LOG RESET ===\n"); f:close() end
        ctld.utils.reopenLogAppend()
    end)
end

local _step_start = os.clock()
local _result = "INCOMPLETE"
local _ok, _err = pcall(function()

-- ══════════════════════════════════════════════════════════════════════════════
-- STEP 1 — Enregistrement + vérification zones AIZ_P/AIZ_D et véhicule
-- ══════════════════════════════════════════════════════════════════════════════
if step == 1 then

    -- Remplacer transportPilotNames par ce pilot UNIQUEMENT (evite contamination inter-scenarios)
    cfg.settings["transportPilotNames"] = { AI_UNIT }
    CTLDCoreManager.getInstance():_initAITransports()

    local zm = CTLDZoneManager.getInstance()

    -- Vérifier zone AIZ_P
    local zP = zm._troopZones[AIZ_P]
    check("MT-08.1.1", "AIZ_P zone trouvée : " .. AIZ_P, zP ~= nil)
    if zP then
        check("MT-08.1.2", "AIZ_P.isAIPickup=true", zP.isAIPickup == true)
    end

    -- Vérifier zone AIZ_D
    local zD = zm._troopZones[AIZ_D]
    check("MT-08.1.3", "AIZ_D zone trouvée : " .. AIZ_D, zD ~= nil)
    if zD then
        check("MT-08.1.4", "AIZ_D.isAIDropoff=true", zD.isAIDropoff == true)
        check("MT-08.1.5", "AIZ_D.aiDropMode='G'", zD.aiDropMode == "G",
            "aiDropMode=" .. tostring(zD.aiDropMode))
    end

    -- Activer le groupe (late-activation dans le .miz)
    local grp = Group.getByName(AI_UNIT)
    if grp then grp:activate() end

    -- Vérifier héli AI
    local unit = Unit.getByName(AI_UNIT)
    check("MT-08.1.6", "Héli AI '" .. AI_UNIT .. "' présent", unit ~= nil)
    if unit then
        check("MT-08.1.7", "Sans pilote humain", unit:getPlayerName() == nil)
        local caps = (ctld.gs("capabilitiesByType") or {})[unit:getTypeName()] or {}
        check("MT-08.1.8", "canTransportWholeVehicle configuré", caps.canTransportWholeVehicle == true)
    end

    -- Vérifier qu'il y a au moins un véhicule loadable WAITING dans la zone AIZ_P
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
        check("MT-08.1.9", "Au moins 1 véhicule WAITING dans la zone " .. AIZ_P, vehInZone > 0,
            "count_in_zone=" .. vehInZone)
    end

    -- Patch runtime : ajouter Hummer dans loadableVehiclesBLUE si absent
    local lv = cfg.settings["loadableVehiclesBLUE"] or {}
    local hvFound = false
    for _, t in ipairs(lv) do if t == "Hummer" then hvFound = true; break end end
    if not hvFound then table.insert(lv, "Hummer"); cfg.settings["loadableVehiclesBLUE"] = lv end

    report("⬛ STEP 1 OK — Pose l'heli sur " .. AIZ_P .. " (HMMWV doit etre dedans), re-injecte pour STEP 2")
    _G[STEP_N] = 2
    _result = "step=1 SUCCESS"

-- ══════════════════════════════════════════════════════════════════════════════
-- STEP 2 — Vérifier loadVehicle déclenché (HMMWV chargé)
-- ══════════════════════════════════════════════════════════════════════════════
elseif step == 2 then

    local unit = Unit.getByName(AI_UNIT)
    if not unit or not unit:isExist() then fail("Héli AI introuvable") end

    local ok, vs = pcall(CTLDVehicleSpawner.getInstance)
    if not ok then fail("CTLDVehicleSpawner indisponible") end

    local loaded = vs:findLoadedVehicles(unit)
    local hasVeh = loaded and #loaded > 0
    check("MT-08.2.1", "Véhicule chargé à bord après posé sur AIZ_P", hasVeh,
        "nb_loaded=" .. tostring(loaded and #loaded or 0))

    if hasVeh then
        local veh = loaded[1]
        report("🚗 Véhicule chargé: id=" .. tostring(veh.id) .. " type=" .. tostring(veh.vehicleType))

        -- Vérifie que l'unité DCS du véhicule chargé n'est plus visible (LOADED = cachée)
        local vehDcsUnit = veh.unit
        check("MT-08.2.2", "Véhicule DCS masqué (état LOADED)",
            vehDcsUnit == nil or not vehDcsUnit:isExist() or veh:getState() == CTLDVehicle.STATE.LOADED)

        report("⬛ STEP 2 OK — Envoie l'héli sur " .. AIZ_D .. " (posé), re-injecte pour STEP 3")
        _G[STEP_N] = 3
        _result = "step=2 SUCCESS"
    else
        report("⚠️  Pas de véhicule chargé — l'héli est-il bien posé dans " .. AIZ_P .. " avec le HMMWV dedans ?")
        _result = "step=2 WAITING"
    end

-- ══════════════════════════════════════════════════════════════════════════════
-- STEP 3 — Vérifier unloadVehicle déclenché (plus de véhicule chargé)
-- ══════════════════════════════════════════════════════════════════════════════
elseif step == 3 then

    local unit = Unit.getByName(AI_UNIT)
    if not unit or not unit:isExist() then fail("Héli AI introuvable") end

    local ok, vs = pcall(CTLDVehicleSpawner.getInstance)
    if not ok then fail("CTLDVehicleSpawner indisponible") end

    local loaded = vs:findLoadedVehicles(unit)
    local hasVeh = loaded and #loaded > 0
    check("MT-08.3.1", "Véhicule déchargé après posé sur AIZ_D", not hasVeh,
        "nb_loaded=" .. tostring(loaded and #loaded or 0))

    if not hasVeh then
        report("✅ Unload confirmé — vérifie sur F10 map que le HMMWV est apparu près de " .. AIZ_D)
        report("⬛ Re-injecte pour STEP 4 (cleanup)")
        _G[STEP_N] = 4
        _result = "step=3 SUCCESS"
    else
        report("⚠️  Véhicule encore à bord — l'héli est-il bien posé dans " .. AIZ_D .. " ?")
        _result = "step=3 WAITING"
    end

-- ══════════════════════════════════════════════════════════════════════════════
-- STEP 4 — Cleanup
-- ══════════════════════════════════════════════════════════════════════════════
elseif step == 4 then

    cleanup()
    report("✅ MT-08 ALL SUCCESS — AI vehicle cycle complet (pickup AIZ_P → unload AIZ_D)")
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
