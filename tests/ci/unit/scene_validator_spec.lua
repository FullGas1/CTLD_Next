---@diagnostic disable
-- tests/unit/scene_validator_spec.lua
-- busted specs for the scene mod-validation pipeline:
--   CTLDSceneManager:_auditAfterModValidator()  (P1)
--   CTLDSceneManager:isSceneEnabled()           (P1)
--   CTLDCrateManager:_purgeDisabledScenes()     (P1)
--   _injectSceneCrate disabled guard            (P1)
--   CTLDSceneManager:playScene disabled guard   (P1)
--   requiresMod WARN emission                   (P2)
--   step.critical abort                         (P3)
-- ============================================================

-- ─────────────────────────────────────────────────────────────
-- Shared helpers / setup
-- ─────────────────────────────────────────────────────────────

local function makeUnit()
    return {
        getName      = function(_) return "test_unit" end,
        getPoint     = function(_) return { x = 0, y = 5, z = 0 } end,
        getPosition  = function(_)
            return { x = { x = 1, y = 0, z = 0 }, p = { x = 0, y = 5, z = 0 } }
        end,
        getCoalition = function(_) return coalition.side.BLUE end,
        getCountry   = function(_) return 2 end,
        isExist      = function(_) return true end,
    }
end

-- ─────────────────────────────────────────────────────────────
-- U-120 — _auditAfterModValidator: disabled flag propagation
-- ─────────────────────────────────────────────────────────────
describe("U-120 — _auditAfterModValidator: disabled flag propagation", function()

    local sm, mv

    before_each(function()
        -- Reset singletons
        _smInstance = nil
        CTLDModValidator._instance = nil
        CTLDCrateManager._instance = nil
        _cmInstance = nil

        sm = CTLDSceneManager.getInstance()
        mv = CTLDModValidator.getInstance()
        mv._probePos = { x = 0, z = 0 }
    end)

    it("C1: scene with a registry entry whose STATIC type is invalid → model._disabled = true", function()
        -- Register object type in the registry
        CTLDObjectRegistry.registerIfAbsent("__test_static_bad__", {
            groupType = "STATIC",
            type      = "BadStaticTypeMod_XYZ",
            category  = "Fortifications",
        })
        -- Mark the type as invalid in the validator cache
        mv._cache["S:BadStaticTypeMod_XYZ"] = false

        local model = {
            name  = "TestSceneBadStatic",
            steps = {
                { registryKey = "__test_static_bad__", polar = { distance = 10, angle = 0 },
                  delayAfterPreviousStep = 0 },
            },
        }
        sm:registerSceneModel(model)
        sm:_auditAfterModValidator()

        assert.is_true(model._disabled == true)
    end)

    it("C2: scene with a registry entry whose GROUND type is invalid → model._disabled = true", function()
        CTLDObjectRegistry.registerIfAbsent("__test_ground_bad__", {
            groupType = "GROUND",
            type      = "BadGroundTypeMod_XYZ",
            category  = nil,
        })
        mv._cache["G:BadGroundTypeMod_XYZ"] = false

        local model = {
            name  = "TestSceneBadGround",
            steps = {
                { registryKey = "__test_ground_bad__", polar = { distance = 5, angle = 0 },
                  delayAfterPreviousStep = 0 },
            },
        }
        sm:registerSceneModel(model)
        sm:_auditAfterModValidator()

        assert.is_true(model._disabled == true)
    end)

    it("C3: scene with all valid types → model._disabled is nil/false", function()
        CTLDObjectRegistry.registerIfAbsent("__test_static_ok__", {
            groupType = "STATIC",
            type      = "GoodStaticType_XYZ",
            category  = "Fortifications",
        })
        mv._cache["S:GoodStaticType_XYZ"] = true

        local model = {
            name  = "TestSceneGoodStatic",
            steps = {
                { registryKey = "__test_static_ok__", polar = { distance = 10, angle = 0 },
                  delayAfterPreviousStep = 0 },
            },
        }
        sm:registerSceneModel(model)
        sm:_auditAfterModValidator()

        assert.is_falsy(model._disabled)
    end)

    it("C4: scene with probeSkip=true step → NOT marked disabled even if type is absent from cache", function()
        CTLDObjectRegistry.registerIfAbsent("__test_probeSkip__", {
            groupType = "STATIC",
            type      = "SomeModHelipad_XYZ",
            category  = "Heliports",
            probeSkip = true,
        })
        -- Intentionally NOT setting cache entry (type not probed)
        -- mv._cache["S:SomeModHelipad_XYZ"] = nil  → isStaticInvalid returns false (not probed = not invalid)

        local model = {
            name  = "TestSceneProbeSkip",
            steps = {
                { registryKey = "__test_probeSkip__", polar = { distance = 10, angle = 0 },
                  delayAfterPreviousStep = 0 },
            },
        }
        sm:registerSceneModel(model)
        sm:_auditAfterModValidator()

        assert.is_falsy(model._disabled)
    end)

    it("C5: func-only step (no registryKey) never causes disable", function()
        local model = {
            name  = "TestSceneFuncOnly",
            steps = {
                { delayAfterPreviousStep = 0, func = function() end },
            },
        }
        sm:registerSceneModel(model)
        sm:_auditAfterModValidator()

        assert.is_falsy(model._disabled)
    end)

end)

-- ─────────────────────────────────────────────────────────────
-- U-121 — isSceneEnabled()
-- ─────────────────────────────────────────────────────────────
describe("U-121 — isSceneEnabled()", function()

    local sm

    before_each(function()
        _smInstance = nil
        CTLDModValidator._instance = nil
        sm = CTLDSceneManager.getInstance()
    end)

    it("C1: returns true for registered, non-disabled scene", function()
        local model = { name = "EnabledScene", steps = {{ delayAfterPreviousStep = 0, func = function() end }} }
        sm:registerSceneModel(model)
        assert.is_true(sm:isSceneEnabled("EnabledScene"))
    end)

    it("C2: returns false for registered but _disabled scene", function()
        local model = { name = "DisabledScene", _disabled = true,
                        steps = {{ delayAfterPreviousStep = 0, func = function() end }} }
        sm:registerSceneModel(model)
        assert.is_false(sm:isSceneEnabled("DisabledScene"))
    end)

    it("C3: returns false for unknown scene name", function()
        assert.is_false(sm:isSceneEnabled("NoSuchScene_XYZ"))
    end)

end)

-- ─────────────────────────────────────────────────────────────
-- U-122 — playScene disabled guard
-- ─────────────────────────────────────────────────────────────
describe("U-122 — playScene: disabled scene returns nil", function()

    local sm, unit

    before_each(function()
        _smInstance = nil
        CTLDModValidator._instance = nil
        sm   = CTLDSceneManager.getInstance()
        unit = makeUnit()
    end)

    it("C1: playScene on disabled model returns nil", function()
        local model = { name = "DisabledForPlay", _disabled = true,
                        steps = {{ delayAfterPreviousStep = 0, func = function() end }} }
        sm:registerSceneModel(model)
        local scene = sm:playScene(unit, "DisabledForPlay", {}, nil)
        assert.is_nil(scene)
    end)

    it("C2: playScene on enabled model returns a scene instance", function()
        local model = { name = "EnabledForPlay",
                        steps = {{ delayAfterPreviousStep = 0, func = function() end }} }
        sm:registerSceneModel(model)
        local scene = sm:playScene(unit, "EnabledForPlay", {}, nil)
        assert.is_not_nil(scene)
    end)

end)

-- ─────────────────────────────────────────────────────────────
-- U-123 — _injectSceneCrate disabled guard
-- ─────────────────────────────────────────────────────────────
describe("U-123 — _injectSceneCrate: disabled model is skipped", function()

    local cm

    before_each(function()
        CTLDCrateManager._instance = nil
        _cmInstance = nil
        _smInstance = nil
        CTLDModValidator._instance = nil
        cm = CTLDCrateManager.getInstance()
        -- Ensure _processedCrates exists
        if not cm._processedCrates then cm._processedCrates = {} end
        if not cm._weightIndex     then cm._weightIndex = {} end
    end)

    it("C1: disabled model — _injectSceneCrate does not add entry to _weightIndex", function()
        local model = {
            name      = "SceneDisabledInject",
            _disabled = true,
            crate     = { weight = 1001.99, cratesRequired = 1 },
        }
        cm:_injectSceneCrate("SceneDisabledInject", model)
        assert.is_nil(cm._weightIndex[1001.99])
    end)

    it("C2: enabled model — _injectSceneCrate adds entry to _weightIndex", function()
        local model = {
            name  = "SceneEnabledInject",
            crate = { weight = 1001.98, cratesRequired = 1 },
        }
        cm:_injectSceneCrate("SceneEnabledInject", model)
        assert.is_not_nil(cm._weightIndex[1001.98])
    end)

end)

-- ─────────────────────────────────────────────────────────────
-- U-124 — _purgeDisabledScenes
-- ─────────────────────────────────────────────────────────────
describe("U-124 — _purgeDisabledScenes", function()

    local cm, sm

    before_each(function()
        _smInstance = nil
        CTLDModValidator._instance = nil
        CTLDCrateManager._instance = nil
        _cmInstance = nil

        sm = CTLDSceneManager.getInstance()
        cm = CTLDCrateManager.getInstance()
        if not cm._processedCrates then cm._processedCrates = {} end
        if not cm._weightIndex     then cm._weightIndex = {} end
    end)

    it("C1: disabled scene entry removed from singleCrates and _weightIndex", function()
        -- Register a disabled model
        local model = { name = "PurgeScene", _disabled = true,
                        steps = {{ delayAfterPreviousStep = 0, func = function() end }} }
        sm:registerSceneModel(model)

        -- Manually inject an entry as if _injectSceneCrate ran before _disabled was set
        local entry = { weight = 1001.77, unit = "PurgeScene", desc = "test", cratesRequired = 1 }
        cm._weightIndex[1001.77] = entry
        cm._processedCrates["Both"] = { singleCrates = { { singleCrate = entry } }, mixedSets = {} }

        cm:_purgeDisabledScenes()

        assert.is_nil(cm._weightIndex[1001.77])
        assert.equals(0, #cm._processedCrates["Both"].singleCrates)
    end)

    it("C2: enabled scene entry is preserved after purge", function()
        local model = { name = "KeepScene",
                        steps = {{ delayAfterPreviousStep = 0, func = function() end }} }
        sm:registerSceneModel(model)

        local entry = { weight = 1001.76, unit = "KeepScene", desc = "keep", cratesRequired = 1 }
        cm._weightIndex[1001.76] = entry
        cm._processedCrates["Both"] = { singleCrates = { { singleCrate = entry } }, mixedSets = {} }

        cm:_purgeDisabledScenes()

        assert.is_not_nil(cm._weightIndex[1001.76])
        assert.equals(1, #cm._processedCrates["Both"].singleCrates)
    end)

    it("C3: unknown scene unit (not in _models) — entry preserved (non-scene crate)", function()
        -- Entry whose unit is not a registered scene model → should not be purged
        local entry = { weight = 1001.75, unit = "NotAScene", desc = "crate", cratesRequired = 1 }
        cm._weightIndex[1001.75] = entry
        cm._processedCrates["Both"] = { singleCrates = { { singleCrate = entry } }, mixedSets = {} }

        cm:_purgeDisabledScenes()

        assert.is_not_nil(cm._weightIndex[1001.75])
        assert.equals(1, #cm._processedCrates["Both"].singleCrates)
    end)

end)

-- ─────────────────────────────────────────────────────────────
-- U-125 — step.critical abort
-- ─────────────────────────────────────────────────────────────
describe("U-125 — step.critical: abort when spawn returns nil", function()

    local sm, unit

    before_each(function()
        _smInstance = nil
        CTLDModValidator._instance = nil
        sm   = CTLDSceneManager.getInstance()
        unit = makeUnit()
    end)

    it("C1: critical step with nil spawn → scene._aborted = true, subsequent steps skipped", function()
        local step2Executed = false

        local model = {
            name  = "CriticalAbortScene",
            steps = {
                {
                    -- registryKey points to a non-existent registry entry → spawnObject returns nil
                    registryKey            = "__nonexistent_registry_key_xyz__",
                    polar                  = { distance = 10, angle = 0 },
                    delayAfterPreviousStep = 0,
                    critical               = true,
                    relativeHeadingInDegrees = 0,
                    relativeAltitudeInMeters = 0,
                },
                {
                    delayAfterPreviousStep = 0,
                    func = function() step2Executed = true end,
                },
            },
        }
        sm:registerSceneModel(model)
        local scene = sm:playScene(unit, "CriticalAbortScene", {}, nil)

        assert.is_not_nil(scene)
        assert.is_true(scene._aborted)
        assert.is_false(step2Executed)
    end)

    it("C2: non-critical step with nil spawn → scene continues, subsequent steps run", function()
        local step2Executed = false

        local model = {
            name  = "NonCriticalScene",
            steps = {
                {
                    registryKey            = "__nonexistent_registry_key_xyz__",
                    polar                  = { distance = 10, angle = 0 },
                    delayAfterPreviousStep = 0,
                    -- critical = false (default, field absent)
                    relativeHeadingInDegrees = 0,
                    relativeAltitudeInMeters = 0,
                },
                {
                    delayAfterPreviousStep = 0,
                    func = function() step2Executed = true end,
                },
            },
        }
        sm:registerSceneModel(model)
        local scene = sm:playScene(unit, "NonCriticalScene", {}, nil)

        assert.is_not_nil(scene)
        assert.is_false(scene._aborted)
        assert.is_true(step2Executed)
    end)

    it("C3: critical step with successful spawn → scene continues normally", function()
        local step2Executed = false
        -- Stub spawnObject to return a non-nil object for a specific key
        local origSpawn = CTLDObjectRegistry.spawnObject
        CTLDObjectRegistry.spawnObject = function(key, ...)
            if key == "__mock_ok_spawn__" then
                return { isExist = function() return true end, getName = function() return "mock" end }
            end
            return nil
        end

        local model = {
            name  = "CriticalSuccessScene",
            steps = {
                {
                    registryKey            = "__mock_ok_spawn__",
                    polar                  = { distance = 10, angle = 0 },
                    delayAfterPreviousStep = 0,
                    critical               = true,
                    relativeHeadingInDegrees = 0,
                    relativeAltitudeInMeters = 0,
                },
                {
                    delayAfterPreviousStep = 0,
                    func = function() step2Executed = true end,
                },
            },
        }
        sm:registerSceneModel(model)
        local scene = sm:playScene(unit, "CriticalSuccessScene", {}, nil)

        CTLDObjectRegistry.spawnObject = origSpawn  -- restore

        assert.is_not_nil(scene)
        assert.is_false(scene._aborted)
        assert.is_true(step2Executed)
    end)

end)

-- ─────────────────────────────────────────────────────────────
-- U-126 — requiresMod WARN (audit emits outText, no disable)
-- ─────────────────────────────────────────────────────────────
describe("U-126 — requiresMod: scene stays enabled but WARN is emitted", function()

    local sm, mv, outTextCalls

    before_each(function()
        _smInstance = nil
        CTLDModValidator._instance = nil
        sm = CTLDSceneManager.getInstance()
        mv = CTLDModValidator.getInstance()
        mv._probePos = { x = 0, z = 0 }

        -- Capture outText calls
        outTextCalls = {}
        local origOT = trigger.action.outText
        trigger.action.outText = function(msg, dur)
            outTextCalls[#outTextCalls + 1] = msg
            return origOT(msg, dur)
        end
    end)

    it("C1: requiresMod scene with no invalid types → not disabled, WARN outText emitted", function()
        local model = {
            name       = "RequiresModScene",
            requiresMod = "SomeMod_XYZ",
            steps      = {{ delayAfterPreviousStep = 0, func = function() end }},
        }
        sm:registerSceneModel(model)
        sm:_auditAfterModValidator()

        assert.is_falsy(model._disabled)
        local found = false
        for _, msg in ipairs(outTextCalls) do
            if msg:find("RequiresModScene") and msg:find("SomeMod_XYZ") then
                found = true; break
            end
        end
        assert.is_true(found)
    end)

    it("C2: scene without requiresMod → no spurious requiresMod outText", function()
        local model = {
            name  = "NoRequiresModScene",
            steps = {{ delayAfterPreviousStep = 0, func = function() end }},
        }
        sm:registerSceneModel(model)
        sm:_auditAfterModValidator()

        local found = false
        for _, msg in ipairs(outTextCalls) do
            if msg:find("NoRequiresModScene") and msg:find("requires mod") then
                found = true; break
            end
        end
        assert.is_false(found)
    end)

end)
