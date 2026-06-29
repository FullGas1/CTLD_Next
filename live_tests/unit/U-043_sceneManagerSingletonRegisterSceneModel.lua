---@diagnostic disable
-- ============================================================
-- U-43 : CTLDSceneManager singleton + registerSceneModel
-- Module  : R4 (src/CTLD_sceneManager.lua)
-- ============================================================

do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_sceneManager.lua")

trigger.action.outText("U-43: CTLDSceneManager singleton + registerSceneModel", 10)

ctld_test.start("U-43", "CTLDSceneManager singleton + registerSceneModel")

local mgr  = CTLDSceneManager.getInstance()
local mgr2 = CTLDSceneManager.getInstance()

-- Singleton idempotent
ctld_test.assert(mgr == mgr2,                           "getInstance() retourne la même instance")
ctld_test.assertNotNil(mgr,                             "instance non-nil")

-- Built-in FARP Alpha enregistré au démarrage
ctld_test.assertNotNil(mgr:getModel("FARP Alpha"),      "FARP Alpha enregistré built-in")

-- getModel inconnu → nil
ctld_test.assertNil(mgr:getModel("NonExistent"),        "getModel inconnu → nil")

-- registerSceneModel(nil) → false
ctld_test.assert(mgr:registerSceneModel(nil) == false,  "registerSceneModel(nil) → false")

-- registerSceneModel(name="") → false
ctld_test.assert(mgr:registerSceneModel({ name = "", steps = {} }) == false,
                                                        "registerSceneModel(name='') → false")

-- registerSceneModel valide → true
local ok = mgr:registerSceneModel({
    name  = "TestScene_U43",
    steps = { { delayAfterPreviousStep = 0, func = function(_ctx) end } },
})
ctld_test.assert(ok == true,                            "registerSceneModel valide → true")
ctld_test.assertNotNil(mgr:getModel("TestScene_U43"),   "getModel retrouve le modèle enregistré")

-- Double enregistrement → false
ctld_test.assert(
    mgr:registerSceneModel({ name = "TestScene_U43", steps = {} }) == false,
    "duplicate registerSceneModel → false"
)

ctld_test.finish()
