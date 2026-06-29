---@diagnostic disable
-- ============================================================
-- F-94 : Legacy API — Troops wrappers (6 functions)
-- Module  : Q1 (src/legacy/legacy_api.lua → src/CTLD_troop.lua)
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

-- Reset singletons
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

-- Reset troop manager
CTLDTroopManager._instance = nil

-- ── Mock CTLDTroopManager ──────────────────────────────────
local _calls = {}
local _realGetInstance = CTLDTroopManager.getInstance
CTLDTroopManager.getInstance = function()
    return {
        spawnGroupAtTrigger        = function(s,side,n,name,r)     table.insert(_calls, {"spawnGroupAtTrigger",side,n,name,r}) end,
        spawnGroupAtPoint          = function(s,side,n,pt,r)       table.insert(_calls, {"spawnGroupAtPoint",side,n,pt,r}) end,
        preLoadTransport           = function(s,u,n,t)             table.insert(_calls, {"preLoadTransport",u,n,t}) end,
        unloadTransport            = function(s,u)                  table.insert(_calls, {"unloadTransport",u}) end,
        loadTransport              = function(s,u)                  table.insert(_calls, {"loadTransport",u}) end,
        unloadInProximityToEnemy   = function(s,u,d)               table.insert(_calls, {"unloadInProximityToEnemy",u,d}); return true end,
    }
end

dofile(SRC .. "compat/legacy_api.lua")

ctld_test.start("F-94", "Legacy API — Troops wrappers routing + deprecation warning")

-- Track warnings
local _warnings = {}
local _origWarn = ctld.logWarning
ctld.logWarning = function(msg, ...)
    table.insert(_warnings, msg)
    _origWarn(msg, ...)
end

-- spawnGroupAtTrigger
ctld.spawnGroupAtTrigger(2, 5, "TZ1", 100)
ctld_test.assertEqual(_calls[#_calls][1], "spawnGroupAtTrigger", "spawnGroupAtTrigger: routed")
ctld_test.assertEqual(_calls[#_calls][2], 2,                     "spawnGroupAtTrigger: side=2")
ctld_test.assertEqual(_calls[#_calls][3], 5,                     "spawnGroupAtTrigger: number=5")
ctld_test.assertEqual(_calls[#_calls][4], "TZ1",                 "spawnGroupAtTrigger: triggerName=TZ1")
ctld_test.assert(string.find(_warnings[#_warnings], "spawnGroupAtTrigger") ~= nil,
    "spawnGroupAtTrigger: deprecation warning logged")

-- spawnGroupAtPoint
local pt = { x=100, y=0, z=200 }
ctld.spawnGroupAtPoint(1, 3, pt, 50)
ctld_test.assertEqual(_calls[#_calls][1], "spawnGroupAtPoint",   "spawnGroupAtPoint: routed")
ctld_test.assertEqual(_calls[#_calls][4], pt,                    "spawnGroupAtPoint: point passed")

-- preLoadTransport
ctld.preLoadTransport("heli1", 8, nil)
ctld_test.assertEqual(_calls[#_calls][1], "preLoadTransport",    "preLoadTransport: routed")
ctld_test.assertEqual(_calls[#_calls][2], "heli1",               "preLoadTransport: unitName=heli1")
ctld_test.assertEqual(_calls[#_calls][3], 8,                     "preLoadTransport: number=8")

-- unloadTransport
ctld.unloadTransport("heli2")
ctld_test.assertEqual(_calls[#_calls][1], "unloadTransport",     "unloadTransport: routed")
ctld_test.assertEqual(_calls[#_calls][2], "heli2",               "unloadTransport: unitName=heli2")

-- loadTransport
ctld.loadTransport("heli3")
ctld_test.assertEqual(_calls[#_calls][1], "loadTransport",       "loadTransport: routed")
ctld_test.assertEqual(_calls[#_calls][2], "heli3",               "loadTransport: unitName=heli3")

-- unloadInProximityToEnemy
local ret = ctld.unloadInProximityToEnemy("heli4", 300)
ctld_test.assertEqual(_calls[#_calls][1], "unloadInProximityToEnemy", "unloadInProximityToEnemy: routed")
ctld_test.assertEqual(_calls[#_calls][2], "heli4",               "unloadInProximityToEnemy: unitName=heli4")
ctld_test.assertEqual(_calls[#_calls][3], 300,                   "unloadInProximityToEnemy: distance=300")
ctld_test.assert(ret == true,                                     "unloadInProximityToEnemy: return value forwarded")

-- Restore
ctld.logWarning = _origWarn
CTLDTroopManager.getInstance = _realGetInstance

ctld_test.finish()
