---@diagnostic disable
-- ============================================================
-- U-20 : CTLDVehicleSpawner singleton
-- Module  : M5 (src/CTLD_vehicle.lua)
-- Objectif: Vérifier le pattern singleton :
--   - Deux appels getInstance() retournent la même référence
--   - _vehicles et _unitToVehicle sont initialisés comme tables
--   - _vehicleCount démarre à 0
-- ============================================================

-- Purge CTLD.log
do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_core.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_vehicle.lua")

ctld_test.start("U-20", "CTLDVehicleSpawner — singleton")

-- Reset singleton
CTLDVehicleSpawner._instance = nil

local ok = pcall(function() CTLDVehicleSpawner.getInstance() end)
ctld_test.assert(ok, "CTLDVehicleSpawner.getInstance() ne crash pas")

local s1 = CTLDVehicleSpawner._instance
local s2 = CTLDVehicleSpawner.getInstance()

ctld_test.assertNotNil(s1, "première instance non-nil")
ctld_test.assert(s1 == s2, "deux appels getInstance() retournent la même référence")

-- Vérification structure interne
ctld_test.assert(type(s1._vehicles)      == "table", "_vehicles est une table")
ctld_test.assert(type(s1._unitToVehicle) == "table", "_unitToVehicle est une table")
ctld_test.assertEqual(s1._vehicleCount, 0, "_vehicleCount initial == 0")

ctld_test.finish()
