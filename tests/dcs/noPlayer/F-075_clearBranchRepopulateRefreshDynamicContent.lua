---@diagnostic disable
-- ============================================================
-- F-75 : clearBranch + repopulate + refresh (dynamic content)
-- Module  : M8 (src/CTLD_menu.lua)
-- Objectif: pattern proximité — clearBranch efface, nouvelles commandes rendues
-- ============================================================

do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_menu.lua")

ctld_test.start("F-75", "clearBranch + repopulate + refresh pattern")

-- ── Mock missionCommands ──────────────────────────────────────
local _cmdCalls = {}
local _origRemove = missionCommands.removeItemForGroup
local _origAddSub = missionCommands.addSubMenuForGroup
local _origAddCmd = missionCommands.addCommandForGroup
missionCommands.removeItemForGroup = function() end
missionCommands.addSubMenuForGroup = function() end
missionCommands.addCommandForGroup = function(gid, name, path, fn, arg) table.insert(_cmdCalls, name) end

local mgr  = ctld.MenuManager:getInstance()
local menu = mgr:createMenuForGroup(9999)
menu:addSubMenu({}, "Pack Vehicles")

-- Première population + render
menu:addCommand({"Pack Vehicles"}, "Old Vehicle 1", function() end, {})
menu:addCommand({"Pack Vehicles"}, "Old Vehicle 2", function() end, {})
menu:refresh()

-- Deuxième cycle : clearBranch + nouvelles commandes
_cmdCalls = {}
menu:clearBranch({"Pack Vehicles"})
menu:addCommand({"Pack Vehicles"}, "New Vehicle A", function() end, {})
menu:addCommand({"Pack Vehicles"}, "New Vehicle B", function() end, {})
menu:addCommand({"Pack Vehicles"}, "New Vehicle C", function() end, {})
menu:refresh()

-- T1: exactement 3 nouvelles commandes rendues
ctld_test.assertEqual(#_cmdCalls, 3,             "T1: 3 commandes rendues après clearBranch")
ctld_test.assertEqual(_cmdCalls[1], "New Vehicle A", "T2: commande 1 = New Vehicle A")
ctld_test.assertEqual(_cmdCalls[2], "New Vehicle B", "T3: commande 2 = New Vehicle B")
ctld_test.assertEqual(_cmdCalls[3], "New Vehicle C", "T4: commande 3 = New Vehicle C")

-- T5: anciennes commandes absentes du rendu
local hasOld = false
for _, name in ipairs(_cmdCalls) do if name:find("Old Vehicle") then hasOld = true end end
ctld_test.assert(not hasOld, "T5: anciennes commandes absentes")

-- Restore
missionCommands.removeItemForGroup = _origRemove
missionCommands.addSubMenuForGroup = _origAddSub
missionCommands.addCommandForGroup = _origAddCmd

ctld_test.finish()
