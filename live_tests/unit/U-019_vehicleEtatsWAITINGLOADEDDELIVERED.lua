---@diagnostic disable
-- ============================================================
-- U-19 : CTLDVehicle états (WAITING → LOADED → DELIVERED)
-- Module  : M5 (src/CTLD_vehicle.lua)
-- Objectif: Vérifier les transitions d'état de CTLDVehicle :
--   - Création → état initial WAITING
--   - setState(LOADED)    → getState() == "LOADED"
--   - setState(DELIVERED) → getState() == "DELIVERED"
--   - Champs d'identité préservés (id, vehicleType, spawnData)
-- Ce test est purement unitaire : aucune API DCS requise.
-- ============================================================

-- Purge CTLD.log
do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_core.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_vehicle.lua")

ctld_test.start("U-19", "CTLDVehicle états WAITING → LOADED → DELIVERED")

-- ---- Construction ----
local spawnData = {
    groupName   = "CTLD_VEH_M1045_HMMWV_TOW_veh_1",
    unitName    = "CTLD_VEH_M1045_HMMWV_TOW_veh_1",
    vehicleType = "M1045 HMMWV TOW",
    countryId   = 2,
    coalitionId = 2,
}

local veh = CTLDVehicle:new({
    id          = "veh_1",
    vehicleType = "M1045 HMMWV TOW",
    spawnData   = spawnData,
})

ctld_test.assertNotNil(veh, "CTLDVehicle:new() retourne une instance non-nil")
ctld_test.assertEqual(veh:getState(), CTLDVehicle.STATE.WAITING,
    "état initial == WAITING")
ctld_test.assertEqual(veh.id, "veh_1", "id préservé")
ctld_test.assertEqual(veh.vehicleType, "M1045 HMMWV TOW", "vehicleType préservé")
ctld_test.assertNotNil(veh.spawnData, "spawnData non-nil")
ctld_test.assertEqual(veh.spawnData.groupName, spawnData.groupName,
    "spawnData.groupName préservé")

-- ---- Transition WAITING → LOADED ----
veh:setState(CTLDVehicle.STATE.LOADED)
ctld_test.assertEqual(veh:getState(), CTLDVehicle.STATE.LOADED,
    "après setState(LOADED) → getState() == LOADED")

-- ---- Transition LOADED → DELIVERED ----
veh:setState(CTLDVehicle.STATE.DELIVERED)
ctld_test.assertEqual(veh:getState(), CTLDVehicle.STATE.DELIVERED,
    "après setState(DELIVERED) → getState() == DELIVERED")

-- ---- Constantes de classe ----
ctld_test.assertEqual(CTLDVehicle.STATE.WAITING,   "WAITING",   "STATE.WAITING == 'WAITING'")
ctld_test.assertEqual(CTLDVehicle.STATE.LOADED,    "LOADED",    "STATE.LOADED == 'LOADED'")
ctld_test.assertEqual(CTLDVehicle.STATE.DELIVERED, "DELIVERED", "STATE.DELIVERED == 'DELIVERED'")

-- ---- Champs optionnels nil par défaut ----
ctld_test.assertNil(veh.unit,         "unit nil par défaut")
ctld_test.assertNil(veh.spawner,      "spawner nil par défaut")
ctld_test.assertNil(veh.logisticZone, "logisticZone nil par défaut")
ctld_test.assertNil(veh.loadMethod,   "loadMethod nil par défaut")

ctld_test.finish()
