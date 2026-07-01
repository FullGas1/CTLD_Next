---@diagnostic disable
-- ============================================================
-- U-62 : ctld.Menu — addCommand succès + guards
-- Module  : M8 (src/CTLD_menu.lua)
-- Objectif: succès, anyArgument nil→{}, guards fn/arg/name invalides
-- ============================================================

do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_menu.lua")

ctld_test.start("U-62", "ctld.Menu addCommand succes + guards")

local mgr  = ctld.MenuManager:getInstance()
local menu = mgr:createMenuForGroup(9999)
menu:addSubMenu({}, "Section")

local callbackFired = false
local cbArg = nil

-- T1: succès — avec anyArgument
local r1 = menu:addCommand({"Section"}, "Do Thing", function(arg) callbackFired = true cbArg = arg end, { id = 7 })
ctld_test.assert(r1.success,            "T1a: success=true")
ctld_test.assertNotNil(r1.commandId,    "T1b: commandId non-nil")

-- T2: anyArgument nil → node.anyArgument == {}
local r2 = menu:addCommand({"Section"}, "No Arg Cmd", function() end, nil)
ctld_test.assert(r2.success, "T2a: success même avec anyArgument nil")
local node2 = menu:_getNode({"Section", "No Arg Cmd"})
ctld_test.assertNotNil(node2 and node2.anyArgument, "T2b: anyArgument non-nil (default {})")
ctld_test.assertEqual(type(node2 and node2.anyArgument), "table", "T2c: anyArgument est une table")

-- T3: commandName nil → failure
local r3 = menu:addCommand({"Section"}, nil, function() end, {})
ctld_test.assert(not r3.success,    "T3: failure si commandName=nil")

-- T4: fn non-function → failure
local r4 = menu:addCommand({"Section"}, "Bad Fn", "not_a_function", {})
ctld_test.assert(not r4.success,    "T4: failure si fn n'est pas une function")

-- T5: anyArgument non-table → failure
local r5 = menu:addCommand({"Section"}, "Bad Arg", function() end, "string_arg")
ctld_test.assert(not r5.success,    "T5: failure si anyArgument est une string")

-- T6: parent = command node → failure
menu:addCommand({"Section"}, "Leaf", function() end, {})
local r6 = menu:addCommand({"Section", "Leaf"}, "ChildCmd", function() end, {})
ctld_test.assert(not r6.success,    "T6: failure si parent est un command node")

ctld_test.finish()
