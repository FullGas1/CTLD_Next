---@diagnostic disable
-- ============================================================
-- U-83 : CTLDCrateManager:spawnCrate / findDescriptorByUnitType
-- Module  : Q1 (src/CTLD_crate.lua)
-- ============================================================

do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")

local SRC = "C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/"
dofile(SRC .. "CTLD_core.lua")

-- ── DCS stubs ──────────────────────────────────────────────
-- spawnCrate uses ctld.utils.dynAddStatic which internally calls coalition.addStaticObject.
-- Mocking coalition.addStaticObject captures the final call from dynAddStatic.
local _spawnedStatics = {}   -- name → data (populated by coalition.addStaticObject mock)
local _addStaticOrig  = coalition.addStaticObject
coalition.addStaticObject = function(countryId, data)
    _spawnedStatics[data.name] = { countryId = countryId, data = data }
end

local _staticByName = {}
local _getStaticOrig = StaticObject.getByName
StaticObject.getByName = function(name)
    return _staticByName[name] or _spawnedStatics[name] and { _name = name } or nil
end

local _absTimeOrig = timer.getAbsTime
timer.getAbsTime = function() return 100 end

-- ── Load modules ───────────────────────────────────────────
dofile(SRC .. "lib/CTLD_objectRegistry.lua")
dofile(SRC .. "lib/CTLDParachuteEffect.lua")
dofile(SRC .. "CTLD_zone.lua")
dofile(SRC .. "CTLD_player.lua")
dofile(SRC .. "CTLD_menu.lua")

-- Reset singletons
CTLDDCSEventBridge._instance = nil
EventDispatcher._instance    = nil
CTLDZoneManager._instance    = nil
CTLDPlayerManager._instance  = nil
ctld.MenuManager._instance   = nil

dofile(SRC .. "CTLD_crate.lua")

-- Reset crate manager
local _cmInst = nil
-- Access via the module-local _cmInstance through getInstance
local cm = CTLDCrateManager.getInstance()

ctld_test.start("U-83", "CTLDCrateManager:spawnCrate / findDescriptorByUnitType")

-- ── findDescriptorByUnitType ───────────────────────────────
local d1 = cm:findDescriptorByUnitType("M-1 Abrams")
ctld_test.assertNotNil(d1,                          "findDescriptorByUnitType: M-1 Abrams found")
ctld_test.assertEqual(d1.cratesRequired, 4,         "findDescriptorByUnitType: cratesRequired=4")

local d2 = cm:findDescriptorByUnitType("M1043 HMMWV Armament")
ctld_test.assertNotNil(d2,                          "findDescriptorByUnitType: Humvee found")
ctld_test.assertEqual(d2.cratesRequired, nil,       "findDescriptorByUnitType: Humvee cratesRequired=nil (1 crate)")

local d_none = cm:findDescriptorByUnitType("NonExistentUnit")
ctld_test.assertNil(d_none,                         "findDescriptorByUnitType: unknown unit → nil")

local d_nil = cm:findDescriptorByUnitType(nil)
ctld_test.assertNil(d_nil,                          "findDescriptorByUnitType: nil → nil")

-- ── spawnCrate ─────────────────────────────────────────────
local eventsFired = {}
EventDispatcher.getInstance():subscribe("OnCrateSpawned", function(evt)
    table.insert(eventsFired, evt)
end)

local pos = { x = 100, y = 10, z = 200 }
local crate1 = cm:spawnCrate(d2, pos, coalition.side.BLUE, "pilot1", "crate_spawn")
ctld_test.assertNotNil(crate1,                      "spawnCrate: returns CTLDCrate")
ctld_test.assertNotNil(crate1.crateName,            "spawnCrate: crateName assigned")
ctld_test.assertEqual(crate1.coalition, coalition.side.BLUE, "spawnCrate: coalition=BLUE")
ctld_test.assertEqual(crate1.spawnedBy, "pilot1",  "spawnCrate: spawnedBy=pilot1")
ctld_test.assertEqual(crate1.spawnMethod, "crate_spawn", "spawnCrate: spawnMethod=crate_spawn")
ctld_test.assertEqual(crate1.position, pos,         "spawnCrate: position stored")

-- Static spawned with correct data
local spawnData = _spawnedStatics[crate1.crateName]
ctld_test.assertNotNil(spawnData,                   "spawnCrate: coalition.addStaticObject called")
ctld_test.assertEqual(spawnData.data.x, 100,        "spawnCrate: x=100")
ctld_test.assertEqual(spawnData.data.y, 200,        "spawnCrate: y(=z)=200")
ctld_test.assertEqual(spawnData.data.mass, d2.weight, "spawnCrate: mass=descriptor.weight")
ctld_test.assertEqual(spawnData.data.category, "Cargos", "spawnCrate: category=Cargos")

-- Crate registered in manager
ctld_test.assertNotNil(cm.crates[crate1.crateName], "spawnCrate: crate registered in manager")

-- OnCrateSpawned fired
ctld_test.assertEqual(#eventsFired, 1,              "spawnCrate: OnCrateSpawned fired once")
ctld_test.assertEqual(eventsFired[1].crateName, crate1.crateName,
    "spawnCrate: event.crateName matches")

-- modelKey "dynamic": canCargo=true
local crate2 = cm:spawnCrate(d2, { x=0, y=0, z=0 }, coalition.side.RED, nil, "vehicle_pack",
    country.id.RUSSIA, "dynamic")
ctld_test.assertNotNil(crate2,                      "spawnCrate dynamic model: returns crate")
local sd2 = _spawnedStatics[crate2.crateName]
ctld_test.assertEqual(sd2.data.canCargo, true,      "spawnCrate dynamic: canCargo=true")

-- Missing descriptor → nil
local bad = cm:spawnCrate(nil, pos, coalition.side.BLUE, nil, "crate_spawn")
ctld_test.assertNil(bad,                            "spawnCrate nil descriptor → nil")

-- Restore stubs
coalition.addStaticObject = _addStaticOrig
StaticObject.getByName    = _getStaticOrig
timer.getAbsTime          = _absTimeOrig

ctld_test.finish()
