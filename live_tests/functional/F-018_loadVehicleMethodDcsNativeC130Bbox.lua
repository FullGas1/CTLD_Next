---@diagnostic disable
-- ============================================================
-- F-18 : loadVehicle method=dcs_native (C-130 bbox)
-- Module  : M5 (src/CTLD_vehicle.lua)
-- Objectif: Vérifier que loadVehicle(method="dcs_native") :
--   1. Ne crash pas
--   2. Passe le vehicle en état LOADED
--   3. Publie OnVehicleLoaded avec method="dcs_native"
--   4. Enregistre loadTransportName
-- Note: Ce test appelle loadVehicle directement avec method="dcs_native"
--       pour valider le comportement sans C-130 réel dans la mission.
--       La détection bbox (_checkNativeLoading) est couverte par U-21.
-- Précondition : un transport BLUE doit être présent dans la mission.
-- ============================================================

-- Purge CTLD.log
do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")
ctld_test.cleanup()

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_core.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_vehicle.lua")

ctld_test.start("F-18", "loadVehicle method=dcs_native → OnVehicleLoaded")

CTLDVehicleSpawner._instance = nil
EventDispatcher._instance    = nil
CTLDDCSEventBridge._instance = nil

CTLDVehicleSpawner.getInstance()
local vs = CTLDVehicleSpawner._instance

-- Représente le C-130 dans ce test
local transport = ctld_test.getTransport()
if not transport then ctld_test.finish() return end

local vehicleType = "M1045 HMMWV TOW"

-- Spawn vehicle
local vehicle = vs:spawnVehicleForTransport(vehicleType, transport, nil)
ctld_test.assertNotNil(vehicle, "spawnVehicleForTransport OK")
if not vehicle then ctld_test.finish() return end

ctld_test.assertEqual(vehicle:getState(), CTLDVehicle.STATE.WAITING,
    "vehicle en WAITING avant dcs_native load")

-- Capturer OnVehicleLoaded
local loadedPayload = nil
EventDispatcher.getInstance():subscribe("OnVehicleLoaded", function(p)
    loadedPayload = p
end)

-- Simuler détection bbox : appel direct loadVehicle avec method=dcs_native
local okLoad = pcall(function()
    vs:loadVehicle(vehicle, transport, nil, "dcs_native")
end)

ctld_test.assert(okLoad, "loadVehicle dcs_native ne crash pas")
ctld_test.assertEqual(vehicle:getState(), CTLDVehicle.STATE.LOADED,
    "vehicle en LOADED après dcs_native load")
ctld_test.assertNil(vehicle.unit,
    "vehicle.unit == nil après dcs_native load")
ctld_test.assertEqual(vehicle.loadMethod, "dcs_native",
    "loadMethod == 'dcs_native'")
ctld_test.assertNotNil(vehicle.loadTransportName,
    "loadTransportName enregistré")

-- Event OnVehicleLoaded
ctld_test.assertNotNil(loadedPayload, "OnVehicleLoaded publié")

if loadedPayload then
    ctld_test.assertEqual(loadedPayload.vehicleId, vehicle.id,
        "payload.vehicleId correct")
    ctld_test.assertEqual(loadedPayload.method, "dcs_native",
        "payload.method == 'dcs_native'")
    ctld_test.assertNotNil(loadedPayload.transportUnitObject, "payload.transportUnitObject non-nil")
    ctld_test.assertNotNil(loadedPayload.position,  "payload.position non-nil")
    ctld_test.assertNotNil(loadedPayload.timestamp, "payload.timestamp non-nil")
end

ctld_test.finish()
