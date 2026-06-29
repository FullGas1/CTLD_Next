---@diagnostic disable
-- ============================================================
-- F-25 : CTLDPlayerManager — OnVehicleLoaded/Unloaded → loadedVehicles
-- Module  : M7 (src/CTLD_player.lua)
-- Objectif: Vérifier que :
--   1. OnVehicleLoaded  → player.loadedVehicles contient le ctldVehicleObject
--   2. OnVehicleUnloaded → player.loadedVehicles revient à 0
-- Précondition : un transport BLUE au sol dans la mission.
-- ============================================================

do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")
ctld_test.cleanup()

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_core.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_menu.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_player.lua")

ctld_test.start("F-25", "OnVehicleLoaded/Unloaded → player.loadedVehicles")

CTLDPlayerManager._instance  = nil
EventDispatcher._instance    = nil
CTLDDCSEventBridge._instance = nil

local mgr = CTLDPlayerManager.getInstance()

local transport = ctld_test.getTransport()
if not transport then ctld_test.finish() return end

-- Enregistrer le joueur
local okEnter = pcall(function()
    mgr:onPlayerEnterUnit({ initiator = transport })
end)
ctld_test.assert(okEnter, "onPlayerEnterUnit ne crash pas")

local playerObj = mgr:getPlayer(transport:getName())
ctld_test.assertNotNil(playerObj, "player présent avant les events")
if not playerObj then ctld_test.finish() return end

ctld_test.assertEqual(#playerObj.loadedVehicles, 0, "loadedVehicles == 0 avant events")

-- Mock CTLDVehicle
local mockVehicle = { id = "veh_test_F25", vehicleType = "M1045 HMMWV TOW" }

-- Publier OnVehicleLoaded
EventDispatcher.getInstance():publish("OnVehicleLoaded", {
    vehicleId            = mockVehicle.id,
    ctldVehicleObject    = mockVehicle,
    dcsUnitObject        = nil,
    vehicleType          = mockVehicle.vehicleType,
    transportUnitObject  = transport,
    player               = "TestPlayer",
    method               = "menu_ctld",
    spawnMethod          = "request_vehicle",
    position             = transport:getPoint(),
    transportPosition    = transport:getPoint(),
    timestamp            = timer.getAbsTime(),
})

ctld_test.assertEqual(#playerObj.loadedVehicles, 1,
    "loadedVehicles == 1 après OnVehicleLoaded")
ctld_test.assert(playerObj.loadedVehicles[1] == mockVehicle,
    "référence ctldVehicleObject correcte dans loadedVehicles")

-- Publier OnVehicleUnloaded
EventDispatcher.getInstance():publish("OnVehicleUnloaded", {
    vehicleId            = mockVehicle.id,
    ctldVehicleObject    = mockVehicle,
    dcsUnitObject        = nil,
    vehicleType          = mockVehicle.vehicleType,
    transportUnitObject  = transport,
    player               = "TestPlayer",
    method               = "menu_ctld",
    spawnMethod          = "request_vehicle",
    position             = transport:getPoint(),
    timestamp            = timer.getAbsTime(),
})

ctld_test.assertEqual(#playerObj.loadedVehicles, 0,
    "loadedVehicles == 0 après OnVehicleUnloaded")

ctld_test.finish()
