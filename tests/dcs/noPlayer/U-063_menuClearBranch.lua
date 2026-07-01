---@diagnostic disable
-- ============================================================
-- U-63 : ctld.Menu — clearBranch
-- Module  : M8 (src/CTLD_menu.lua)
-- Objectif: vide children, container intact, guards
-- ============================================================

do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_menu.lua")

ctld_test.start("U-63", "ctld.Menu clearBranch")

local mgr  = ctld.MenuManager:getInstance()
local menu = mgr:createMenuForGroup(9999)
menu:addSubMenu({}, "Pack Vehicles")
menu:addCommand({"Pack Vehicles"}, "Vehicle A", function() end, {})
menu:addCommand({"Pack Vehicles"}, "Vehicle B", function() end, {})

-- T1: avant clearBranch — 2 enfants
local nodeBefore = menu:_getNode({"Pack Vehicles"})
ctld_test.assertEqual(#(nodeBefore and nodeBefore.children or {}), 2, "T1: 2 enfants avant clearBranch")

-- T2: clearBranch → success
local r = menu:clearBranch({"Pack Vehicles"})
ctld_test.assert(r.success, "T2: clearBranch retourne success=true")

-- T3: après clearBranch — container vide mais toujours présent
local nodeAfter = menu:_getNode({"Pack Vehicles"})
ctld_test.assertNotNil(nodeAfter,                                 "T3a: container node toujours présent")
ctld_test.assertEqual(#(nodeAfter and nodeAfter.children or {}), 0, "T3b: children vide après clearBranch")

-- T4: container toujours dans les children du parent (root)
ctld_test.assertEqual(#menu.children, 1, "T4: Pack Vehicles toujours dans les children root")

-- T5: clearBranch sur path inconnu → failure
local r2 = menu:clearBranch({"Inexistant"})
ctld_test.assert(not r2.success, "T5: failure si path inconnu")

-- T6: clearBranch sur command node → failure
menu:addCommand({"Pack Vehicles"}, "Solo Cmd", function() end, {})
local r3 = menu:clearBranch({"Pack Vehicles", "Solo Cmd"})
ctld_test.assert(not r3.success, "T6: failure si target est un command node")

ctld_test.finish()
