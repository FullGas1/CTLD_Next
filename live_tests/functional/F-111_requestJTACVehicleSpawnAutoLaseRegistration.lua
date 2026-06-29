---@diagnostic disable
-- ============================================================
-- F-111 — Request JTAC Vehicle: spawn + auto-lase registration
-- UH-1H BLUE only (no C-130/CH-47 required)
--
-- Automated (sandbox) asserts:
--   1. "Hummer" in JTAC_unitTypeNames[2] (config)
--   2. spawnJTACVehicleForTransport: no Lua error
--   3. vehicle.spawnData.groupName is set
--   4. deregisterJTAC(groupName): no error even when jtacs entry absent
--   5. registerJTACVehicle: vehicle present in _vehicles
--
-- Note: startLase is async (timer.scheduleFunction +1s). The JTAC entry in
-- jmgr.jtacs[groupName] is only populated once autoLase fires in a real DCS mission.
-- Confirmed live: PASS visual (F-109b, 2026-04-27) — Hummer spawned, F10 JTAC menu active.
-- ============================================================

local LOG_PATH = "C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/"
local SRC      = "C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/"

-- Purge CTLD.log
local _f = io.open(LOG_PATH .. "CTLD.log", "w"); if _f then _f:close() end

dofile(LOG_PATH .. "setup.lua")
dofile(SRC .. "CTLD_menu.lua")
dofile(SRC .. "CTLD_zone.lua")
dofile(SRC .. "CTLD_crate.lua")
dofile(SRC .. "CTLD_troop.lua")
dofile(SRC .. "CTLD_jtac.lua")
dofile(SRC .. "CTLD_vehicle.lua")

ctld_test.start("F-111", "Request JTAC Vehicle — spawn + auto-lase registration")
ctld_test.cleanup()

local transport = ctld_test.getTransport()
if not transport then ctld_test.finish() return end

local jmgr   = CTLDJTACManager.getInstance()
local vspawn = CTLDVehicleSpawner.getInstance()

-- Mock logistic zone (coalition + point only needed by spawnVehicleForTransport)
local mockZone = { coalition = transport:getCoalition(), point = transport:getPoint() }

local VEHICLE_TYPE = "Hummer"

-- 1. Config lists Hummer for BLUE
local blueTypes = (ctld.gs("JTAC_unitTypeNames") or {})[2] or {}
local hummerInConfig = false
for _, t in ipairs(blueTypes) do if t == VEHICLE_TYPE then hummerInConfig = true end end
ctld_test.assert(hummerInConfig, "[1] 'Hummer' in JTAC_unitTypeNames[2] (BLUE)")

-- 2. spawnJTACVehicleForTransport returns without Lua error
local ok, vehicle = pcall(function()
    return vspawn:spawnJTACVehicleForTransport(VEHICLE_TYPE, transport, mockZone)
end)
ctld_test.assert(ok, "[2] spawnJTACVehicleForTransport: no Lua error")

if not (ok and vehicle) then
    ctld_test.assert(false, "[3] SKIP — vehicle nil (DCS spawn requires live env)")
    ctld_test.assert(false, "[4] SKIP — vehicle nil")
    ctld_test.assert(false, "[5] SKIP — vehicle nil")
    ctld_test.finish()
    return
end

-- 3. spawnData.groupName set
local gname = vehicle.spawnData and vehicle.spawnData.groupName
ctld_test.assertNotNil(gname, "[3] vehicle.spawnData.groupName is set")

-- NOTE: [4] jmgr.jtacs[gname] is populated async via startLase → timer +1s → autoLase.
-- In sandbox timer callbacks never fire → entry stays nil. Confirmed live: F-109b PASS visual.

-- 4. deregisterJTAC is a no-op (and safe) when entry is absent (sandbox path)
local deregOk = pcall(function() jmgr:deregisterJTAC(gname) end)
ctld_test.assert(deregOk, "[4] deregisterJTAC: no error even when jtacs entry absent (sandbox)")
ctld_test.assertNil(jmgr.jtacs[gname], "[4b] jtacs[groupName] nil after deregister")

-- 5. registerJTACVehicle: vehicle present in _vehicles
vspawn:registerJTACVehicle(gname, VEHICLE_TYPE, nil, nil)
local found = false
for _, v in pairs(vspawn._vehicles) do
    if v.spawnData and v.spawnData.groupName == gname then found = true end
end
ctld_test.assert(found, "[5] registerJTACVehicle: entry present in _vehicles")

ctld_test.finish()
