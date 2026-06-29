---@diagnostic disable
-- ============================================================
-- U-01 : EventDispatcher — singleton
-- Module  : C1 (src/CTLD_core.lua)
-- Objectif: Vérifier que deux appels à EventDispatcher.getInstance()
--           retournent exactement la même instance (même référence).
-- ============================================================

-- Purge CTLD.log
do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")

-- Load module under test
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_core.lua")

ctld_test.start("U-01", "EventDispatcher — singleton")

-- Reset singleton to ensure clean state for this test
EventDispatcher._instance = nil

local inst1 = EventDispatcher.getInstance()
local inst2 = EventDispatcher.getInstance()

ctld_test.assertNotNil(inst1, "getInstance() retourne une instance non-nil")
ctld_test.assert(inst1 == inst2, "deux appels getInstance() retournent la même référence")
ctld_test.assert(type(inst1._listeners) == "table", "_listeners est une table")

ctld_test.finish()
