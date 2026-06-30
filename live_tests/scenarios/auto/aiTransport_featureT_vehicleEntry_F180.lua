---@diagnostic disable
-- =============================================================================
-- aiTransport_featureT_vehicleEntry_F180.lua  [AUTO]
-- F-180 — Feature T : aiPickVehicleEntry — sélection et flag isScene
--
-- PRÉREQUIS : CTLD initialisé, CTLDSceneManager accessible.
--   Ne nécessite pas de zones DCS dans le .miz.
--
-- OBJECTIF : vérifier que aiPickVehicleEntry() :
--   - retourne nil si isAll=true (chemin scan physique legacy)
--   - retourne nil si aucun stock positif disponible
--   - retourne l'entrée avec le stock le plus élevé
--   - positionne isScene=true si le typeName est dans CTLDSceneManager._models
--   - positionne isScene=false si le typeName est un type DCS non-scène
-- =============================================================================

-- ── 1. Witchcraft guard ──────────────────────────────────────────────────────
if not ctld or not ctld.utils then
    trigger.action.outText("[F-180] ABORT: CTLD not initialized. Inject CTLD_Next.lua first.", 15)
    return Witchcraft
end

-- ── 2. Double-injection guard ────────────────────────────────────────────────
if _SCN_F180_RUNNING then
    trigger.action.outText("[F-180] already running.", 10)
    return Witchcraft
end
_SCN_F180_RUNNING = true

do

local cfg = CTLDConfig.get()
local _savedDebug          = cfg.settings["debug"]
local _savedDebugScreenLog = cfg.settings["debugScreenLog"]
cfg.settings["debug"]          = true
cfg.settings["debugScreenLog"] = true

local TAG   = "[F-180]"
local START = os.date("%Y-%m-%d %H:%M:%S")

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

    -- ── Injecter un modèle de test dans CTLDSceneManager ──────────────────
    local sm = CTLDSceneManager.getInstance()
    local _savedModels = sm._models  -- sauvegarde
    sm._models = {}
    for k, v in pairs(_savedModels) do sm._models[k] = v end  -- copie shallow

    local TEST_SCENE_NAME = "__TEST_SCENE_F154__"
    sm._models[TEST_SCENE_NAME] = { steps = {} }  -- modèle factice

    local function cleanup()
        sm._models[TEST_SCENE_NAME] = nil
    end

    -- ── F-180.1 : isAll=true → retourne nil (scan physique) ──────────────
    local zoneAll = CTLDTroopZone:new({
        zoneName    = "TEST_VENTRY_ALL",
        isAIPickup  = true,
        pickMaxStock = 0,
        _aiVehicleStock = { isAll = true, init = {}, current = {} },
    })
    local resAll = zoneAll:aiPickVehicleEntry()
    check("F-180.1", "isAll=true → nil (scan physique legacy)", resAll == nil,
          tostring(resAll))

    -- ── F-180.2 : _aiVehicleStock=nil → retourne nil ─────────────────────
    local zoneNoStock = CTLDTroopZone:new({
        zoneName    = "TEST_VENTRY_NIL",
        isAIPickup  = true,
        pickMaxStock = 0,
    })
    local resNil = zoneNoStock:aiPickVehicleEntry()
    check("F-180.2", "_aiVehicleStock=nil → nil", resNil == nil)

    -- ── F-180.3 : tous stocks=0 → retourne nil ───────────────────────────
    local zoneZero = CTLDTroopZone:new({
        zoneName    = "TEST_VENTRY_ZERO",
        isAIPickup  = true,
        pickMaxStock = 0,
        _aiVehicleStock = {
            isAll   = false,
            init    = { ["Hummer"] = 0 },
            current = { ["Hummer"] = 0 },
        },
    })
    local resZero = zoneZero:aiPickVehicleEntry()
    check("F-180.3", "stock=0 → nil", resZero == nil)

    -- ── F-180.4 : DCS type (pas de scène) → isScene=false ────────────────
    local zoneDCS = CTLDTroopZone:new({
        zoneName    = "TEST_VENTRY_DCS",
        isAIPickup  = true,
        pickMaxStock = 0,
        _aiVehicleStock = {
            isAll   = false,
            init    = { ["Hummer"] = 3 },
            current = { ["Hummer"] = 3 },
        },
    })
    local resDCS = zoneDCS:aiPickVehicleEntry()
    check("F-180.4", "DCS type : résultat non-nil",   resDCS ~= nil)
    check("F-180.5", "DCS type : isScene=false",      resDCS and resDCS.isScene == false,
          tostring(resDCS and resDCS.isScene))
    check("F-180.6", "DCS type : type='Hummer'",      resDCS and resDCS.type == "Hummer",
          tostring(resDCS and resDCS.type))

    -- ── F-180.7 : scène enregistrée → isScene=true ───────────────────────
    local zoneScene = CTLDTroopZone:new({
        zoneName    = "TEST_VENTRY_SCENE",
        isAIPickup  = true,
        pickMaxStock = 0,
        _aiVehicleStock = {
            isAll   = false,
            init    = { [TEST_SCENE_NAME] = 2 },
            current = { [TEST_SCENE_NAME] = 2 },
        },
    })
    local resScene = zoneScene:aiPickVehicleEntry()
    check("F-180.7", "scène enregistrée : résultat non-nil",    resScene ~= nil)
    check("F-180.8", "scène enregistrée : isScene=true",        resScene and resScene.isScene == true,
          tostring(resScene and resScene.isScene))
    check("F-180.9", "scène enregistrée : type correct",
          resScene and resScene.type == TEST_SCENE_NAME,
          tostring(resScene and resScene.type))

    -- ── F-180.10 : sélection priorité stock (Hummer=1, TestScene=3) ──────
    -- → TestScene doit être choisi (stock plus élevé)
    local zoneMixed = CTLDTroopZone:new({
        zoneName    = "TEST_VENTRY_MIXED",
        isAIPickup  = true,
        pickMaxStock = 0,
        _aiVehicleStock = {
            isAll   = false,
            init    = { ["Hummer"] = 1, [TEST_SCENE_NAME] = 3 },
            current = { ["Hummer"] = 1, [TEST_SCENE_NAME] = 3 },
        },
    })
    -- Après 10 picks sans consume, TestScene doit toujours gagner
    local wrongPick = false
    for i = 1, 10 do
        local r = zoneMixed:aiPickVehicleEntry()
        if r and r.type ~= TEST_SCENE_NAME then wrongPick = true end
    end
    check("F-180.10", "sélection stock max : TestScene(3) toujours choisi vs Hummer(1)",
          not wrongPick, "Hummer picked at least once")

    -- ── F-180.11 : stock=-1 (illimité) → stock=math.huge → prioritaire ───
    local zoneUnlim = CTLDTroopZone:new({
        zoneName    = "TEST_VENTRY_UNLIM",
        isAIPickup  = true,
        pickMaxStock = 0,
        _aiVehicleStock = {
            isAll   = false,
            init    = { ["Hummer"] = 5, ["M1025 HMMWV Armament"] = -1 },
            current = { ["Hummer"] = 5, ["M1025 HMMWV Armament"] = -1 },
        },
    })
    local wrongUnlim = false
    for i = 1, 10 do
        local r = zoneUnlim:aiPickVehicleEntry()
        if r and r.type ~= "M1025 HMMWV Armament" then wrongUnlim = true end
    end
    check("F-180.11", "stock=-1 (illimité) prioritaire sur stock=5",
          not wrongUnlim, "Hummer picked instead of unlimited M1025")

    cleanup()
    report("✅ F-180 ALL PASS — aiPickVehicleEntry sélection et isScene corrects")

end)

-- Ensure cleanup even on failure
pcall(function()
    CTLDSceneManager.getInstance()._models["__TEST_SCENE_F154__"] = nil
end)

cfg.settings["debug"]          = _savedDebug
cfg.settings["debugScreenLog"] = _savedDebugScreenLog

if not _ok then
    trigger.action.outText(TAG .. " ❌ FAIL: " .. tostring(_err), 60, true)
    _SCN_F180_RUNNING = false
    return TAG .. " FAIL: " .. tostring(_err)
end
trigger.action.outText(TAG .. " ✅ ALL PASS", 30, true)
_SCN_F180_RUNNING = false

end  -- do isolation scope
return Witchcraft
