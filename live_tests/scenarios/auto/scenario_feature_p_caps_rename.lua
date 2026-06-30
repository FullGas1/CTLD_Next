---@diagnostic disable
-- =============================================================================
-- AUTO — Feature P : validation renommage capabilitiesByType + groundVehicleWeights
-- =============================================================================
-- Vérifie que tous les champs renommés sont correctement définis en config
-- et correctement lus par les managers (CTLDTroopManager, CTLDCrateManager,
-- CTLDPlayerManager, CTLDVehicleSpawner).
--
-- U-97 : capabilitiesByType["UH-1H"] — tous champs renommés + valeurs attendues
-- U-98 : capabilitiesByType["Mi-24P"] — champs sans parachute/véhicule entier
-- U-99 : groundVehicleWeights — valeurs attendues
-- F-159 : _transportLimit("UH-1H") → 8
-- F-160 : _transportLimit("Mi-24P") → 10
-- F-161 : _transportLimit("unknown_type") → fallback numberOfTroops
-- F-162 : _isDynamicCapable(mockUH1H) → true
-- F-163 : _isDynamicCapable(mockSK60) → false
-- F-164 : _detectCapabilities(mockUH1H) → isTransport=true, canCarryVehicles=true
-- F-165 : _detectCapabilities(mockMi24P) → isTransport=true, canCarryVehicles=false
-- F-166 : loadVehicle 2ème chargement bloqué par maxWholeVehiclesOnboard=1
--
-- Prérequis : aucun (entièrement mocké)
-- Famille   : auto
-- =============================================================================

-- ── Witchcraft guard ───────────────────────────────────────────────────────
if not ctld or not ctld.utils then
    trigger.action.outText("[FEAT-P] ABORT: CTLD not initialized. Inject CTLD_Next.lua first.", 15)
    return Witchcraft
end

-- ── Double-injection guard ─────────────────────────────────────────────
if _SCN_FEAT_P_RUNNING then
    trigger.action.outText("[FEAT-P] already running.", 10)
    return Witchcraft
end
_SCN_FEAT_P_RUNNING = true

do  -- isolation scope
trigger.action.outText("[FEAT-P] START — capabilitiesByType rename validation", 8)

local cfg         = CTLDConfig.get()
local _saved_debug = cfg.settings["debug"]
local _savedDebugScreenLog = cfg.settings["debugScreenLog"]
cfg.settings["debug"] = true
cfg.settings["debugScreenLog"] = true

local pass = 0
local fail = 0

local function check(label, actual, expected)
    if actual == expected then
        ctld.utils.log("INFO", "[PASS] %s = %s", label, tostring(actual))
        pass = pass + 1
    else
        ctld.utils.log("ERROR", "[FAIL] %s : expected=%s actual=%s", label, tostring(expected), tostring(actual))
        fail = fail + 1
    end
end

local function checkTrue(label, val)
    if val then
        ctld.utils.log("INFO", "[PASS] %s", label)
        pass = pass + 1
    else
        ctld.utils.log("ERROR", "[FAIL] %s (expected true, got false/nil)", label)
        fail = fail + 1
    end
end

local function checkFalse(label, val)
    if not val then
        ctld.utils.log("INFO", "[PASS] %s", label)
        pass = pass + 1
    else
        ctld.utils.log("ERROR", "[FAIL] %s (expected false/nil, got %s)", label, tostring(val))
        fail = fail + 1
    end
end

-- ── U-97 : capabilitiesByType["UH-1H"] ───────────────────────────────────────
ctld.utils.log("INFO", "── U-97 : caps UH-1H ──")
local caps = ctld.gs("capabilitiesByType") or {}
local uh1h = caps["UH-1H"]
checkTrue("U-97 UH-1H entry exists",          uh1h ~= nil)
if uh1h then
    checkTrue ("U-97 cratesEnabled",              uh1h.cratesEnabled)
    checkTrue ("U-97 troopsEnabled",              uh1h.troopsEnabled)
    checkTrue ("U-97 canParachuteDrop",           uh1h.canParachuteDrop)
    checkTrue ("U-97 canSlingload",               uh1h.canSlingload)
    checkTrue ("U-97 canTransportWholeVehicle",   uh1h.canTransportWholeVehicle)
    checkTrue ("U-97 useNativeDcsCargoSystem",    uh1h.useNativeDcsCargoSystem)
    check     ("U-97 maxTroopsOnboard",           uh1h.maxTroopsOnboard,         8)
    check     ("U-97 maxCratesOnboard",           uh1h.maxCratesOnboard,         1)
    check     ("U-97 maxWholeVehiclesOnboard",    uh1h.maxWholeVehiclesOnboard,  1)
    -- vérifier que les ANCIENS noms n'existent plus
    checkFalse("U-97 old 'crates' gone",              uh1h.crates)
    checkFalse("U-97 old 'troops' gone",              uh1h.troops)
    checkFalse("U-97 old 'unitLoadLimits' gone",      uh1h.unitLoadLimits)
    checkFalse("U-97 old 'internalCargoLimits' gone", uh1h.internalCargoLimits)
    checkFalse("U-97 old 'maxVehicles' gone",         uh1h.maxVehicles)
    checkFalse("U-97 old 'vehicleTransportEnabled' gone", uh1h.vehicleTransportEnabled)
    checkFalse("U-97 old 'canParachute' gone",        uh1h.canParachute)
    checkFalse("U-97 old 'dynamicCargoUnits' gone",   uh1h.dynamicCargoUnits)
end

-- ── U-98 : capabilitiesByType["Mi-24P"] ──────────────────────────────────────
ctld.utils.log("INFO", "── U-98 : caps Mi-24P ──")
local mi24 = caps["Mi-24P"]
checkTrue("U-98 Mi-24P entry exists",         mi24 ~= nil)
if mi24 then
    checkTrue ("U-98 cratesEnabled",              mi24.cratesEnabled)
    checkTrue ("U-98 troopsEnabled",              mi24.troopsEnabled)
    checkFalse("U-98 canParachuteDrop=false",     mi24.canParachuteDrop)
    checkFalse("U-98 canSlingload=false",         mi24.canSlingload)
    checkFalse("U-98 canTransportWholeVehicle=false", mi24.canTransportWholeVehicle)
    checkTrue ("U-98 useNativeDcsCargoSystem",    mi24.useNativeDcsCargoSystem)
    check     ("U-98 maxTroopsOnboard",           mi24.maxTroopsOnboard,        10)
    check     ("U-98 maxCratesOnboard",           mi24.maxCratesOnboard,         1)
    check     ("U-98 maxWholeVehiclesOnboard",    mi24.maxWholeVehiclesOnboard,  0)
end

-- ── U-99 : groundVehicleWeights ──────────────────────────────────────────────
ctld.utils.log("INFO", "── U-99 : groundVehicleWeights ──")
local gvw = ctld.gs("groundVehicleWeights") or {}
check("U-99 BRDM-2 weight",          gvw["BRDM-2"],               7000)
check("U-99 BTR_D weight",           gvw["BTR_D"],                8000)
check("U-99 M1045 HMMWV TOW weight", gvw["M1045 HMMWV TOW"],      3220)
check("U-99 M1043 HMMWV Arm weight", gvw["M1043 HMMWV Armament"], 2500)
-- vérifier que l'ancien nom ne retourne rien
local old_vw = ctld.gs("vehiclesWeight")
checkFalse("U-99 old 'vehiclesWeight' key gone", old_vw ~= nil)

-- ── F-159 : _transportLimit UH-1H ────────────────────────────────────────────
ctld.utils.log("INFO", "── F-159 : _transportLimit UH-1H ──")
local tm = CTLDTroopManager.getInstance()
check("F-159 _transportLimit(UH-1H)", tm:_transportLimit("UH-1H"), 8)

-- ── F-160 : _transportLimit Mi-24P ───────────────────────────────────────────
ctld.utils.log("INFO", "── F-160 : _transportLimit Mi-24P ──")
check("F-160 _transportLimit(Mi-24P)", tm:_transportLimit("Mi-24P"), 10)

-- ── F-161 : _transportLimit fallback ─────────────────────────────────────────
ctld.utils.log("INFO", "── F-161 : _transportLimit fallback ──")
local fallback = ctld.gs("numberOfTroops") or 10
check("F-161 _transportLimit(unknown) fallback", tm:_transportLimit("unknown_type_xyz"), fallback)

-- ── F-162 : _isDynamicCapable UH-1H → true ───────────────────────────────────
ctld.utils.log("INFO", "── F-162 : _isDynamicCapable UH-1H ──")
local cm = CTLDCrateManager.getInstance()
local mockUH1H = { getTypeName = function() return "UH-1H" end }
checkTrue("F-162 _isDynamicCapable(UH-1H)", cm:_isDynamicCapable(mockUH1H))

-- ── F-163 : _isDynamicCapable SK-60 → false ──────────────────────────────────
ctld.utils.log("INFO", "── F-163 : _isDynamicCapable SK-60 ──")
local mockSK60 = { getTypeName = function() return "SK-60" end }
checkFalse("F-163 _isDynamicCapable(SK-60)", cm:_isDynamicCapable(mockSK60))

-- ── F-164 : _detectCapabilities UH-1H ────────────────────────────────────────
ctld.utils.log("INFO", "── F-164 : _detectCapabilities UH-1H ──")
local pm = CTLDPlayerManager.getInstance()
local mockUH1H_unit = { getTypeName = function() return "UH-1H" end }
local isTransport164, canCarry164 = pm:_detectCapabilities(mockUH1H_unit)
checkTrue ("F-164 isTransport(UH-1H)",      isTransport164)
checkTrue ("F-164 canCarryVehicles(UH-1H)", canCarry164)

-- ── F-165 : _detectCapabilities Mi-24P ───────────────────────────────────────
ctld.utils.log("INFO", "── F-165 : _detectCapabilities Mi-24P ──")
local mockMi24_unit = { getTypeName = function() return "Mi-24P" end }
local isTransport165, canCarry165 = pm:_detectCapabilities(mockMi24_unit)
checkTrue ("F-165 isTransport(Mi-24P)",           isTransport165)
checkFalse("F-165 canCarryVehicles(Mi-24P)=false", canCarry165)

-- ── F-166 : loadVehicle bloqué par maxWholeVehiclesOnboard=1 ─────────────────
ctld.utils.log("INFO", "── F-166 : maxWholeVehiclesOnboard capacity guard ──")
local vs = CTLDVehicleSpawner.getInstance()

local TRANSPORT_NAME = "mock_transport_FP166"
local mockTransport166 = {
    getName     = function() return TRANSPORT_NAME end,
    getPoint    = function() return { x = 0, y = 0, z = 0 } end,
    getTypeName = function() return "UH-1H" end,
}

local veh0 = CTLDVehicle:new({ id = "fp166_v0", vehicleType = "M1043 HMMWV Armament" })
local veh1 = CTLDVehicle:new({ id = "fp166_v1", vehicleType = "M1045 HMMWV TOW" })

-- veh0 : déjà LOADED sur ce transport (occupe le slot unique)
veh0.state             = CTLDVehicle.STATE.LOADED
veh0.loadTransportName = TRANSPORT_NAME
veh0.loadMethod        = "menu_ctld"

-- veh1 : en attente de chargement
veh1.state = CTLDVehicle.STATE.WAITING

vs._vehicles["fp166_v0"] = veh0
vs._vehicles["fp166_v1"] = veh1

-- Intercepter le log WARNING "vehicle capacity"
local _orig_log = ctld.utils.log
local warnSeen = false
ctld.utils.log = function(level, msg, ...)
    if level == "WARNING" and msg and msg:find("vehicle capacity") then
        warnSeen = true
    end
    _orig_log(level, msg, ...)
end

vs:loadVehicle(veh1, mockTransport166, "test_player", "menu_ctld")

ctld.utils.log = _orig_log

checkTrue("F-166 WARNING capacity emitted",             warnSeen)
check("F-166 veh1 still WAITING after blocked load",   veh1:getState(), CTLDVehicle.STATE.WAITING)

-- Cleanup
vs._vehicles["fp166_v0"] = nil
vs._vehicles["fp166_v1"] = nil

-- ── Résultat final ────────────────────────────────────────────────────────────
cfg.settings["debug"] = _saved_debug
cfg.settings["debugScreenLog"] = _savedDebugScreenLog

local total = pass + fail
local msg = string.format(
    "[FEAT-P] DONE — %d/%d PASS%s",
    pass, total,
    fail > 0 and (" | " .. fail .. " FAIL — voir CTLD.log") or ""
)
trigger.action.outText(msg, 15, true)
ctld.utils.log("INFO", msg)

_SCN_FEAT_P_RUNNING = false
return "TAG=FEAT_P_RENAME | steps=" .. total .. " | pass=" .. pass .. " | fail=" .. fail
end  -- do isolation scope
return Witchcraft
