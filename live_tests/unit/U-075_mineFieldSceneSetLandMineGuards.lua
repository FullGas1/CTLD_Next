---@diagnostic disable
-- ============================================================
-- U-75 : mineFieldScene.setLandMine — guards
-- Module  : M10 (src/scenes/CTLD_mineFieldScene.lua)
-- Objectif: nil unit → false ; nbMinesColumns=0 + unit réel → false
-- ============================================================

do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/core/CTLD_objectRegistry.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_sceneManager.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/scenes/CTLD_mineFieldScene.lua")

ctld_test.start("U-75", "mineFieldScene.setLandMine guards")

local scene = CTLDSceneManager.getInstance():getModel("mineField")

-- T1: nil unit → false + message d'erreur
local ok1, msg1 = scene.setLandMine(nil, 20, 5, 15, 6, 12)
ctld_test.assert(not ok1,          "T1a: nil unit → false")
ctld_test.assertNotNil(msg1,       "T1b: message d'erreur non-nil")
ctld_test.assert(type(msg1) == "string" and msg1:find("ERROR"), "T1c: message contient 'ERROR'")

-- T2: nbMinesColumns=0 + unit réel → nbMines=0 → false
local transport = ctld_test.getTransport()
if not transport then ctld_test.finish() return end

local ok2, msg2 = scene.setLandMine(transport, 20, 0, 15, 6, 12)
ctld_test.assert(not ok2,          "T2a: nbMinesColumns=0 → false")
ctld_test.assertNotNil(msg2,       "T2b: message d'erreur non-nil")

ctld_test.finish()
