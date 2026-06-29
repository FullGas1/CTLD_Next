---@diagnostic disable
-- ============================================================
-- U-65 : ctld.Menu — removeMenuBranch
-- Module  : M8 (src/CTLD_menu.lua)
-- Objectif: suppression + removedCount, root guard, path inconnu
-- ============================================================

do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_menu.lua")

ctld_test.start("U-65", "ctld.Menu removeMenuBranch")

local mgr  = ctld.MenuManager:getInstance()
local menu = mgr:createMenuForGroup(9999)
menu:addSubMenu({}, "Section A")
menu:addCommand({"Section A"}, "Cmd 1", function() end, {})
menu:addCommand({"Section A"}, "Cmd 2", function() end, {})

-- T1: avant suppression — Section A accessible
ctld_test.assertNotNil(menu:_getNode({"Section A"}), "T1: Section A présente avant suppression")

-- T2: removeMenuBranch → success + removedCount = 3 (1 submenu + 2 commands)
local r = menu:removeMenuBranch({"Section A"})
ctld_test.assert(r.success,             "T2a: success=true")
ctld_test.assertEqual(r.removedCount, 3, "T2b: removedCount = 3")

-- T3: après suppression — Section A inaccessible
ctld_test.assertNil(menu:_getNode({"Section A"}), "T3: Section A absente après suppression")

-- T4: _lookup nettoyé — les clés enfants supprimées
ctld_test.assertNil(menu._lookup["Section A.Cmd 1"], "T4a: Cmd 1 retiré du _lookup")
ctld_test.assertNil(menu._lookup["Section A.Cmd 2"], "T4b: Cmd 2 retiré du _lookup")

-- T5: root path {} → failure (cannot remove root)
local r2 = menu:removeMenuBranch({})
ctld_test.assert(not r2.success, "T5: failure si pathTable vide (root)")

-- T6: path inconnu → failure
local r3 = menu:removeMenuBranch({"Inexistant"})
ctld_test.assert(not r3.success, "T6: failure si path inconnu")

ctld_test.finish()
