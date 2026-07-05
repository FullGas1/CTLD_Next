---@diagnostic disable
-- CTLD_sceneManager.lua
-- CTLDSceneManager singleton — scene model registry + sequential execution engine.
-- CtldScene      — executes one scene instance step by step.
--
-- Step types (fields in each step table):
--   polar  : { polar={distance, angle}, relativeHeadingInDegrees, relativeAltitudeInMeters,
--              registryKey [, preFunc] [, func] }
--              Deterministic position relative to the trigger unit's snapshot position.
--   axis   : { axis={count, safeDistance, spacing}, registryKey [, preFunc] [, func] }
--              Random single axis around the unit; N objects spread along it.
--   func   : { func=function(ctx) ... end }
--              No spawn; only executes the function (post-spawn hook).
--
-- Each step supports two optional script hooks:
--   preFunc(ctx) — runs BEFORE spawn. Return false to skip this step's spawn (scene continues).
--                  Call ctx.scene:abort(reason) to stop the scene entirely.
--   func(ctx)    — runs AFTER spawn (or after skipped spawn).
--                  ctx.spawnedObj is the last DCS object spawned this step (nil if skipped).
--
-- All steps carry delayAfterPreviousStep (seconds).  After executing step N,
-- the engine waits that many seconds before starting step N+1.  The same field
-- is also used before step 1 (initial delay from mission start / scene trigger).
--
-- Scene models may define an onComplete field:
--   model.onComplete = function(scene) ... end
--   Called automatically when all steps finish. Overridden if playScene() passes its own callback.
--
-- Dependencies: CTLDUtils, CTLDObjectRegistry
-- DCS API: timer.getTime, timer.scheduleFunction, Unit.*, Airbase.*,
--          trigger.action.outText
-- ====================================================================================================

-- ====================================================================================================
-- CtldScene
-- ====================================================================================================

CtldScene = class()

local _sceneCounter = 0

-- Creates and immediately starts a new scene instance.
-- @param unit   DCS Unit object (trigger unit — position/heading snapshot is taken here)
-- @param model  table { name=string, steps={...} }
-- @return CtldScene
-- @param unit        DCS Unit — trigger unit; position/heading snapshot taken here
-- @param model       table    — scene model (name + steps)
-- @param params      table    — optional key/value bag passed to step funcs via ctx.scene._params
-- @param onComplete  function — optional callback called with (scene) when last step finishes
function CtldScene:init(unit, model, params, onComplete)
    _sceneCounter  = _sceneCounter + 1
    self._name      = string.format("%s#%d", model.name, _sceneCounter)
    self._modelName = model.name   -- original model name for registry lookups (repack support)
    self._unit      = unit
    self._steps     = model.steps
    self._stepIndex   = 0
    self._timeMarker  = 0
    self._spawnedObjs = {}
    self._params      = params     or {}
    self._onComplete  = onComplete or model.onComplete or nil
    self._aborted     = false

    -- Cache coalition/country at init so steps work even if the unit leaves mid-scene.
    self._coalitionId = unit:getCoalition()
    self._countryId   = unit:getCountry()

    -- Snapshot reference position and heading at creation time.
    -- All step positions are computed relative to this snapshot (unit may have moved).
    -- A prescript func may override _refX/_refZ/_refAlt via ctx.scene before the first spawn step.
    local pt        = unit:getPoint()
    self._refX      = pt.x          -- world North axis
    self._refZ      = pt.z          -- world East axis
    self._refAlt    = pt.y          -- altitude (metres)
    self._refHdgRad = ctld.utils.getHeadingInRadians("CtldScene", unit, true)

    -- Magnetic declination is constant for the whole scene (computed once at reference point).
    self._magDecDeg = math.deg(
        ctld.utils.getNorthCorrectionInRadians("CtldScene", { x = self._refX, y = self._refZ })
    )
end

-- Schedules the first step.
function CtldScene:_execute()
    local firstDelay = tonumber(self._steps[1].delayAfterPreviousStep) or 0
    self._timeMarker = timer.getTime() + firstDelay
    if self._timeMarker > timer.getTime() then
        local fn = function() self:_runNextStep() end
        timer.scheduleFunction(fn, nil, self._timeMarker)
    else
        self:_runNextStep()
    end
end

-- Aborts the scene: stops all further step scheduling and skips onComplete.
-- Safe to call from within a preFunc or func.
function CtldScene:abort(reason)
    self._aborted = true
    ctld.utils.log("WARN", "CtldScene '%s' aborted: %s", self._name, tostring(reason or "no reason"))
end

-- Executes the current step then schedules the next one.
function CtldScene:_runNextStep()
    if self._aborted then return end

    self._stepIndex = self._stepIndex + 1
    local step = self._steps[self._stepIndex]
    if not step then
        ctld.utils.log("WARN", "CtldScene '%s': no step at index %d", self._name, self._stepIndex)
        return
    end

    local coalitionId = self._coalitionId
    local countryId   = self._countryId
    local spawnedObj  = nil

    -- -----------------------------------------------------------------------
    -- preFunc — executed before spawn.
    -- Returning false skips the spawn of this step (scene continues).
    -- Calling ctx.scene:abort() stops the scene entirely.
    -- -----------------------------------------------------------------------
    local skipSpawn = false
    if step.preFunc then
        local ctx = {
            unit  = self._unit,
            step  = step,
            scene = self,
        }
        local ok, result = pcall(step.preFunc, ctx)
        if not ok then
            ctld.utils.log("ERROR", "CtldScene '%s' step %d preFunc error: %s",
                self._name, self._stepIndex, tostring(result))
        elseif result == false then
            skipSpawn = true
        end
        if self._aborted then return end
    end

    -- -----------------------------------------------------------------------
    -- Spawn phase (skipped for func-only steps or when preFunc returns false)
    -- -----------------------------------------------------------------------
    if step.registryKey and not skipSpawn then
        local desc = CTLDObjectRegistry.get(step.registryKey)

        -- Auto-inject circleRadius when the descriptor uses circle formation.
        local overrides = {}
        if desc and desc.formation and desc.formation.type == "circle" then
            local safeR = ctld.utils.getSecureDistanceFromUnit(self._unit:getName()) or 10
            overrides.circleRadius = safeR + (ctld.gs("spawnDistanceInCircle") or 10)
        end

        if step.polar then
            -- Polar step: deterministic world position derived from the snapshot.
            local spawnX, spawnEast, spawnHdgDeg = ctld.utils.getRelativeCoords(
                self._refX, self._refZ, self._refHdgRad, self._refAlt,
                step.polar.angle    or 0,
                step.polar.distance or 0,
                step.relativeHeadingInDegrees or 0,
                step.relativeAltitudeInMeters or 0,
                self._magDecDeg
            )
            spawnedObj = CTLDObjectRegistry.spawnObject(
                step.registryKey, coalitionId, countryId,
                spawnX, spawnEast, math.rad(spawnHdgDeg), overrides
            )
            if spawnedObj then
                self._spawnedObjs[#self._spawnedObjs + 1] = spawnedObj
            end

        elseif step.axis then
            -- Axis step: random single axis; N objects distributed along it.
            local count    = step.axis.count       or 1
            local safeDist = step.axis.safeDistance
                          or ctld.utils.getSecureDistanceFromUnit(self._unit:getName())
                          or 20
            local spacing  = step.axis.spacing or (ctld.gs("crateSpacing") or 5)
            local result   = ctld.utils.getSpawnObjectPositions(self._unit, count, safeDist, spacing)
            for _, pos in ipairs(result.positions) do
                local obj = CTLDObjectRegistry.spawnObject(
                    step.registryKey, coalitionId, countryId,
                    pos.x, pos.z, 0, overrides
                )
                if obj then
                    self._spawnedObjs[#self._spawnedObjs + 1] = obj
                    spawnedObj = obj   -- pass the last spawned object to func
                end
            end
        end

        -- step.critical = true: if the spawn produced nothing, the scene cannot continue.
        -- Abort immediately rather than silently proceeding with a broken partial scene.
        if step.critical and spawnedObj == nil then
            self:abort(string.format(
                "critical step %d failed — registryKey '%s' produced no object",
                self._stepIndex, tostring(step.registryKey)))
            return
        end
    end

    -- -----------------------------------------------------------------------
    -- Optional func — receives a named context table (ctx).
    -- ctx.unit       : DCS Unit (trigger unit)
    -- ctx.spawnedObj : last object spawned in this step (nil for func-only steps)
    -- ctx.step       : current step table
    -- ctx.scene      : this CtldScene instance (read/write _refX/_refZ/_refAlt, _params, etc.)
    -- -----------------------------------------------------------------------
    if step.func then
        local ctx = {
            unit       = self._unit,
            spawnedObj = spawnedObj,
            step       = step,
            scene      = self,
        }
        local ok, err = pcall(step.func, ctx)
        if not ok then
            ctld.utils.log("ERROR", "CtldScene '%s' step %d func error: %s",
                self._name, self._stepIndex, tostring(err))
        end
    end

    -- -----------------------------------------------------------------------
    -- Schedule next step, or fire onComplete when the last step finishes.
    -- -----------------------------------------------------------------------
    if self._aborted then return end
    if self._steps[self._stepIndex + 1] then
        self._timeMarker = self._timeMarker + (tonumber(step.delayAfterPreviousStep) or 0)
        if self._timeMarker > timer.getTime() then
            local fn = function() self:_runNextStep() end
            timer.scheduleFunction(fn, nil, self._timeMarker)
        else
            self:_runNextStep()
        end
    else
        ctld.utils.log("INFO", "CtldScene '%s': completed (%d steps)", self._name, self._stepIndex)
        if self._onComplete then
            local ok, err = pcall(self._onComplete, self)
            if not ok then
                ctld.utils.log("ERROR", "CtldScene '%s' onComplete error: %s",
                    self._name, tostring(err))
            end
        end
    end
end

-- ====================================================================================================
-- CTLDSceneManager
-- ====================================================================================================

CTLDSceneManager = class()

local _smInstance = nil

function CTLDSceneManager.getInstance()
    if not _smInstance then
        _smInstance = setmetatable({}, CTLDSceneManager)
        _smInstance:_init()
    end
    return _smInstance
end

function CTLDSceneManager:_init()
    self._models = {}   -- model name → model table
    self._active = {}   -- scene name  → CtldScene instance
    self:_registerBuiltins()
    local n = 0
    for _ in pairs(self._models) do n = n + 1 end
    ctld.utils.log("INFO", "CTLDSceneManager: initialized (%d built-in scene(s))", n)
end

-- Registers a scene model.  Returns true on success.
-- External files (e.g. CTLD_mineFieldScene.lua) call this at load time.
-- @param model  table  { name=string, steps={...} }
function CTLDSceneManager:registerSceneModel(model)
    if not model or not model.name or model.name == "" then
        ctld.utils.log("WARN", "CTLDSceneManager:registerSceneModel: model missing 'name' field")
        return false
    end
    if self._models[model.name] then
        ctld.utils.log("WARN", "CTLDSceneManager:registerSceneModel: '%s' already registered", model.name)
        return false
    end
    self._models[model.name] = model
    ctld.utils.log("INFO", "CTLDSceneManager: registered scene model '%s'", model.name)
    -- If CTLDCrateManager is already initialized (late scene registration, e.g. Witchcraft injection),
    -- inject the crate descriptor immediately so it appears in the Request Equipment menu.
    if model.crate and CTLDCrateManager and CTLDCrateManager._instance then
        CTLDCrateManager._instance:_injectSceneCrate(model.name, model)
    end
    return true
end

-- Starts a named scene triggered by a DCS unit.
-- @param unit        DCS Unit object
-- @param modelName   string    key in _models
-- @param params      table     optional key/value bag forwarded to step funcs via ctx.scene._params
-- @param onComplete  function  optional callback(scene) fired when the last step finishes
-- @return CtldScene instance, or nil on error
function CTLDSceneManager:playScene(unit, modelName, params, onComplete)
    if not unit or not unit:isExist() then
        ctld.utils.log("WARN", "CTLDSceneManager:playScene: unit is nil or dead")
        return nil
    end
    local model = self._models[modelName]
    if not model then
        ctld.utils.log("WARN", "CTLDSceneManager:playScene: unknown model '%s'", tostring(modelName))
        return nil
    end
    if model._disabled then
        ctld.utils.log("WARN", "CTLDSceneManager:playScene: scene '%s' is disabled (missing DCS type)", tostring(modelName))
        return nil
    end
    local scene = CtldScene:new(unit, model, params, onComplete)
    self._active[scene._name] = scene
    scene:_execute()
    ctld.utils.log("INFO", "CTLDSceneManager: started scene '%s' for unit '%s'",
        scene._name, unit:getName())
    return scene
end

--- Play a scene without a live DCS unit (e.g. parachute auto-unpack — no player context).
-- Builds a minimal virtual unit table from pos + coalition/country so that CtldScene can
-- compute reference position, heading (north, 0 rad), coalition and country.
-- @param modelName   string  key in _models
-- @param pos         vec3    reference position (centroid of landed crates)
-- @param coalitionId number  coalition.side.RED / coalition.side.BLUE
-- @param countryId   number  country.id.*
-- @param params      table   optional — forwarded to scene._params (same as playScene)
-- @return CtldScene instance, or nil on error
function CTLDSceneManager:playSceneAtPos(modelName, pos, coalitionId, countryId, params)
    if not pos then
        ctld.utils.log("WARN", "CTLDSceneManager:playSceneAtPos: pos is nil")
        return nil
    end
    -- North-facing direction vector (heading = 0).
    local mockUnit = {
        isExist     = function(_) return true end,
        getName     = function(_) return "__auto_unpack__" end,
        getCoalition= function(_) return coalitionId end,
        getCountry  = function(_) return countryId end,
        getPoint    = function(_) return pos end,
        getPosition = function(_)
            return { x = { x = 1, y = 0, z = 0 }, p = pos }
        end,
    }
    return self:playScene(mockUnit, modelName, params, nil)
end

-- Returns a registered model table by name, or nil.
function CTLDSceneManager:getModel(name)
    return self._models[name]
end

-- Alias: returns a registered scene model by name, or nil.
-- Used by AI vehicle pickup to distinguish whole-unit types from crate-assembled scenes.
function CTLDSceneManager:getScene(name)
    return self._models[name]
end

--- Returns true when the scene model is registered and NOT disabled by _auditAfterModValidator.
-- @param name string  model name
function CTLDSceneManager:isSceneEnabled(name)
    local m = self._models[name]
    return m ~= nil and not m._disabled
end

--- Post-validator audit: scan every registered scene model, check each step's registry entry
-- against CTLDModValidator results, disable models with missing types, and purge their menu
-- entries from CTLDCrateManager.
-- Called from CTLDCoreManager:init() immediately after CTLDModValidator:run().
-- Also emits WARN outText for scenes that declare requiresMod (cannot be auto-validated).
function CTLDSceneManager:_auditAfterModValidator()
    local mv  = CTLDModValidator.getInstance()
    local reg = CTLDObjectRegistry
    local invalids = {}   -- sceneName → { typeName, ... }

    for modelName, model in pairs(self._models) do
        local missingTypes = {}
        for _, step in ipairs(model.steps or {}) do
            local rk   = step.registryKey
            local desc = rk and reg._db[rk]
            if desc and not desc.probeSkip then
                local t = desc.type
                if t then
                    if desc.groupType == "STATIC" and mv:isStaticInvalid(t) then
                        missingTypes[#missingTypes + 1] = t
                    elseif desc.groupType == "GROUND" and mv:isGroundInvalid(t) then
                        missingTypes[#missingTypes + 1] = t
                    end
                end
            end
        end

        if #missingTypes > 0 then
            model._disabled    = true
            invalids[modelName] = missingTypes
        end
    end

    -- Report disabled scenes
    if next(invalids) then
        local lines = { "[CTLD] Scenes disabled — missing DCS type(s):" }
        for sn, types in pairs(invalids) do
            -- Remove duplicates in types list
            local seen, uniq = {}, {}
            for _, t in ipairs(types) do
                if not seen[t] then seen[t] = true; uniq[#uniq + 1] = t end
            end
            lines[#lines + 1] = string.format("  '%s': %s", sn, table.concat(uniq, ", "))
        end
        local msg = table.concat(lines, "\n")
        ctld.utils.log("WARN", msg)
        trigger.action.outText(msg, 30)
    end

    -- Warn about requiresMod scenes (cannot be auto-validated; menu is still shown)
    for modelName, model in pairs(self._models) do
        if model.requiresMod and not model._disabled then
            local msg = string.format(
                "[CTLD] Scene '%s' requires mod '%s' — cannot be auto-validated. "
                .. "Ensure all clients have this mod installed.",
                modelName, model.requiresMod)
            ctld.utils.log("WARN", msg)
            trigger.action.outText(msg, 20)
        end
    end

    -- Purge disabled scenes from the Request Equipment menu
    if next(invalids) and CTLDCrateManager and CTLDCrateManager._instance then
        CTLDCrateManager._instance:_purgeDisabledScenes()
    end
end

-- ====================================================================================================
-- Repack support
-- ====================================================================================================

--- Returns scene instances that support onRepack and are within radius of pos.
-- Used by refreshPackSection to discover nearby repackable FARP scenes.
-- @param pos    vec3    reference position (player unit position)
-- @param radius number  search radius in metres
-- @return table  ordered list of CtldScene instances
function CTLDSceneManager:findNearbyRepackableScenes(pos, radius)
    local result = {}
    local r2     = radius * radius
    for _, scene in pairs(self._active) do
        local dx = scene._refX - pos.x
        local dz = scene._refZ - pos.z
        if dx * dx + dz * dz <= r2 then
            local model = self._models[scene._modelName]
            if model and model.onRepack then
                result[#result + 1] = scene
            end
        end
    end
    return result
end

--- Capture warehouse snapshot via onRepack, destroy all spawned objects, remove from active.
-- Must be called BEFORE the scene objects are gone (onRepack reads the live warehouse).
-- @param scene CtldScene
-- @return table  repackData (may contain .warehouseSnapshot)
function CTLDSceneManager:packScene(scene)
    local model      = self._models[scene._modelName]
    local repackData = {}
    if model and model.onRepack then
        local ok, err = pcall(model.onRepack, scene, repackData)
        if not ok then
            ctld.utils.log("ERROR", "CTLDSceneManager:packScene onRepack error for '%s': %s",
                scene._name, tostring(err))
        end
    end
    local destroyed = 0
    for _, obj in ipairs(scene._spawnedObjs) do
        local ok, err = pcall(function()
            if obj.isExist and obj:isExist() then
                obj:destroy()
                destroyed = destroyed + 1
            end
        end)
        if not ok then
            ctld.utils.log("WARN", "CTLDSceneManager:packScene destroy error: %s", tostring(err))
        end
    end
    self._active[scene._name] = nil
    ctld.utils.log("INFO", "CTLDSceneManager:packScene: '%s' packed (%d object(s) destroyed)",
        scene._name, destroyed)
    return repackData
end

-- ====================================================================================================
-- Built-in scene registration
-- ====================================================================================================

-- All scenes are defined in their own files under scenes/ and self-register via
-- CTLDSceneManager.getInstance():registerSceneModel(). No built-in registration needed.
function CTLDSceneManager:_registerBuiltins()
end


