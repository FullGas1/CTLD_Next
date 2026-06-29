---@diagnostic disable
-- ============================================================
-- F-96 : Legacy API — Crates wrappers (3 functions) + spawnCrate now functional
-- Module  : Q1 (src/legacy/legacy_api.lua → src/CTLD_crate.lua)
-- ============================================================

do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")

local SRC = "C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/"
dofile(SRC .. "CTLD_core.lua")
dofile(SRC .. "lib/CTLD_objectRegistry.lua")
dofile(SRC .. "lib/CTLDParachuteEffect.lua")
dofile(SRC .. "CTLD_zone.lua")
dofile(SRC .. "CTLD_player.lua")
dofile(SRC .. "CTLD_menu.lua")

CTLDDCSEventBridge._instance = nil
EventDispatcher._instance    = nil
CTLDZoneManager._instance    = nil
CTLDPlayerManager._instance  = nil
ctld.MenuManager._instance   = nil

dofile(SRC .. "CTLD_crate.lua")
dofile(SRC .. "CTLD_troop.lua")
dofile(SRC .. "CTLD_beacon.lua")
dofile(SRC .. "CTLD_jtac.lua")
dofile(SRC .. "CTLD_vehicle.lua")

-- ── DCS stubs for static spawn ─────────────────────────────
local _spawnedStatics = {}
local _addStaticOrig = coalition.addStaticObject
coalition.addStaticObject = function(cId, data)
    _spawnedStatics[data.name] = { cId = cId, data = data }
end

local _getStaticOrig = StaticObject.getByName
StaticObject.getByName = function(name)
    return _spawnedStatics[name] and { _name = name } or nil
end

local _getZoneOrig = trigger.misc.getZone
local _getZoneData = { ZN1 = { point = { x=500, z=600 }, radius = 100 } }
trigger.misc.getZone = function(name) return _getZoneData[name] end

local _heightOrig = land.getHeight
land.getHeight = function(p) return 5 end

local _flagsSet = {}
local _setFlagOrig = trigger.action.setUserFlag
trigger.action.setUserFlag = function(f, v) _flagsSet[tostring(f)] = v end

dofile(SRC .. "compat/legacy_api.lua")

ctld_test.start("F-96", "Legacy API — Crates wrappers + spawnCrate functional")

-- ── ctld.spawnCrateAtZone ──────────────────────────────────
local crate1 = ctld.spawnCrateAtZone("blue", 1000.01, "ZN1")
ctld_test.assertNotNil(crate1,                       "spawnCrateAtZone: returns CTLDCrate (functional)")
ctld_test.assertEqual(crate1.coalition, coalition.side.BLUE, "spawnCrateAtZone: coalition=BLUE")
local sd1 = _spawnedStatics[crate1.crateName]
ctld_test.assertNotNil(sd1,                          "spawnCrateAtZone: coalition.addStaticObject called")
ctld_test.assertEqual(sd1.data.x, 500,               "spawnCrateAtZone: x from zone point")

-- Unknown zone → nil
local bad1 = ctld.spawnCrateAtZone("blue", 1000.01, "NO_ZONE")
ctld_test.assertNil(bad1,                            "spawnCrateAtZone: unknown zone → nil")

-- Unknown weight → nil
local bad2 = ctld.spawnCrateAtZone("blue", 9999, "ZN1")
ctld_test.assertNil(bad2,                            "spawnCrateAtZone: unknown weight → nil")

-- ── ctld.spawnCrateAtPoint ────────────────────────────────
local pt = { x=300, y=5, z=400 }
local crate2 = ctld.spawnCrateAtPoint("red", 1000.11, pt, 0)
ctld_test.assertNotNil(crate2,                       "spawnCrateAtPoint: returns CTLDCrate")
ctld_test.assertEqual(crate2.coalition, coalition.side.RED, "spawnCrateAtPoint: coalition=RED")
local sd2 = _spawnedStatics[crate2.crateName]
ctld_test.assertNotNil(sd2,                          "spawnCrateAtPoint: static spawned")
ctld_test.assertEqual(sd2.data.x, 300,               "spawnCrateAtPoint: x=300")

-- ── ctld.cratesInZone ────────────────────────────────────
-- Spawn a crate in the zone then check the watcher sets the flag
ctld.cratesInZone("ZN1", 77)
-- watcher fires immediately (_tick runs inline), flag set to count
ctld_test.assertNotNil(_flagsSet["77"],              "cratesInZone: watcher sets user flag 77")
-- 2 crates registered; only those on-ground and within radius count
-- (crate1 at x=500,z=600 is at center; crate2 at x=300,z=400 is outside 100m radius)
ctld_test.assertEqual(_flagsSet["77"], 1,            "cratesInZone: 1 crate in zone (crate1)")

-- Restore stubs
coalition.addStaticObject = _addStaticOrig
StaticObject.getByName    = _getStaticOrig
trigger.misc.getZone      = _getZoneOrig
land.getHeight            = _heightOrig
trigger.action.setUserFlag = _setFlagOrig

ctld_test.finish()
