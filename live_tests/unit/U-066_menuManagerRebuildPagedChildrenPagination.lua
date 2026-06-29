---@diagnostic disable
-- ============================================================
-- U-66 : ctld.MenuManager — _rebuildPagedChildren pagination
-- Module  : M8 (src/CTLD_menu.lua)
-- Objectif: ≤10 inline, 11→9+NextPage+2, 20→deux niveaux pagination
-- ============================================================

do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_menu.lua")

ctld_test.start("U-66", "ctld.MenuManager _rebuildPagedChildren pagination")

-- ── Mock missionCommands ──────────────────────────────────────
local _subCalls = {}
local _cmdCalls = {}
local _origAddSub = missionCommands.addSubMenuForGroup
local _origAddCmd = missionCommands.addCommandForGroup
local _origRemove = missionCommands.removeItemForGroup
missionCommands.addSubMenuForGroup = function(gid, name, path) table.insert(_subCalls, name) end
missionCommands.addCommandForGroup = function(gid, name, path, fn, arg) table.insert(_cmdCalls, name) end
missionCommands.removeItemForGroup = function() end

local function makeNodes(n)
    local nodes = {}
    for i = 1, n do
        table.insert(nodes, {
            name = "item" .. i,
            type = "command",
            enabled = true,
            functionToCall = function() end,
            anyArgument = {},
        })
    end
    return nodes
end

-- T1: ≤10 items → tous rendus, pas de Next Page
_subCalls = {} _cmdCalls = {}
ctld.MenuManager:_rebuildPagedChildren(9999, {}, makeNodes(10))
ctld_test.assertEqual(#_cmdCalls, 10, "T1a: 10 items → 10 commandes rendues")
ctld_test.assertEqual(#_subCalls, 0,  "T1b: aucun sous-menu Next Page")

-- T2: 11 items → 9 rendus + Next Page + 2 dans la page suivante
_subCalls = {} _cmdCalls = {}
ctld.MenuManager:_rebuildPagedChildren(9999, {}, makeNodes(11))
ctld_test.assertEqual(#_cmdCalls, 11, "T2a: 11 commandes rendues au total")
ctld_test.assertEqual(#_subCalls, 1,  "T2b: un sous-menu Next Page créé")

-- T3: 20 items → deux niveaux de pagination (2 × Next Page)
_subCalls = {} _cmdCalls = {}
ctld.MenuManager:_rebuildPagedChildren(9999, {}, makeNodes(20))
ctld_test.assertEqual(#_cmdCalls, 20, "T3a: 20 commandes rendues au total")
ctld_test.assertEqual(#_subCalls, 2,  "T3b: deux sous-menus Next Page créés")

-- Restore
missionCommands.addSubMenuForGroup = _origAddSub
missionCommands.addCommandForGroup = _origAddCmd
missionCommands.removeItemForGroup = _origRemove

ctld_test.finish()
