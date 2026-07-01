---@diagnostic disable
-- =============================================================================
-- aiTransport_featureT_stockRestore_F179.lua  [AUTO]
-- F-179 — Feature T : restauration du stock lors du dropoff AI (navette)
--
-- PRÉREQUIS : CTLD initialisé (classes disponibles en mémoire).
--   Ne nécessite pas de zones DCS dans le .miz.
--
-- OBJECTIF : vérifier que aiRestoreTroopStock() et aiRestoreVehicleStock()
--   restaurent correctement le stock courant, sans dépasser le plafond init,
--   et sans effet quand isAll=true ou stock=-1 (illimité).
-- =============================================================================

-- ── 1. Witchcraft guard ──────────────────────────────────────────────────────
if not ctld or not ctld.utils then
    trigger.action.outText("[F-179] ABORT: CTLD not initialized. Inject CTLD_Next.lua first.", 15)
    return Witchcraft
end

-- ── 2. Double-injection guard ────────────────────────────────────────────────
if _SCN_F179_RUNNING then
    trigger.action.outText("[F-179] already running.", 10)
    return Witchcraft
end
_SCN_F179_RUNNING = true

do

local cfg = CTLDConfig.get()
local _savedDebug          = cfg.settings["debug"]
local _savedDebugScreenLog = cfg.settings["debugScreenLog"]
cfg.settings["debug"]          = true
cfg.settings["debugScreenLog"] = true

local TAG   = "[F-179]"
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
    -- SECTION A — Troop stock restore
    -- ═══════════════════════════════════════════════════════════════════════

    local zone = CTLDTroopZone:new({
        zoneName     = "TEST_RESTORE_T",
        isAIPickup   = true,
        pickMaxStock = 0,
        _aiTroopStock = {
            isAll   = false,
            init    = { ["Standard Group"] = 3 },
            current = { ["Standard Group"] = 1 },  -- partially consumed
        },
    })

    -- A.1 : restore 1 → current = 2
    zone:aiRestoreTroopStock("Standard Group", 1)
    check("F-179.1", "restore 1 : current = 2",
          zone._aiTroopStock.current["Standard Group"] == 2,
          tostring(zone._aiTroopStock.current["Standard Group"]))

    -- A.2 : restore 1 → current = 3 (plafond atteint)
    zone:aiRestoreTroopStock("Standard Group", 1)
    check("F-179.2", "restore 1 : current = 3 (plafond init)",
          zone._aiTroopStock.current["Standard Group"] == 3,
          tostring(zone._aiTroopStock.current["Standard Group"]))

    -- A.3 : restore sur plafond → ne dépasse pas init (3)
    zone:aiRestoreTroopStock("Standard Group", 1)
    check("F-179.3", "restore sur plafond : current reste 3",
          zone._aiTroopStock.current["Standard Group"] == 3,
          tostring(zone._aiTroopStock.current["Standard Group"]))

    -- A.4 : restore avec n > 1 (reste capé)
    zone._aiTroopStock.current["Standard Group"] = 0
    zone:aiRestoreTroopStock("Standard Group", 10)
    check("F-179.4", "restore n=10 capé à init=3",
          zone._aiTroopStock.current["Standard Group"] == 3,
          tostring(zone._aiTroopStock.current["Standard Group"]))

    -- A.5 : restore sans n (défaut=1)
    zone._aiTroopStock.current["Standard Group"] = 0
    zone:aiRestoreTroopStock("Standard Group")
    check("F-179.5", "restore sans n : +1 (défaut)",
          zone._aiTroopStock.current["Standard Group"] == 1,
          tostring(zone._aiTroopStock.current["Standard Group"]))

    -- A.6 : isAll=true → restore est no-op
    local zoneAll = CTLDTroopZone:new({
        zoneName     = "TEST_RESTORE_T_ALL",
        isAIPickup   = true,
        pickMaxStock = 0,
        _aiTroopStock = { isAll = true, init = {}, current = {} },
    })
    zoneAll:aiRestoreTroopStock("Standard Group", 1)  -- must not error
    check("F-179.6", "isAll=true : restore est no-op (pas d'erreur)", true)

    -- A.7 : restore d'une clé absente → no-op (maxS=nil → return early)
    zone:aiRestoreTroopStock("Unknown Template", 1)
    check("F-179.7", "restore clé absente : no-op (pas d'erreur)", true)

    -- ═══════════════════════════════════════════════════════════════════════
    -- SECTION B — Vehicle stock restore
    -- ═══════════════════════════════════════════════════════════════════════

    local zoneV = CTLDTroopZone:new({
        zoneName    = "TEST_RESTORE_V",
        isAIPickup  = true,
        pickMaxStock = 0,
        _aiVehicleStock = {
            isAll   = false,
            init    = { ["Hummer"] = 2 },
            current = { ["Hummer"] = 0 },  -- fully consumed
        },
    })

    -- B.1 : restore véhicule → 1
    zoneV:aiRestoreVehicleStock("Hummer")
    check("F-179.8", "restore vehicule : current[Hummer] = 1",
          zoneV._aiVehicleStock.current["Hummer"] == 1,
          tostring(zoneV._aiVehicleStock.current["Hummer"]))

    -- B.2 : restore → plafond 2
    zoneV:aiRestoreVehicleStock("Hummer")
    check("F-179.9", "restore vehicule : current[Hummer] = 2 (plafond)",
          zoneV._aiVehicleStock.current["Hummer"] == 2,
          tostring(zoneV._aiVehicleStock.current["Hummer"]))

    -- B.3 : restore sur plafond → reste 2
    zoneV:aiRestoreVehicleStock("Hummer")
    check("F-179.10", "restore vehicule sur plafond : reste 2",
          zoneV._aiVehicleStock.current["Hummer"] == 2,
          tostring(zoneV._aiVehicleStock.current["Hummer"]))

    -- B.4 : stock=-1 (illimité dans init) → restore est no-op (maxS==-1 → return early)
    local zoneVUnlim = CTLDTroopZone:new({
        zoneName    = "TEST_RESTORE_V_UNLIM",
        isAIPickup  = true,
        pickMaxStock = 0,
        _aiVehicleStock = {
            isAll   = false,
            init    = { ["M1025 HMMWV Armament"] = -1 },
            current = { ["M1025 HMMWV Armament"] = -1 },
        },
    })
    zoneVUnlim:aiRestoreVehicleStock("M1025 HMMWV Armament")  -- no-op
    check("F-179.11", "vehicule stock=-1 : restore no-op, reste -1",
          zoneVUnlim._aiVehicleStock.current["M1025 HMMWV Armament"] == -1,
          tostring(zoneVUnlim._aiVehicleStock.current["M1025 HMMWV Armament"]))

    report("✅ F-179 ALL PASS — restauration stock troop/vehicle correcte")

end)

if not _ok then
    cfg.settings["debug"]          = _savedDebug
    cfg.settings["debugScreenLog"] = _savedDebugScreenLog
    trigger.action.outText(TAG .. " ❌ FAIL: " .. tostring(_err), 60, true)
    _SCN_F179_RUNNING = false
    return TAG .. " FAIL: " .. tostring(_err)
end

cfg.settings["debug"]          = _savedDebug
cfg.settings["debugScreenLog"] = _savedDebugScreenLog
trigger.action.outText(TAG .. " ✅ ALL PASS", 30, true)
_SCN_F179_RUNNING = false

end  -- do isolation scope
return Witchcraft
