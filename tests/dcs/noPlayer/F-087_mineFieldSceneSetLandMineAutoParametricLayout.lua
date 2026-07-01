---@diagnostic disable
-- ============================================================
-- F-87 : mineFieldScene.setLandMineAuto — parametric layout
-- Module  : M10 (src/scenes/CTLD_mineFieldScene.lua)
-- Objectif: width/length/nbMines → correct quinconce spawn
--           T1: 50m × 80m, 40 mines → feasible count near 40
--           T2: single mine (nbMines=1) → 1 mine spawned
--           T3: guards (nil unit, nbMines=0, dims<=0)
-- ============================================================

do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/core/CTLD_objectRegistry.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_sceneManager.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/scenes/CTLD_mineFieldScene.lua")

ctld_test.start("F-87", "mineFieldScene setLandMineAuto parametric")

local transport = ctld_test.getTransport()
if not transport then ctld_test.finish() return end

local scene = CTLDSceneManager.getInstance():getModel("mineField")
ctld_test.clearMines()

-- T1: 50m × 80m, 40 mines — actual count within ±5 of requested
local ok1, r1 = scene.setLandMineAuto(transport, 20, 50, 80, 40)
ctld_test.saveMineMarks()
ctld_test.assert(ok1,                              "T1a: return true")
ctld_test.assertNotNil(r1,                         "T1b: result non-nil")
local n1 = type(r1) == "table" and #r1 or 0
ctld_test.assert(n1 >= 35 and n1 <= 45,            "T1c: mine count near 40 (got " .. tostring(n1) .. ", expect 35–45)")
env.info("[F-87] T1: setLandMineAuto 50x80 ~40 mines → got " .. tostring(n1))

-- T2: nbMines=1 → single mine via single-mine branch
local ok2, r2 = scene.setLandMineAuto(transport, 20, 50, 80, 1)
ctld_test.assert(ok2,                              "T2a: nbMines=1 → return true")
ctld_test.assertEqual(type(r2) == "table" and #r2 or 0, 1, "T2b: nbMines=1 → 1 mine spawned")

-- T3: guards
local ok3, msg3 = scene.setLandMineAuto(nil, 20, 50, 80, 40)
ctld_test.assert(not ok3,                          "T3a: nil unit → false")
ctld_test.assertNotNil(msg3,                       "T3b: error message non-nil")

local ok4, msg4 = scene.setLandMineAuto(transport, 20, 50, 80, 0)
ctld_test.assert(not ok4,                          "T4a: nbMines=0 → false")
ctld_test.assertNotNil(msg4,                       "T4b: error message non-nil")

local ok5, msg5 = scene.setLandMineAuto(transport, 20, 0, 80, 10)
ctld_test.assert(not ok5,                          "T5a: widthMeters=0 → false")
ctld_test.assertNotNil(msg5,                       "T5b: error message non-nil")

ctld_test.finish()
