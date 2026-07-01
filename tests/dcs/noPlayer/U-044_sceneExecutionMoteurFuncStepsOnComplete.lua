---@diagnostic disable
-- ============================================================
-- U-44 : CtldScene exécution moteur — func steps, onComplete
-- Module  : R4 (src/CTLD_sceneManager.lua)
-- ============================================================

do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_sceneManager.lua")

trigger.action.outText("U-44: CtldScene execution engine (func-only steps) | scene: TestExec_U44", 15)

ctld_test.start("U-44", "CtldScene step execution engine — func-only steps, delay=0, onComplete")

-- Stub CTLDObjectRegistry (not used for func-only steps but must be defined)
CTLDObjectRegistry = CTLDObjectRegistry or {
    get         = function() return nil end,
    spawnObject = function() return nil end,
}

-- Mock unit (DCS Position3 with x=forward vector, p=position point)
local mockUnit = {
    getName      = function(self) return "test_heli" end,
    getPoint     = function(self) return { x = 0, y = 5, z = 0 } end,
    getPosition  = function(self) return { x = { x = 1, y = 0, z = 0 }, p = { x = 0, y = 5, z = 0 } } end,
    getCoalition = function(self) return coalition.side.BLUE end,
    getCountry   = function(self) return 2 end,
    isExist      = function(self) return true end,
}

-- Model with 3 func-only steps, all delay=0 → executes synchronously (no scheduleFunction)
local execOrder = {}
local ctxCapture = {}

local model = {
    name  = "TestExec_U44",
    steps = {
        {
            delayAfterPreviousStep = 0,
            func = function(ctx)
                table.insert(execOrder, 1)
                ctxCapture[1] = ctx
            end,
        },
        {
            delayAfterPreviousStep = 0,
            func = function(ctx)
                table.insert(execOrder, 2)
                ctxCapture[2] = ctx
            end,
        },
        {
            delayAfterPreviousStep = 0,
            func = function(ctx)
                table.insert(execOrder, 3)
                ctxCapture[3] = ctx
            end,
        },
    },
}

local mgr = CTLDSceneManager.getInstance()
mgr:registerSceneModel(model)

local completedScene = nil
local scene = mgr:playScene(mockUnit, "TestExec_U44", { testParam = 42 }, function(s)
    completedScene = s
end)

-- Scene instance returned
ctld_test.assertNotNil(scene,                           "playScene retourne une instance CtldScene")

-- 3 steps executed
ctld_test.assertEqual(#execOrder, 3,                    "3 steps exécutés")

-- Executed in order
ctld_test.assertEqual(execOrder[1], 1,                  "step 1 exécuté en premier")
ctld_test.assertEqual(execOrder[2], 2,                  "step 2 exécuté en second")
ctld_test.assertEqual(execOrder[3], 3,                  "step 3 exécuté en dernier")

-- onComplete fired with the scene instance
ctld_test.assertNotNil(completedScene,                  "onComplete appelé après le dernier step")
ctld_test.assert(completedScene == scene,               "onComplete reçoit la bonne instance de scène")

-- ctx.scene._params forwarded
ctld_test.assertEqual(
    ctxCapture[1] and ctxCapture[1].scene._params.testParam, 42,
    "ctx.scene._params.testParam transmis correctement"
)

ctld_test.finish()
