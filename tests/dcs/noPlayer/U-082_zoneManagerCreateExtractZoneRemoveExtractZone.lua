---@diagnostic disable
-- ============================================================
-- U-82 : CTLDZoneManager — createExtractZone / removeExtractZone /
--        changeRemainingGroups / isUnitInZone
-- Module  : Q1 (src/CTLD_zone.lua)
-- ============================================================

do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")

local SRC = "C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/"
dofile(SRC .. "CTLD_core.lua")

-- DCS stubs
local _getZoneData = {}   -- name → zone data or nil
local _getZoneOrig = trigger.misc.getZone
trigger.misc.getZone = function(name) return _getZoneData[name] end
local _smokeLog = {}
local _smokeOrig = trigger.action.smoke
trigger.action.smoke = function(pt, color) table.insert(_smokeLog, { pt=pt, color=color }) end
local _heightOrig = land.getHeight
land.getHeight = function(p) return 10 end
local _unitByName = {}
local _unitGetOrig = Unit.getByName
Unit.getByName = function(name) return _unitByName[name] end

-- Helper: register a zone at given coords + radius
local function _registerZone(name, x, z, r)
    _getZoneData[name] = { point = { x=x, z=z }, radius = r or 100 }
end

dofile(SRC .. "CTLD_zone.lua")
CTLDDCSEventBridge._instance = nil
EventDispatcher._instance    = nil
CTLDZoneManager._instance    = nil
local zm = CTLDZoneManager.getInstance()

ctld_test.start("U-82", "CTLDZoneManager new methods — createExtractZone / removeExtractZone / changeRemainingGroups / isUnitInZone")

-- ── createExtractZone ──────────────────────────────────────
_registerZone("EXZ1", 1000, 2000, 150)

local ok1 = zm:createExtractZone("EXZ1", 42, -1)
ctld_test.assert(ok1 == true,                       "createExtractZone valid: returns true")
local z1 = zm._troopZones["EXZ1"]
ctld_test.assertNotNil(z1,                          "createExtractZone: zone stored")
ctld_test.assertEqual(z1.objectiveFlag, "42",       "createExtractZone: objectiveFlag=42")
ctld_test.assertEqual(z1.radius, 150,               "createExtractZone: radius=150")
ctld_test.assert(z1.active == true,                 "createExtractZone: active=true")
ctld_test.assert(z1:hasExtract(),                   "createExtractZone: hasExtract()==true")
ctld_test.assert(not z1:hasPickup(),                "createExtractZone: hasPickup()==false")

-- No smoke (smoke=-1)
ctld_test.assertEqual(#_smokeLog, 0,                "no smoke when smoke=-1")

-- Smoke triggered when smoke >= 0
_registerZone("EXZ2", 3000, 4000, 100)
zm:createExtractZone("EXZ2", "objFlag", 1)  -- smoke color 1
ctld_test.assertEqual(#_smokeLog, 1,                "smoke triggered when color>=0")

-- Duplicate returns false
local ok_dup = zm:createExtractZone("EXZ1", 99)
ctld_test.assert(ok_dup == false,                   "duplicate createExtractZone returns false")

-- Invalid zone returns false
local ok_inv = zm:createExtractZone("NO_SUCH_ZONE", 1)
ctld_test.assert(ok_inv == false,                   "invalid zone returns false")

-- ── removeExtractZone ──────────────────────────────────────
local ok_rem = zm:removeExtractZone("EXZ1", 42)
ctld_test.assert(ok_rem == true,                    "removeExtractZone: returns true")
ctld_test.assertNil(zm._troopZones["EXZ1"],         "removeExtractZone: zone removed")

local ok_notfound = zm:removeExtractZone("NO_ZONE")
ctld_test.assert(ok_notfound == false,              "removeExtractZone non-existent: returns false")

-- ── changeRemainingGroups ──────────────────────────────────
-- Inject a pickup zone directly
_registerZone("PKZ1", 500, 500, 80)
zm:createExtractZone("PKZ1", "f1")  -- creates extract zone (no pickup stock)
local ok_nostock = zm:changeRemainingGroups("PKZ1", 3)
ctld_test.assert(ok_nostock == false,               "changeRemainingGroups on extract-only zone: false")

-- Inject a TroopZone with pickup stock
local pzone = CTLDTroopZone:new({
    dcsName="PKZ2", zoneName="PKZ2", coalition=2,
    center={x=100,y=10,z=100}, radius=50, pickMaxStock=5, active=true })
zm._troopZones["PKZ2"] = pzone
ctld_test.assertEqual(pzone.pickCurrentStock, 5,    "PKZ2 initial stock=5")

zm:changeRemainingGroups("PKZ2", 3)
ctld_test.assertEqual(pzone.pickCurrentStock, 8,    "changeRemainingGroups +3 → 8")

zm:changeRemainingGroups("PKZ2", -4)
ctld_test.assertEqual(pzone.pickCurrentStock, 4,    "changeRemainingGroups -4 → 4")

zm:changeRemainingGroups("PKZ2", -10)
ctld_test.assertEqual(pzone.pickCurrentStock, 0,    "changeRemainingGroups clamped to 0")

local ok_nf = zm:changeRemainingGroups("NOPE", 1)
ctld_test.assert(ok_nf == false,                    "changeRemainingGroups not-found: false")

-- ── isUnitInZone ──────────────────────────────────────────
-- Inject an extract zone at known position
local exz = CTLDTroopZone:new({
    dcsName="EXZ3", zoneName="EXZ3", coalition=0,
    center={x=0,y=0,z=0}, radius=200,
    objectiveFlag="myFlag", active=true })
zm._troopZones["EXZ3"] = exz

-- Unit inside
_unitByName["unitInside"] = {
    isExist  = function() return true end,
    getPoint = function() return { x=50, y=0, z=50 } end,
}
local found = zm:isUnitInZone("unitInside", "extract")
ctld_test.assertNotNil(found,                       "isUnitInZone: unit inside extract zone → found")
ctld_test.assertEqual(found.zoneName, "EXZ3",       "isUnitInZone: correct zone returned")

-- Unit outside
_unitByName["unitOutside"] = {
    isExist  = function() return true end,
    getPoint = function() return { x=5000, y=0, z=5000 } end,
}
local notfound = zm:isUnitInZone("unitOutside", "extract")
ctld_test.assertNil(notfound,                       "isUnitInZone: unit outside → nil")

-- Wrong type (pickup) — EXZ3 has no pickup
local wrongtype = zm:isUnitInZone("unitInside", "pickup")
ctld_test.assertNil(wrongtype,                      "isUnitInZone: unit in extract zone, lookup pickup → nil")

-- Unknown unit
local unknown = zm:isUnitInZone("UNKNOWN", "extract")
ctld_test.assertNil(unknown,                        "isUnitInZone: unknown unit → nil")

-- Restore stubs
trigger.misc.getZone  = _getZoneOrig
trigger.action.smoke  = _smokeOrig
land.getHeight        = _heightOrig
Unit.getByName        = _unitGetOrig

ctld_test.finish()
