---@diagnostic disable
-- ============================================================
-- U-74 : mineFieldScene — structure + auto-registration
-- Module  : M10 (src/scenes/CTLD_mineFieldScene.lua)
-- Note    : mineFieldScene est local dans le fichier source.
--           On l'accède via CTLDSceneManager.getInstance():getModel("mineField")
-- ============================================================

do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/core/CTLD_objectRegistry.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_sceneManager.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/scenes/CTLD_mineFieldScene.lua")

ctld_test.start("U-74", "mineFieldScene structure + auto-registration")

-- Récupère le modèle via CTLDSceneManager (mineFieldScene est local dans le source)
local scene = CTLDSceneManager.getInstance():getModel("mineField")

-- T1: modèle enregistré et accessible
ctld_test.assertNotNil(scene,                        "T1: modèle 'mineField' trouvé dans CTLDSceneManager")

-- T2: nom du modèle
ctld_test.assertEqual(scene.name, "mineField",       "T2: scene.name == 'mineField'")

-- T3: stepsDatas — exactement 1 step
ctld_test.assertNotNil(scene.stepsDatas,             "T3a: stepsDatas non-nil")
ctld_test.assertEqual(#scene.stepsDatas, 1,          "T3b: 1 step déclaré")

-- T4: step 1 — délai 0 et func valide
local step = scene.stepsDatas[1]
ctld_test.assertEqual(step.delayAfterPreviousStep, 0, "T4a: delayAfterPreviousStep == 0")
ctld_test.assertEqual(type(step.func), "function",    "T4b: step.func est une function")

-- T5: setLandMine est une function accessible
ctld_test.assertEqual(type(scene.setLandMine), "function", "T5: setLandMine est une function")

ctld_test.finish()
