---@diagnostic disable
-- =============================================================================
-- AUTO — CL-9: ctld.pickupZones → CTLDTroopZone instanciation (legacy compat)
-- =============================================================================
-- F-CL9-1 : trigger zone entry → CTLDTroopZone créé, stock/smoke/active/coalition OK
-- F-CL9-2 : limit=-1 → pickMaxStock=0 (unlimited) ; hasPickup()=true
-- F-CL9-3 : stockFlagName = zoneName.."_count" ; setUserFlag appelé sur consumeStock
-- F-CL9-4 : ship unit name fallback → CTLDTroopZone créé avec position ship
--
-- Prerequisites : none (fully mocked)
-- Family        : auto
-- =============================================================================

-- ── Witchcraft guard ───────────────────────────────────────────────────────
if not ctld or not ctld.utils then
    trigger.action.outText("[CL9] ABORT: CTLD not initialized. Inject CTLD_Next.lua first.", 15)
    return Witchcraft
end

-- ── Double-injection guard ─────────────────────────────────────────────
if _SCN_CL9_RUNNING then
    trigger.action.outText("[CL9] already running.", 10)
    return Witchcraft
end
_SCN_CL9_RUNNING = true

do  -- isolation scope
trigger.action.outText("[CL9] START — pickupZones legacy instanciation", 8)

local cfg          = CTLDConfig.get()
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

-- ── Mock trigger.misc.getZone ─────────────────────────────────────────────────
local _origGetZone = trigger.misc.getZone
trigger.misc.getZone = function(name)
    if name == "testpickzone" then
        return { point = { x=100, y=0, z=200 }, radius = 500 }
    end
    -- "USS_Tarawa" returns nil → triggers ship fallback
    return nil
end

-- ── Mock Unit.getByName (ship fallback) ───────────────────────────────────────
local _origUnitGetByName = Unit.getByName
Unit.getByName = function(name)
    if name == "USS_Tarawa" then
        return {
            isExist  = function() return true end,
            getPoint = function() return { x=500, y=0, z=600 } end,
        }
    end
    return _origUnitGetByName(name)
end

-- ── Mock trigger.action.setUserFlag ──────────────────────────────────────────
local _capturedFlags = {}
local _origSetUserFlag = trigger.action.setUserFlag
trigger.action.setUserFlag = function(flagName, value)
    _capturedFlags[tostring(flagName)] = value
end

-- ── Inject test pickupZones into config ──────────────────────────────────────
local _savedPickupZones = cfg.settings["pickupZones"]
cfg.settings["pickupZones"] = {
    { "testpickzone", "blue", -1,  "yes", 2 },    -- trigger zone, unlimited, BLUE, active
    { "USS_Tarawa",   "none",  5,  "yes", 0 },    -- ship unit, 5 groups, any coalition
}

-- ── Run _loadLegacyZones ──────────────────────────────────────────────────────
local zm  = CTLDZoneManager.getInstance()
local _savedTroopZones = zm._troopZones
zm._troopZones = {}

local ok, err = pcall(function() zm:_loadLegacyZones() end)
if not ok then
    ctld.utils.log("ERROR", "[FAIL] _loadLegacyZones crash: %s", tostring(err))
    fail = fail + 1
end

-- ── F-CL9-1 : trigger zone instanciée correctement ───────────────────────────
ctld.utils.log("INFO", "── F-CL9-1 : trigger zone instanciation ──")
local tz = zm._troopZones["testpickzone"]
check("F-CL9-1.1 zone créée",            tz ~= nil,          true)
if tz then
    check("F-CL9-1.2 center.x",          tz.center.x,        100)
    check("F-CL9-1.3 radius",            tz.radius,          500)
    check("F-CL9-1.4 coalition BLUE",    tz.coalition,       2)
    check("F-CL9-1.5 active",            tz.active,          true)
    check("F-CL9-1.6 smoke set",         tz.smoke ~= nil,    true)
end

-- ── F-CL9-2 : limit=-1 → unlimited ───────────────────────────────────────────
ctld.utils.log("INFO", "── F-CL9-2 : limit=-1 → pickMaxStock=0 (unlimited) ──")
if tz then
    check("F-CL9-2.1 pickMaxStock=0 (unlimited)", tz.pickMaxStock, 0)
    check("F-CL9-2.2 hasPickup()=true",           tz:hasPickup(),  true)
    -- consumeStock on unlimited always returns true
    check("F-CL9-2.3 consumeStock unlimited",      tz:consumeStock(10), true)
end

-- ── F-CL9-3 : stockFlagName + setUserFlag ─────────────────────────────────────
ctld.utils.log("INFO", "── F-CL9-3 : stockFlagName + setUserFlag on consumeStock ──")
-- Create a limited zone to test actual stock sync
local limZone = CTLDTroopZone:new({
    dcsName       = "limzone", zoneName = "limzone",
    coalition     = 0,
    center        = { x=0, y=0, z=0 }, radius = 100,
    pickMaxStock  = 5,
    stockFlagName = "limzone_count",
})
_capturedFlags = {}
limZone:consumeStock(2)
check("F-CL9-3.1 stockFlagName set",     limZone.stockFlagName,              "limzone_count")
check("F-CL9-3.2 flag synced on consume",_capturedFlags["limzone_count"],    3)
limZone:restoreStock(1)
check("F-CL9-3.3 flag synced on restore",_capturedFlags["limzone_count"],    4)

-- derived flag for trigger zone
if tz then
    check("F-CL9-3.4 auto stockFlagName",  tz.stockFlagName, "testpickzone_count")
end

-- ── F-CL9-4 : ship fallback ───────────────────────────────────────────────────
ctld.utils.log("INFO", "── F-CL9-4 : ship unit fallback ──")
local sz = zm._troopZones["USS_Tarawa"]
check("F-CL9-4.1 ship zone créée",       sz ~= nil,          true)
if sz then
    check("F-CL9-4.2 center.x = ship pos", sz.center.x,      500)
    check("F-CL9-4.3 radius from config",  sz.radius > 0,    true)
    check("F-CL9-4.4 pickMaxStock=5",      sz.pickMaxStock,   5)
    check("F-CL9-4.5 auto stockFlagName",  sz.stockFlagName,  "USS_Tarawa_count")
end

-- ── Restore ───────────────────────────────────────────────────────────────────
cfg.settings["pickupZones"]   = _savedPickupZones
cfg.settings["debug"]         = _saved_debug
zm._troopZones                = _savedTroopZones
trigger.misc.getZone          = _origGetZone
Unit.getByName                = _origUnitGetByName
trigger.action.setUserFlag    = _origSetUserFlag

-- ── Final result ──────────────────────────────────────────────────────────────
local total = pass + fail
local msg = string.format(
    "[CL9] DONE — %d/%d PASS%s",
    pass, total,
    fail > 0 and (" | " .. fail .. " FAIL — see CTLD.log") or ""
)
trigger.action.outText(msg, 15, true)
ctld.utils.log("INFO", msg)

_SCN_CL9_RUNNING = false
return "TAG=CL9_PICKUP_ZONES | steps=" .. total .. " | pass=" .. pass .. " | fail=" .. fail
end  -- do isolation scope
return Witchcraft
