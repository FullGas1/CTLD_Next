---@diagnostic disable
-- ============================================================
-- U-61 : ctld.Menu — addSubMenu guards
-- Module  : M8 (src/CTLD_menu.lua)
-- Objectif: name nil, parent = command node → failure
-- ============================================================

do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_menu.lua")

ctld_test.start("U-61", "ctld.Menu addSubMenu guards")

local mgr  = ctld.MenuManager:getInstance()
local menu = mgr:createMenuForGroup(9999)

-- T1: menuName nil → failure
local r1 = menu:addSubMenu({}, nil)
ctld_test.assert(not r1.success,    "T1a: success=false si name=nil")
ctld_test.assertNil(r1.subMenuId,   "T1b: subMenuId=nil si name=nil")

-- T2: menuName number → failure
local r2 = menu:addSubMenu({}, 123)
ctld_test.assert(not r2.success,    "T2: success=false si name=number")

-- T3: parent = command node → cannot add submenu under command
menu:addSubMenu({}, "Section")
menu:addCommand({"Section"}, "My Command", function() end, {})
local r3 = menu:addSubMenu({"Section", "My Command"}, "ChildMenu")
ctld_test.assert(not r3.success,    "T3: success=false si parent=command node")

ctld_test.finish()
