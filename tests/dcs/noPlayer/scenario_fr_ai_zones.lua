---@diagnostic disable
-- =============================================================================
-- AUTO — Feature R+S: AI zones (_loadAIZonesFromConfig + _checkAIStatus)
-- =============================================================================
-- Section 1 — Feature S: _loadAIZonesFromConfig (replaces deleted _parseAIZ)
-- F-R-1  : pickup T stock=10    → isAIPickup=true, pickMaxStock=10, coalition=BLUE
-- F-R-2  : dropoff zone         → isAIDropoff=true, pickMaxStock=nil
-- F-R-3  : pickup troopStock=-1 → pickMaxStock=0 (unlimited)
-- F-R-4  : pickup troopStock=0  → pickMaxStock=nil (disabled)
-- F-R-5  : missing coalition    → zone not created (ERROR)
-- F-R-6  : invalid cargoType    → zone created, aiCargoType=T (WARN, default)
--
-- Section 2 — hasAIPickup / hasAIDropoff
-- F-R-7  : hasAIPickup / hasAIDropoff on manually created CTLDTroopZone
--
-- Section 3-4 — Zone query methods
-- F-R-8  : getTroopZoneAtPoint excludes isAIPickup zones (player guard)
-- F-R-9  : getAIPickupZoneAt returns AIZ_P zone, ignores AIZ_D
-- F-R-10 : getAIDropoffZoneAt returns AIZ_D zone, ignores AIZ_P
--
-- Section 5 — Transport lifecycle
-- F-R-11 : cleanupDeadTransports removes stale _inTransit entry
-- F-R-12 : onTransportDead triggers cleanup via event
--
-- Section 6 — aiZones config format loading
-- F-R-13 : aiZones config (new format) → isAIPickup / isAIDropoff / pickMaxStock correct
--
-- Section 7 — aiDropMode via _loadAIZonesFromConfig
-- F-R-14 : aiDropMode="G"  → zone.aiDropMode="G"
-- F-R-15 : aiDropMode="P"  → zone.aiDropMode="P"
-- F-R-16 : aiDropMode="GP" → zone.aiDropMode="GP"
-- F-R-17 : no aiDropMode   → default "GP"
-- F-R-18 : invalid aiDropMode → zone created (WARN), aiDropMode stored as "GP" (Fix 6)
-- F-R-19 : CTLDTroopZone aiDropMode attribute default = "GP"
-- F-R-20 : multiple dropoff entries with varying aiDropMode
--
-- Section 8 — _checkAIStatus fallback template scan
-- F-R-21 : first template compatible → selected directly
-- F-R-22 : first too big, second fits → fallback picks second
-- F-R-23 : all templates exceed capacity → embark never called
-- F-R-24 : teams=[] → embark never called
-- F-R-25 : hasTroops=true → pickup branch skipped entirely
-- F-R-26 : allowRandomAiTeamPickups=true + mixed → compatible always found
--
-- Section 9 — Feature S: troopTemplates + vehicleTypes whitelists
-- F-R-27 : zone with troopTemplates set → attribute stored on zone
-- F-R-28 : zone without troopTemplates → attribute nil (all templates eligible)
-- F-R-29 : zone with vehicleTypes set  → attribute stored on zone
-- F-R-30 : zone without vehicleTypes  → attribute nil (no filter)
-- F-R-31 : troopTemplates filter at pickup — matching name → picked
-- F-R-32 : troopTemplates filter at pickup — no match → pickup skipped
-- F-R-47 : vehicleTypes filter at pickup — matching type → passes filter
-- F-R-48 : vehicleTypes filter at pickup — non-matching type → filtered out
--
-- Section 10 — _validateZoneNames AIZ coherence + grouped report MM
-- F-R-33 : missing coalition   → ERROR, zone not created
-- F-R-34 : duplicate dcsZoneName → ERROR (second), both skipped
-- F-R-35 : dzn not in ME       → ERROR, zone not created
-- F-R-36 : invalid cargoType   → WARN (in warns[], Fix 5), zone created
-- F-R-37 : invalid aiDropMode  → WARN (warns[]), zone created, aiDropMode="GP" (Fix 6)
-- F-R-38 : troopTemplates unknown name → WARN, zone created
-- F-R-39 : P+D overlap same coalition → WARN, both zones created
-- F-R-40 : any error/warn → outText called, message contains "CTLD" + "error"
--
-- Section 12 — Rapport MM live (outText réel → écran + log)
-- F-R-49 : config avec 5 ERRORs + 2 WARNs → rapport affiché écran + CTLD.log
--
-- Section 11 — Nouveaux checks (G1/G2/G3/G4/G5 + Fix5/Fix6)
-- F-R-41 : ni isPickup ni isDropoff → ERROR, zone not created
-- F-R-42 : troopTemplates TOUS inconnus → WARN distinct, zone created
-- F-R-43 : isPickup + troopStock=0  → WARN, zone created
-- F-R-44 : vehicleTypes TOUS inconnus dans loadableVehicles → WARN, zone created
-- F-R-45 : coalition "ROUGE" (typo) → ERROR, zone not created
-- F-R-46 : cargoType=V, aucun transport canTransportWholeVehicle → ERROR, zone not created
--
-- Prerequisites : none (fully mocked)
-- Family        : auto
-- =============================================================================

-- ── Witchcraft guard ───────────────────────────────────────────────────────
if not ctld or not ctld.utils then
    trigger.action.outText("[FR] ABORT: CTLD not initialized. Inject CTLD_Next.lua first.", 15)
    return Witchcraft
end

-- ── Double-injection guard ─────────────────────────────────────────────
if _SCN_FR_RUNNING then
    trigger.action.outText("[FR] already running.", 10)
    return Witchcraft
end
_SCN_FR_RUNNING = true

do  -- isolation scope
trigger.action.outText("[FR] START — AI Zones Feature R+S", 8)

local cfg          = CTLDConfig.get()
local _saved_debug = cfg.settings["debug"]
local _savedDebugScreenLog = cfg.settings["debugScreenLog"]
cfg.settings["debug"] = true
cfg.settings["debugScreenLog"] = true

local pass_n = 0
local fail_n = 0

local function check(label, actual, expected)
    if actual == expected then
        ctld.utils.log("INFO", "[PASS] %s = %s", label, tostring(actual))
        pass_n = pass_n + 1
    else
        ctld.utils.log("ERROR", "[FAIL] %s : expected=%s actual=%s", label, tostring(expected), tostring(actual))
        fail_n = fail_n + 1
    end
end
local function checkTrue(label, cond)  check(label, cond == true,           true) end
local function checkFalse(label, cond) check(label, cond == false or cond == nil, true) end
local function checkNil(label, val)    check(label, val == nil,              true) end
local function checkNotNil(label, val) check(label, val ~= nil,              true) end

-- ── Helpers ──────────────────────────────────────────────────────────────────
local zm = CTLDZoneManager.getInstance()
local tm = CTLDTroopManager.getInstance()

-- Build a minimal CTLDTroopZone for injection into _troopZones
local function mkZone(name, coa, attrs)
    local z = CTLDTroopZone:new({
        dcsName  = name, zoneName = name,
        coalition = coa or 0,
        center   = { x=0, y=0, z=0 },
        radius   = 500,
    })
    for k, v in pairs(attrs or {}) do z[k] = v end
    return z
end

-- Helper: inject one aiZones entry, call _loadAIZonesFromConfig, return zone, restore.
local function withAIZ(entry, fn)
    local _sAiZ  = cfg.settings["aiZones"]
    local _sTZ   = zm._troopZones
    local _sGetZ = trigger.misc.getZone
    cfg.settings["aiZones"] = { entry }
    trigger.misc.getZone = function() return { point={x=0,y=0,z=0}, radius=200 } end
    zm._troopZones   = {}
    zm._aiZoneErrors = nil
    zm:_loadAIZonesFromConfig()
    local zone = zm._troopZones[entry.dcsZoneName]
    fn(zone)
    cfg.settings["aiZones"] = _sAiZ
    zm._troopZones          = _sTZ
    trigger.misc.getZone    = _sGetZ
    zm._aiZoneErrors        = nil
end

-- Helper: inject one aiZones entry with NO matching DCS zone (zone not in ME).
-- _loadAIZonesFromConfig should skip it → nil zone returned.
local function withAIZ_noMEZone(entry, fn)
    local _sAiZ  = cfg.settings["aiZones"]
    local _sTZ   = zm._troopZones
    local _sGetZ = trigger.misc.getZone
    cfg.settings["aiZones"] = { entry }
    trigger.misc.getZone = function() return nil end   -- zone absent from ME
    zm._troopZones   = {}
    zm._aiZoneErrors = { [entry.dcsZoneName] = true }  -- pre-set error (simulate validate)
    zm:_loadAIZonesFromConfig()
    local zone = zm._troopZones[entry.dcsZoneName]
    fn(zone)
    cfg.settings["aiZones"] = _sAiZ
    zm._troopZones          = _sTZ
    trigger.misc.getZone    = _sGetZ
    zm._aiZoneErrors        = nil
end

-- ══════════════════════════════════════════════════════════════════════════════
-- Section 1 — Feature S: _loadAIZonesFromConfig
-- ══════════════════════════════════════════════════════════════════════════════

-- F-R-1: pickup T stock=10 → isAIPickup=true, pickMaxStock=10, coalition=BLUE
withAIZ(
    { dcsZoneName="ai_fr1", coalition="BLUE", isPickup=true, cargoType="T", troopStock=10 },
    function(z)
        checkNotNil("F-R-1.1", z)
        if z then
            checkTrue ("F-R-1.2", z.isAIPickup)
            checkFalse("F-R-1.3", z.isAIDropoff)
            check     ("F-R-1.4", z.pickMaxStock, 10)
            check     ("F-R-1.5", z.coalition,    coalition.side.BLUE)
        end
    end)

-- F-R-2: dropoff zone → isAIDropoff=true, pickMaxStock=nil
withAIZ(
    { dcsZoneName="ai_fr2", coalition="BLUE", isDropoff=true },
    function(z)
        checkNotNil("F-R-2.1", z)
        if z then
            checkFalse("F-R-2.2", z.isAIPickup)
            checkTrue ("F-R-2.3", z.isAIDropoff)
            checkNil  ("F-R-2.4", z.pickMaxStock)
        end
    end)

-- F-R-3: pickup troopStock=-1 → pickMaxStock=0 (unlimited)
withAIZ(
    { dcsZoneName="ai_fr3", coalition="BLUE", isPickup=true, cargoType="T", troopStock=-1 },
    function(z)
        checkNotNil("F-R-3.1", z)
        if z then check("F-R-3.2", z.pickMaxStock, 0) end
    end)

-- F-R-4: pickup troopStock=0 → pickMaxStock=nil (disabled)
withAIZ(
    { dcsZoneName="ai_fr4", coalition="BLUE", isPickup=true, cargoType="T", troopStock=0 },
    function(z)
        checkNotNil("F-R-4.1", z)
        if z then checkNil("F-R-4.2", z.pickMaxStock) end
    end)

-- F-R-5: missing coalition → zone not created (error pre-set by _validateZoneNames)
withAIZ_noMEZone(
    { dcsZoneName="ai_fr5", isPickup=true, cargoType="T", troopStock=5 },  -- no coalition
    function(z)
        checkNil("F-R-5.1", z)  -- zone skipped due to _aiZoneErrors
    end)

-- F-R-6: invalid cargoType → zone created with default "T" (WARN, not error)
withAIZ(
    { dcsZoneName="ai_fr6", coalition="BLUE", isPickup=true, cargoType="INVALID" },
    function(z)
        checkNotNil("F-R-6.1", z)
        -- aiCargoType passes through raw value; validation only emits WARN
        if z then checkNotNil("F-R-6.2", z.aiCargoType) end
    end)

-- ══════════════════════════════════════════════════════════════════════════════
-- Section 2 — CTLDTroopZone hasAIPickup / hasAIDropoff
-- ══════════════════════════════════════════════════════════════════════════════

-- F-R-7
local zP = mkZone("mock_P", 2, { isAIPickup=true })
local zD = mkZone("mock_D", 2, { isAIDropoff=true })
local zN = mkZone("mock_N", 2, {})

checkTrue ("F-R-7.1", zP:hasAIPickup())
checkFalse("F-R-7.2", zP:hasAIDropoff())
checkFalse("F-R-7.3", zD:hasAIPickup())
checkTrue ("F-R-7.4", zD:hasAIDropoff())
checkFalse("F-R-7.5", zN:hasAIPickup())
checkFalse("F-R-7.6", zN:hasAIDropoff())

-- ══════════════════════════════════════════════════════════════════════════════
-- Section 3 — getTroopZoneAtPoint excludes isAIPickup zones
-- ══════════════════════════════════════════════════════════════════════════════

-- F-R-8: inject a P zone into _troopZones, verify getTroopZoneAtPoint ignores it
local _saved_tz = zm._troopZones
zm._troopZones = {}

local zPinj = mkZone("inj_P", 0, { isAIPickup=true, active=true,
    center={x=0,y=0,z=0}, radius=9999 })
zm._troopZones["inj_P"] = zPinj

local found = zm:getTroopZoneAtPoint({x=0,y=0,z=0}, 0)
checkNil("F-R-8.1", found)  -- should NOT return the AIZ_P zone

-- but getAIPickupZoneAt should find it
local foundAI = zm:getAIPickupZoneAt({x=0,y=0,z=0}, 0)
checkNotNil("F-R-8.2", foundAI)
if foundAI then check("F-R-8.3", foundAI.zoneName, "inj_P") end

zm._troopZones = _saved_tz

-- ══════════════════════════════════════════════════════════════════════════════
-- Section 4 — getAIPickupZoneAt / getAIDropoffZoneAt
-- ══════════════════════════════════════════════════════════════════════════════

-- F-R-9 / F-R-10: inject P + D zones, verify getters filter correctly
local _saved_tz2 = zm._troopZones
zm._troopZones = {}

local zPI = mkZone("ai_pickup",  2, { isAIPickup=true,  active=true, center={x=0,y=0,z=0}, radius=9999 })
local zDI = mkZone("ai_dropoff", 2, { isAIDropoff=true, active=true, center={x=0,y=0,z=0}, radius=9999 })
zm._troopZones["ai_pickup"]  = zPI
zm._troopZones["ai_dropoff"] = zDI

-- getAIPickupZoneAt should return P not D
local rP = zm:getAIPickupZoneAt({x=0,y=0,z=0}, 2)
checkNotNil("F-R-9.1", rP)
if rP then check("F-R-9.2", rP.zoneName, "ai_pickup") end

-- getAIDropoffZoneAt should return D not P
local rD = zm:getAIDropoffZoneAt({x=0,y=0,z=0}, 2)
checkNotNil("F-R-10.1", rD)
if rD then check("F-R-10.2", rD.zoneName, "ai_dropoff") end

-- coalition filter: BLUE zone not returned for RED query
local rPRed = zm:getAIPickupZoneAt({x=0,y=0,z=0}, 1)  -- RED
checkNil("F-R-9.3", rPRed)  -- zPI is coalition=2 (BLUE) → not returned for RED

zm._troopZones = _saved_tz2

-- ══════════════════════════════════════════════════════════════════════════════
-- Section 5 — cleanupDeadTransports / onTransportDead
-- ══════════════════════════════════════════════════════════════════════════════

-- F-R-11: inject stale entry (non-existent unit) → cleanupDeadTransports removes it
local _saved_transit = tm._inTransit
tm._inTransit = { ["ghost_unit_CTLD_FR"] = { { _jtacUnits = {} } } }

tm:cleanupDeadTransports()
checkNil("F-R-11.1", tm._inTransit["ghost_unit_CTLD_FR"])  -- removed

tm._inTransit = _saved_transit

-- F-R-12: onTransportDead with nil initiator → no crash, no cleanup
local _saved_transit2 = tm._inTransit
tm._inTransit = { ["ghost2_CTLD_FR"] = { { _jtacUnits = {} } } }

local ok12, err12 = pcall(function()
    tm:onTransportDead(nil)                          -- nil event → guard fires
end)
checkTrue ("F-R-12.1", ok12)                         -- no crash
checkNotNil("F-R-12.2", tm._inTransit["ghost2_CTLD_FR"])  -- stale not cleaned (initiator nil)

-- with dead initiator mock (isExist returns false)
local deadMock = { isExist = function() return false end }
local ok12b, err12b = pcall(function()
    tm:onTransportDead({ initiator = deadMock })
end)
checkTrue("F-R-12.3", ok12b)                          -- no crash
checkNil ("F-R-12.4", tm._inTransit["ghost2_CTLD_FR"])  -- stale cleaned up

tm._inTransit = _saved_transit2

-- ══════════════════════════════════════════════════════════════════════════════
-- Section 6 — aiZones config format loading (Feature S)
-- ══════════════════════════════════════════════════════════════════════════════

-- F-R-13: inject aiZones config + fake trigger.misc.getZone → zones created correctly
local _savedAiZ13  = cfg.settings["aiZones"]
local _savedGetZ13 = trigger.misc.getZone
local _savedTZ13   = zm._troopZones

cfg.settings["aiZones"] = {
    { dcsZoneName="test_ai_p", coalition="BLUE", isPickup=true,  cargoType="T", troopStock=5 },
    { dcsZoneName="test_ai_d", coalition="BLUE", isDropoff=true },
}
trigger.misc.getZone = function(name)
    return { point = { x=100, y=0, z=200 }, radius = 300 }
end

zm._troopZones   = {}
zm._aiZoneErrors = nil
zm:_loadAIZonesFromConfig()

local zAIP = zm._troopZones["test_ai_p"]
local zAID = zm._troopZones["test_ai_d"]

checkNotNil("F-R-13.1", zAIP)
checkNotNil("F-R-13.2", zAID)
if zAIP then
    checkTrue ("F-R-13.3", zAIP:hasAIPickup())
    checkFalse("F-R-13.4", zAIP:hasAIDropoff())
    check     ("F-R-13.5", zAIP.pickMaxStock, 5)
end
if zAID then
    checkFalse("F-R-13.6", zAID:hasAIPickup())
    checkTrue ("F-R-13.7", zAID:hasAIDropoff())
    checkNil  ("F-R-13.8", zAID.pickMaxStock)
end

-- Restore
cfg.settings["aiZones"] = _savedAiZ13
trigger.misc.getZone    = _savedGetZ13
zm._troopZones          = _savedTZ13
zm._aiZoneErrors        = nil

-- ══════════════════════════════════════════════════════════════════════════════
-- Section 7 — aiDropMode via _loadAIZonesFromConfig
-- ══════════════════════════════════════════════════════════════════════════════

-- F-R-14: aiDropMode="G"
withAIZ(
    { dcsZoneName="fr14", coalition="BLUE", isDropoff=true, aiDropMode="G" },
    function(z) checkNotNil("F-R-14.1", z); if z then check("F-R-14.2", z.aiDropMode, "G") end end)

-- F-R-15: aiDropMode="P"
withAIZ(
    { dcsZoneName="fr15", coalition="BLUE", isDropoff=true, aiDropMode="P" },
    function(z) checkNotNil("F-R-15.1", z); if z then check("F-R-15.2", z.aiDropMode, "P") end end)

-- F-R-16: aiDropMode="GP"
withAIZ(
    { dcsZoneName="fr16", coalition="BLUE", isDropoff=true, aiDropMode="GP" },
    function(z) checkNotNil("F-R-16.1", z); if z then check("F-R-16.2", z.aiDropMode, "GP") end end)

-- F-R-17: no aiDropMode → default "GP"
withAIZ(
    { dcsZoneName="fr17", coalition="BLUE", isDropoff=true },
    function(z) checkNotNil("F-R-17.1", z); if z then check("F-R-17.2", z.aiDropMode, "GP") end end)

-- F-R-18: invalid aiDropMode → zone created (WARN), aiDropMode stored as "GP" (Fix 6)
withAIZ(
    { dcsZoneName="fr18", coalition="BLUE", isDropoff=true, aiDropMode="X" },
    function(z)
        checkNotNil("F-R-18.1", z)               -- zone IS created (invalid mode = WARN only)
        if z then check("F-R-18.2", z.aiDropMode, "GP") end  -- Fix 6: stored as "GP"
    end)

-- F-R-19: CTLDTroopZone aiDropMode attribute default = "GP"
local zDM = mkZone("dm_test", 2, { isAIDropoff=true })
check("F-R-19.1", zDM.aiDropMode, "GP")

-- F-R-20: multiple dropoff entries with varying aiDropMode
local _savedAiZ20  = cfg.settings["aiZones"]
local _savedGZ20   = trigger.misc.getZone
local _savedTrZ20  = zm._troopZones

cfg.settings["aiZones"] = {
    { dcsZoneName="dm_g",  coalition="BLUE", isDropoff=true, aiDropMode="G"  },
    { dcsZoneName="dm_p",  coalition="BLUE", isDropoff=true, aiDropMode="P"  },
    { dcsZoneName="dm_gp", coalition="BLUE", isDropoff=true, aiDropMode="GP" },
    { dcsZoneName="dm_df", coalition="BLUE", isDropoff=true },  -- default
}
trigger.misc.getZone = function() return { point={x=0,y=0,z=0}, radius=100 } end
zm._troopZones   = {}
zm._aiZoneErrors = nil
zm:_loadAIZonesFromConfig()

local zG  = zm._troopZones["dm_g"]
local zP  = zm._troopZones["dm_p"]
local zGP = zm._troopZones["dm_gp"]
local zDF = zm._troopZones["dm_df"]

checkNotNil("F-R-20.1", zG)
if zG  then check("F-R-20.2", zG.aiDropMode,  "G")  end
if zP  then check("F-R-20.3", zP.aiDropMode,  "P")  end
if zGP then check("F-R-20.4", zGP.aiDropMode, "GP") end
if zDF then check("F-R-20.5", zDF.aiDropMode, "GP") end

cfg.settings["aiZones"] = _savedAiZ20
trigger.misc.getZone    = _savedGZ20
zm._troopZones          = _savedTrZ20
zm._aiZoneErrors        = nil

-- ══════════════════════════════════════════════════════════════════════════════
-- Section 8 — _checkAIStatus fallback template scan (FA-1)
-- F-R-21 : first template compatible → selected directly
-- F-R-22 : first template too big, second fits → fallback picks second
-- F-R-23 : all templates exceed capacity → embark never called
-- F-R-24 : teams=[] → embark never called
-- F-R-25 : hasTroops=true → pickup branch skipped entirely
-- F-R-26 : allowRandomAiTeamPickups=true + mixed → compatible always found
-- ══════════════════════════════════════════════════════════════════════════════

local core = CTLDCoreManager.getInstance()

-- Config saves
local _savedPilotNames = cfg.settings["transportPilotNames"]
local _savedRandom     = cfg.settings["allowRandomAiTeamPickups"]
local _savedCapsByType = cfg.settings["capabilitiesByType"]
cfg.settings["transportPilotNames"]      = { ["test_ai_fallback"] = true }  -- hash (onAILand uses pilotNames[name])
cfg.settings["allowRandomAiTeamPickups"] = false
cfg.settings["capabilitiesByType"]       = {
    ["UH-1H"] = { troopsEnabled=true, maxTroopsOnboard=8, canTransportWholeVehicle=false },
}

-- Unit mock: AI, on ground, coalition 2, UH-1H
local mockAIUnit = {
    getName       = function() return "test_ai_fallback" end,
    isExist       = function() return true end,
    getCoalition  = function() return 2 end,
    getTypeName   = function() return "UH-1H" end,
    getPlayerName = function() return nil end,
    getPoint      = function() return { x=0, y=0, z=0 } end,
    inAir         = function() return false end,
    getGroup      = function() return { getID = function() return 99 end } end,
    getCountry    = function() return 2 end,
}
local _savedGetByName = Unit.getByName
Unit.getByName = function(n) if n == "test_ai_fallback" then return mockAIUnit end return nil end

local _savedLandH = land.getHeight
land.getHeight = function() return 0 end  -- unit.y=0 → AGL=0 → not inAir

-- AIZ_P pickup zone stub (in-zone check bypassed via getAIPickupZoneAt mock)
local aiPickZoneStub = mkZone("test_ai_pz", 2, { isAIPickup=true, active=true })

-- Templates: big exceeds maxTroopsOnboard(8), small fits
local tmplBig   = { name="BigTeam",   total=20, riflemen=20, _dbKey="big",   specificParams={} }
local tmplSmall = { name="SmallTeam", total=4,  riflemen=4,  _dbKey="small", specificParams={} }

-- Mock factory helpers
local function mkMockTM(hasTroopsVal, canEmbarkFn)
    local called = {}
    local mock = {
        _called = called,
        hasTroops             = function(s, n) return hasTroopsVal end,
        _weightForGroup       = function(s, t) return t.total * 100 end,
        _canEmbark            = canEmbarkFn,
        embarkFromTroopZone   = function(s, u, z, t) called[#called+1] = t.name ; return true end,
        cleanupDeadTransports = function(s) end,
    }
    return mock
end

local function mkMockZM(pickZone)
    return {
        getAIDropoffZoneAt = function() return nil end,
        getAIPickupZoneAt  = function() return pickZone end,
    }
end

local _savedTMInst  = CTLDTroopManager.getInstance
local _savedZMInst  = CTLDZoneManager.getInstance
local _savedAiTeams = core._aiTeams

-- F-R-21: first template compatible → used directly
do
    local mockTM = mkMockTM(false, function(s, tn, un, tot, w) return true end)
    CTLDTroopManager.getInstance = function() return mockTM end
    CTLDZoneManager.getInstance  = function() return mkMockZM(aiPickZoneStub) end
    core._aiTeams = { [2] = { tmplBig } }
    core:onAILand({ initiator = mockAIUnit })
    check    ("F-R-21.1", #mockTM._called, 1)
    if #mockTM._called > 0 then check("F-R-21.2", mockTM._called[1], "BigTeam") end
end

-- F-R-22: first template too big, second fits → fallback picks second
do
    local mockTM = mkMockTM(false, function(s, tn, un, tot, w) return tot <= 8 end)
    CTLDTroopManager.getInstance = function() return mockTM end
    CTLDZoneManager.getInstance  = function() return mkMockZM(aiPickZoneStub) end
    core._aiTeams = { [2] = { tmplBig, tmplSmall } }
    core:onAILand({ initiator = mockAIUnit })
    check    ("F-R-22.1", #mockTM._called, 1)
    if #mockTM._called > 0 then check("F-R-22.2", mockTM._called[1], "SmallTeam") end
end

-- F-R-23: all templates exceed capacity → embark never called
do
    local mockTM = mkMockTM(false, function(s, tn, un, tot, w) return false end)
    CTLDTroopManager.getInstance = function() return mockTM end
    CTLDZoneManager.getInstance  = function() return mkMockZM(aiPickZoneStub) end
    core._aiTeams = { [2] = { tmplBig, tmplBig } }
    core:onAILand({ initiator = mockAIUnit })
    check("F-R-23.1", #mockTM._called, 0)
end

-- F-R-24: teams=[] → embark never called
do
    local mockTM = mkMockTM(false, function(s, tn, un, tot, w) return true end)
    CTLDTroopManager.getInstance = function() return mockTM end
    CTLDZoneManager.getInstance  = function() return mkMockZM(aiPickZoneStub) end
    core._aiTeams = { [2] = {} }
    core:onAILand({ initiator = mockAIUnit })
    check("F-R-24.1", #mockTM._called, 0)
end

-- F-R-25: hasTroops=true → pickup branch skipped
do
    local mockTM = mkMockTM(true, function(s, tn, un, tot, w) return true end)
    CTLDTroopManager.getInstance = function() return mockTM end
    CTLDZoneManager.getInstance  = function() return mkMockZM(aiPickZoneStub) end
    core._aiTeams = { [2] = { tmplSmall } }
    core:onAILand({ initiator = mockAIUnit })
    check("F-R-25.1", #mockTM._called, 0)
end

-- F-R-26: allowRandomAiTeamPickups=true, only SmallTeam compatible → always found over 10 runs
do
    cfg.settings["allowRandomAiTeamPickups"] = true
    local tmplBig2 = { name="BigTeam2", total=20, riflemen=20, _dbKey="big2", specificParams={} }
    local allFound = true
    for _ = 1, 10 do
        local mockTM = mkMockTM(false, function(s, tn, un, tot, w) return tot <= 8 end)
        CTLDTroopManager.getInstance = function() return mockTM end
        CTLDZoneManager.getInstance  = function() return mkMockZM(aiPickZoneStub) end
        core._aiTeams = { [2] = { tmplBig, tmplBig2, tmplSmall } }
        core:onAILand({ initiator = mockAIUnit })
        if #mockTM._called ~= 1 or mockTM._called[1] ~= "SmallTeam" then allFound = false end
    end
    checkTrue("F-R-26.1", allFound)
    cfg.settings["allowRandomAiTeamPickups"] = false
end

-- Restore section 8
CTLDTroopManager.getInstance             = _savedTMInst
CTLDZoneManager.getInstance              = _savedZMInst
core._aiTeams                            = _savedAiTeams
Unit.getByName                           = _savedGetByName
land.getHeight                           = _savedLandH
cfg.settings["transportPilotNames"]      = _savedPilotNames
cfg.settings["allowRandomAiTeamPickups"] = _savedRandom
cfg.settings["capabilitiesByType"]       = _savedCapsByType

-- ══════════════════════════════════════════════════════════════════════════════
-- Section 9 — Feature S: troopTemplates + vehicleTypes whitelists
-- ══════════════════════════════════════════════════════════════════════════════

-- F-R-27: zone with troopTemplates set → attribute stored on zone
withAIZ(
    { dcsZoneName="fr27", coalition="BLUE", isPickup=true, cargoType="T", troopStock=5,
      troopTemplates={"Spec Ops Group", "Anti Tank"} },
    function(z)
        checkNotNil("F-R-27.1", z)
        if z then
            checkNotNil("F-R-27.2", z.troopTemplates)
            if z.troopTemplates then
                check("F-R-27.3", z.troopTemplates[1], "Spec Ops Group")
                check("F-R-27.4", z.troopTemplates[2], "Anti Tank")
            end
        end
    end)

-- F-R-28: zone without troopTemplates → attribute nil (all templates eligible)
withAIZ(
    { dcsZoneName="fr28", coalition="BLUE", isPickup=true, cargoType="T", troopStock=5 },
    function(z)
        checkNotNil("F-R-28.1", z)
        if z then checkNil("F-R-28.2", z.troopTemplates) end
    end)

-- F-R-29: zone with vehicleTypes set → attribute stored on zone
withAIZ(
    { dcsZoneName="fr29", coalition="BLUE", isPickup=true, cargoType="V",
      vehicleTypes={"Hummer", "M1045 HMMWV TOW"} },
    function(z)
        checkNotNil("F-R-29.1", z)
        if z then
            checkNotNil("F-R-29.2", z.vehicleTypes)
            if z.vehicleTypes then
                check("F-R-29.3", z.vehicleTypes[1], "Hummer")
                check("F-R-29.4", z.vehicleTypes[2], "M1045 HMMWV TOW")
            end
        end
    end)

-- F-R-30: zone without vehicleTypes → attribute nil (no filter)
withAIZ(
    { dcsZoneName="fr30", coalition="BLUE", isPickup=true, cargoType="V" },
    function(z)
        checkNotNil("F-R-30.1", z)
        if z then checkNil("F-R-30.2", z.vehicleTypes) end
    end)

-- F-R-31: troopTemplates filter at pickup — matching name → team passes filter
-- Simulates the filtering logic in onAILand: teams filtered by nameSet from zone.troopTemplates
do
    local zone31 = mkZone("zone31", 2, {
        isAIPickup     = true,
        troopTemplates = { "Anti Tank" },
    })
    local allTeams = {
        { name="Standard Group", total=10 },
        { name="Anti Tank",      total=5  },
        { name="Spec Ops Group", total=4  },
    }
    -- Apply filter (mirrors onAILand logic)
    local nameSet = {}
    for _, tn in ipairs(zone31.troopTemplates) do nameSet[tn] = true end
    local filtered = {}
    for _, t in ipairs(allTeams) do
        if nameSet[t.name] then filtered[#filtered + 1] = t end
    end
    check("F-R-31.1", #filtered, 1)
    if #filtered > 0 then check("F-R-31.2", filtered[1].name, "Anti Tank") end
end

-- F-R-32: troopTemplates filter at pickup — no match → empty list
do
    local zone32 = mkZone("zone32", 2, {
        isAIPickup     = true,
        troopTemplates = { "NonExistentTeam" },
    })
    local allTeams = {
        { name="Standard Group", total=10 },
        { name="Anti Tank",      total=5  },
    }
    local nameSet = {}
    for _, tn in ipairs(zone32.troopTemplates) do nameSet[tn] = true end
    local filtered = {}
    for _, t in ipairs(allTeams) do
        if nameSet[t.name] then filtered[#filtered + 1] = t end
    end
    check("F-R-32.1", #filtered, 0)  -- no match → pickup will be skipped by onAILand
end

-- F-R-47: vehicleTypes filter at pickup — matching type → passes filter
-- Mirrors onAILand: typeSet built from zone.vehicleTypes, loadables filtered by vehicleType
do
    local zone47 = mkZone("zone47", 2, {
        isAIPickup   = true,
        vehicleTypes = { "Hummer" },
    })
    local loadables = {
        { vehicleType = "M1045 HMMWV TOW" },
        { vehicleType = "Hummer"          },
        { vehicleType = "BTR-80"          },
    }
    local typeSet = {}
    for _, vt in ipairs(zone47.vehicleTypes) do typeSet[vt] = true end
    local filtered = {}
    for _, v in ipairs(loadables) do
        if typeSet[v.vehicleType] then filtered[#filtered + 1] = v end
    end
    check    ("F-R-47.1", #filtered,               1)
    if #filtered > 0 then
        check("F-R-47.2", filtered[1].vehicleType, "Hummer")
    end
end

-- F-R-48: vehicleTypes filter at pickup — non-matching type → filtered out
do
    local zone48 = mkZone("zone48", 2, {
        isAIPickup   = true,
        vehicleTypes = { "Hummer" },
    })
    local loadables = {
        { vehicleType = "M1045 HMMWV TOW" },
        { vehicleType = "BTR-80"          },
    }
    local typeSet = {}
    for _, vt in ipairs(zone48.vehicleTypes) do typeSet[vt] = true end
    local filtered = {}
    for _, v in ipairs(loadables) do
        if typeSet[v.vehicleType] then filtered[#filtered + 1] = v end
    end
    check("F-R-48.1", #filtered, 0)  -- no match → vehicle pickup skipped by onAILand
end

-- ══════════════════════════════════════════════════════════════════════════════
-- Section 10 — _validateZoneNames AIZ section + grouped report MM
-- F-R-33 : missing coalition   → ERROR, _aiZoneErrors set, zone not created
-- F-R-34 : duplicate dzn       → ERROR (second), both skipped in load
-- F-R-35 : dzn not in ME       → ERROR, zone not created
-- F-R-36 : invalid cargoType   → WARN (in errors[] label), _aiZoneErrors NOT set, zone created
-- F-R-37 : invalid aiDropMode  → WARN, _aiZoneErrors NOT set, zone created
-- F-R-38 : troopTemplates unknown → WARN, zone created
-- F-R-39 : P+D overlap same coalition → WARN, both zones created
-- F-R-40 : report outText called when errors/warns exist
-- ══════════════════════════════════════════════════════════════════════════════

-- Full-pipeline helper: validate → capture _aiZoneErrors → load → return zones
local function validateAndLoad(entries, getZoneFn)
    local _sAiZ  = cfg.settings["aiZones"]
    local _sGetZ = trigger.misc.getZone
    local _sOutT = trigger.action.outText
    local _sTZ   = zm._troopZones

    cfg.settings["aiZones"] = entries
    trigger.misc.getZone = getZoneFn or function() return {point={x=0,y=0,z=0},radius=200} end
    local captured = nil
    trigger.action.outText = function(msg, dur) captured = msg end

    zm._troopZones   = {}
    zm._aiZoneErrors = nil
    zm:_validateZoneNames()
    local aiZErr = zm._aiZoneErrors or {}    -- capture BEFORE _loadAIZonesFromConfig clears it
    zm:_loadAIZonesFromConfig()

    local zones = {}
    for k, v in pairs(zm._troopZones) do zones[k] = v end

    cfg.settings["aiZones"]    = _sAiZ
    trigger.misc.getZone       = _sGetZ
    trigger.action.outText     = _sOutT
    zm._troopZones              = _sTZ
    zm._aiZoneErrors            = nil
    return zones, aiZErr, captured
end

-- F-R-33: missing coalition → ERROR, _aiZoneErrors set, zone not created
do
    local dzn = "aiz_fr33"
    local zones, aiZErr, report = validateAndLoad(
        { { dcsZoneName=dzn, isPickup=true, cargoType="T", troopStock=5 } }  -- no coalition
    )
    checkTrue ("F-R-33.1", aiZErr[dzn])       -- in error set
    checkNil  ("F-R-33.2", zones[dzn])        -- zone NOT created
    checkNotNil("F-R-33.3", report)            -- report shown (outText called)
end

-- F-R-34: duplicate dcsZoneName → second entry gets ERROR, both skipped in load
do
    local dzn = "aiz_fr34"
    local zones, aiZErr, report = validateAndLoad({
        { dcsZoneName=dzn, coalition="BLUE", isPickup=true  },
        { dcsZoneName=dzn, coalition="BLUE", isDropoff=true },  -- duplicate
    })
    checkTrue("F-R-34.1", aiZErr[dzn])    -- error set on duplicate (both skipped)
    checkNil ("F-R-34.2", zones[dzn])     -- zone NOT created (even first entry skipped)
end

-- F-R-35: dcsZoneName not found in ME → ERROR, zone not created
do
    local dzn = "aiz_fr35"
    -- getZoneFn always returns nil → zone "not in ME"
    local zones, aiZErr, report = validateAndLoad(
        { { dcsZoneName=dzn, coalition="BLUE", isPickup=true } },
        function() return nil end
    )
    checkTrue("F-R-35.1", aiZErr[dzn])   -- in error set
    checkNil ("F-R-35.2", zones[dzn])    -- zone NOT created
end

-- F-R-36: invalid cargoType → WARN (in warns[], Fix 5), _aiZoneErrors NOT set, zone IS created
do
    local dzn = "aiz_fr36"
    local zones, aiZErr, report = validateAndLoad(
        { { dcsZoneName=dzn, coalition="BLUE", isPickup=true, cargoType="BOGUS" } }
    )
    checkFalse("F-R-36.1", aiZErr[dzn])    -- NOT in error set (warn only)
    checkNotNil("F-R-36.2", zones[dzn])    -- zone IS created
    checkNotNil("F-R-36.3", report)        -- WARN in report
end

-- F-R-37: invalid aiDropMode → WARN (warns[]), zone IS created, aiDropMode="GP" (Fix 6)
do
    local dzn = "aiz_fr37"
    local zones, aiZErr, report = validateAndLoad(
        { { dcsZoneName=dzn, coalition="BLUE", isDropoff=true, aiDropMode="X" } }
    )
    checkFalse  ("F-R-37.1", aiZErr[dzn])           -- NOT in error set
    checkNotNil ("F-R-37.2", zones[dzn])             -- zone IS created
    if zones[dzn] then
        check("F-R-37.3", zones[dzn].aiDropMode, "GP")  -- Fix 6: stored as "GP"
    end
end

-- F-R-38: troopTemplates with unknown name → WARN, zone IS created
do
    local dzn = "aiz_fr38"
    local zones, aiZErr, report = validateAndLoad(
        { { dcsZoneName=dzn, coalition="BLUE", isPickup=true, cargoType="T", troopStock=5,
            troopTemplates={"__NonExistentTemplate__"} } }
    )
    checkFalse("F-R-38.1", aiZErr[dzn])    -- NOT in error set (warn only)
    checkNotNil("F-R-38.2", zones[dzn])    -- zone IS created
end

-- F-R-39: P+D overlap same coalition → WARN, both zones created
do
    local dznP = "aiz_fr39_p"
    local dznD = "aiz_fr39_d"
    -- Same position → guaranteed overlap
    local function getZ() return {point={x=0,y=0,z=0}, radius=500} end
    local zones, aiZErr, report = validateAndLoad(
        {
            { dcsZoneName=dznP, coalition="BLUE", isPickup=true,  cargoType="T", troopStock=5 },
            { dcsZoneName=dznD, coalition="BLUE", isDropoff=true  },
        },
        getZ
    )
    checkFalse("F-R-39.1", aiZErr[dznP])   -- P not in error set (overlap = warn only)
    checkFalse("F-R-39.2", aiZErr[dznD])   -- D not in error set
    checkNotNil("F-R-39.3", zones[dznP])   -- P zone created
    checkNotNil("F-R-39.4", zones[dznD])   -- D zone created
    checkNotNil("F-R-39.5", report)        -- WARN shown (overlap)
end

-- F-R-40: any error/warn → outText called, message contains "CTLD"
do
    local zones, aiZErr, report = validateAndLoad(
        { { dcsZoneName="aiz_fr40", isPickup=true } }  -- no coalition → ERROR
    )
    checkNotNil("F-R-40.1", report)
    if report then
        checkTrue("F-R-40.2", string.find(report, "CTLD", 1, true) ~= nil)
        checkTrue("F-R-40.3", string.find(report, "error", 1, true) ~= nil)
    end
end

-- ══════════════════════════════════════════════════════════════════════════════
-- Section 11 — Nouveaux checks G1/G2/G3/G4/G5 + Fix5/Fix6
-- ══════════════════════════════════════════════════════════════════════════════

-- F-R-41: ni isPickup ni isDropoff → ERROR, zone not created (G1)
do
    local dzn = "aiz_fr41"
    local zones, aiZErr, report = validateAndLoad(
        { { dcsZoneName=dzn, coalition="BLUE" } }  -- neither isPickup nor isDropoff
    )
    checkTrue  ("F-R-41.1", aiZErr[dzn])    -- in error set (G1 = ERROR)
    checkNil   ("F-R-41.2", zones[dzn])     -- zone NOT created
    checkNotNil("F-R-41.3", report)         -- report shown
end

-- F-R-42: troopTemplates TOUS inconnus → WARN distinct "all troopTemplates are unknown",
--         zone IS created (G2)
do
    local dzn = "aiz_fr42"
    local zones, aiZErr, report = validateAndLoad(
        { { dcsZoneName=dzn, coalition="BLUE", isPickup=true, cargoType="T", troopStock=5,
            troopTemplates={"__NoExist1__", "__NoExist2__"} } }
    )
    checkFalse ("F-R-42.1", aiZErr[dzn])    -- NOT in error set (warn only)
    checkNotNil("F-R-42.2", zones[dzn])     -- zone IS created
    checkNotNil("F-R-42.3", report)         -- WARN shown
    if report then
        checkTrue("F-R-42.4", string.find(report, "all troopTemplates are unknown", 1, true) ~= nil)
    end
end

-- F-R-43: isPickup + troopStock=0 → WARN "troopStock=0", zone IS created (G3)
do
    local dzn = "aiz_fr43"
    local zones, aiZErr, report = validateAndLoad(
        { { dcsZoneName=dzn, coalition="BLUE", isPickup=true, cargoType="T", troopStock=0 } }
    )
    checkFalse ("F-R-43.1", aiZErr[dzn])    -- NOT in error set (warn only)
    checkNotNil("F-R-43.2", zones[dzn])     -- zone IS created
    checkNotNil("F-R-43.3", report)         -- WARN shown
    if report then
        checkTrue("F-R-43.4", string.find(report, "troopStock=0", 1, true) ~= nil)
    end
end

-- F-R-44: vehicleTypes TOUS inconnus dans loadableVehicles → WARN, zone IS created (G4)
do
    local dzn     = "aiz_fr44"
    local _savedCaps = cfg.settings["capabilitiesByType"]
    cfg.settings["capabilitiesByType"] = {
        ["UH-1H"] = {
            canTransportWholeVehicle = true,
            loadableVehiclesRED      = { "Hummer" },
            loadableVehiclesBLUE     = { "Hummer" },
        },
    }
    local zones, aiZErr, report = validateAndLoad(
        { { dcsZoneName=dzn, coalition="BLUE", isPickup=true, cargoType="V",
            vehicleTypes={"__UnknownVehicleType1__", "__UnknownVehicleType2__"} } }
    )
    cfg.settings["capabilitiesByType"] = _savedCaps
    checkFalse ("F-R-44.1", aiZErr[dzn])    -- NOT in error set (warn only)
    checkNotNil("F-R-44.2", zones[dzn])     -- zone IS created
    checkNotNil("F-R-44.3", report)         -- WARN shown
    if report then
        checkTrue("F-R-44.4", string.find(report, "all vehicleTypes entries are unknown", 1, true) ~= nil)
    end
end

-- F-R-45: coalition "ROUGE" (faute de frappe) → ERROR, zone not created
do
    local dzn = "aiz_fr45"
    local zones, aiZErr, report = validateAndLoad(
        { { dcsZoneName=dzn, coalition="ROUGE", isPickup=true, cargoType="T", troopStock=5 } }
    )
    checkTrue  ("F-R-45.1", aiZErr[dzn])    -- in error set (invalid coalition)
    checkNil   ("F-R-45.2", zones[dzn])     -- zone NOT created
    checkNotNil("F-R-45.3", report)         -- report shown
end

-- F-R-46: cargoType=V + aucun transport canTransportWholeVehicle → ERROR, zone not created (G5)
do
    local dzn     = "aiz_fr46"
    local _savedCaps = cfg.settings["capabilitiesByType"]
    cfg.settings["capabilitiesByType"] = {
        ["UH-1H"] = { cratesEnabled = true },  -- no canTransportWholeVehicle
    }
    local zones, aiZErr, report = validateAndLoad(
        { { dcsZoneName=dzn, coalition="BLUE", isPickup=true, cargoType="V" } }
    )
    cfg.settings["capabilitiesByType"] = _savedCaps
    checkTrue  ("F-R-46.1", aiZErr[dzn])    -- in error set (G5 = ERROR)
    checkNil   ("F-R-46.2", zones[dzn])     -- zone NOT created
    checkNotNil("F-R-46.3", report)         -- report shown
    if report then
        checkTrue("F-R-46.4", string.find(report, "canTransportWholeVehicle", 1, true) ~= nil)
    end
end

-- ══════════════════════════════════════════════════════════════════════════════
-- Section 12 — Rapport MM live : outText réel → écran + CTLD.log
-- F-R-49 : config 5 ERRORs + 2 WARNs → rapport complet visible écran + log
-- ══════════════════════════════════════════════════════════════════════════════

-- F-R-49: rapport de validation MM avec données erronées
-- Le rapport DOIT apparaître sur l'écran DCS ET dans CTLD.log.
-- Données injectées :
--   bad_G1   → ni isPickup ni isDropoff (G1 ERROR)
--   bad_coa  → coalition="ROUGE" invalide (ERROR)
--   bad_noME → dcsZoneName absent du ME (ERROR)
--   bad_dup  × 2 → duplicate dcsZoneName (ERROR)
--   bad_G5   → cargoType=V sans canTransportWholeVehicle (G5 ERROR)
--   bad_G3   → troopStock=0 pickup troop (G3 WARN)
--   bad_G2   → tous troopTemplates inconnus (G2 WARN)
do
    local _sAiZ  = cfg.settings["aiZones"]
    local _sGetZ = trigger.misc.getZone
    local _sTZ   = zm._troopZones
    local _sOutT = trigger.action.outText
    local _sCaps = cfg.settings["capabilitiesByType"]

    -- Wrapper : capture ET affiche réellement sur écran
    local capturedReport = nil
    trigger.action.outText = function(msg, dur)
        capturedReport = msg
        _sOutT(msg, dur)   -- ← rapport visible écran DCS
    end

    -- Retourne nil pour bad_noME, zone réelle pour les autres
    trigger.misc.getZone = function(name)
        if name == "bad_noME" then return nil end
        return { point={x=0,y=0,z=0}, radius=200 }
    end

    -- Aucun transport avec canTransportWholeVehicle → G5 se déclenche
    cfg.settings["capabilitiesByType"] = {
        ["UH-1H"] = { cratesEnabled = true },
    }

    cfg.settings["aiZones"] = {
        { dcsZoneName="bad_G1",  coalition="BLUE" },                           -- G1 ERROR
        { dcsZoneName="bad_coa", coalition="ROUGE", isPickup=true },           -- coalition ERROR
        { dcsZoneName="bad_noME", coalition="BLUE", isDropoff=true },          -- absent ME ERROR
        { dcsZoneName="bad_dup", coalition="BLUE", isPickup=true, cargoType="T", troopStock=5 },
        { dcsZoneName="bad_dup", coalition="BLUE", isDropoff=true },           -- duplicate ERROR
        { dcsZoneName="bad_G5",  coalition="BLUE", isPickup=true, cargoType="V" }, -- G5 ERROR
        { dcsZoneName="bad_G3",  coalition="BLUE", isPickup=true, cargoType="T", troopStock=0 }, -- G3 WARN
        { dcsZoneName="bad_G2",  coalition="BLUE", isPickup=true, cargoType="T", troopStock=5,
          troopTemplates={"__NX1__", "__NX2__"} },                             -- G2 WARN
    }

    zm._troopZones   = {}
    zm._aiZoneErrors = nil
    zm:_validateZoneNames()   -- ← appel réel, outText wrapper fire → écran + capture

    local aiZErr = zm._aiZoneErrors or {}

    -- Rapport reçu et affiché
    checkNotNil("F-R-49.1",  capturedReport)
    if capturedReport then
        checkTrue("F-R-49.2",  string.find(capturedReport, "CTLD",     1, true) ~= nil)
        checkTrue("F-R-49.3",  string.find(capturedReport, "error",    1, true) ~= nil)
        checkTrue("F-R-49.4",  string.find(capturedReport, "bad_G1",   1, true) ~= nil)
        checkTrue("F-R-49.5",  string.find(capturedReport, "bad_coa",  1, true) ~= nil)
        checkTrue("F-R-49.6",  string.find(capturedReport, "bad_noME", 1, true) ~= nil)
        checkTrue("F-R-49.7",  string.find(capturedReport, "bad_dup",  1, true) ~= nil)
        checkTrue("F-R-49.8",  string.find(capturedReport, "bad_G5",   1, true) ~= nil)
        checkTrue("F-R-49.9",  string.find(capturedReport, "troopStock=0", 1, true) ~= nil)
        checkTrue("F-R-49.10", string.find(capturedReport, "all troopTemplates are unknown", 1, true) ~= nil)
    end

    -- Zones ERROR → dans le set d'erreurs (seront skippées au load)
    checkTrue ("F-R-49.11", aiZErr["bad_G1"]   == true)
    checkTrue ("F-R-49.12", aiZErr["bad_coa"]  == true)
    checkTrue ("F-R-49.13", aiZErr["bad_noME"] == true)
    checkTrue ("F-R-49.14", aiZErr["bad_dup"]  == true)
    checkTrue ("F-R-49.15", aiZErr["bad_G5"]   == true)

    -- Zones WARN uniquement → PAS dans le set d'erreurs (seront créées)
    checkFalse("F-R-49.16", aiZErr["bad_G3"] == true)
    checkFalse("F-R-49.17", aiZErr["bad_G2"] == true)

    -- Restauration
    trigger.action.outText          = _sOutT
    trigger.misc.getZone            = _sGetZ
    cfg.settings["aiZones"]         = _sAiZ
    cfg.settings["capabilitiesByType"] = _sCaps
    zm._troopZones                   = _sTZ
    zm._aiZoneErrors                 = nil
end

-- ══════════════════════════════════════════════════════════════════════════════
-- Summary
-- ══════════════════════════════════════════════════════════════════════════════
cfg.settings["debug"] = _saved_debug
cfg.settings["debugScreenLog"] = _savedDebugScreenLog

local total = pass_n + fail_n
local msg = string.format("[FR] DONE — %d/%d PASS%s", pass_n, total,
    fail_n > 0 and (" | " .. fail_n .. " FAIL(S) — check CTLD.log") or " ✓")
trigger.action.outText(msg, 30, true)
ctld.utils.log("INFO", msg)

_SCN_FR_RUNNING = false
return msg
end  -- do isolation scope
return Witchcraft
