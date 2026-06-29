---@diagnostic disable
-- ============================================================
-- U-06 : CTLDPlayerTracker — getPlayerByUnit / isPlayerUnit
-- Module  : C1 (src/CTLD_core.lua)
-- Objectif: Vérifier l'index byUnit : getPlayerByUnit(unitName) et
--           isPlayerUnit(unitName) après injection manuelle d'entrées.
-- Note    : On injecte directement dans _byUnit/_byPlayer sans passer
--           par les événements DCS (test unitaire pur).
-- ============================================================

-- Purge CTLD.log
do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_core.lua")

ctld_test.start("U-06", "CTLDPlayerTracker — getPlayerByUnit / isPlayerUnit")

-- Créer une instance de CTLDPlayerTracker sans passer par init()
-- pour éviter les dépendances DCS (bridge, scan, timer).
-- On instancie directement et on peuple les index manuellement.
local tracker = setmetatable({}, CTLDPlayerTracker)
tracker._byUnit   = {}
tracker._byPlayer = {}

-- Injecter deux joueurs fictifs
tracker._byUnit["unit_alpha"]   = "PlayerAlpha"
tracker._byUnit["unit_bravo"]   = "PlayerBravo"
tracker._byPlayer["PlayerAlpha"] = { unitName = "unit_alpha", coalition = 2 }
tracker._byPlayer["PlayerBravo"] = { unitName = "unit_bravo", coalition = 1 }

-- getPlayerByUnit : cas positifs
ctld_test.assertEqual(tracker:getPlayerByUnit("unit_alpha"), "PlayerAlpha",
    "getPlayerByUnit('unit_alpha') == 'PlayerAlpha'")
ctld_test.assertEqual(tracker:getPlayerByUnit("unit_bravo"), "PlayerBravo",
    "getPlayerByUnit('unit_bravo') == 'PlayerBravo'")

-- getPlayerByUnit : unité non enregistrée → nil
ctld_test.assertNil(tracker:getPlayerByUnit("unit_unknown"),
    "getPlayerByUnit('unit_unknown') == nil")

-- isPlayerUnit : cas positifs
ctld_test.assert(tracker:isPlayerUnit("unit_alpha"),  "isPlayerUnit('unit_alpha') == true")
ctld_test.assert(tracker:isPlayerUnit("unit_bravo"),  "isPlayerUnit('unit_bravo') == true")

-- isPlayerUnit : unité non enregistrée → false
ctld_test.assert(not tracker:isPlayerUnit("unit_ai"), "isPlayerUnit('unit_ai') == false")

ctld_test.finish()
