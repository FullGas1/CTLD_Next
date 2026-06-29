---@diagnostic disable
-- ============================================================
-- U-57 : ctld.MenuManager — singleton
-- Module  : M8 (src/CTLD_menu.lua)
-- Objectif: getInstance() idempotent — même instance retournée
-- ============================================================

do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_menu.lua")

-- Reset singleton (CTLD_menu.lua does it at module level, but explicit for clarity)
ctld.MenuManager._instance = nil

ctld_test.start("U-57", "ctld.MenuManager singleton")

local i1 = ctld.MenuManager:getInstance()
local i2 = ctld.MenuManager:getInstance()

ctld_test.assertNotNil(i1,          "T1: getInstance() returns non-nil")
ctld_test.assert(i1 == i2,          "T2: two calls return same instance")
ctld_test.assertNotNil(i1.menus,    "T3: menus table initialized")

ctld_test.finish()
