---@diagnostic disable
-- ============================================================
-- F-81 : ctld.MenuManager — pagination visuelle DCS F10
-- Module  : M8 (src/CTLD_menu.lua)
-- Objectif: 11 items dans un sous-menu → 9 visibles + "→ Next Page"
--           REQUIRES: reboot de mission propre avant exécution
-- ============================================================

do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_menu.lua")

ctld_test.start("F-81", "MenuManager pagination visuelle DCS F10")

-- Récupère le groupe joueur réel
local transport = ctld_test.getTransport()
if not transport then ctld_test.finish() return end
local group   = transport:getGroup()
local groupId = group:getID()

-- Construit le menu avec 11 commandes dans "CTLD Test Pagination"
local mgr  = ctld.MenuManager:getInstance()
local menu = mgr:createMenuForGroup(groupId)
menu:addSubMenu({}, "CTLD Test Pagination")
for i = 1, 11 do
    local idx = i
    menu:addCommand({"CTLD Test Pagination"}, "Item " .. idx, function() end, {})
end

local result = menu:refresh()
ctld_test.assert(result.success, "T1: refresh() success=true (missionCommands OK)")

-- Instructions pour le vérificateur
env.info("[F-81] ═══════════════════════════════════════════════")
env.info("[F-81] VERIFICATION VISUELLE — ouvre le menu F10 :")
env.info("[F-81]   CTLD Test Pagination →")
env.info("[F-81]   ATTENDU : Items 1 à 9 en F1-F9,")
env.info("[F-81]             F10 = '→ Next Page'")
env.info("[F-81]   ATTENDU dans Next Page : Items 10 et 11")
env.info("[F-81] ═══════════════════════════════════════════════")

ctld_test.finish()
