---@diagnostic disable
-- ============================================================
-- F-43 : FARP Alpha scene — structure validation
-- Module  : R4 (src/CTLD_sceneManager.lua)
-- ============================================================

do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_sceneManager.lua")

trigger.action.outText("F-43: FARP Alpha scene structure validation | scene: FARP Alpha", 15)

ctld_test.start("F-43", "FARP Alpha scene — 14 steps, keys et types de steps")

local mgr = CTLDSceneManager.getInstance()

-- Built-in registered
local model = mgr:getModel("FARP Alpha")
ctld_test.assertNotNil(model,                                   "FARP Alpha enregistré built-in")

local steps = model.steps

-- 14 steps total (13 spawn + 1 func)
ctld_test.assertEqual(#steps, 14,                               "14 steps dans FARP Alpha")

-- Step 1: SINGLE_HELIPAD — polar + func
ctld_test.assertEqual(steps[1].registryKey, "SINGLE_HELIPAD",  "step 1 : registryKey = SINGLE_HELIPAD")
ctld_test.assertNotNil(steps[1].polar,                         "step 1 : type polar présent")
ctld_test.assertEqual(steps[1].polar.distance, 100,            "step 1 : polar.distance = 100")
ctld_test.assertEqual(steps[1].polar.angle, 0,                 "step 1 : polar.angle = 0")
ctld_test.assertNotNil(steps[1].func,                          "step 1 : func (fuel warehouse)")

-- Step 14: func-only (completion message)
ctld_test.assertNil(steps[14].registryKey,                     "step 14 : func-only (pas de registryKey)")
ctld_test.assertNotNil(steps[14].func,                         "step 14 : func présente (completion message)")

-- All polar steps carry relativeHeadingInDegrees
ctld_test.assertNotNil(steps[2].relativeHeadingInDegrees,      "step 2 : relativeHeadingInDegrees présent")

-- delayAfterPreviousStep present on all steps
local allHaveDelay = true
for i, s in ipairs(steps) do
    if s.delayAfterPreviousStep == nil then
        allHaveDelay = false
        break
    end
end
ctld_test.assert(allHaveDelay,                                  "tous les steps ont delayAfterPreviousStep")

ctld_test.finish()
