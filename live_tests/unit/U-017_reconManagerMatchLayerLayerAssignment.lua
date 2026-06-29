---@diagnostic disable
-- ============================================================
-- U-17 : CTLDReconManager._matchLayer — layer assignment
-- Module  : M3 (src/CTLD_recon.lua)
-- Objectif: Vérifier que _matchLayer retourne le bon layer
--           quand l'unité a l'attribut correspondant, et nil sinon.
-- Note    : unit:hasAttribute() est appelé via pcall dans _matchLayer.
--           On crée des stubs d'unité avec hasAttribute() contrôlable.
-- ============================================================

-- Purge CTLD.log
do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_core.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_recon.lua")

ctld_test.start("U-17", "CTLDReconManager._matchLayer — layer assignment")

CTLDReconManager._instance = nil
local rm = setmetatable({}, CTLDReconManager)

-- Construire un tableau de layers de test
local testLayers = {
    { layerId = "infantry",      filterAttrib = "Infantry",    iconRenderer = "infantry"   },
    { layerId = "ground_vehicles", filterAttrib = "Vehicles",  iconRenderer = "vehicle"    },
    { layerId = "air_defense",   filterAttrib = "Air Defence", iconRenderer = "aa"         },
}

-- Helper : unité stub avec un seul attribut
local function makeUnit(attribute)
    return {
        hasAttribute = function(self, attr)
            return attr == attribute
        end
    }
end

-- Unité Infantry → layer infantry
local unitInf = makeUnit("Infantry")
local layerInf = rm:_matchLayer(unitInf, testLayers)
ctld_test.assertNotNil(layerInf, "unité Infantry → layer non-nil")
ctld_test.assertEqual(layerInf.layerId, "infantry", "unité Infantry → layerId == 'infantry'")

-- Unité Vehicles → layer ground_vehicles
local unitVeh = makeUnit("Vehicles")
local layerVeh = rm:_matchLayer(unitVeh, testLayers)
ctld_test.assertNotNil(layerVeh, "unité Vehicles → layer non-nil")
ctld_test.assertEqual(layerVeh.layerId, "ground_vehicles", "unité Vehicles → layerId == 'ground_vehicles'")

-- Unité Air Defence → layer air_defense
local unitAA = makeUnit("Air Defence")
local layerAA = rm:_matchLayer(unitAA, testLayers)
ctld_test.assertNotNil(layerAA, "unité Air Defence → layer non-nil")
ctld_test.assertEqual(layerAA.layerId, "air_defense", "unité Air Defence → layerId == 'air_defense'")

-- Unité avec attribut non dans la liste → nil
local unitShip = makeUnit("Ships")
local layerShip = rm:_matchLayer(unitShip, testLayers)
ctld_test.assertNil(layerShip, "unité Ships (hors liste) → nil")

-- Unité dont hasAttribute() throw → pcall protège → nil
local unitCrash = {
    hasAttribute = function(self, attr)
        error("simulated DCS API error")
    end
}
local layerCrash = rm:_matchLayer(unitCrash, testLayers)
ctld_test.assertNil(layerCrash, "unité dont hasAttribute() throw → nil (pcall protège)")

-- Liste de layers vide → nil
local layerEmpty = rm:_matchLayer(unitInf, {})
ctld_test.assertNil(layerEmpty, "liste layers vide → nil")

ctld_test.finish()
