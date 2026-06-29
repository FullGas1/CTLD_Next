---@diagnostic disable
-- ============================================================
-- F-97 : Legacy API — Beacon wrapper (createRadioBeaconAtZone)
-- Module  : Q1 (src/legacy/legacy_api.lua → src/CTLD_beacon.lua)
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

CTLDBeaconManager._instance = nil

-- ── Mock CTLDBeaconManager ─────────────────────────────────
local _calls = {}
local _origBM = CTLDBeaconManager.getInstance
CTLDBeaconManager.getInstance = function()
    return {
        createAtZone = function(s, zone, coa, battery, name)
            table.insert(_calls, { zone=zone, coa=coa, battery=battery, name=name })
        end
    }
end

dofile(SRC .. "compat/legacy_api.lua")

ctld_test.start("F-97", "Legacy API — createRadioBeaconAtZone routing")

-- Track deprecation warning
local _warned = false
local _origWarn = ctld.logWarning
ctld.logWarning = function(msg, ...)
    if string.find(msg, "createRadioBeaconAtZone") then _warned = true end
    _origWarn(msg, ...)
end

ctld.createRadioBeaconAtZone("BZ1", "blue", 3600, "Alpha Beacon")

ctld_test.assert(_warned,                            "createRadioBeaconAtZone: deprecation warning logged")
ctld_test.assertEqual(#_calls, 1,                   "createRadioBeaconAtZone: createAtZone called once")
ctld_test.assertEqual(_calls[1].zone, "BZ1",        "createRadioBeaconAtZone: zone=BZ1")
ctld_test.assertEqual(_calls[1].coa, "blue",        "createRadioBeaconAtZone: coalition=blue")
ctld_test.assertEqual(_calls[1].battery, 3600,      "createRadioBeaconAtZone: batteryLife=3600")
ctld_test.assertEqual(_calls[1].name, "Alpha Beacon", "createRadioBeaconAtZone: name=Alpha Beacon")

-- Restore
ctld.logWarning = _origWarn
CTLDBeaconManager.getInstance = _origBM

ctld_test.finish()
