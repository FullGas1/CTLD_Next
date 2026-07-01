---@diagnostic disable
-- ============================================================
-- F-74 : order détermine l'ordre de rendu DCS
-- Module  : M8 (src/CTLD_menu.lua)
-- Objectif: 3 submenus insérés ordre 30/10/20 → rendus 10/20/30
-- ============================================================

do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_menu.lua")

ctld_test.start("F-74", "order determine l'ordre de rendu DCS")

-- ── Mock missionCommands ──────────────────────────────────────
local _renderOrder = {}
local _origRemove = missionCommands.removeItemForGroup
local _origAddSub = missionCommands.addSubMenuForGroup
local _origAddCmd = missionCommands.addCommandForGroup
missionCommands.removeItemForGroup = function() end
-- Capture uniquement les sous-menus sans parent (parentPath nil = root level)
missionCommands.addSubMenuForGroup = function(gid, name, path)
    if path == nil then table.insert(_renderOrder, name) end
end
missionCommands.addCommandForGroup = function() end

local mgr  = ctld.MenuManager:getInstance()
local menu = mgr:createMenuForGroup(9999)

-- Insertion dans l'ordre 30 / 10 / 20 intentionnellement
menu:addSubMenu({}, "Section C", { order = 30 })
menu:addSubMenu({}, "Section A", { order = 10 })
menu:addSubMenu({}, "Section B", { order = 20 })

menu:refresh()

-- Attendu : Section A (10), Section B (20), Section C (30)
ctld_test.assertEqual(_renderOrder[1], "Section A", "T1: premier rendu = Section A (order 10)")
ctld_test.assertEqual(_renderOrder[2], "Section B", "T2: deuxième rendu = Section B (order 20)")
ctld_test.assertEqual(_renderOrder[3], "Section C", "T3: troisième rendu = Section C (order 30)")
ctld_test.assertEqual(#_renderOrder, 3,              "T4: exactement 3 sous-menus rendus")

-- Restore
missionCommands.removeItemForGroup = _origRemove
missionCommands.addSubMenuForGroup = _origAddSub
missionCommands.addCommandForGroup = _origAddCmd

ctld_test.finish()
