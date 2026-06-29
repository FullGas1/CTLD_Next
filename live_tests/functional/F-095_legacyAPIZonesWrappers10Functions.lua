---@diagnostic disable
-- ============================================================
-- F-95 : Legacy API — Zones wrappers (10 functions)
-- Module  : Q1 (src/legacy/legacy_api.lua → src/CTLD_zone.lua)
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

CTLDTroopManager._instance = nil

-- ── Mock CTLDZoneManager ───────────────────────────────────
local _calls = {}
local _origZM = CTLDZoneManager.getInstance
CTLDZoneManager.getInstance = function()
    return {
        setTroopZoneActive      = function(s,n,a)    table.insert(_calls, {"setTroopZoneActive",n,a}) end,
        changeRemainingGroups   = function(s,n,amt)  table.insert(_calls, {"changeRemainingGroups",n,amt}) end,
        activateWaypointZone    = function(s,n)      table.insert(_calls, {"activateWaypointZone",n}) end,
        deactivateWaypointZone  = function(s,n)      table.insert(_calls, {"deactivateWaypointZone",n}) end,
        createExtractZone       = function(s,z,f,sm) table.insert(_calls, {"createExtractZone",z,f,sm}) end,
        removeExtractZone       = function(s,z,f)    table.insert(_calls, {"removeExtractZone",z,f}) end,
    }
end

-- ── Mock CTLDTroopManager (for count watchers) ────────────
local _tCalls = {}
local _origTM = CTLDTroopManager.getInstance
CTLDTroopManager.getInstance = function()
    return {
        startGroupCountWatcher  = function(s,z,b,r)  table.insert(_tCalls, {"startGroupCountWatcher",z,b,r}) end,
        startUnitCountWatcher   = function(s,z,b,r)  table.insert(_tCalls, {"startUnitCountWatcher",z,b,r}) end,
    }
end

dofile(SRC .. "compat/legacy_api.lua")

ctld_test.start("F-95", "Legacy API — Zones wrappers routing")

-- activatePickupZone
ctld.activatePickupZone("PZ1")
ctld_test.assertEqual(_calls[#_calls][1], "setTroopZoneActive",  "activatePickupZone: routed to setTroopZoneActive")
ctld_test.assertEqual(_calls[#_calls][2], "PZ1",                 "activatePickupZone: zoneName=PZ1")
ctld_test.assertEqual(_calls[#_calls][3], true,                  "activatePickupZone: active=true")

-- deactivatePickupZone
ctld.deactivatePickupZone("PZ2")
ctld_test.assertEqual(_calls[#_calls][3], false,                 "deactivatePickupZone: active=false")

-- changeRemainingGroupsForPickupZone
ctld.changeRemainingGroupsForPickupZone("PZ3", 5)
ctld_test.assertEqual(_calls[#_calls][1], "changeRemainingGroups", "changeRemainingGroupsForPickupZone: routed")
ctld_test.assertEqual(_calls[#_calls][2], "PZ3",                   "changeRemainingGroupsForPickupZone: zone=PZ3")
ctld_test.assertEqual(_calls[#_calls][3], 5,                       "changeRemainingGroupsForPickupZone: amount=5")

-- activateWaypointZone
ctld.activateWaypointZone("WZ1")
ctld_test.assertEqual(_calls[#_calls][1], "activateWaypointZone",  "activateWaypointZone: routed")
ctld_test.assertEqual(_calls[#_calls][2], "WZ1",                   "activateWaypointZone: zone=WZ1")

-- deactivateWaypointZone
ctld.deactivateWaypointZone("WZ2")
ctld_test.assertEqual(_calls[#_calls][1], "deactivateWaypointZone", "deactivateWaypointZone: routed")
ctld_test.assertEqual(_calls[#_calls][2], "WZ2",                    "deactivateWaypointZone: zone=WZ2")

-- createExtractZone
ctld.createExtractZone("EZ1", 42, -1)
ctld_test.assertEqual(_calls[#_calls][1], "createExtractZone",     "createExtractZone: routed")
ctld_test.assertEqual(_calls[#_calls][2], "EZ1",                   "createExtractZone: zone=EZ1")
ctld_test.assertEqual(_calls[#_calls][3], 42,                      "createExtractZone: flag=42")

-- removeExtractZone
ctld.removeExtractZone("EZ1", 42)
ctld_test.assertEqual(_calls[#_calls][1], "removeExtractZone",     "removeExtractZone: routed")
ctld_test.assertEqual(_calls[#_calls][2], "EZ1",                   "removeExtractZone: zone=EZ1")
ctld_test.assertEqual(_calls[#_calls][3], 42,                      "removeExtractZone: flag=42")

-- countDroppedGroupsInZone
ctld.countDroppedGroupsInZone("DZ1", 10, 11)
ctld_test.assertEqual(_tCalls[#_tCalls][1], "startGroupCountWatcher", "countDroppedGroupsInZone: routed")
ctld_test.assertEqual(_tCalls[#_tCalls][2], "DZ1",                    "countDroppedGroupsInZone: zone=DZ1")
ctld_test.assertEqual(_tCalls[#_tCalls][3], 10,                       "countDroppedGroupsInZone: blueFlag=10")
ctld_test.assertEqual(_tCalls[#_tCalls][4], 11,                       "countDroppedGroupsInZone: redFlag=11")

-- countDroppedUnitsInZone
ctld.countDroppedUnitsInZone("DZ2", 20, 21)
ctld_test.assertEqual(_tCalls[#_tCalls][1], "startUnitCountWatcher",  "countDroppedUnitsInZone: routed")
ctld_test.assertEqual(_tCalls[#_tCalls][2], "DZ2",                    "countDroppedUnitsInZone: zone=DZ2")

-- Restore
CTLDZoneManager.getInstance  = _origZM
CTLDTroopManager.getInstance = _origTM

ctld_test.finish()
