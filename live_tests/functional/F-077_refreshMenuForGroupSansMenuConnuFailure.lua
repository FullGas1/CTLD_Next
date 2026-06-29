---@diagnostic disable
-- ============================================================
-- F-77 : refreshMenuForGroup sans menu connu → failure
-- Module  : M8 (src/CTLD_menu.lua)
-- Objectif: groupId inexistant → success=false + message + refreshedCount=0
-- ============================================================

do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_menu.lua")

ctld_test.start("F-77", "refreshMenuForGroup sans menu connu → failure")

local _origRemove = missionCommands.removeItemForGroup
missionCommands.removeItemForGroup = function() end

local mgr = ctld.MenuManager:getInstance()
-- Ne pas créer de menu pour le groupId 8888
local result = mgr:refreshMenuForGroup(8888)

ctld_test.assert(not result.success,           "T1: success=false pour groupId inconnu")
ctld_test.assertNotNil(result.message,         "T2: message d'erreur fourni")
ctld_test.assertEqual(result.refreshedCount, 0, "T3: refreshedCount=0")

missionCommands.removeItemForGroup = _origRemove

ctld_test.finish()
