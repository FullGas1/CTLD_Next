---@diagnostic disable
-- ============================================================
-- U-27 : CTLDPlayerManager singleton + getPlayer nil
-- Module  : M7 (src/CTLD_player.lua)
-- Objectif: Vérifier que :
--   1. CTLDPlayerManager.getInstance() est idempotent (singleton)
--   2. getPlayer("unknown") retourne nil
-- Précondition : aucun transport requis.
-- ============================================================

do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_core.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_menu.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_player.lua")

ctld_test.start("U-27", "CTLDPlayerManager singleton + getPlayer nil")

CTLDPlayerManager._instance = nil
EventDispatcher._instance   = nil
CTLDDCSEventBridge._instance = nil

local m1 = CTLDPlayerManager.getInstance()
ctld_test.assertNotNil(m1, "getInstance() retourne une instance")

local m2 = CTLDPlayerManager.getInstance()
ctld_test.assert(m1 == m2, "getInstance() idempotent (même instance)")

ctld_test.assertNil(m1:getPlayer("unit_inexistante"),
    "getPlayer('unit_inexistante') == nil")
ctld_test.assertNil(m1:getPlayer(""),
    "getPlayer('') == nil")
ctld_test.assertNil(m1:getPlayer(nil),
    "getPlayer(nil) == nil")

ctld_test.finish()
