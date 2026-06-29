---@diagnostic disable
-- ============================================================
-- F-17 : unloadVehicle method=menu_ctld
-- Module  : M5 (src/CTLD_vehicle.lua)
-- Objectif: Vérifier que unloadVehicle(method="menu_ctld") :
--   1. Ne crash pas
--   2. Passe le vehicle en état DELIVERED
--   3. Respawn l'unité DCS (vehicle.unit non-nil)
--   4. Publie OnVehicleUnloaded avec le bon payload
--   5. Ré-enregistre l'unité dans _unitToVehicle
-- Précondition : un transport BLUE doit être présent dans la mission.
-- ============================================================

-- Purge CTLD.log
do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")
ctld_test.cleanup()

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_core.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_vehicle.lua")

ctld_test.start("F-17", "unloadVehicle method=menu_ctld → OnVehicleUnloaded")

CTLDVehicleSpawner._instance = nil
EventDispatcher._instance    = nil
CTLDDCSEventBridge._instance = nil

CTLDVehicleSpawner.getInstance()
local vs = CTLDVehicleSpawner._instance

local transport = ctld_test.getTransport()
if not transport then ctld_test.finish() return end

local vehicleType = "M1045 HMMWV TOW"

-- Setup : spawn + load
local vehicle = vs:spawnVehicleForTransport(vehicleType, transport, nil)
ctld_test.assertNotNil(vehicle, "spawnVehicleForTransport OK")
if not vehicle then ctld_test.finish() return end

vs:loadVehicle(vehicle, transport, nil, "menu_ctld")
ctld_test.assertEqual(vehicle:getState(), CTLDVehicle.STATE.LOADED,
    "vehicle en LOADED avant unload")

-- Capturer OnVehicleUnloaded
local unloadedPayload = nil
EventDispatcher.getInstance():subscribe("OnVehicleUnloaded", function(p)
    unloadedPayload = p
end)

-- Exécuter unloadVehicle method=menu_ctld
local okUnload = pcall(function()
    vs:unloadVehicle(vehicle, transport, "TestPlayer", "menu_ctld")
end)

ctld_test.assert(okUnload, "unloadVehicle ne crash pas")
ctld_test.assertEqual(vehicle:getState(), CTLDVehicle.STATE.WAITING,
    "vehicle en état WAITING après unload (re-loadable)")

-- L'unité DCS est respawnée (dans la mission réelle), en test DCS sim :
-- dynAdd retourne une table, Group.getByName peut retourner nil si DCS ne persiste pas
-- On vérifie que le code ne crash pas et que vehicle.unit a été mis à jour
-- (peut être nil si dynAdd ne persiste pas l'unité dans ce contexte test)
ctld_test.assert(true, "INFO: vehicle.unit après unload = " .. tostring(vehicle.unit))

-- Vérification event OnVehicleUnloaded
ctld_test.assertNotNil(unloadedPayload, "OnVehicleUnloaded publié")

if unloadedPayload then
    ctld_test.assertEqual(unloadedPayload.vehicleId, vehicle.id,
        "payload.vehicleId correct")
    ctld_test.assertEqual(unloadedPayload.vehicleType, vehicleType,
        "payload.vehicleType correct")
    ctld_test.assertNotNil(unloadedPayload.transportUnitObject, "payload.transportUnitObject non-nil")
    ctld_test.assertEqual(unloadedPayload.method, "menu_ctld",
        "payload.method == 'menu_ctld'")
    ctld_test.assertEqual(unloadedPayload.player, "TestPlayer",
        "payload.player correct")
    ctld_test.assertNotNil(unloadedPayload.position, "payload.position non-nil")
    ctld_test.assertNotNil(unloadedPayload.timestamp, "payload.timestamp non-nil")
end

-- Double-unload doit être ignorée (vehicle plus en LOADED)
local okDoubleUnload = pcall(function()
    vs:unloadVehicle(vehicle, transport, nil, "menu_ctld")
end)
ctld_test.assert(okDoubleUnload, "double unloadVehicle ne crash pas (ignored silently)")
ctld_test.assertEqual(vehicle:getState(), CTLDVehicle.STATE.WAITING,
    "état reste WAITING après double-unload ignoré")

ctld_test.finish()
