---@diagnostic disable
-- =============================================================================
-- aiTransport_featureT_stockParsing_F176.lua  [AUTO]
-- F-176 — Feature T : vérification du parsing troopStock/vehicleStock tables
--
-- PRÉREQUIS : CTLD initialisé, zones de debug présentes dans le .miz
--   (AIZ_base_B_P_5, AIZ_depot_B_P_T_10, AIZ_depot_B_P_V_10, AIZ_depot_B_P_TV_5_10)
--
-- OBJECTIF : vérifier que _loadAIZonesFromConfig() peuple correctement
--   les champs _aiTroopStock et _aiVehicleStock sur les CTLDTroopZone créées.
-- =============================================================================

-- ── 1. Witchcraft guard ──────────────────────────────────────────────────────
if not ctld or not ctld.utils then
    trigger.action.outText("[F-176] ABORT: CTLD not initialized. Inject CTLD_Next.lua first.", 15)
    return Witchcraft
end

-- ── 2. Double-injection guard ────────────────────────────────────────────────
if _SCN_F176_RUNNING then
    trigger.action.outText("[F-176] already running.", 10)
    return Witchcraft
end
_SCN_F176_RUNNING = true

do

local cfg = CTLDConfig.get()
local _savedDebug          = cfg.settings["debug"]
local _savedDebugScreenLog = cfg.settings["debugScreenLog"]
cfg.settings["debug"]          = true
cfg.settings["debugScreenLog"] = true
local _saved_debug = _savedDebug  -- alias pour compatibilité avec le code existant

local TAG   = "[F-176]"
local START = os.date("%Y-%m-%d %H:%M:%S")
ctld_test = ctld_test or {}

local function log(msg)    ctld.utils.log("INFO", TAG .. " " .. msg) end
local function report(msg) trigger.action.outText(TAG .. " " .. msg, 20); log(msg) end
local function pass(id, desc)   report("[PASS] " .. id .. " — " .. desc) end
local function fail(id, desc, details)
    local msg = "[FAIL] " .. id .. " — " .. desc .. (details and (" | " .. details) or "")
    trigger.action.outText(TAG .. " !! " .. msg, 60); log(msg)
    error(msg)
end
local function check(id, desc, cond, details)
    if cond then pass(id, desc) else fail(id, desc, details) end
end

report("==== START " .. START .. " ====")

local _ok, _err = pcall(function()

    -- Re-init AIZ zones (reset _aiZoneErrors, reload from config)
    cfg.settings["transportPilotNames"] = {}
    CTLDCoreManager.getInstance():_initAITransports()

    local zm = CTLDZoneManager.getInstance()

    -- ── Zone AIZ_base_B_P_5 : troopStock={Standard Group=5, Anti Tank=2} ──────
    local zBase = zm._troopZones["AIZ_base_B_P_5"]
    check("F-176.1", "AIZ_base_B_P_5 existe", zBase ~= nil)
    if zBase then
        local ts = zBase._aiTroopStock
        check("F-176.2", "_aiTroopStock non-nil",   ts ~= nil)
        check("F-176.3", "_aiTroopStock.isAll=false", ts and ts.isAll == false, tostring(ts and ts.isAll))
        check("F-176.4", "init[Standard Group]=5",   ts and ts.init["Standard Group"] == 5,
              tostring(ts and ts.init["Standard Group"]))
        check("F-176.5", "init[Anti Tank]=2",        ts and ts.init["Anti Tank"] == 2,
              tostring(ts and ts.init["Anti Tank"]))
        check("F-176.6", "current[Standard Group] initialized", ts and ts.current["Standard Group"] == 5,
              tostring(ts and ts.current["Standard Group"]))
        check("F-176.7", "_aiVehicleStock=nil (T-only zone)", zBase._aiVehicleStock == nil)
        -- pickMaxStock=0 (unlimited gate — real stock managed by _aiTroopStock)
        check("F-176.8", "pickMaxStock=0 (unlimited gate)", zBase.pickMaxStock == 0)
    end

    -- ── Zone AIZ_depot_B_P_T_10 : troopStock={All=-1} ────────────────────────
    local zAll = zm._troopZones["AIZ_depot_B_P_T_10"]
    check("F-176.9", "AIZ_depot_B_P_T_10 existe", zAll ~= nil)
    if zAll then
        local ts = zAll._aiTroopStock
        check("F-176.10", "_aiTroopStock.isAll=true", ts and ts.isAll == true, tostring(ts and ts.isAll))
    end

    -- ── Zone AIZ_depot_B_P_V_10 : vehicleStock={Hummer=3, M1025...=-1} ───────
    local zVeh = zm._troopZones["AIZ_depot_B_P_V_10"]
    check("F-176.11", "AIZ_depot_B_P_V_10 existe", zVeh ~= nil)
    if zVeh then
        local vs = zVeh._aiVehicleStock
        check("F-176.12", "_aiVehicleStock non-nil",    vs ~= nil)
        check("F-176.13", "_aiVehicleStock.isAll=false", vs and vs.isAll == false)
        check("F-176.14", "init[Hummer]=3",              vs and vs.init["Hummer"] == 3,
              tostring(vs and vs.init["Hummer"]))
        check("F-176.15", "init[M1025 HMMWV Armament]=-1", vs and vs.init["M1025 HMMWV Armament"] == -1,
              tostring(vs and vs.init["M1025 HMMWV Armament"]))
        check("F-176.16", "_aiTroopStock=nil (V-only zone)", zVeh._aiTroopStock == nil)
    end

    -- ── Zone AIZ_depot_B_P_TV_5_10 : troopStock={All=-1}, vehicleStock={Hummer=5} ──
    local zTV = zm._troopZones["AIZ_depot_B_P_TV_5_10"]
    check("F-176.17", "AIZ_depot_B_P_TV_5_10 existe", zTV ~= nil)
    if zTV then
        local ts = zTV._aiTroopStock
        local vs = zTV._aiVehicleStock
        check("F-176.18", "TV zone: _aiTroopStock.isAll=true", ts and ts.isAll == true)
        check("F-176.19", "TV zone: _aiVehicleStock non-nil",  vs ~= nil)
        check("F-176.20", "TV zone: vehicleStock[Hummer]=5",   vs and vs.init["Hummer"] == 5,
              tostring(vs and vs.init["Hummer"]))
    end

    report("✅ F-176 ALL PASS — troopStock/vehicleStock tables correctement parsées")

end)

cfg.settings["debug"]          = _savedDebug
cfg.settings["debugScreenLog"] = _savedDebugScreenLog

if not _ok then
    trigger.action.outText(TAG .. " ❌ FAIL: " .. tostring(_err), 60, true)
    _SCN_F176_RUNNING = false
    return TAG .. " FAIL: " .. tostring(_err)
end

trigger.action.outText(TAG .. " ✅ ALL PASS", 30, true)
_SCN_F176_RUNNING = false

end  -- do isolation scope
return Witchcraft
