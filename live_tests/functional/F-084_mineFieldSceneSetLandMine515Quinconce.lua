---@diagnostic disable
-- ============================================================
-- F-84 : mineFieldScene.setLandMine — 5×15 quinconce
-- Module  : M10 (src/scenes/CTLD_mineFieldScene.lua)
-- Objectif: quinconce 5 cols × 15 lignes = 68 mines réelles + grand quad F10
-- VISUAL  : mines en quinconce 5col×15lig + quad F10
--           odd rows (1,3,...,15) : 8 × 5 = 40 mines
--           even rows (2,4,...,14): 7 × 4 = 28 mines
--           total = 68 mines
-- ============================================================

do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/core/CTLD_objectRegistry.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_sceneManager.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/scenes/CTLD_mineFieldScene.lua")

ctld_test.start("F-84", "mineFieldScene setLandMine 5x15 quinconce")

local transport = ctld_test.getTransport()
if not transport then ctld_test.finish() return end

local scene = CTLDSceneManager.getInstance():getModel("mineField")
ctld_test.clearMines()

-- 5 colonnes (impair) × 15 lignes — quinconce: 8×5 + 7×4 = 68 mines
local ok, result = scene.setLandMine(transport, 20, 5, 15, 6, 12)
ctld_test.saveMineMarks()

ctld_test.assert(ok,              "T1: return true")
ctld_test.assertNotNil(result,    "T2: result non-nil")
ctld_test.assertEqual(#result, 68, "T3: 68 mines spawned — quinconce 5×15 (return value)")

-- Verify all spawned objects actually exist in DCS world via StaticObject.getByName
local existing = 0
for _, obj in ipairs(result) do
    local so = StaticObject.getByName(obj:getName())
    if so and so:isExist() then existing = existing + 1 end
end
ctld_test.assertEqual(existing, 68, "T4: 68 mines existent dans le monde DCS (StaticObject.getByName)")

env.info("[F-84] VISUAL: 68 mines quinconce 5col×15lig + grand quad F10")

ctld_test.finish()
