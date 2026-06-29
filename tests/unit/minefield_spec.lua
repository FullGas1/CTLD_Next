---@diagnostic disable
-- tests/unit/minefield_spec.lua
-- busted specs for mineFieldScene structure and setLandMine guards
-- Reference: live_tests/unit/U-074, U-075
-- ============================================================

-- Resolve repo root so we can dofile src/scenes/CTLD_mineFieldScene.lua
local _thisFile = debug.getinfo(1, "S").source:match("^@(.+)tests[\\/]unit[\\/]")
if not _thisFile then _thisFile = "" end  -- relative path: cwd is repo root

-- ─────────────────────────────────────────────────────────────
describe("mineFieldScene", function()

    -- Load the scene file once before any test.
    -- CTLDSceneManager, CTLDObjectRegistry and CTLDPlayerManager
    -- are already available via tests/helpers/loader.lua.
    setup(function()
        -- Reset singleton so scene registration is clean
        _smInstance = nil
        dofile(_thisFile .. "src/scenes/CTLD_mineFieldScene.lua")
    end)

    -- ── U-074 : structure + auto-registration ─────────────────
    describe("U-074 — structure + auto-registration", function()

        it("model 'mineField' is registered in CTLDSceneManager", function()
            local scene = CTLDSceneManager.getInstance():getModel("mineField")
            assert.is_not_nil(scene)
        end)

        it("scene.name == 'mineField'", function()
            local scene = CTLDSceneManager.getInstance():getModel("mineField")
            assert.equals("mineField", scene.name)
        end)

        it("scene.steps has exactly 1 entry", function()
            local scene = CTLDSceneManager.getInstance():getModel("mineField")
            assert.is_not_nil(scene.steps)
            assert.equals(1, #scene.steps)
        end)

        it("step 1 has delayAfterPreviousStep == 0", function()
            local scene = CTLDSceneManager.getInstance():getModel("mineField")
            assert.equals(0, scene.steps[1].delayAfterPreviousStep)
        end)

        it("step 1 func is a function", function()
            local scene = CTLDSceneManager.getInstance():getModel("mineField")
            assert.equals("function", type(scene.steps[1].func))
        end)

        it("scene.setLandMine is a function", function()
            local scene = CTLDSceneManager.getInstance():getModel("mineField")
            assert.equals("function", type(scene.setLandMine))
        end)

    end)

    -- ── U-075 : setLandMine guards ─────────────────────────────
    describe("U-075 — setLandMine guards", function()

        local scene
        local mockUnit

        before_each(function()
            scene = CTLDSceneManager.getInstance():getModel("mineField")
            mockUnit = {
                _name = "test_heli",
                getName      = function(self) return self._name end,
                getPoint     = function(self) return { x = 0, y = 5, z = 0 } end,
                getPosition  = function(self)
                    return { x = { x = 1, y = 0, z = 0 }, p = { x = 0, y = 5, z = 0 } }
                end,
                getCoalition = function(self) return coalition.side.BLUE end,
                getCountry   = function(self) return 2 end,
                isExist      = function(self) return true end,
            }
        end)

        -- T1: nil unit → false + error message
        it("nil unit → returns false", function()
            local ok, _ = scene.setLandMine(nil, 20, 5, 15, 6, 12)
            assert.is_false(ok)
        end)

        it("nil unit → error message is non-nil", function()
            local _, msg = scene.setLandMine(nil, 20, 5, 15, 6, 12)
            assert.is_not_nil(msg)
        end)

        it("nil unit → error message contains 'ERROR'", function()
            local _, msg = scene.setLandMine(nil, 20, 5, 15, 6, 12)
            assert.is_truthy(type(msg) == "string" and msg:find("ERROR"))
        end)

        -- T2: nbMinesColumns=0 → nbMines=0 → false (unit is valid, guard on nbMines)
        it("nbMinesColumns=0 → returns false", function()
            local ok, _ = scene.setLandMine(mockUnit, 20, 0, 15, 6, 12)
            assert.is_false(ok)
        end)

        it("nbMinesColumns=0 → error message is non-nil", function()
            local _, msg = scene.setLandMine(mockUnit, 20, 0, 15, 6, 12)
            assert.is_not_nil(msg)
        end)

    end)

end)
