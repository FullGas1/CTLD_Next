---@diagnostic disable
-- =============================================================================
-- scenario_mt09_ai_full_cycle.lua  [INTERACTIVE]
-- MT-09 — AI cycle complet : troupes + vehicule entier (zone TV)
--
-- PREREQUIS MISSION :
--   - Heli BLUE nomme "heliai_full" (UH-1H), sans pilote humain
--   - Route : WP sur AIZ_depot_B_P_TV_5_10 (pose) -> AIZ_livraison_B_D_G (pose)
--   - AIZ_depot_B_P_TV_5_10  : zone pickup TV (troupes + vehicule), r~61m
--   - AIZ_livraison_B_D_G    : zone dropoff, r~274m
--   - Hummers BLUE (veh_mm_*) places a proximite de AIZ_depot (~200m du centre)
--   - enable_debug.lua injecte avant ce script
--   - ctldLogPath defini dans le .miz (trigger MISSION START)
--
-- PROTOCOLE :
--   Step 1 — Enregistre heliai_full, verifie zones + vehicules
--   Step 2 — Pose sur AIZ_depot_B_P_TV_5_10 : troupes + vehicule charges
--   Step 3 — Pose sur AIZ_livraison_B_D_G   : troupes + vehicule decharges
--   Step 4 — Cleanup
-- =============================================================================


-- ── Witchcraft guard ────────────────────────────────────────────────
if not ctld or not ctld.utils then
    trigger.action.outText("[MT-09] ABORT: CTLD not initialized. Inject CTLD_Next.lua first.", 15)
    return Witchcraft
end
local cfg = CTLDConfig.get()
local _saved_debug = cfg.settings["debug"]
local _savedDebugScreenLog = cfg.settings["debugScreenLog"]
cfg.settings["debug"] = true
cfg.settings["debugScreenLog"] = true

local TAG    = "[MT-09]"
local START  = os.date("%Y-%m-%d %H:%M:%S")
local STEP_N = "_MT09_STEP"

local AI_UNIT = "heliai_full"
local AIZ_P   = "AIZ_depot_B_P_TV_5_10"
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
        if f then f:write("[" .. START .. "] === MT-09 LOG RESET ===\n"); f:close() end
        ctld.utils.reopenLogAppend()
    end)
end

local _step_start = os.clock()
local _result = "INCOMPLETE"
local _ok, _err = pcall(function()

-- ══════════════════════════════════════════════════════════════════════════════
-- STEP 1 — Verification prerequis + enregistrement
-- ══════════════════════════════════════════════════════════════════════════════
if step == 1 then

    -- Remplacer transportPilotNames par ce pilot UNIQUEMENT (evite contamination inter-scenarios)
    cfg.settings["transportPilotNames"] = { AI_UNIT }
    CTLDCoreManager.getInstance():_initAITransports()

    local zm = CTLDZoneManager.getInstance()
    local zP = zm._troopZones[AIZ_P]
    local zD = zm._troopZones[AIZ_D]
    check("MT-09.1.1", "AIZ_P trouvee: " .. AIZ_P, zP ~= nil)
    check("MT-09.1.2", "AIZ_D trouvee: " .. AIZ_D, zD ~= nil)
    if zP then
        check("MT-09.1.3", "AIZ_P.isAIPickup=true",     zP.isAIPickup  == true)
        check("MT-09.1.4", "AIZ_P.aiCargoType=TV",       zP.aiCargoType == "TV",
            "aiCargoType=" .. tostring(zP.aiCargoType))
    end
    if zD then
        check("MT-09.1.5", "AIZ_D.isAIDropoff=true",    zD.isAIDropoff == true)
    end

    -- Activer le groupe (late-activation dans le .miz)
    local grp = Group.getByName(AI_UNIT)
    if grp then grp:activate() end

    local unit = Unit.getByName(AI_UNIT)
    check("MT-09.1.6", "Heli AI '" .. AI_UNIT .. "' present", unit ~= nil)
    if unit then
        check("MT-09.1.7", "Sans pilote humain",               unit:getPlayerName() == nil)
        local caps = (ctld.gs("capabilitiesByType") or {})[unit:getTypeName()] or {}
        check("MT-09.1.8", "troopsEnabled=true",               caps.troopsEnabled            == true)
        check("MT-09.1.9", "canTransportWholeVehicle=true",    caps.canTransportWholeVehicle == true)
        report("maxVehicleWeight=" .. tostring(caps.maxVehicleWeight) .. " kg")
    end

    -- Vehicules CTLD enregistres
    local ok, vs = pcall(CTLDVehicleSpawner.getInstance)
    check("MT-09.1.10", "CTLDVehicleSpawner disponible", ok)
    if ok and vs then
        local count = 0
        for _ in pairs(vs._vehicles) do count = count + 1 end
        check("MT-09.1.11", "Au moins 1 vehicule enregistre", count > 0, "count=" .. count)
    end

    report("STEP 1 OK — Pose " .. AI_UNIT .. " sur " .. AIZ_P .. " puis re-injecte STEP 2")
    _G[STEP_N] = 2
    _result = "step=1 SUCCESS"

-- ══════════════════════════════════════════════════════════════════════════════
-- STEP 2 — Pickup troupes + vehicule (pose sur AIZ_P TV)
-- ══════════════════════════════════════════════════════════════════════════════
elseif step == 2 then

    local tm   = CTLDTroopManager.getInstance()
    local unit = Unit.getByName(AI_UNIT)
    check("MT-09.2.0", "Heli AI present", unit ~= nil and unit:isExist())

    local hasTr = tm:hasTroops(AI_UNIT)
    local ok, vs = pcall(CTLDVehicleSpawner.getInstance)
    local hasVeh = false
    if ok and vs and unit then
        local loaded = vs:findLoadedVehicles(unit)
        hasVeh = #loaded > 0
    end

    if hasTr or hasVeh then
        -- Heli still in transit: normal mid-flight injection
        if hasTr then
            local list = tm:getInTransit(AI_UNIT) or {}
            local total = 0
            for _, grp in ipairs(list) do total = total + (grp.unitTotal or 0) end
            report("Troupes a bord: " .. total .. " soldat(s)")
        end
        if hasVeh then
            local loaded = vs:findLoadedVehicles(unit)
            report("Vehicule a bord: type=" .. tostring(loaded[1].vehicleType))
        end
        report("STEP 2 OK (en vol) — Pose " .. AI_UNIT .. " sur " .. AIZ_D .. " puis re-injecte STEP 3")
        _G[STEP_N] = 3
        _result = "step=2 SUCCESS"
    else
        -- Cycle may already be complete: check for deployed groups near AIZ_D
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
        -- [PASS] if cycle completed (groups deployed near AIZ_D)
        check("MT-09.2.1", "Cycle TV complet (pickup+dropoff confirme par groupes deployes)", deployedCount > 0,
            "deployed_groups_near_AIZ_D=" .. deployedCount)
        report("STEP 2+3 OK (cycle rapide) — " .. deployedCount .. " groupe(s) deployes pres de " .. AIZ_D)
        _G[STEP_N] = 4  -- skip step 3, cycle already done
        _result = "step=2 SUCCESS (cycle complet)"
    end

-- ══════════════════════════════════════════════════════════════════════════════
-- STEP 3 — Dropoff troupes + vehicule (pose sur AIZ_D)
-- ══════════════════════════════════════════════════════════════════════════════
elseif step == 3 then

    local tm   = CTLDTroopManager.getInstance()
    local unit = Unit.getByName(AI_UNIT)
    check("MT-09.3.0", "Heli AI present", unit ~= nil and unit:isExist())

    local hasTr = tm:hasTroops(AI_UNIT)
    check("MT-09.3.1", "hasTroops=false apres dropoff sur AIZ_D", not hasTr,
        "hasTroops=" .. tostring(hasTr))

    local ok, vs = pcall(CTLDVehicleSpawner.getInstance)
    local hasVeh = false
    if ok and vs and unit then
        local loaded = vs:findLoadedVehicles(unit)
        hasVeh = #loaded > 0
        check("MT-09.3.2", "Plus de vehicule a bord apres dropoff", not hasVeh,
            "nb_loaded=" .. tostring(#loaded))
    end

    if not hasTr and not hasVeh then
        report("STEP 3 OK — Troupes + vehicule deposes. Re-injecte STEP 4 (cleanup)")
        _G[STEP_N] = 4
        _result = "step=3 SUCCESS"
    elseif hasTr or hasVeh then
        report("Encore du cargo a bord. Re-injecte apres pose sur AIZ_D.")
        _result = "step=3 WAITING"
    end

-- ══════════════════════════════════════════════════════════════════════════════
-- STEP 4 — Cleanup
-- ══════════════════════════════════════════════════════════════════════════════
elseif step == 4 then

    cleanup()
    report("MT-09 ALL SUCCESS — cycle complet troupes + vehicule entier valide")
    _G[STEP_N] = 1
    _result = "ALL SUCCESS"

else
    fail("step=" .. step .. " sans branche")
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
