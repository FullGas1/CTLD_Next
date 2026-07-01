---@diagnostic disable
-- ============================================================
-- F-24 : CTLDPlayerManager.onPlayerEnterUnit → menu créé
-- Module  : M7 (src/CTLD_player.lua)
-- Objectif: Vérifier qu'après onPlayerEnterUnit avec un vrai transport :
--   1. Le CTLDPlayer est créé dans _players
--   2. Un menu est créé dans ctld.MenuManager pour le groupId
--   3. Le menu contient le sous-menu "CTLD"
-- Précondition : un transport BLUE au sol dans la mission.
-- ============================================================

do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")
ctld_test.cleanup()

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_core.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_menu.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_player.lua")

ctld_test.start("F-24", "onPlayerEnterUnit → player créé + menu ctld.MenuManager")

CTLDPlayerManager._instance  = nil
EventDispatcher._instance    = nil
CTLDDCSEventBridge._instance = nil

local mgr = CTLDPlayerManager.getInstance()

local transport = ctld_test.getTransport()
if not transport then ctld_test.finish() return end

local unitName = transport:getName()
local group    = transport:getGroup()
local groupId  = group and group:getID() or nil

local okEnter = pcall(function()
    mgr:onPlayerEnterUnit({ initiator = transport })
end)
ctld_test.assert(okEnter, "onPlayerEnterUnit ne crash pas")

-- Player créé
local playerObj = mgr:getPlayer(unitName)
ctld_test.assertNotNil(playerObj, "CTLDPlayer créé dans _players")

if playerObj then
    ctld_test.assertEqual(playerObj.unitName, unitName, "player.unitName correct")
    ctld_test.assertEqual(playerObj.groupId,  groupId,  "player.groupId correct")
end

-- Menu créé dans ctld.MenuManager
local menu = ctld.MenuManager:getInstance():getMenuByGroupId(groupId)
ctld_test.assertNotNil(menu, "ctld.MenuManager a un menu pour le groupId")

if menu then
    -- Le sous-menu "CTLD" doit exister (level 1)
    local ctldNode = nil
    for _, child in ipairs(menu.children or {}) do
        if child.name == "CTLD" then ctldNode = child; break end
    end
    ctld_test.assertNotNil(ctldNode, "sous-menu 'CTLD' présent dans le menu")
end

ctld_test.finish()
