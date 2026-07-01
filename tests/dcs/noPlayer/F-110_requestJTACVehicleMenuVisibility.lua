---@diagnostic disable
-- ============================================================
-- F-110 — Request JTAC Vehicle menu visibility
-- UH-1H BLUE only (no C-130/CH-47 required)
--
-- Verifies:
--   1. JTAC_unitTypeNames config is populated for coalition 2 (BLUE)
--   2. Settings exist: JTAC_droneRadius, JTAC_droneAltitude, JTAC_unitTypeNames
--   3. BLUE coalition has >= 1 requestable JTAC vehicle type
--   4. RED coalition has >= 1 requestable JTAC vehicle type (isolated per coalition)
--   5. Default BLUE types include "Hummer" (drones are in unitList, not JTAC_unitTypeNames)
--   6. Default RED  types include "SKP-11" (drones are in unitList, not JTAC_unitTypeNames)
--
-- Does NOT perform in-game menu injection (requires actual mission + player slot).
-- Verified visually in F-109a: menu appeared correctly in BLUE, absent in RED.
-- ============================================================

local LOG_PATH = "C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/"
local SRC      = "C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/"

-- Purge CTLD.log
local _f = io.open(LOG_PATH .. "CTLD.log", "w"); if _f then _f:close() end

dofile(LOG_PATH .. "setup.lua")
dofile(SRC .. "CTLD_menu.lua")
dofile(SRC .. "CTLD_zone.lua")
dofile(SRC .. "CTLD_jtac.lua")
dofile(SRC .. "CTLD_vehicle.lua")

ctld_test.start("F-110", "Request JTAC Vehicle — menu config visibility")

-- 1. JTAC_unitTypeNames exists in config
local typeNames = ctld.gs("JTAC_unitTypeNames")
ctld_test.assertNotNil(typeNames, "[1] JTAC_unitTypeNames defined in config")

-- 2. Other JTAC settings
ctld_test.assertNotNil(ctld.gs("JTAC_droneRadius"),   "[2a] JTAC_droneRadius defined")
ctld_test.assertNotNil(ctld.gs("JTAC_droneAltitude"), "[2b] JTAC_droneAltitude defined")

-- 3. BLUE coalition (2) has types
local blueTypes = typeNames and typeNames[2] or {}
ctld_test.assert(type(blueTypes) == "table" and #blueTypes >= 1,
    string.format("[3] BLUE has >= 1 JTAC vehicle type (found %d)", #blueTypes))

-- 4. RED coalition (1) has types
local redTypes = typeNames and typeNames[1] or {}
ctld_test.assert(type(redTypes) == "table" and #redTypes >= 1,
    string.format("[4] RED has >= 1 JTAC vehicle type (found %d)", #redTypes))

-- 5. Default BLUE types: Hummer (only default; drones are separate unitList entries)
local blueSet = {}
for _, t in ipairs(blueTypes) do blueSet[t] = true end
ctld_test.assert(blueSet["Hummer"], "[5] BLUE default: 'Hummer' present")

-- 6. Default RED types: SKP-11 (only default; drones are separate unitList entries)
local redSet = {}
for _, t in ipairs(redTypes) do redSet[t] = true end
ctld_test.assert(redSet["SKP-11"], "[6] RED default: 'SKP-11' present")

-- 7. Type names are strings (no nil entries)
local allStrings = true
for _, t in ipairs(blueTypes) do
    if type(t) ~= "string" then allStrings = false end
end
ctld_test.assert(allStrings, "[7] BLUE type names are all strings")

ctld_test.finish()
