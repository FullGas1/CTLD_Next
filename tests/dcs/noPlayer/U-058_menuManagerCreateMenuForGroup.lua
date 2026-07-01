---@diagnostic disable
-- ============================================================
-- U-58 : ctld.MenuManager — createMenuForGroup
-- Module  : M8 (src/CTLD_menu.lua)
-- Objectif: succès, idempotence, guards (nil / string)
-- ============================================================

do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_menu.lua")

ctld_test.start("U-58", "ctld.MenuManager createMenuForGroup")

local mgr = ctld.MenuManager:getInstance()

-- T1: valid groupId → menu created
local menu = mgr:createMenuForGroup(9999)
ctld_test.assertNotNil(menu,                        "T1a: menu non-nil pour groupId valide")
ctld_test.assertNotNil(mgr.menus[9999],             "T1b: menu stocké dans mgr.menus[9999]")
ctld_test.assertEqual(menu.groupId, 9999,           "T1c: menu.groupId == 9999")

-- T2: idempotent — second call returns same object
local menu2 = mgr:createMenuForGroup(9999)
ctld_test.assert(menu == menu2,                     "T2: deuxième appel retourne le même objet")

-- T3: nil groupId → nil retourné
local bad1 = mgr:createMenuForGroup(nil)
ctld_test.assertNil(bad1,                           "T3: groupId nil → nil")

-- T4: string groupId → nil retourné
local bad2 = mgr:createMenuForGroup("abc")
ctld_test.assertNil(bad2,                           "T4: groupId string → nil")

ctld_test.finish()
