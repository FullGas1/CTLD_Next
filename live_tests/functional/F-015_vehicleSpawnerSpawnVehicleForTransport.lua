---@diagnostic disable
-- ============================================================
-- F-15 : CTLDVehicleSpawner.spawnVehicleForTransport
-- Module  : M5 (src/CTLD_vehicle.lua)
-- Objectif: Vérifier que spawnVehicleForTransport :
--   1. Ne crash pas
--   2. Retourne un CTLDVehicle en état WAITING
--   3. Publie OnVehicleSpawnedForTransport avec payload correct
--   4. Enregistre le vehicle dans _vehicles et _unitToVehicle
--
-- DEPENDENCY mission martyr :
--   - Transport BLUE au sol (UH-1H "uh1-1" ou similaire)
--   - Au moins un slot BLUE connecté
-- ============================================================

-- Purge CTLD.log
do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")
ctld_test.cleanup()

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_core.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_vehicle.lua")

ctld_test.start("F-15", "CTLDVehicleSpawner.spawnVehicleForTransport → OnVehicleSpawnedForTransport")

CTLDVehicleSpawner._instance = nil
EventDispatcher._instance    = nil
CTLDDCSEventBridge._instance = nil

local ok = pcall(function() CTLDVehicleSpawner.getInstance() end)
ctld_test.assert(ok, "CTLDVehicleSpawner init OK")
local vs = CTLDVehicleSpawner._instance

local transport = ctld_test.getTransport()
if not transport then ctld_test.finish() return end

-- Capturer OnVehicleSpawnedForTransport
local spawnedPayload = nil
EventDispatcher.getInstance():subscribe("OnVehicleSpawnedForTransport", function(p)
    spawnedPayload = p
end)

-- Exécuter spawn
local vehicleType = "M1045 HMMWV TOW"
local vehicle = nil
local okSpawn = pcall(function()
    vehicle = vs:spawnVehicleForTransport(vehicleType, transport, nil)
end)

ctld_test.assert(okSpawn, "spawnVehicleForTransport ne crash pas")
ctld_test.assertNotNil(vehicle, "spawnVehicleForTransport retourne un CTLDVehicle")

if vehicle then
    ctld_test.assertEqual(vehicle:getState(), CTLDVehicle.STATE.WAITING,
        "vehicle état == WAITING")
    ctld_test.assertEqual(vehicle.vehicleType, vehicleType,
        "vehicle.vehicleType correct")
    ctld_test.assertNotNil(vehicle.spawnData, "vehicle.spawnData non-nil")

    if vehicle.spawnData then
        ctld_test.assertNotNil(vehicle.spawnData.groupName, "spawnData.groupName non-nil")
        ctld_test.assertNotNil(vehicle.spawnData.unitName,  "spawnData.unitName non-nil")
        ctld_test.assertEqual(vehicle.spawnData.groupName, vehicle.spawnData.unitName,
            "groupName == unitName")
    end

    -- Vérifie enregistrement dans _vehicles
    ctld_test.assertNotNil(vs._vehicles[vehicle.id],
        "vehicle enregistré dans _vehicles")

    -- Vérifie enregistrement dans _unitToVehicle (si unit spawné)
    if vehicle.unit then
        local unitName = vehicle.unit:getName()
        ctld_test.assertNotNil(vs._unitToVehicle[unitName],
            "unit enregistré dans _unitToVehicle")
        ctld_test.assertEqual(vs._unitToVehicle[unitName], vehicle.id,
            "_unitToVehicle[unitName] == vehicle.id")
    else
        ctld_test.assert(true,
            "INFO: unit non spawné en test (dynAdd retourne nil sans vraie DCS mission)")
    end
end

-- OnVehicleSpawnedForTransport publié
ctld_test.assertNotNil(spawnedPayload, "OnVehicleSpawnedForTransport publié")

if spawnedPayload then
    ctld_test.assertNotNil(spawnedPayload.vehicleId,   "payload.vehicleId non-nil")
    ctld_test.assertNotNil(spawnedPayload.vehicleType, "payload.vehicleType non-nil")
    ctld_test.assertEqual(spawnedPayload.vehicleType, vehicleType,
        "payload.vehicleType correct")
    ctld_test.assertNotNil(spawnedPayload.spawner,   "payload.spawner non-nil")
    ctld_test.assertNotNil(spawnedPayload.position,  "payload.position non-nil")
    ctld_test.assertEqual(spawnedPayload.spawnMethod, "request_vehicle",
        "payload.spawnMethod == 'request_vehicle'")
end

ctld_test.finish()
