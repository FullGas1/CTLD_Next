---@diagnostic disable
-- ============================================================
-- F-83 : mineFieldScene.setLandMine — 1×1 (single mine)
-- Module  : M10 (src/scenes/CTLD_mineFieldScene.lua)
-- Objectif: 1 mine spawned réel + carré F10 dessiné
-- VISUAL  : 1 mine visible dans la mission + carré F10 autour
-- ============================================================

do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/core/CTLD_objectRegistry.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_sceneManager.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/scenes/CTLD_mineFieldScene.lua")

ctld_test.start("F-83", "mineFieldScene setLandMine 1x1 single mine")

local transport = ctld_test.getTransport()
if not transport then ctld_test.finish() return end

local scene = CTLDSceneManager.getInstance():getModel("mineField")
ctld_test.clearMines()

-- 1 colonne × 1 mine, 20m devant le transport
local ok, result = scene.setLandMine(transport, 20, 1, 1, 6, 12)
ctld_test.saveMineMarks()

ctld_test.assert(ok,                         "T1: return true")
ctld_test.assertNotNil(result,               "T2: result non-nil")
ctld_test.assertEqual(type(result), "table", "T3: result est une table")
ctld_test.assertEqual(#result, 1,            "T4: 1 objet spawné (return value)")

-- Verify spawned objects actually exist in DCS world via StaticObject.getByName
local existing = 0
for _, obj in ipairs(result) do
    local so = StaticObject.getByName(obj:getName())
    if so and so:isExist() then existing = existing + 1 end
end
ctld_test.assertEqual(existing, 1,           "T5: 1 mine existe dans le monde DCS (StaticObject.getByName)")

env.info("[F-83] VISUAL: 1 mine spawned ~20m devant le transport + carré F10")

ctld_test.finish()
