---@diagnostic disable
-- ============================================================
-- F-85 : mineFieldScene.setLandMine — 4×3 quinconce (colonnes paires)
-- Module  : M10 (src/scenes/CTLD_mineFieldScene.lua)
-- Objectif: quinconce 4 cols × 3 lignes = 11 mines réelles + quad F10
-- VISUAL  : mines en quinconce 4col×3lig + quad F10
--           row 1 (odd): 4 mines
--           row 2 (even): 3 mines
--           row 3 (odd): 4 mines
--           total = 11 mines
-- ============================================================

do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/core/CTLD_objectRegistry.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_sceneManager.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/scenes/CTLD_mineFieldScene.lua")

ctld_test.start("F-85", "mineFieldScene setLandMine 4x3 quinconce")

local transport = ctld_test.getTransport()
if not transport then ctld_test.finish() return end

local scene = CTLDSceneManager.getInstance():getModel("mineField")
ctld_test.clearMines()

-- 4 colonnes (pair) × 3 lignes — quinconce: 4+3+4 = 11 mines
local ok, result = scene.setLandMine(transport, 20, 4, 3, 6, 12)
ctld_test.saveMineMarks()

ctld_test.assert(ok,              "T1: return true")
ctld_test.assertNotNil(result,    "T2: result non-nil")
ctld_test.assertEqual(#result, 11, "T3: 11 mines spawned — quinconce 4×3 (return value)")

-- Verify all spawned objects actually exist in DCS world via StaticObject.getByName
local existing = 0
for _, obj in ipairs(result) do
    local so = StaticObject.getByName(obj:getName())
    if so and so:isExist() then existing = existing + 1 end
end
ctld_test.assertEqual(existing, 11, "T4: 11 mines existent dans le monde DCS (StaticObject.getByName)")

env.info("[F-85] VISUAL: 11 mines quinconce 4col×3lig + quad F10")

ctld_test.finish()
