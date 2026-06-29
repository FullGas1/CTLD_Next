---@diagnostic disable
-- ============================================================
-- F-86 : mineFieldScene — showMinefieldOnF10Map = false
-- Module  : M10 (src/scenes/CTLD_mineFieldScene.lua)
-- Objectif: drawQuad NOT called when config param is false
--           drawQuad IS called when config param is true (default)
-- ============================================================

do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/core/CTLD_objectRegistry.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_sceneManager.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/scenes/CTLD_mineFieldScene.lua")

ctld_test.start("F-86", "mineFieldScene showMinefieldOnF10Map config guard")

local transport = ctld_test.getTransport()
if not transport then ctld_test.finish() return end

local scene = CTLDSceneManager.getInstance():getModel("mineField")

ctld_test.clearMines()

-- Intercept ctld.utils.drawQuad to count calls
local drawQuadCallCount = 0
local originalDrawQuad = ctld.utils.drawQuad
ctld.utils.drawQuad = function(...)
    drawQuadCallCount = drawQuadCallCount + 1
    return originalDrawQuad(...)
end

-- T1: showMinefieldOnF10Map = false → drawQuad NOT called
CTLDConfig.get().settings["showMinefieldOnF10Map"] = false
drawQuadCallCount = 0
local ok1, r1 = scene.setLandMine(transport, 20, 3, 2, 6, 12)
ctld_test.assert(ok1,                               "T1a: setLandMine returns true (config=false)")
ctld_test.assertEqual(drawQuadCallCount, 0,         "T1b: drawQuad NOT called when showMinefieldOnF10Map=false")

-- T2: showMinefieldOnF10Map = true → drawQuad called once
CTLDConfig.get().settings["showMinefieldOnF10Map"] = true
drawQuadCallCount = 0
local ok2, r2 = scene.setLandMine(transport, 20, 3, 2, 6, 12)
ctld_test.assert(ok2,                               "T2a: setLandMine returns true (config=true)")
ctld_test.assertEqual(drawQuadCallCount, 1,         "T2b: drawQuad called once when showMinefieldOnF10Map=true")

-- Restore
ctld.utils.drawQuad = originalDrawQuad

ctld_test.finish()
