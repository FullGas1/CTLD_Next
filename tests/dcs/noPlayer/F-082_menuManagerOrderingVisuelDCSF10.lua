---@diagnostic disable
-- ============================================================
-- F-82 : ctld.MenuManager — ordering visuel DCS F10
-- Module  : M8 (src/CTLD_menu.lua)
-- Objectif: 3 submenus insérés ordre 30/10/20 → rendus A/B/C dans F10
--           REQUIRES: reboot de mission propre avant exécution
-- ============================================================

do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_menu.lua")

ctld_test.start("F-82", "MenuManager ordering visuel DCS F10")

-- Récupère le groupe joueur réel
local transport = ctld_test.getTransport()
if not transport then ctld_test.finish() return end
local group   = transport:getGroup()
local groupId = group:getID()

-- Construit le menu : insertion intentionnellement dans l'ordre C/A/B (30/10/20)
-- Le rendu DCS doit afficher A (10) → B (20) → C (30)
local mgr  = ctld.MenuManager:getInstance()
local menu = mgr:createMenuForGroup(groupId)
menu:addSubMenu({}, "Section C — order 30", { order = 30 })
menu:addSubMenu({}, "Section A — order 10", { order = 10 })
menu:addSubMenu({}, "Section B — order 20", { order = 20 })

-- Ajoute une commande dans chaque section pour les rendre visibles
menu:addCommand({"Section C — order 30"}, "cmd C", function() end, {})
menu:addCommand({"Section A — order 10"}, "cmd A", function() end, {})
menu:addCommand({"Section B — order 20"}, "cmd B", function() end, {})

local result = menu:refresh()
ctld_test.assert(result.success, "T1: refresh() success=true (missionCommands OK)")

-- Instructions pour le vérificateur
env.info("[F-82] ═══════════════════════════════════════════════")
env.info("[F-82] VERIFICATION VISUELLE — ouvre le menu F10 :")
env.info("[F-82]   ATTENDU (ordre croissant de F-key) :")
env.info("[F-82]   F1 = 'Section A — order 10'")
env.info("[F-82]   F2 = 'Section B — order 20'")
env.info("[F-82]   F3 = 'Section C — order 30'")
env.info("[F-82]   (pas d'importance si F1/F2/F3 exactement,")
env.info("[F-82]    l'ordre A→B→C doit être respecté)")
env.info("[F-82] ═══════════════════════════════════════════════")

ctld_test.finish()
