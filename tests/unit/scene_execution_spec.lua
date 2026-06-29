---@diagnostic disable
-- tests/unit/scene_execution_spec.lua
-- busted specs for CtldScene execution engine (func-only steps, onComplete)
-- Reference: live_tests/unit/U-044
-- ============================================================

-- ─────────────────────────────────────────────────────────────
describe("CtldScene execution engine — func-only steps, onComplete", function()
    -- U-044
    -- With delayAfterPreviousStep=0 and timer.getTime()=0 (stub),
    -- timeMarker=0 and 0>0 is false → all steps execute synchronously.

    local mgr
    local mockUnit

    before_each(function()
        -- Reset singleton so scene counter also resets cleanly
        _smInstance = nil   -- module-local in CTLD_sceneManager.lua
        mgr = CTLDSceneManager.getInstance()

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

    -- ── playScene returns a scene instance ────────────────────
    describe("playScene() return value", function()

        it("returns non-nil for a registered model", function()
            local model = { name = "Test_ReturnVal", steps = {
                { delayAfterPreviousStep = 0, func = function() end },
            }}
            mgr:registerSceneModel(model)
            local scene = mgr:playScene(mockUnit, "Test_ReturnVal", {}, nil)
            assert.is_not_nil(scene)
        end)

        it("returns nil for unknown model", function()
            local scene = mgr:playScene(mockUnit, "NonExistentModel", {}, nil)
            assert.is_nil(scene)
        end)

        it("returns nil when unit is nil", function()
            local model = { name = "Test_NilUnit", steps = {
                { delayAfterPreviousStep = 0, func = function() end },
            }}
            mgr:registerSceneModel(model)
            local scene = mgr:playScene(nil, "Test_NilUnit", {}, nil)
            assert.is_nil(scene)
        end)

    end)

    -- ── 3 func-only steps execute synchronously ───────────────
    describe("3 func-only steps with delay=0", function()

        local execOrder, ctxCapture, completedScene, model

        before_each(function()
            execOrder     = {}
            ctxCapture    = {}
            completedScene = nil

            model = {
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
            mgr:registerSceneModel(model)
            mgr:playScene(mockUnit, "TestExec_U44", { testParam = 42 },
                function(s) completedScene = s end)
        end)

        it("3 steps were executed", function()
            assert.equals(3, #execOrder)
        end)

        it("step 1 executed first", function()
            assert.equals(1, execOrder[1])
        end)

        it("step 2 executed second", function()
            assert.equals(2, execOrder[2])
        end)

        it("step 3 executed third", function()
            assert.equals(3, execOrder[3])
        end)

        it("onComplete is called after last step", function()
            assert.is_not_nil(completedScene)
        end)

        it("onComplete receives the scene instance", function()
            local scene = mgr:playScene(mockUnit, "TestExec_U44", {}, function(s) completedScene = s end)
            assert.equals(scene, completedScene)
        end)

        it("ctx.scene._params.testParam == 42", function()
            assert.is_not_nil(ctxCapture[1])
            assert.equals(42, ctxCapture[1].scene._params.testParam)
        end)

        it("ctx.scene is the same instance across all steps", function()
            assert.equals(ctxCapture[1].scene, ctxCapture[2].scene)
            assert.equals(ctxCapture[2].scene, ctxCapture[3].scene)
        end)

        it("ctx.unit is the mockUnit", function()
            assert.equals(mockUnit, ctxCapture[1].unit)
        end)

    end)

    -- ── crashing step is isolated ─────────────────────────────
    describe("crashing step isolation", function()

        it("a crashing func does not stop execution of subsequent steps", function()
            local afterCrash = false
            local model = {
                name  = "TestCrash",
                steps = {
                    {
                        delayAfterPreviousStep = 0,
                        func = function() error("intentional crash") end,
                    },
                    {
                        delayAfterPreviousStep = 0,
                        func = function() afterCrash = true end,
                    },
                },
            }
            mgr:registerSceneModel(model)
            assert.has_no_error(function()
                mgr:playScene(mockUnit, "TestCrash", {}, nil)
            end)
            assert.is_true(afterCrash)
        end)

    end)

    -- ── duplicate model registration ──────────────────────────
    describe("registerSceneModel()", function()

        it("re-registering same name is silently ignored", function()
            local calls = 0
            local m1 = { name = "DupModel", steps = {{ delayAfterPreviousStep = 0, func = function() calls = calls + 1 end }} }
            local m2 = { name = "DupModel", steps = {{ delayAfterPreviousStep = 0, func = function() calls = calls + 10 end }} }
            mgr:registerSceneModel(m1)
            mgr:registerSceneModel(m2)  -- should be ignored
            mgr:playScene(mockUnit, "DupModel", {}, nil)
            -- m1's func called (calls=1), m2 ignored
            assert.equals(1, calls)
        end)

    end)

    -- ── getModel / getScene ───────────────────────────────────
    describe("getModel() / getScene()", function()

        it("getModel returns the registered model table", function()
            local m = { name = "ModelLookup", steps = {{ delayAfterPreviousStep = 0, func = function() end }} }
            mgr:registerSceneModel(m)
            assert.equals(m, mgr:getModel("ModelLookup"))
        end)

        it("getModel returns nil for unknown name", function()
            assert.is_nil(mgr:getModel("NoSuchModel_XYZ"))
        end)

    end)

end)
