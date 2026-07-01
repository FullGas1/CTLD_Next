---@diagnostic disable
-- ============================================================
-- U-07 : CTLDPlayerTracker — getUnitByPlayer / getAllPlayers
-- Module  : C1 (src/CTLD_core.lua)
-- Objectif: Vérifier l'index byPlayer : getUnitByPlayer(playerName)
--           retourne { unitName, coalition } et getAllPlayers() retourne
--           la liste complète des joueurs connectés.
-- ============================================================

-- Purge CTLD.log
do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_core.lua")

ctld_test.start("U-07", "CTLDPlayerTracker — getUnitByPlayer / getAllPlayers")

-- Instancier sans init() pour test unitaire pur
local tracker = setmetatable({}, CTLDPlayerTracker)
tracker._byUnit   = {}
tracker._byPlayer = {}

-- Injecter trois joueurs
tracker._byUnit["unit_charlie"]  = "PlayerCharlie"
tracker._byUnit["unit_delta"]    = "PlayerDelta"
tracker._byUnit["unit_echo"]     = "PlayerEcho"
tracker._byPlayer["PlayerCharlie"] = { unitName = "unit_charlie", coalition = 2 }
tracker._byPlayer["PlayerDelta"]   = { unitName = "unit_delta",   coalition = 2 }
tracker._byPlayer["PlayerEcho"]    = { unitName = "unit_echo",    coalition = 1 }

-- getUnitByPlayer : cas positifs
local dataC = tracker:getUnitByPlayer("PlayerCharlie")
ctld_test.assertNotNil(dataC, "getUnitByPlayer('PlayerCharlie') non-nil")
ctld_test.assertEqual(dataC.unitName,  "unit_charlie", "unitName correct")
ctld_test.assertEqual(dataC.coalition, 2,              "coalition BLUE == 2")

local dataE = tracker:getUnitByPlayer("PlayerEcho")
ctld_test.assertNotNil(dataE, "getUnitByPlayer('PlayerEcho') non-nil")
ctld_test.assertEqual(dataE.coalition, 1, "coalition RED == 1")

-- getUnitByPlayer : joueur non connecté → nil
ctld_test.assertNil(tracker:getUnitByPlayer("PlayerUnknown"),
    "getUnitByPlayer('PlayerUnknown') == nil")

-- getAllPlayers : doit retourner 3 entrées
local all = tracker:getAllPlayers()
ctld_test.assertEqual(#all, 3, "getAllPlayers() retourne 3 entrées")

-- Vérifier que chaque entrée a les champs requis
local hasPlayerName, hasUnitName, hasCoalition = true, true, true
for _, entry in ipairs(all) do
    if not entry.playerName then hasPlayerName = false end
    if not entry.unitName   then hasUnitName   = false end
    if entry.coalition == nil then hasCoalition = false end
end
ctld_test.assert(hasPlayerName, "toutes les entrées ont playerName")
ctld_test.assert(hasUnitName,   "toutes les entrées ont unitName")
ctld_test.assert(hasCoalition,  "toutes les entrées ont coalition")

-- getAllPlayers : liste vide si aucun joueur
local emptyTracker = setmetatable({}, CTLDPlayerTracker)
emptyTracker._byUnit   = {}
emptyTracker._byPlayer = {}
local empty = emptyTracker:getAllPlayers()
ctld_test.assertEqual(#empty, 0, "getAllPlayers() retourne table vide si aucun joueur")

ctld_test.finish()
