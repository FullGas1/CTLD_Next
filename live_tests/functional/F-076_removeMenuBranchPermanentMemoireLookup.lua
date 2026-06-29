---@diagnostic disable
-- ============================================================
-- F-76 : removeMenuBranch permanent — mémoire + _lookup
-- Module  : M8 (src/CTLD_menu.lua)
-- Objectif: nœud absent du parent + _lookup nettoyé après suppression
-- ============================================================

do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_menu.lua")

ctld_test.start("F-76", "removeMenuBranch permanent memoire + lookup")

local mgr  = ctld.MenuManager:getInstance()
local menu = mgr:createMenuForGroup(9999)
menu:addSubMenu({}, "Section A")
menu:addCommand({"Section A"}, "Cmd 1", function() end, {})
menu:addCommand({"Section A"}, "Cmd 2", function() end, {})

-- Contrôle avant suppression
ctld_test.assertNotNil(menu:_getNode({"Section A"}),         "T1: Section A présente avant")
ctld_test.assertEqual(#menu.children, 1,                      "T2: 1 enfant racine avant")
ctld_test.assertNotNil(menu._lookup["Section A.Cmd 1"],       "T3: Cmd 1 dans _lookup avant")

-- Suppression
local r = menu:removeMenuBranch({"Section A"})
ctld_test.assert(r.success,                                    "T4: success=true")

-- Contrôle après suppression
ctld_test.assertNil(menu:_getNode({"Section A"}),             "T5: Section A absente après")
ctld_test.assertEqual(#menu.children, 0,                       "T6: racine vide après suppression")
ctld_test.assertNil(menu._lookup["Section A.Cmd 1"],           "T7: Cmd 1 retiré du _lookup")
ctld_test.assertNil(menu._lookup["Section A.Cmd 2"],           "T8: Cmd 2 retiré du _lookup")

ctld_test.finish()
