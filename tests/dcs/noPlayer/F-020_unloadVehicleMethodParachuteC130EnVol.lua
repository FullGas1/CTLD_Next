---@diagnostic disable
-- ============================================================
-- F-20 : unloadVehicle method=parachute (C-130 en vol)
-- Module  : M5 (src/CTLD_vehicle.lua)
-- Objectif: Vérifier que unloadVehicle(method="parachute") :
--   1. Ne crash pas
--   2. Passe le vehicle en état DELIVERED
--   3. Publie OnVehicleUnloaded avec method="parachute"
-- Ce test simule la sortie de bbox en vol (airdrop) en appelant
-- unloadVehicle directement avec method="parachute".
-- Précondition : un transport BLUE doit être présent dans la mission.
-- ============================================================

-- Purge CTLD.log
do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")
ctld_test.cleanup()

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_core.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_vehicle.lua")

ctld_test.start("F-20", "unloadVehicle method=parachute (en vol) → OnVehicleUnloaded")

CTLDVehicleSpawner._instance = nil
EventDispatcher._instance    = nil
CTLDDCSEventBridge._instance = nil

CTLDVehicleSpawner.getInstance()
local vs = CTLDVehicleSpawner._instance

local transport = ctld_test.getTransport()
if not transport then ctld_test.finish() return end

local vehicleType = "M1045 HMMWV TOW"

-- Setup : spawn + load dcs_native (in-flight bbox detection)
local vehicle = vs:spawnVehicleForTransport(vehicleType, transport, nil)
ctld_test.assertNotNil(vehicle, "spawnVehicleForTransport OK")
if not vehicle then ctld_test.finish() return end

vs:loadVehicle(vehicle, transport, nil, "dcs_native")
ctld_test.assertEqual(vehicle:getState(), CTLDVehicle.STATE.LOADED,
    "vehicle en LOADED avant parachute unload")

-- Capturer OnVehicleUnloaded
local unloadedPayload = nil
EventDispatcher.getInstance():subscribe("OnVehicleUnloaded", function(p)
    unloadedPayload = p
end)

-- Simuler éjection en vol : appel direct unloadVehicle avec method="parachute"
local okUnload = pcall(function()
    vs:unloadVehicle(vehicle, transport, nil, "parachute")
end)

ctld_test.assert(okUnload, "unloadVehicle parachute ne crash pas")
ctld_test.assertEqual(vehicle:getState(), CTLDVehicle.STATE.DELIVERED,
    "vehicle en DELIVERED après parachute unload")

-- Event OnVehicleUnloaded
ctld_test.assertNotNil(unloadedPayload, "OnVehicleUnloaded publié")

if unloadedPayload then
    ctld_test.assertEqual(unloadedPayload.vehicleId, vehicle.id,
        "payload.vehicleId correct")
    ctld_test.assertEqual(unloadedPayload.vehicleType, vehicleType,
        "payload.vehicleType correct")
    ctld_test.assertEqual(unloadedPayload.method, "parachute",
        "payload.method == 'parachute'")
    ctld_test.assertNotNil(unloadedPayload.transportUnitObject, "payload.transportUnitObject non-nil")
    ctld_test.assertNotNil(unloadedPayload.position,  "payload.position non-nil")
    ctld_test.assertNotNil(unloadedPayload.timestamp, "payload.timestamp non-nil")
end

ctld_test.finish()
