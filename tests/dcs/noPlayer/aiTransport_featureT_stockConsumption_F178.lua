---@diagnostic disable
-- =============================================================================
-- aiTransport_featureT_stockConsumption_F178.lua  [AUTO]
-- F-178 — Feature T : décrément du stock lors du pickup AI
--
-- PRÉREQUIS : CTLD initialisé (classes disponibles en mémoire).
--   Ne nécessite pas de zones DCS dans le .miz.
--
-- OBJECTIF : vérifier que aiConsumeTroopStock() et aiConsumeVehicleStock()
--   décrémentent correctement le stock courant, sans descendre sous 0,
--   et sans effet quand isAll=true.
-- =============================================================================

-- ── 1. Witchcraft guard ──────────────────────────────────────────────────────
if not ctld or not ctld.utils then
    trigger.action.outText("[F-178] ABORT: CTLD not initialized. Inject CTLD_Next.lua first.", 15)
    return Witchcraft
end

-- ── 2. Double-injection guard ────────────────────────────────────────────────
if _SCN_F178_RUNNING then
    trigger.action.outText("[F-178] already running.", 10)
    return Witchcraft
end
_SCN_F178_RUNNING = true

do

local cfg = CTLDConfig.get()
local _savedDebug          = cfg.settings["debug"]
local _savedDebugScreenLog = cfg.settings["debugScreenLog"]
cfg.settings["debug"]          = true
cfg.settings["debugScreenLog"] = true

local TAG   = "[F-178]"
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

    -- ═══════════════════════════════════════════════════════════════════════
    -- SECTION A — Troop stock consumption
    -- ═══════════════════════════════════════════════════════════════════════

    local zone = CTLDTroopZone:new({
        zoneName    = "TEST_CONSUME_T",
        isAIPickup  = true,
        pickMaxStock = 0,
        _aiTroopStock = {
            isAll   = false,
            init    = { ["Standard Group"] = 3 },
            current = { ["Standard Group"] = 3 },
        },
    })

    -- A.1 : premier consume → current = 2
    zone:aiConsumeTroopStock("Standard Group")
    check("F-178.1", "après 1 consume : current[Standard Group] = 2",
          zone._aiTroopStock.current["Standard Group"] == 2,
          tostring(zone._aiTroopStock.current["Standard Group"]))

    -- A.2 : deuxième consume → current = 1
    zone:aiConsumeTroopStock("Standard Group")
    check("F-178.2", "après 2 consumes : current[Standard Group] = 1",
          zone._aiTroopStock.current["Standard Group"] == 1,
          tostring(zone._aiTroopStock.current["Standard Group"]))

    -- A.3 : troisième consume → current = 0
    zone:aiConsumeTroopStock("Standard Group")
    check("F-178.3", "après 3 consumes : current[Standard Group] = 0",
          zone._aiTroopStock.current["Standard Group"] == 0,
          tostring(zone._aiTroopStock.current["Standard Group"]))

    -- A.4 : quatrième consume (sur stock=0) → toujours 0, pas de négatif
    zone:aiConsumeTroopStock("Standard Group")
    check("F-178.4", "consume sur stock=0 : toujours 0 (pas de négatif)",
          zone._aiTroopStock.current["Standard Group"] == 0,
          tostring(zone._aiTroopStock.current["Standard Group"]))

    -- A.5 : consume d'une clé absente → pas d'erreur, autres clés intactes
    zone._aiTroopStock.current["Standard Group"] = 2
    zone:aiConsumeTroopStock("Unknown Template")
    check("F-178.5", "consume template absent : Standard Group intact",
          zone._aiTroopStock.current["Standard Group"] == 2,
          tostring(zone._aiTroopStock.current["Standard Group"]))

    -- A.6 : isAll=true → consume est no-op (aucun current à modifier)
    local zoneAll = CTLDTroopZone:new({
        zoneName     = "TEST_CONSUME_T_ALL",
        isAIPickup   = true,
        pickMaxStock = 0,
        _aiTroopStock = { isAll = true, init = {}, current = {} },
    })
    zoneAll:aiConsumeTroopStock("Standard Group")  -- must not error
    check("F-178.6", "isAll=true : consume est no-op (pas d'erreur)", true)

    -- ═══════════════════════════════════════════════════════════════════════
    -- SECTION B — Vehicle stock consumption
    -- ═══════════════════════════════════════════════════════════════════════

    local zoneV = CTLDTroopZone:new({
        zoneName    = "TEST_CONSUME_V",
        isAIPickup  = true,
        pickMaxStock = 0,
        _aiVehicleStock = {
            isAll   = false,
            init    = { ["Hummer"] = 2 },
            current = { ["Hummer"] = 2 },
        },
    })

    -- B.1 : premier consume véhicule → 1
    zoneV:aiConsumeVehicleStock("Hummer")
    check("F-178.7", "après 1 consume vehicule : current[Hummer] = 1",
          zoneV._aiVehicleStock.current["Hummer"] == 1,
          tostring(zoneV._aiVehicleStock.current["Hummer"]))

    -- B.2 : deuxième consume → 0
    zoneV:aiConsumeVehicleStock("Hummer")
    check("F-178.8", "après 2 consumes vehicule : current[Hummer] = 0",
          zoneV._aiVehicleStock.current["Hummer"] == 0,
          tostring(zoneV._aiVehicleStock.current["Hummer"]))

    -- B.3 : troisième consume (stock=0) → toujours 0
    zoneV:aiConsumeVehicleStock("Hummer")
    check("F-178.9", "consume vehicule sur stock=0 : toujours 0",
          zoneV._aiVehicleStock.current["Hummer"] == 0,
          tostring(zoneV._aiVehicleStock.current["Hummer"]))

    -- B.4 : stock=-1 (illimité) → consume est no-op (s=-1, condition s>0 fausse)
    local zoneVUnlimited = CTLDTroopZone:new({
        zoneName    = "TEST_CONSUME_V_UNLIMITED",
        isAIPickup  = true,
        pickMaxStock = 0,
        _aiVehicleStock = {
            isAll   = false,
            init    = { ["M1025 HMMWV Armament"] = -1 },
            current = { ["M1025 HMMWV Armament"] = -1 },
        },
    })
    zoneVUnlimited:aiConsumeVehicleStock("M1025 HMMWV Armament")
    check("F-178.10", "stock=-1 (illimité) : consume est no-op, reste -1",
          zoneVUnlimited._aiVehicleStock.current["M1025 HMMWV Armament"] == -1,
          tostring(zoneVUnlimited._aiVehicleStock.current["M1025 HMMWV Armament"]))

    report("✅ F-178 ALL PASS — décrément stock troop/vehicle correct")

end)

if not _ok then
    cfg.settings["debug"]          = _savedDebug
    cfg.settings["debugScreenLog"] = _savedDebugScreenLog
    trigger.action.outText(TAG .. " ❌ FAIL: " .. tostring(_err), 60, true)
    _SCN_F178_RUNNING = false
    return TAG .. " FAIL: " .. tostring(_err)
end

cfg.settings["debug"]          = _savedDebug
cfg.settings["debugScreenLog"] = _savedDebugScreenLog
trigger.action.outText(TAG .. " ✅ ALL PASS", 30, true)
_SCN_F178_RUNNING = false

end  -- do isolation scope
return Witchcraft
