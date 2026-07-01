---@diagnostic disable
-- ============================================================
-- F-99 : Pack Vehicle — findPackableVehicles + packVehicle flow
-- Module  : Q1 (src/CTLD_vehicle.lua + src/CTLD_crate.lua)
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

CTLDVehicleSpawner._instance = nil

-- ── DCS stubs ──────────────────────────────────────────────
local _spawnedStatics = {}
local _addStaticOrig  = coalition.addStaticObject
coalition.addStaticObject = function(cId, data)
    _spawnedStatics[data.name] = { cId = cId, data = data }
end
local _getStaticOrig = StaticObject.getByName
StaticObject.getByName = function(name) return _spawnedStatics[name] and { _name = name } or nil end
local _heightOrig = land.getHeight
land.getHeight = function(p) return 0 end

-- Mock transport unit (helicopter, NOT dynamic cargo)
local _transport = {
    _name     = "Heli1",
    _coa      = coalition.side.BLUE,
    _country  = country.id.USA,
    _typeName = "UH-1H",
    _point    = { x=0, y=5, z=0 },
    _desc     = { box = { min={x=-5,y=-2,z=-5}, max={x=5,y=3,z=5} } },
    isExist    = function() return true end,
    getName    = function(s) return s._name end,
    getCoalition = function(s) return s._coa end,
    getCountry   = function(s) return s._country end,
    getTypeName  = function(s) return s._typeName end,
    getPoint     = function(s) return s._point end,
    getVelocity  = function(s) return { x=0, y=0, z=0 } end,
    getDesc      = function(s) return s._desc end,
    -- north-facing orientation (heading = 0 rad)
    getPosition  = function(s) return { x={x=1,y=0,z=0}, y={x=0,y=1,z=0}, p=s._point } end,
}

-- Mock packable vehicle (Humvee-MG: 1 crate required)
local _vehicleDestroyed = false
local _vehicle = {
    _name     = "HumveeMG1",
    _typeName = "M1043 HMMWV Armament",
    _point    = { x=50, y=0, z=50 },
    isExist    = function() return not _vehicleDestroyed end,
    getName    = function(s) return s._name end,
    getTypeName= function(s) return s._typeName end,
    getPoint   = function(s) return s._point end,
    destroy    = function(s) _vehicleDestroyed = true end,
}

-- Mock Unit.getByName
local _unitByNameOrig = Unit.getByName
Unit.getByName = function(name)
    if name == "Heli1"      then return _transport end
    if name == "HumveeMG1"  then return _vehicle   end
    return nil
end

-- Mock coalition.getGroups for ground units
local _getGroupsOrig = coalition.getGroups
coalition.getGroups = function(coa, cat)
    if coa == coalition.side.BLUE and cat == Group.Category.GROUND then
        return {
            { getUnits = function() return { _vehicle } end }
        }
    end
    return {}
end

-- Mock timer.scheduleFunction (used by CTLDVehicleSpawner:init timers)
local _schedOrig = timer.scheduleFunction
timer.scheduleFunction = function(fn, arg, t) end  -- suppress for tests

-- Mock CTLDPlayerManager BEFORE getInstance() to satisfy init:registerMenuSection
local _refreshed = {}
local _origPM = CTLDPlayerManager.getInstance
CTLDPlayerManager.getInstance = function()
    return {
        _players = {},
        registerMenuSection = function() end,
        refreshForUnit = function(s, n) table.insert(_refreshed, n) end,
    }
end

-- Events
local _events = {}
EventDispatcher.getInstance():subscribe("OnVehiclePacked", function(e)
    table.insert(_events, e)
end)
EventDispatcher.getInstance():subscribe("OnCrateSpawned", function(e)
    table.insert(_events, { _type="OnCrateSpawned", crateName=e.crateName })
end)

local vs = CTLDVehicleSpawner.getInstance()

ctld_test.start("F-99", "Pack Vehicle — findPackableVehicles + packVehicle flow")

-- ── findPackableVehicles ──────────────────────────────────
local packable = vs:findPackableVehicles(_transport)
ctld_test.assertEqual(#packable, 1,                          "findPackableVehicles: 1 vehicle found")
ctld_test.assertEqual(packable[1].unitName, "HumveeMG1",    "findPackableVehicles: correct unitName")
ctld_test.assertNotNil(packable[1].descriptor,               "findPackableVehicles: descriptor attached")
ctld_test.assertEqual(packable[1].descriptor.unit, "M1043 HMMWV Armament",
    "findPackableVehicles: correct descriptor unit type")

-- Vehicle outside radius should not appear
local _farVehicle = {
    _point = { x=5000, y=0, z=5000 },
    _typeName = "M1043 HMMWV Armament",
    isExist = function() return true end,
    getName = function(s) return "FarHumvee" end,
    getTypeName = function(s) return s._typeName end,
    getPoint = function(s) return s._point end,
}
local _origGetGroups = coalition.getGroups
coalition.getGroups = function(coa, cat)
    if coa == coalition.side.BLUE and cat == Group.Category.GROUND then
        return {{ getUnits = function() return { _farVehicle } end }}
    end
    return {}
end
local packable2 = vs:findPackableVehicles(_transport)
ctld_test.assertEqual(#packable2, 0,                         "findPackableVehicles: vehicle outside radius not found")

-- Restore nearby vehicle
coalition.getGroups = function(coa, cat)
    if coa == coalition.side.BLUE and cat == Group.Category.GROUND then
        return {{ getUnits = function() return { _vehicle } end }}
    end
    return {}
end

-- ── packVehicle ───────────────────────────────────────────
local _msgs = {}
local _outTextOrig = trigger.action.outTextForGroup
trigger.action.outTextForGroup = function(gid, msg, dur) table.insert(_msgs, msg) end

local playerObj = { unitName="Heli1", groupId=1, coalition=coalition.side.BLUE }
vs:packVehicle("Heli1", "HumveeMG1", playerObj)

ctld_test.assert(_vehicleDestroyed,                          "packVehicle: vehicle unit destroyed")

-- 1 crate spawned (Humvee-MG: cratesRequired=nil → 1 crate)
local crateSpawnEvents = {}
for _, e in ipairs(_events) do
    if e._type == "OnCrateSpawned" then table.insert(crateSpawnEvents, e) end
end
ctld_test.assertEqual(#crateSpawnEvents, 1,                  "packVehicle: 1 crate spawned (no cratesRequired)")
local _staticCount = 0; for _ in pairs(_spawnedStatics) do _staticCount = _staticCount + 1 end
ctld_test.assertEqual(_staticCount, 1,                       "packVehicle: coalition.addStaticObject called once")

-- OnVehiclePacked fired
local packEvents = {}
for _, e in ipairs(_events) do
    if e.vehicleType then table.insert(packEvents, e) end
end
ctld_test.assertEqual(#packEvents, 1,                        "packVehicle: OnVehiclePacked published")
ctld_test.assertEqual(packEvents[1].vehicleType, "M1043 HMMWV Armament",
    "packVehicle: event.vehicleType correct")
ctld_test.assertEqual(packEvents[1].cratesSpawned, 1,        "packVehicle: event.cratesSpawned=1")

-- Player notified
ctld_test.assertEqual(#_msgs, 1,                             "packVehicle: outTextForGroup called")
ctld_test.assert(string.find(_msgs[1], "Humvee") ~= nil or string.find(_msgs[1], "crate") ~= nil,
    "packVehicle: message contains vehicle info")

-- Menu refreshed
ctld_test.assertEqual(#_refreshed, 1,                        "packVehicle: refreshForUnit called")
ctld_test.assertEqual(_refreshed[1], "Heli1",                "packVehicle: refresh for transport unit")

-- Vehicle no longer exists → guard
_vehicleDestroyed = false  -- reset flag but vehicle mock returns false on isExist
local _vehicle2 = {
    isExist = function() return false end,
    getName = function(s) return "Ghost" end,
    getTypeName = function(s) return "M-1 Abrams" end,
    getPoint = function(s) return { x=0,y=0,z=0 } end,
    destroy = function(s) end,
}
Unit.getByName = function(name)
    if name == "Heli1"  then return _transport end
    if name == "Ghost"  then return _vehicle2  end
    return nil
end
vs:packVehicle("Heli1", "Ghost", playerObj)
ctld_test.assert(not _vehicleDestroyed,                      "packVehicle: guard — dead vehicle not destroyed again")

-- Restore stubs
coalition.addStaticObject    = _addStaticOrig
StaticObject.getByName       = _getStaticOrig
land.getHeight               = _heightOrig
Unit.getByName               = _unitByNameOrig
coalition.getGroups          = _getGroupsOrig
timer.scheduleFunction       = _schedOrig
CTLDPlayerManager.getInstance= _origPM
trigger.action.outTextForGroup = _outTextOrig

ctld_test.finish()
