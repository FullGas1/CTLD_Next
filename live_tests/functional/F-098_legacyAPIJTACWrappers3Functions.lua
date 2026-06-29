---@diagnostic disable
-- ============================================================
-- F-98 : Legacy API — JTAC wrappers (3 functions)
-- Module  : Q1 (src/legacy/legacy_api.lua → src/CTLD_jtac.lua)
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

CTLDJTACManager._instance = nil

-- ── Mock CTLDJTACManager ───────────────────────────────────
local _calls = {}
local _origGet = CTLDJTACManager.get
CTLDJTACManager.get = function()
    return {
        autoLase    = function(s,grp,code,smoke,lock,col,radio) table.insert(_calls, {"autoLase",grp,code,smoke,lock,col,radio}) end,
        startLase   = function(s,grp,code,smoke,lock,col,radio) table.insert(_calls, {"startLase",grp,code,smoke,lock,col,radio}) end,
        stopAutoLase= function(s,grp)                           table.insert(_calls, {"stopAutoLase",grp}) end,
    }
end

dofile(SRC .. "compat/legacy_api.lua")

ctld_test.start("F-98", "Legacy API — JTAC wrappers routing")

-- Track deprecation warnings
local _warnings = {}
local _origWarn = ctld.logWarning
ctld.logWarning = function(msg, ...) table.insert(_warnings, msg); _origWarn(msg, ...) end

-- JTACAutoLase
ctld.JTACAutoLase("JTAC1", 1688, true, "vehicle", "red", true)
ctld_test.assertEqual(_calls[#_calls][1], "autoLase",         "JTACAutoLase: routed to autoLase")
ctld_test.assertEqual(_calls[#_calls][2], "JTAC1",            "JTACAutoLase: groupName=JTAC1")
ctld_test.assertEqual(_calls[#_calls][3], 1688,               "JTACAutoLase: laserCode=1688")
ctld_test.assertEqual(_calls[#_calls][4], true,               "JTACAutoLase: smoke=true")
ctld_test.assert(string.find(_warnings[#_warnings], "JTACAutoLase") ~= nil,
    "JTACAutoLase: deprecation warning logged")

-- JTACStart
ctld.JTACStart("JTAC2", 1688, false, "armor", "green", false)
ctld_test.assertEqual(_calls[#_calls][1], "startLase",        "JTACStart: routed to startLase")
ctld_test.assertEqual(_calls[#_calls][2], "JTAC2",            "JTACStart: groupName=JTAC2")
ctld_test.assert(string.find(_warnings[#_warnings], "JTACStart") ~= nil,
    "JTACStart: deprecation warning logged")

-- JTACAutoLaseStop
ctld.JTACAutoLaseStop("JTAC3")
ctld_test.assertEqual(_calls[#_calls][1], "stopAutoLase",     "JTACAutoLaseStop: routed to stopAutoLase")
ctld_test.assertEqual(_calls[#_calls][2], "JTAC3",            "JTACAutoLaseStop: groupName=JTAC3")
ctld_test.assert(string.find(_warnings[#_warnings], "JTACAutoLaseStop") ~= nil,
    "JTACAutoLaseStop: deprecation warning logged")

-- Restore
ctld.logWarning = _origWarn
CTLDJTACManager.get = _origGet

ctld_test.finish()
