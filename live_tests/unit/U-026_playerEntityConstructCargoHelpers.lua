---@diagnostic disable
-- ============================================================
-- U-26 : CTLDPlayer entity — construct + cargo helpers
-- Module  : M7 (src/CTLD_player.lua)
-- Objectif: Vérifier que CTLDPlayer:new() crée un objet avec les
--   propriétés correctes, et que addLoadedVehicle / removeLoadedVehicle
--   / addLoadedCrate / removeLoadedCrate fonctionnent par identité.
-- Précondition : aucun transport requis (mock uniquement).
-- ============================================================

do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_core.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_menu.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_player.lua")

ctld_test.start("U-26", "CTLDPlayer entity — construct + cargo helpers")

-- Construct
local playerObj = CTLDPlayer:new({
    unitName         = "test_unit",
    groupId          = 42,
    groupName        = "test_group",
    coalition        = coalition.side.BLUE,
    typeName         = "UH-1H",
    isTransport      = true,
    canCarryVehicles = false,
})

ctld_test.assertNotNil(playerObj, "CTLDPlayer:new() retourne un objet")
ctld_test.assertEqual(playerObj.unitName,         "test_unit",          "unitName correct")
ctld_test.assertEqual(playerObj.groupId,          42,                   "groupId correct")
ctld_test.assertEqual(playerObj.groupName,        "test_group",         "groupName correct")
ctld_test.assertEqual(playerObj.coalition,        coalition.side.BLUE,  "coalition correct")
ctld_test.assertEqual(playerObj.typeName,         "UH-1H",              "typeName correct")
ctld_test.assertEqual(playerObj.isTransport,      true,                 "isTransport correct")
ctld_test.assertEqual(playerObj.canCarryVehicles, false,                "canCarryVehicles correct")
ctld_test.assertEqual(#playerObj.loadedTroops,    0,                    "loadedTroops vide à l'init")
ctld_test.assertEqual(#playerObj.loadedCrates,    0,                    "loadedCrates vide à l'init")
ctld_test.assertEqual(#playerObj.loadedVehicles,  0,                    "loadedVehicles vide à l'init")

-- addLoadedVehicle / removeLoadedVehicle
local veh1 = { id = "veh_1" }
local veh2 = { id = "veh_2" }

playerObj:addLoadedVehicle(veh1)
ctld_test.assertEqual(#playerObj.loadedVehicles, 1, "loadedVehicles == 1 après add veh1")

playerObj:addLoadedVehicle(veh2)
ctld_test.assertEqual(#playerObj.loadedVehicles, 2, "loadedVehicles == 2 après add veh2")

playerObj:removeLoadedVehicle(veh1)
ctld_test.assertEqual(#playerObj.loadedVehicles, 1, "loadedVehicles == 1 après remove veh1")
ctld_test.assertEqual(playerObj.loadedVehicles[1], veh2, "veh2 reste après remove veh1")

playerObj:removeLoadedVehicle(veh2)
ctld_test.assertEqual(#playerObj.loadedVehicles, 0, "loadedVehicles == 0 après remove veh2")

-- removeLoadedVehicle sur objet absent → pas de crash
local okRemove = pcall(function() playerObj:removeLoadedVehicle(veh1) end)
ctld_test.assert(okRemove, "removeLoadedVehicle objet absent ne crash pas")
ctld_test.assertEqual(#playerObj.loadedVehicles, 0, "loadedVehicles toujours 0")

-- addLoadedCrate / removeLoadedCrate
local crate1 = { id = "crate_A" }
playerObj:addLoadedCrate(crate1)
ctld_test.assertEqual(#playerObj.loadedCrates, 1, "loadedCrates == 1 après addLoadedCrate")
playerObj:removeLoadedCrate(crate1)
ctld_test.assertEqual(#playerObj.loadedCrates, 0, "loadedCrates == 0 après removeLoadedCrate")

ctld_test.finish()
