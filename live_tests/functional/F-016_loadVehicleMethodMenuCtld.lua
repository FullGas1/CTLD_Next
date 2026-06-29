---@diagnostic disable
-- ============================================================
-- F-16 : loadVehicle method=menu_ctld
-- Module  : M5 (src/CTLD_vehicle.lua)
-- Objectif: Vérifier que loadVehicle(method="menu_ctld") :
--   1. Ne crash pas
--   2. Passe le vehicle en état LOADED
--   3. Détruit l'unité DCS (vehicle.unit == nil)
--   4. Publie OnVehicleLoaded avec le bon payload
--   5. Met à jour loadMethod et loadTransportName
-- Précondition : un transport BLUE doit être présent dans la mission.
-- ============================================================

-- Purge CTLD.log
do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")
ctld_test.cleanup()

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_core.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_vehicle.lua")

ctld_test.start("F-16", "loadVehicle method=menu_ctld → OnVehicleLoaded")

CTLDVehicleSpawner._instance = nil
EventDispatcher._instance    = nil
CTLDDCSEventBridge._instance = nil

CTLDVehicleSpawner.getInstance()
local vs = CTLDVehicleSpawner._instance

local transport = ctld_test.getTransport()
if not transport then ctld_test.finish() return end

-- Spawn d'abord un vehicle
local vehicleType = "M1045 HMMWV TOW"
local vehicle = vs:spawnVehicleForTransport(vehicleType, transport, nil)

ctld_test.assertNotNil(vehicle, "spawnVehicleForTransport OK avant loadVehicle")
if not vehicle then ctld_test.finish() return end

ctld_test.assertEqual(vehicle:getState(), CTLDVehicle.STATE.WAITING,
    "vehicle en WAITING avant load")

-- Capturer OnVehicleLoaded
local loadedPayload = nil
EventDispatcher.getInstance():subscribe("OnVehicleLoaded", function(p)
    loadedPayload = p
end)

-- Exécuter loadVehicle method=menu_ctld
local okLoad = pcall(function()
    vs:loadVehicle(vehicle, transport, "TestPlayer", "menu_ctld")
end)

ctld_test.assert(okLoad, "loadVehicle ne crash pas")
ctld_test.assertEqual(vehicle:getState(), CTLDVehicle.STATE.LOADED,
    "vehicle en état LOADED après load")
ctld_test.assertNil(vehicle.unit, "vehicle.unit == nil (unité détruite)")
ctld_test.assertEqual(vehicle.loadMethod, "menu_ctld",
    "loadMethod == 'menu_ctld'")
ctld_test.assertEqual(vehicle.loadTransportName, transport:getName(),
    "loadTransportName == transport name")
ctld_test.assertNotNil(vehicle.loadTime, "loadTime non-nil")

-- Vérification event OnVehicleLoaded
ctld_test.assertNotNil(loadedPayload, "OnVehicleLoaded publié")

if loadedPayload then
    ctld_test.assertEqual(loadedPayload.vehicleId, vehicle.id,
        "payload.vehicleId correct")
    ctld_test.assertEqual(loadedPayload.vehicleType, vehicleType,
        "payload.vehicleType correct")
    ctld_test.assertNotNil(loadedPayload.transportUnitObject, "payload.transportUnitObject non-nil")
    ctld_test.assertEqual(loadedPayload.method, "menu_ctld",
        "payload.method == 'menu_ctld'")
    ctld_test.assertEqual(loadedPayload.player, "TestPlayer",
        "payload.player correct")
    ctld_test.assertNotNil(loadedPayload.position, "payload.position non-nil")
    ctld_test.assertNotNil(loadedPayload.timestamp, "payload.timestamp non-nil")
end

-- Tentative de double-load doit être ignorée (vehicle plus en WAITING)
local okDoubleLoad = pcall(function()
    vs:loadVehicle(vehicle, transport, nil, "menu_ctld")
end)
ctld_test.assert(okDoubleLoad, "double loadVehicle ne crash pas (ignored silently)")
ctld_test.assertEqual(vehicle:getState(), CTLDVehicle.STATE.LOADED,
    "état reste LOADED après double-load ignoré")

ctld_test.finish()
