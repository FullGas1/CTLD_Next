---@diagnostic disable
-- ============================================================
-- F-72 : refreshMenuForGroup — séquence complète
-- Module  : M8 (src/CTLD_menu.lua)
-- Objectif: create+addSubMenu+addCommand+refresh
--           → removeItemForGroup + addSubMenuForGroup + addCommandForGroup appelés
-- ============================================================

do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_menu.lua")

ctld_test.start("F-72", "refreshMenuForGroup sequence complete")

-- ── Mock missionCommands ──────────────────────────────────────
local _removeCalls = {}
local _subCalls    = {}
local _cmdCalls    = {}
local _origRemove = missionCommands.removeItemForGroup
local _origAddSub = missionCommands.addSubMenuForGroup
local _origAddCmd = missionCommands.addCommandForGroup
missionCommands.removeItemForGroup = function(gid, path) table.insert(_removeCalls, { gid = gid, path = path }) end
missionCommands.addSubMenuForGroup = function(gid, name, path) table.insert(_subCalls, { gid = gid, name = name }) end
missionCommands.addCommandForGroup = function(gid, name, path, fn, arg) table.insert(_cmdCalls, { gid = gid, name = name }) end

-- Build menu
local mgr  = ctld.MenuManager:getInstance()
local menu = mgr:createMenuForGroup(9999)
menu:addSubMenu({}, "CTLD Commands")
menu:addCommand({"CTLD Commands"}, "Load Crate", function() end, {})

local result = menu:refresh()

-- T1: refresh returns success
ctld_test.assert(result.success,             "T1: refresh retourne success=true")

-- T2: removeItemForGroup appelé une fois pour ce groupe
ctld_test.assertEqual(#_removeCalls, 1,      "T2: removeItemForGroup appelé une fois")
ctld_test.assertEqual(_removeCalls[1].gid, 9999, "T3: removeItemForGroup pour groupId 9999")

-- T4: addSubMenuForGroup appelé (le sous-menu "CTLD Commands")
ctld_test.assert(#_subCalls >= 1,            "T4: addSubMenuForGroup appelé au moins une fois")

-- T5: nom du sous-menu correct
local foundSub = false
for _, c in ipairs(_subCalls) do if c.name == "CTLD Commands" then foundSub = true end end
ctld_test.assert(foundSub,                   "T5: 'CTLD Commands' rendu dans DCS")

-- T6: addCommandForGroup appelé pour la commande
ctld_test.assert(#_cmdCalls >= 1,            "T6: addCommandForGroup appelé au moins une fois")
local foundCmd = false
for _, c in ipairs(_cmdCalls) do if c.name == "Load Crate" then foundCmd = true end end
ctld_test.assert(foundCmd,                   "T7: 'Load Crate' rendu dans DCS")

-- Restore
missionCommands.removeItemForGroup = _origRemove
missionCommands.addSubMenuForGroup = _origAddSub
missionCommands.addCommandForGroup = _origAddCmd

ctld_test.finish()
