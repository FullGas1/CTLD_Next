---@diagnostic disable
-- ============================================================
-- F-73 : disabled nodes invisibles en DCS
-- Module  : M8 (src/CTLD_menu.lua)
-- Objectif: setBranchEnabled(false)+refresh → pas d'appel DCS pour ce nœud
--           setBranchEnabled(true)+refresh → nœud rendu
-- ============================================================

do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_menu.lua")

ctld_test.start("F-73", "disabled nodes invisibles en DCS")

-- ── Mock missionCommands ──────────────────────────────────────
local _subCalls = {}
local _origRemove = missionCommands.removeItemForGroup
local _origAddSub = missionCommands.addSubMenuForGroup
local _origAddCmd = missionCommands.addCommandForGroup
missionCommands.removeItemForGroup = function() end
missionCommands.addSubMenuForGroup = function(gid, name, path) table.insert(_subCalls, name) end
missionCommands.addCommandForGroup = function() end

local function hasName(tbl, name)
    for _, n in ipairs(tbl) do if n == name then return true end end
    return false
end

local mgr  = ctld.MenuManager:getInstance()
local menu = mgr:createMenuForGroup(9999)
menu:addSubMenu({}, "Visible Section",  { order = 10 })
menu:addSubMenu({}, "Hidden Section",   { order = 20, enabled = false })

-- T1: après refresh — Hidden Section absente du DCS
menu:refresh()
ctld_test.assert(    hasName(_subCalls, "Visible Section"), "T1a: Visible Section rendu")
ctld_test.assert(not hasName(_subCalls, "Hidden Section"),  "T1b: Hidden Section NON rendu")

-- T2: enable Hidden Section + refresh → apparaît dans DCS
_subCalls = {}
menu:setBranchEnabled({"Hidden Section"}, true)
menu:refresh()
ctld_test.assert(hasName(_subCalls, "Hidden Section"), "T2a: Hidden Section rendu après enable")
ctld_test.assertEqual(#_subCalls, 2,                   "T2b: 2 sous-menus rendus au total")

-- Restore
missionCommands.removeItemForGroup = _origRemove
missionCommands.addSubMenuForGroup = _origAddSub
missionCommands.addCommandForGroup = _origAddCmd

ctld_test.finish()
