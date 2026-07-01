---@diagnostic disable
-- ============================================================
-- F-42 : CTLDSceneManager.playScene — guards
-- Module  : R4 (src/CTLD_sceneManager.lua)
-- ============================================================

do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_sceneManager.lua")

trigger.action.outText("F-42: CTLDSceneManager playScene guards", 10)

ctld_test.start("F-42", "playScene — guards: nil unit, dead unit, unknown model, valid call")

-- Stub CTLDObjectRegistry (not used by func-only steps)
CTLDObjectRegistry = CTLDObjectRegistry or {
    get         = function() return nil end,
    spawnObject = function() return nil end,
}

-- Mock unit alive
local aliveUnit = {
    getName      = function(self) return "test_heli" end,
    getPoint     = function(self) return { x = 0, y = 5, z = 0 } end,
    getPosition  = function(self) return { x = { x = 1, y = 0, z = 0 }, p = { x = 0, y = 5, z = 0 } } end,
    getCoalition = function(self) return coalition.side.BLUE end,
    getCountry   = function(self) return 2 end,
    isExist      = function(self) return true end,
}

-- Mock unit dead
local deadUnit = {
    getName      = function(self) return "dead_heli" end,
    getPoint     = function(self) return { x = 0, y = 5, z = 0 } end,
    getPosition  = function(self) return { x = { x = 1, y = 0, z = 0 }, p = { x = 0, y = 5, z = 0 } } end,
    getCoalition = function(self) return coalition.side.BLUE end,
    getCountry   = function(self) return 2 end,
    isExist      = function(self) return false end,
}

local mgr = CTLDSceneManager.getInstance()

-- Register a minimal model for the valid-call test
mgr:registerSceneModel({
    name  = "MinimalF42",
    steps = { { delayAfterPreviousStep = 0, func = function(_ctx) end } },
})

-- Guard: nil unit → nil
ctld_test.assertNil(mgr:playScene(nil, "MinimalF42"),       "nil unit → nil")

-- Guard: dead unit (isExist=false) → nil
ctld_test.assertNil(mgr:playScene(deadUnit, "MinimalF42"),  "dead unit → nil")

-- Guard: unknown model → nil
ctld_test.assertNil(mgr:playScene(aliveUnit, "NoSuchModel"), "unknown model → nil")

-- Valid call → scene returned
local scene = mgr:playScene(aliveUnit, "MinimalF42")
ctld_test.assertNotNil(scene,                               "unit vivant + modèle valide → scène retournée")

ctld_test.finish()
