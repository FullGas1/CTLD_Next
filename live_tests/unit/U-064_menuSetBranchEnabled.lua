---@diagnostic disable
-- ============================================================
-- U-64 : ctld.Menu — setBranchEnabled
-- Module  : M8 (src/CTLD_menu.lua)
-- Objectif: toggle enabled true/false, guard path inconnu
-- ============================================================

do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_menu.lua")

ctld_test.start("U-64", "ctld.Menu setBranchEnabled")

local mgr  = ctld.MenuManager:getInstance()
local menu = mgr:createMenuForGroup(9999)
menu:addSubMenu({}, "FOB Section")

-- T1: enable=true (déjà true par défaut) → node.enabled == true
local r1 = menu:setBranchEnabled({"FOB Section"}, true)
ctld_test.assert(r1.success, "T1a: success=true")
local node = menu:_getNode({"FOB Section"})
ctld_test.assert(node and node.enabled == true, "T1b: node.enabled == true après setBranchEnabled(true)")

-- T2: disable → node.enabled == false
local r2 = menu:setBranchEnabled({"FOB Section"}, false)
ctld_test.assert(r2.success, "T2a: success=true")
ctld_test.assert(node and node.enabled == false, "T2b: node.enabled == false après setBranchEnabled(false)")

-- T3: re-enable → node.enabled == true
menu:setBranchEnabled({"FOB Section"}, true)
ctld_test.assert(node and node.enabled == true, "T3: node.enabled == true après re-enable")

-- T4: path inconnu → failure
local r4 = menu:setBranchEnabled({"Inexistant"}, true)
ctld_test.assert(not r4.success, "T4: failure si path inconnu")

ctld_test.finish()
