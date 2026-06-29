---@diagnostic disable
-- ============================================================
-- F-26 : CTLDPlayerManager.onPlayerLeaveUnit → player + menu supprimés
-- Module  : M7 (src/CTLD_player.lua)
-- Objectif: Vérifier qu'après onPlayerLeaveUnit :
--   1. getPlayer(unitName) retourne nil
--   2. Le joueur n'est plus dans _players
-- Précondition : un transport BLUE au sol dans la mission.
-- ============================================================

do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")
ctld_test.cleanup()

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_core.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_menu.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_player.lua")

ctld_test.start("F-26", "onPlayerLeaveUnit → player supprimé de _players")

CTLDPlayerManager._instance  = nil
EventDispatcher._instance    = nil
CTLDDCSEventBridge._instance = nil

local mgr = CTLDPlayerManager.getInstance()

local transport = ctld_test.getTransport()
if not transport then ctld_test.finish() return end

local unitName = transport:getName()

-- Enter
local okEnter = pcall(function()
    mgr:onPlayerEnterUnit({ initiator = transport })
end)
ctld_test.assert(okEnter, "onPlayerEnterUnit ne crash pas")
ctld_test.assertNotNil(mgr:getPlayer(unitName), "player présent après Enter")

-- Leave
local okLeave = pcall(function()
    mgr:onPlayerLeaveUnit({ initiator = transport })
end)
ctld_test.assert(okLeave, "onPlayerLeaveUnit ne crash pas")
ctld_test.assertNil(mgr:getPlayer(unitName),
    "getPlayer(unitName) == nil après Leave")

-- Compter les joueurs restants
local count = 0
for _ in pairs(mgr._players) do count = count + 1 end
ctld_test.assertEqual(count, 0, "_players vide après Leave")

ctld_test.finish()
