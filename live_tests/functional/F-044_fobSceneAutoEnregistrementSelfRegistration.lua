---@diagnostic disable
-- ============================================================
-- F-44 : fobScene auto-enregistrement (self-registration)
-- Module  : R4 (src/scenes/CTLD_fobScene.lua)
-- ============================================================

do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_sceneManager.lua")

trigger.action.outText("F-44: fobScene self-registration | scene: fobScene", 15)

ctld_test.start("F-44", "fobScene auto-enregistrement dans CTLDSceneManager + structure")

local mgr = CTLDSceneManager.getInstance()

-- Before dofile: "fobScene" not yet registered
ctld_test.assertNil(mgr:getModel("fobScene"),                  "fobScene absent avant dofile CTLD_fobScene")

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/scenes/CTLD_fobScene.lua")

-- After dofile: self-registration fired
ctld_test.assertNotNil(mgr:getModel("fobScene"),               "fobScene enregistré après dofile")

local fob = mgr:getModel("fobScene")

-- 4 steps: prescript + container + watchtower + completion
ctld_test.assertEqual(#fob.steps, 4,                           "4 steps dans fobScene")

-- Step 1 (index 1): prescript — func-only, no registryKey
ctld_test.assertNil(fob.steps[1].registryKey,                  "step 0 (prescript) : pas de registryKey")
ctld_test.assertNotNil(fob.steps[1].func,                      "step 0 (prescript) : func présente")

-- Step 2 (index 2): FOB_container
ctld_test.assertEqual(fob.steps[2].registryKey, "FOB_container",
                                                               "step 1 : registryKey = FOB_container")
ctld_test.assertNotNil(fob.steps[2].polar,                     "step 1 : type polar présent")

-- Step 3 (index 3): FOB_watchtower
ctld_test.assertEqual(fob.steps[3].registryKey, "FOB_watchtower",
                                                               "step 2 : registryKey = FOB_watchtower")

-- Step 4 (index 4): completion — func-only
ctld_test.assertNil(fob.steps[4].registryKey,                  "step 3 (completion) : pas de registryKey")
ctld_test.assertNotNil(fob.steps[4].func,                      "step 3 (completion) : func présente")

ctld_test.finish()
