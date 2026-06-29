---@diagnostic disable
-- =============================================================================
-- scenario_mt12_ai_vehicle_native.lua  [INTERACTIVE]
-- MT-12 — AI auto-pickup d'un véhicule DCS natif via vehicleStock (Feature T)
--
-- PRÉREQUIS MISSION :
--   - Héli BLUE nommé "heliai_mt12" (UH-60L ou tout appareil canTransportWholeVehicle=true)
--     Note: si UH-1H utilisé, s'assurer que groundVehicleWeights["Hummer"] <= maxVehicleWeight
--   - Route : WP1 = posé sur AIZ_mt12_B_P_V → WP2 = vol → WP3 = posé sur AIZ_mt12_B_D
--   - Zone DCS trigger "AIZ_mt12_B_P_V" (rayon ~200 m, centré sur WP1)
--   - Zone DCS trigger "AIZ_mt12_B_D"   (rayon ~200 m, centré sur WP3)
--   - AUCUN groupe DCS véhicule dans AIZ_mt12_B_P_V — le scan physique (C1) prendrait
--     le dessus sur le stock virtuel (C2) et _aiTransportVehicle ne serait pas peuplé.
--   - enable_debug.lua injecté avant ce script
--   - ctldLogPath défini dans le .miz (trigger MISSION START)
--
-- USE CASE :
--   Zone AIZ_mt12_B_P_V : vehicleStock = { ["Hummer"] = 2 }
--   C1 : scan physique DCS — aucun véhicule présent → pas de loadVehicle()
--   C2 : aiPickVehicleEntry() → { type="Hummer", isScene=false }
--        → _aiTransportVehicle[unitName] peuplé + aiConsumeVehicleStock → current=1
--   Au dropoff : spawnVehicleAt({ vehicleType="Hummer" }) à la position de l'AIZ_D
--                Message coalition "AI heliai_mt12 delivered vehicle: Hummer"
--   IMPORTANT : vehicleStock=nil bloquerait le pickup (règle A).
--
-- PROTOCOL :
--   Step 1 — Enregistre heliai_mt12 + vérifie zones + vehicleStock initial
--   Step 2 — Vérifie pickup virtuel (_aiTransportVehicle peuplé + stock décrémenté)
--             Re-injecter après que l'héli soit posé sur AIZ_mt12_B_P_V (~2s)
--   Step 3 — Vérifie dropoff (spawn DCS Hummer + _aiTransportVehicle vidé + stock restauré si navette)
--             Re-injecter après que l'héli soit posé sur AIZ_mt12_B_D
--   Step 4 — Cleanup
-- =============================================================================

local cfg = CTLDConfig.get()
local _saved_debug = cfg.settings["debug"]
cfg.settings["debug"] = true

local TAG    = "[MT-12]"
local START  = os.date("%Y-%m-%d %H:%M:%S")
local STEP_N = "_MT12_STEP"

local AI_UNIT    = "heliai_mt12"
local AIZ_P      = "AIZ_mt12_B_P_V"
local AIZ_D      = "AIZ_mt12_B_D"
local VEH_TYPE   = "Hummer"

local function log(msg)    ctld.utils.log("INFO",  TAG .. " " .. msg) end
local function report(msg) trigger.action.outText(TAG .. " " .. msg, 30); log(msg) end
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
-- STEP 1 — Init zones + vehicleStock initial
-- ══════════════════════════════════════════════════════════════════════════════
if step == 1 then

    cfg.settings["transportPilotNames"] = { AI_UNIT }
    CTLDCoreManager.getInstance():_initAITransports()

    local zm = CTLDZoneManager.getInstance()
    local zP = zm._troopZones[AIZ_P]
    local zD = zm._troopZones[AIZ_D]
    check("MT-12.1.1", "AIZ_P trouvée : " .. AIZ_P, zP ~= nil)
    check("MT-12.1.2", "AIZ_D trouvée : " .. AIZ_D, zD ~= nil)
    if zP then
        check("MT-12.1.3", "AIZ_P.isAIPickup=true",        zP.isAIPickup == true)
        check("MT-12.1.4", "AIZ_P.aiCargoType='V'",         zP.aiCargoType == "V",
              tostring(zP.aiCargoType))
        check("MT-12.1.5", "AIZ_P._aiVehicleStock non-nil", zP._aiVehicleStock ~= nil)
        check("MT-12.1.6", "AIZ_P._aiTroopStock=nil",       zP._aiTroopStock == nil)
        if zP._aiVehicleStock then
            local vs = zP._aiVehicleStock
            check("MT-12.1.7", "_aiVehicleStock.isAll=false", vs.isAll == false)
            check("MT-12.1.8", "init[Hummer]=2",
                  vs.init[VEH_TYPE] == 2, tostring(vs.init[VEH_TYPE]))
            check("MT-12.1.9", "current[Hummer]=2 (init)",
                  vs.current[VEH_TYPE] == 2, tostring(vs.current[VEH_TYPE]))
            check("MT-12.1.10", "pickMaxStock=0 (gate illimitée)",
                  zP.pickMaxStock == 0, tostring(zP.pickMaxStock))
        end
    end

    -- Vérifier que Hummer n'est pas une scène enregistrée
    local sm = CTLDSceneManager.getInstance()
    check("MT-12.1.11", "Hummer n'est pas une scène CTLDSceneManager",
          sm:getScene(VEH_TYPE) == nil)

    -- Activer le groupe (late-activation dans le .miz)
    local grp = Group.getByName(AI_UNIT)
    if grp then grp:activate() end

    local unit = Unit.getByName(AI_UNIT)
    check("MT-12.1.12", "Unité AI '" .. AI_UNIT .. "' présente en mission", unit ~= nil)

    -- Vérifier _aiTransportVehicle vide au départ
    local cm = CTLDCoreManager.getInstance()
    check("MT-12.1.13", "_aiTransportVehicle[heliai_mt12] vide initialement",
          cm._aiTransportVehicle[AI_UNIT] == nil)

    report("⬛ STEP 1 OK — Pose l'héli sur " .. AIZ_P .. ", attends 3s, re-injecte pour STEP 2")
    report("   C1 (physique) = aucun véhicule DCS dans la zone → C2 (virtuel Hummer) s'applique")
    _G[STEP_N] = 2
    _result = "step=1 SUCCESS"

-- ══════════════════════════════════════════════════════════════════════════════
-- STEP 2 — Vérifier pickup virtuel (C2 path — aucun véhicule physique dans la zone)
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
                fail("MT-12.2.0 — C1 (physique) a pris le dessus : un véhicule DCS est chargé dans l'héli — retirer le groupe DCS de " .. AIZ_P)
            end
        end
        report("⚠️  _aiTransportVehicle[" .. AI_UNIT .. "]=nil — l'héli est-il bien posé dans " .. AIZ_P .. " ?")
        report("   Attends 2s de plus et re-injecte STEP 2.")
        _result = "step=2 WAITING"
        return
    end

    check("MT-12.2.1", "_aiTransportVehicle peuplé au pickup", vEntry ~= nil)
    check("MT-12.2.2", "type='Hummer'", vEntry.type == VEH_TYPE,
          tostring(vEntry.type))
    check("MT-12.2.3", "isScene=false (DCS natif, pas de scène)",
          vEntry.isScene == false, tostring(vEntry.isScene))
    report("🚗 En transit : " .. tostring(vEntry.type) .. " | isScene=" .. tostring(vEntry.isScene))

    -- Vérifier stock décrémenté
    local zm = CTLDZoneManager.getInstance()
    local zP = zm._troopZones[AIZ_P]
    if zP and zP._aiVehicleStock then
        local cur = zP._aiVehicleStock.current[VEH_TYPE]
        check("MT-12.2.4", "stock Hummer décrémenté (1 consommé → current=1)",
              cur == 1, "current=" .. tostring(cur))
    end

    report("⬛ STEP 2 OK — Envoie l'héli sur " .. AIZ_D .. " (posé), re-injecte pour STEP 3")
    _G[STEP_N] = 3
    _result = "step=2 SUCCESS"

-- ══════════════════════════════════════════════════════════════════════════════
-- STEP 3 — Vérifier dropoff (spawn DCS + _aiTransportVehicle vidé)
-- ══════════════════════════════════════════════════════════════════════════════
elseif step == 3 then

    local cm = CTLDCoreManager.getInstance()
    local vEntry = cm._aiTransportVehicle[AI_UNIT]

    if vEntry ~= nil then
        report("⚠️  _aiTransportVehicle encore peuplé — l'héli est-il bien posé dans " .. AIZ_D .. " ?")
        _result = "step=3 WAITING"
        return
    end

    check("MT-12.3.1", "_aiTransportVehicle vidé après dropoff", vEntry == nil)
    report("🚗 Dropoff confirmé — vérifie sur F10 map qu'un groupe Hummer est apparu près de " .. AIZ_D)
    report("   Message coalition attendu : 'AI heliai_mt12 delivered vehicle: Hummer'")
    report("⬛ Re-injecte pour STEP 4 (cleanup)")
    _G[STEP_N] = 4
    _result = "step=3 SUCCESS"

-- ══════════════════════════════════════════════════════════════════════════════
-- STEP 4 — Cleanup
-- ══════════════════════════════════════════════════════════════════════════════
elseif step == 4 then

    cleanup()
    report("✅ MT-12 ALL SUCCESS — pickup virtuel Hummer (isScene=false) + stock décrément + spawn DCS confirmés")
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
    return TAG .. " step=" .. step .. " FAIL: " .. tostring(_err)
end
if _result == "ALL SUCCESS" then
    return TAG .. " " .. _result .. " (" .. _ms .. "ms)"
end
return TAG .. " " .. _result:gsub("SUCCESS", "SUCCESS (" .. _ms .. "ms)")
                             :gsub("WAITING", "WAITING (" .. _ms .. "ms)")
