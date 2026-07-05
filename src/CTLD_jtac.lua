-- ============================================================
-- CTLD_jtac.lua
-- CTLDJTAC entity + CTLDJTACDetector helpers + CTLDJTACManager singleton
--
-- Dependencies : CTLDConfig (ctld.gs), CTLDUtils, EventDispatcher
-- DCS API      : coalition.addGroup, Group, Unit, Spot, land, world,
--                atmosphere, trigger.action, timer
--
-- JTAC is a feature, not a unit type. It applies to:
--   - ground infantry  (loadable group with jtac=N soldier)
--   - ground vehicle   (crate descriptor with jtac=true)
--   - flying AI drone  (crate descriptor with jtac=true, isFlying=true)
--
-- JTAC lifecycle states:
--   idle       : spawned, no target acquired
--   lasing     : actively lasing a target
--   orbiting   : flying JTAC orbiting a target (implies lasing)
--   in_transit : ground JTAC embarked in a transport
--   dead       : unit destroyed
--
-- Detection: crate descriptor.jtac == true   (no separate jtacUnitTypes table)
-- Laser pool: sequential 1111–1688 (assigned on spawn, freed on death)
-- Timings   : JTAC_laseIntervalSeconds / JTAC_searchIntervalSeconds (config)
-- DCS bug   : coalition.addGroup leaves group empty for ~1s →
--             first _autoLaseLoop is delayed +1s (preserved from source)
-- ============================================================

---@diagnostic disable
ctld = ctld or {}

-- ============================================================
-- CTLDJTAC  (entity)
-- ============================================================

CTLDJTAC = class()

CTLDJTAC.STATE = {
    IDLE       = "idle",
    LASING     = "lasing",
    ORBITING   = "orbiting",
    IN_TRANSIT = "in_transit",
    DEAD       = "dead",
}

-- Reasons passed to stopLase() and _stopLaseAndPublish()
CTLDJTAC.STOP_REASON = {
    TARGET_LOST   = "target_lost",
    TARGET_DESTROYED = "target_destroyed",
    STANDBY_MODE  = "standby_mode",
    IN_TRANSIT    = "jtac_in_transit",
    DEAD          = "jtac_dead",
}

-- Lock mode values (mirrors JTAC_lock config)
CTLDJTAC.LOCK_MODE = {
    ALL     = "all",
    VEHICLE = "vehicle",
    TROOP   = "troop",
}

--- Constructor.
-- @param data table:
--   groupName    (string)   DCS group name
--   laserCode    (number)   assigned laser code (1111-1688)
--   isFlying     (boolean)  drone/aircraft vs ground
--   isInfantry   (boolean)  infantry vs vehicle (ground only)
--   coalitionId  (number)   coalition.side.*
--   smokeEnabled (boolean)  auto-smoke on target
--   smokeColor   (number)   trigger.smokeColor.*
--   lockMode     (string)   "all" | "vehicle" | "troop"
function CTLDJTAC:init(data)
    self.groupName    = data.groupName
    -- unitName: set for infantry JTACs within a composite troop group (unit-keyed registry).
    -- nil for drone/vehicle JTACs (group-keyed registry). Drives Unit.getByName() path in _autoLaseLoop.
    self.unitName     = data.unitName    or nil
    self.laserCode    = data.laserCode
    self.isFlying     = data.isFlying    or false
    self.isInfantry   = data.isInfantry  or false
    self.coalitionId  = data.coalitionId
    self.smokeEnabled = data.smokeEnabled or false
    self.smokeColor   = data.smokeColor  or trigger.smokeColor.Red
    self.lockMode     = data.lockMode    or "all"
    self.state        = CTLDJTAC.STATE.IDLE

    self.radio = CTLDJTACDetector.calculateFMRadio(data.groupName, data.laserCode)

    self.currentTarget  = nil   -- { unitName, unitType, unitId, position, laseStartTime }
    self.laserSpot      = nil
    self.irSpot         = nil

    -- Flying JTACs only: orbit params from crate specificParams + spawn position
    self.orbitParams          = data.orbitParams or nil  -- { speed, alti, orbitRadiusNoLase, orbitRadiusOnLase }
    self.initialPosition      = nil   -- captured at T+2s after spawn
    self.initialRoute         = nil   -- waypoint table built by _setOrbitRoute; replayed on target loss
    self.initialRouteAssigned = false -- true once _setOrbitRoute has been called; prevents re-assignment on every tick
    self.orbitStartTime       = nil
    -- onTargetOrbit: true only while drone executes a Circle pushTask on top of its initial Mission route
    -- (i.e. state==ORBITING, = "orbitingToFollowLasedTarget"). false = drone on initial waypoint loop (IDLE).
    self.onTargetOrbit        = false
    self._routeRefreshId      = nil

    -- Target selection (1 = auto mode, string = manually selected unitName)
    self.selectedTarget = 1

    -- Per-JTAC special options (toggled via F10 menu)
    self.standbyMode         = false
    self.laseSpotCorrections = false
end

--- Begin lasing a new target.
-- @param target    table  { dcsUnit, unitName, unitType, unitId, position }
-- @param laserSpot DCS Spot object (laser)
-- @param irSpot    DCS Spot object (IR)
function CTLDJTAC:startLase(target, laserSpot, irSpot)
    self.currentTarget = {
        unitName      = target.unitName,
        unitType      = target.unitType,
        unitId        = target.unitId,
        position      = target.position,
        laseStartTime = timer.getAbsTime(),
    }
    self.laserSpot = laserSpot
    self.irSpot    = irSpot
    -- Keep ORBITING state if already orbiting; otherwise go LASING
    if self.state ~= CTLDJTAC.STATE.ORBITING then
        self.state = CTLDJTAC.STATE.LASING
    end
end

--- Stop lasing and destroy DCS spots.
-- @param reason string  CTLDJTAC.STOP_REASON.*
function CTLDJTAC:stopLase(reason)
    if self.laserSpot then self.laserSpot:destroy(); self.laserSpot = nil end
    if self.irSpot    then self.irSpot:destroy();    self.irSpot    = nil end
    self.currentTarget = nil
    -- Keep ORBITING state intact — _orbitLoop handles the ORBITING→IDLE transition
    if self.state == CTLDJTAC.STATE.LASING then
        self.state = CTLDJTAC.STATE.IDLE
    end
end

--- Update laser/IR spot position (moving target).
-- @param targetPos table {x, y, z}
function CTLDJTAC:updateLaseSpot(targetPos)
    if self.laserSpot then self.laserSpot:setPoint(targetPos) end
    if self.irSpot    then self.irSpot:setPoint(targetPos)    end
    if self.currentTarget then
        self.currentTarget.position = targetPos
    end
end

--- Flying JTAC: begin orbiting.
-- @param t number  timer.getTime() at orbit start
function CTLDJTAC:startOrbit(t)
    self.state        = CTLDJTAC.STATE.ORBITING
    self.orbitStartTime = t or timer.getTime()
end

--- Flying JTAC: stop orbiting, return to IDLE.
function CTLDJTAC:stopOrbit()
    self.state          = CTLDJTAC.STATE.IDLE
    self.orbitStartTime = nil
end

--- Ground JTAC: mark as embarked in a transport.
function CTLDJTAC:setInTransit()
    self:stopLase(CTLDJTAC.STOP_REASON.IN_TRANSIT)
    self.state = CTLDJTAC.STATE.IN_TRANSIT
end

--- Mark JTAC as dead and clean up spots.
function CTLDJTAC:kill()
    self:stopLase(CTLDJTAC.STOP_REASON.DEAD)
    self.state = CTLDJTAC.STATE.DEAD
end

--- Destroy DCS group + spots.
function CTLDJTAC:destroy()
    self:stopLase(CTLDJTAC.STOP_REASON.DEAD)
    local g = Group.getByName(self.groupName)
    if g then g:destroy() end
end


-- ============================================================
local LASER_CODE_MIN = 1111  -- Lowest valid laser code (NATO range)
local LASER_CODE_MAX = 1688  -- Highest valid laser code (NATO range)

-- CTLDJTACDetector  (static helpers — no instance)
-- ============================================================

CTLDJTACDetector = {}

--- Compute FM radio frequency from laser code.
-- Formula from CTLD_jtac.lua source (ctld.JTACAutoLase, lines 72-74):
--   freq = 30 + floor((code-1000)/100) + ((code-1000) mod 100) * 0.05
-- Range: laser 1111–1688 → FM ~31.5–40.4 MHz
-- @param groupName string
-- @param laserCode number
-- @return table { name, freq (string MHz), mod } or nil
function CTLDJTACDetector.calculateFMRadio(groupName, laserCode)
    local code = tonumber(laserCode)
    if not code or code < LASER_CODE_MIN or code > LASER_CODE_MAX then return nil end
    local laserB  = math.floor((code - 1000) / 100)
    local laserCD = code - 1000 - laserB * 100
    local freq    = tostring(30 + laserB + laserCD * 0.05)
    return { name = groupName, freq = freq, mod = "fm" }
end

--- Find all visible enemies for a JTAC unit, sorted by priority then distance.
-- Uses world.searchObjects (sphere) + land.isVisible (LOS, +2m Y offset).
-- Priority tiers: hpriority(1) > priority(2) > Air Defence(3) > standard(4).
-- Returns a sorted list so callers can iterate for target deconfliction.
-- API: world.searchObjects — verified Hoggit 2026-04-01
-- API: land.isVisible      — verified CTLD_jtac.lua source
-- @param jtacUnit    DCS Unit object
-- @param lockMode    string  "all" | "vehicle" | "troop"
-- @param maxDistance number  metres
-- @return table  sorted array of { dcsUnit, unitName, unitType, unitId, position, priority, distance }
function CTLDJTACDetector.findAllVisibleEnemies(jtacUnit, lockMode, maxDistance)
    if not jtacUnit or not jtacUnit:isExist() then return {} end

    local jtacPos  = jtacUnit:getPoint()
    local jtacCoal = jtacUnit:getCoalition()
    local offsetA  = { x = jtacPos.x, y = jtacPos.y + 2, z = jtacPos.z }
    local results  = {}

    world.searchObjects(
        Object.Category.UNIT,
        { id = world.VolumeType.SPHERE, params = { point = jtacPos, radius = maxDistance } },
        function(unit, _)
            if unit:getCoalition() == jtacCoal then return true end
            if not unit:isExist() or unit:getLife() <= 1 then return true end

            local attrs      = unit:getDesc().attributes or {}
            local isVehicle  = attrs["Vehicles"] == true or attrs["Armored vehicles"] == true
            local isInfantry = attrs["Infantry"] == true
            if lockMode == CTLDJTAC.LOCK_MODE.VEHICLE and not isVehicle  then return true end
            if lockMode == CTLDJTAC.LOCK_MODE.TROOP   and not isInfantry then return true end

            -- LOS check (+2m height offset — avoids terrain/hull occlusion at ground level)
            local unitPos = unit:getPoint()
            local offsetB = { x = unitPos.x, y = unitPos.y + 2, z = unitPos.z }
            if not land.isVisible(offsetA, offsetB) then return true end

            local dist     = ctld.utils.getDistance("CTLDJTACDetector.findAllVisibleEnemies", jtacPos, unitPos)
            local name     = unit:getName()
            local typeName = unit:getTypeName()
            local priority
            if string.find(name, "hpriority") or string.find(typeName, "hpriority") then
                priority = 1
            elseif string.find(name, "priority") or string.find(typeName, "priority") then
                priority = 2
            elseif attrs["Air Defence"] == true then
                priority = 3
            else
                priority = 4
            end

            results[#results + 1] = {
                dcsUnit  = unit,
                unitName = name,
                unitType = typeName,
                unitId   = unit:getID(),
                position = unitPos,
                priority = priority,
                distance = dist,
            }
            return true
        end,
        nil
    )

    table.sort(results, function(a, b)
        if a.priority ~= b.priority then return a.priority < b.priority end
        return a.distance < b.distance
    end)

    return results
end

--- Find the nearest visible enemy for a JTAC unit.
-- Thin wrapper around findAllVisibleEnemies — returns only the first (best) candidate.
-- @param jtacUnit    DCS Unit object
-- @param lockMode    string  "all" | "vehicle" | "troop"
-- @param maxDistance number  metres
-- @return table or nil  { dcsUnit, unitName, unitType, unitId, position, priority, distance }
function CTLDJTACDetector.findNearestVisibleEnemy(jtacUnit, lockMode, maxDistance)
    return CTLDJTACDetector.findAllVisibleEnemies(jtacUnit, lockMode, maxDistance)[1]
end

--- Line-of-sight check (convenience wrapper).
-- API: land.isVisible — verified CTLD_jtac.lua source
-- @param posA table {x,y,z}
-- @param posB table {x,y,z}
-- @return boolean
function CTLDJTACDetector.checkLOS(posA, posB)
    return land.isVisible(posA, posB)
end

--- Compute predictive laser-spot correction for a moving target.
-- Compensates target velocity (+1.0s anticipation) and wind (-1.05s).
-- API: atmosphere.getWind — verified CTLD_jtac.lua source
-- @param targetPos      table {x,y,z}
-- @param targetVelocity table {x,y,z}  Unit:getVelocity()
-- @param wind           table {x,y,z}  atmosphere.getWind(pos)
-- @return table {x,y,z}
function CTLDJTACDetector.calculateCorrectedSpot(targetPos, targetVelocity, wind)
    return {
        x = targetPos.x + targetVelocity.x * 1.0 - wind.x * 1.05,
        y = targetPos.y,
        z = targetPos.z + targetVelocity.z * 1.0 - wind.z * 1.05,
    }
end


-- ============================================================
-- CTLDJTACMessage  (static — message builder)
-- ============================================================

CTLDJTACMessage = {}

--- Build short + full notification strings from a structured context.
-- All i18n calls are co-located here. No message logic elsewhere.
--
-- Supported events:
--   "new_target"        JTAC locks a new target
--   "target_reacquired" manually-selected target back in LOS
--   "target_lost"       target alive but LOS broken
--   "target_destroyed"  target confirmed dead
--   "kia"               JTAC unit destroyed
--   "no_targets"        search loop found nothing (optional use)
--
-- @param ctx table:
--   event       (string)       one of the events above
--   jtacName    (string)       JTAC group name
--   targetType  (string|nil)   DCS typeName of target
--   laserCode   (number|nil)   assigned laser code
--   positionStr (string|nil)   pre-formatted MGRS/DMS string
--   wasSelected (boolean)      target was manually selected by player
--   standby     (boolean)      standby mode active (laser off)
--
-- @return table { short (string), full (string) }
--   short : concise, suitable for SRS read-out (no coords)
--   full  : detailed, displayed on screen (includes code + position)
function CTLDJTACMessage.build(ctx)
    local name  = ctx.jtacName   or "JTAC"
    local ttype = ctx.targetType or ctld.i18n_translate("unknown")
    local code  = ctx.laserCode  and tostring(ctx.laserCode) or ctld.i18n_translate("UNKNOWN")
    local pos   = ctx.positionStr or ""

    local codePosStr = ctld.i18n_translate(". CODE: %1. POSITION: %2", code, pos)

    local short, full

    if ctx.event == "new_target" then
        local verb = ctx.standby
            and ctld.i18n_translate("standing by on")
            or  ctld.i18n_translate("lasing")
        if ctx.wasSelected then
            short = ctld.i18n_translate("%1, selected %2 %3", name, verb, ttype)
        else
            short = ctld.i18n_translate("%1, %2 new target, %3", name, verb, ttype)
        end
        full = short .. codePosStr

    elseif ctx.event == "target_reacquired" then
        short = ctld.i18n_translate("%1, selected target reacquired, %2", name, ttype)
        full  = short .. codePosStr

    elseif ctx.event == "target_lost" then
        if ctx.wasSelected then
            short = ctld.i18n_translate("%1, selected target lost, temporarily lasing %2", name, ttype)
        else
            short = ctld.i18n_translate("%1, target lost.", name)
        end
        full = short

    elseif ctx.event == "target_destroyed" then
        if ctx.wasSelected then
            short = ctld.i18n_translate("%1, selected target destroyed.", name)
        else
            short = ctld.i18n_translate("%1, target destroyed.", name)
        end
        full = short

    elseif ctx.event == "kia" then
        short = ctld.i18n_translate("JTAC %1 KIA!", name)
        full  = short

    elseif ctx.event == "no_targets" then
        short = ctld.i18n_translate("%1, no targets in range.", name)
        full  = short

    else
        short = name .. " " .. tostring(ctx.event)
        full  = short
    end

    return { short = short, full = full }
end


-- ============================================================
-- CTLDJTACManager  (singleton)
-- ============================================================

CTLDJTACManager = class()
CTLDJTACManager._instance = nil

--- Return (or create) the singleton instance.
function CTLDJTACManager.getInstance()
    if not CTLDJTACManager._instance then
        local o          = setmetatable({}, CTLDJTACManager)
        o.jtacs          = {}
        o._laserPool     = {}
        o._pendingJTACs  = {}
        o._orbitScheduleId = nil
        -- Target deconfliction: { [enemyUnitName] = jtacKey } — tracks targets currently being lased.
        -- Prevents multiple concurrent JTACs from lasing the same target.
        o._claimedTargets = {}
        -- JTAC quota counters: number of JTAC objects spawned by players (definitive, non-refillable).
        -- Keyed by coalition.side (1=RED, 2=BLUE). Does NOT count MM JTACs or infantry JTAC soldiers.
        o._jtacSlotsUsed  = { [1] = 0, [2] = 0 }
        o:_initLaserPool()
        CTLDJTACManager._instance = o
        CTLDPlayerManager.getInstance():registerMenuSection({
            key       = "jtac",
            manager   = o,
            method    = "buildMenuSection",
            configKey = "JTAC_jtacStatusF10",
            order     = 90,
        })
    end
    return CTLDJTACManager._instance
end
--- Backward-compatibility alias — prefer getInstance() in new code.
CTLDJTACManager.get = CTLDJTACManager.getInstance

--- Spawn a JTAC from an unpacked crate.
-- The DCS group must already exist in the world (spawned by CTLDCrateManager).
-- DCS bug workaround: first _autoLaseLoop is delayed +1s (group units empty on spawn).
-- @param groupName string   DCS group name
-- @param cfg       table    { laserCode, smokeEnabled, smokeColor, lockMode }  (all optional)
-- @param spawner   table    { playerName, unitName, unitId, coalition }
-- @return CTLDJTAC or nil
function CTLDJTACManager:spawnJTAC(groupName, cfg, spawner)
    local dcsGroup = Group.getByName(groupName)
    if not dcsGroup then
        ctld.logError("CTLDJTACManager:spawnJTAC — group not found: " .. tostring(groupName))
        return nil
    end

    -- Resolve or assign laser code
    local laserCode = cfg and cfg.laserCode
    if not laserCode then
        laserCode = self:_assignLaserCode()
    end
    if not laserCode then
        ctld.logError("CTLDJTACManager:spawnJTAC — laser code pool exhausted")
        return nil
    end

    local coalitionId = dcsGroup:getCoalition()

    -- Unit may be nil for ~1s after spawn (DCS bug); classify defensively
    local dcsUnit    = dcsGroup:getUnits()[1]
    local isFlying   = false
    local isInfantry = false
    if dcsUnit then
        local attrs  = dcsUnit:getDesc().attributes or {}
        isFlying     = attrs["Planes"] == true or attrs["Helicopters"] == true
        isInfantry   = attrs["Infantry"] == true
    end

    -- Explicit false from caller must not be overridden by config (boolean or-pattern trap)
    local smokeEnabled
    if cfg and cfg.smokeEnabled ~= nil then
        smokeEnabled = cfg.smokeEnabled
    elseif coalitionId == coalition.side.RED then
        smokeEnabled = ctld.gs("JTAC_smokeOn_RED") or false
    else
        smokeEnabled = ctld.gs("JTAC_smokeOn_BLUE") or false
    end
    local smokeColor
    if cfg and cfg.smokeColor ~= nil then
        smokeColor = cfg.smokeColor
    elseif coalitionId == coalition.side.RED then
        smokeColor = ctld.gs("JTAC_smokeColour_RED") or trigger.smokeColor.Red
    else
        smokeColor = ctld.gs("JTAC_smokeColour_BLUE") or trigger.smokeColor.Red
    end
    local lockMode = (cfg and cfg.lockMode) or ctld.gs("JTAC_lock") or "all"

    local jtac = CTLDJTAC:new({
        groupName    = groupName,
        laserCode    = laserCode,
        isFlying     = isFlying,
        isInfantry   = isInfantry,
        coalitionId  = coalitionId,
        smokeEnabled = smokeEnabled,
        smokeColor   = smokeColor,
        lockMode     = lockMode,
        orbitParams  = cfg and cfg.orbitParams,
    })

    self.jtacs[groupName] = jtac

    -- DCS bug: coalition.addGroup leaves the group empty for ~1s after spawn.
    -- isFlying may be false if the unit wasn't readable yet. Schedule a T+2s retry
    -- that re-classifies the unit and starts orbit loop if needed.
    local function _tryInitFlying()
        local mgr = CTLDJTACManager.getInstance()
        local j   = mgr.jtacs[groupName]
        if not j then return end
        local g = Group.getByName(groupName)
        if not g then return end
        local u = g:getUnits()[1]
        if not u then return end

        -- Re-classify if isFlying was missed at registration time
        if not j.isFlying then
            local attrs = u:getDesc().attributes or {}
            if attrs["Planes"] == true or attrs["Helicopters"] == true then
                j.isFlying = true
            end
        end

        -- Capture initial position
        if j.isFlying and not j.initialPosition then
            j.initialPosition = u:getPoint()
        end

        -- Start orbit loop if not already running
        if j.isFlying and not mgr._orbitScheduleId then
            mgr._orbitScheduleId = timer.scheduleFunction(
                function(_, t) return CTLDJTACManager.getInstance():_orbitLoop(t) end,
                nil,
                timer.getTime() + 3
            )
        end
    end

    _tryInitFlying()
    -- Always schedule retry: covers DCS 1s delay even when immediate call succeeds partially
    timer.scheduleFunction(function() _tryInitFlying() end, nil, timer.getTime() + 2)

    -- DCS spawn bug: delay first auto-lase loop by 1s so group:getUnits()[1] is populated
    timer.scheduleFunction(
        function(gn, t) return CTLDJTACManager.getInstance():_autoLaseLoop(gn, t) end,
        groupName,
        timer.getTime() + 1
    )

    -- Publish event (dcsUnit may be nil within the 1s DCS spawn window — acceptable)
    self:_publishEvent("OnJTACSpawned", {
        jtac = {
            groupName  = groupName,
            groupId    = dcsGroup:getID(),
            unitName   = dcsUnit and dcsUnit:getName()    or groupName,
            unitId     = dcsUnit and dcsUnit:getID()      or nil,
            unitType   = dcsUnit and dcsUnit:getTypeName() or nil,
            coalition  = coalitionId,
            position   = dcsUnit and dcsUnit:getPoint()   or nil,
            isFlying   = isFlying,
            isInfantry = isInfantry,
            route      = jtac.initialRoute,
        },
        spawner      = spawner,
        laserCode    = laserCode,
        smokeEnabled = smokeEnabled,
        smokeColor   = smokeColor,
        lockMode     = lockMode,
        radio        = jtac.radio,
        timestamp    = timer.getAbsTime(),
    })

    -- Rebuild player menus so the new per-JTAC submenu appears immediately.
    CTLDPlayerManager.getInstance():refreshAll()

    return jtac
end

--- Get a JTAC entity by DCS group name.
-- @param groupName string
-- @return CTLDJTAC or nil
function CTLDJTACManager:getJTACByName(groupName)
    return self.jtacs[groupName]
end

--- Mark a ground JTAC as in-transit (called by CTLDTroopManager / CTLDVehicleSpawner).
-- @param groupName string   JTAC group name
-- @param transport table    { unitName, playerName }
function CTLDJTACManager:setJTACInTransit(groupName, transport)
    local jtac = self.jtacs[groupName]
    if not jtac or jtac.state == CTLDJTAC.STATE.DEAD then return end

    jtac:setInTransit()

    self:_publishEvent("OnJTACInTransit", {
        jtac      = { groupName = groupName, coalition = jtac.coalitionId },
        transport = transport,
        timestamp = timer.getAbsTime(),
    })
end

--- Silently deregister a JTAC (vehicle repacked into crates).
-- Stops lasing, frees laser code, removes from registry.
-- Does NOT publish OnJTACDead — repack is not a combat death.
-- @param groupName string
function CTLDJTACManager:deregisterJTAC(groupName)
    local jtac = self.jtacs[groupName]
    if not jtac then return end
    -- Release active target claim (stopLase below does not call _stopLaseAndPublish)
    if jtac.currentTarget then
        self:_releaseTarget(jtac.currentTarget.unitName)
    end
    local jtacKey = jtac.unitName or groupName
    self:_releaseAllTargetsFor(jtacKey)  -- belt-and-suspenders: clear any stale claims
    jtac:stopLase(CTLDJTAC.STOP_REASON.IN_TRANSIT)
    self:_freeLaserCode(jtac.laserCode)
    self.jtacs[groupName] = nil
    ctld.utils.log("INFO", "CTLDJTACManager:deregisterJTAC — '%s' silently deregistered", groupName)
    -- Rebuild player menus to remove the deregistered JTAC submenu.
    CTLDPlayerManager.getInstance():refreshAll()
end

--- Resume auto-lase for a JTAC after vehicle unload.
-- Restores state to IDLE and restarts the _autoLaseLoop.
-- @param groupName string
function CTLDJTACManager:resumeJTAC(groupName)
    local jtac = self.jtacs[groupName]
    if not jtac then return end
    jtac.state = CTLDJTAC.STATE.IDLE
    self:startLase(groupName)
    ctld.utils.log("INFO", "CTLDJTACManager:resumeJTAC — '%s' resumed after unload", groupName)
end

--- Smoke current target on demand (F10 menu action).
-- Applies JTAC_smokeMarginOfError offset.
-- @param groupName string
function CTLDJTACManager:requestSmoke(groupName)
    local jtac = self.jtacs[groupName]
    if not jtac or not jtac.currentTarget then return end

    local targetPos = jtac.currentTarget.position
    local margin    = ctld.gs("JTAC_smokeMarginOfError") or 50
    local smokePos  = {
        x = targetPos.x + (ctld.gs("JTAC_smokeOffset_x") or 0) + math.random(-margin, margin),
        y = targetPos.y + (ctld.gs("JTAC_smokeOffset_y") or 2),
        z = targetPos.z + (ctld.gs("JTAC_smokeOffset_z") or 0) + math.random(-margin, margin),
    }

    trigger.action.smoke(smokePos, jtac.smokeColor)

    self:_publishEvent("OnJTACSmokeTarget", {
        jtac          = { groupName = groupName, coalition = jtac.coalitionId },
        target        = { unitName = jtac.currentTarget.unitName, position = targetPos },
        smokePosition = smokePos,
        smokeColor    = jtac.smokeColor,
        timestamp     = timer.getAbsTime(),
    })
end

--- Called when a JTAC unit is destroyed (routed from CTLDDCSEventBridge / S_EVENT_DEAD).
-- @param groupName string
-- @param killer    table or nil  { unitName, playerName }
function CTLDJTACManager:killJTAC(groupName, killer)
    local jtac = self.jtacs[groupName]
    if not jtac then return end

    local lastTarget = jtac.currentTarget
    jtac:kill()

    local kiaMsg = CTLDJTACMessage.build({ event = "kia", jtacName = groupName })
    ctld.utils.notifyCoalition(kiaMsg.full, 10, jtac.coalitionId, jtac.radio, kiaMsg.short)

    self:_publishEvent("OnJTACDead", {
        jtac = {
            groupName = groupName,
            coalition = jtac.coalitionId,
            laserCode = jtac.laserCode,
        },
        killer      = killer,
        lastTarget  = lastTarget,
        timestamp   = timer.getAbsTime(),
    })

    self:_freeLaserCode(jtac.laserCode)
    self.jtacs[groupName] = nil
    -- Rebuild player menus to remove the dead JTAC submenu.
    CTLDPlayerManager.getInstance():refreshAll()
end

-- ============================================================
-- Legacy-compatible public API (called by compat/legacy_api.lua)
-- ============================================================

--- Spawn a flying JTAC from an unpacked crate and start auto-lase.
-- Orchestrates: ctld.utils.buildGroupUnitDef → spawnFromDescriptor → startLase.
-- Can also be called from legacy DO SCRIPT (ctld.JTACAutoLase wrapper path).
-- @param transport  Unit    transport unit (player helicopter)
-- @param position   vec3    horizontal spawn position {x, y, z} (y = ground level)
-- @param descriptor table   crate descriptor { unit, spawnAs, isJTAC, ... }
-- @param countryId  number  country.id.*
-- @return boolean  true if spawn succeeded
function CTLDJTACManager:deployAirJTAC(transport, position, descriptor, countryId)
    if not (ctld.gs("JTAC_dropEnabled") ~= false) then
        ctld.utils.log("INFO", "CTLDJTACManager:deployAirJTAC — JTAC_dropEnabled=false, skipped")
        return false
    end
    -- Default spawnAs to "AIRPLANE" when field absent (legacy compat)
    local desc  = descriptor.spawnAs and descriptor or { spawnAs = "AIRPLANE", unit = descriptor.unit, isJTAC = true }
    local gid   = ctld.utils.getNextUniqId()
    local uid   = ctld.utils.getNextUniqId()
    local gname = string.format("CTLD_AIR_%d", gid)
    local unitDef = ctld.utils.buildGroupUnitDef(desc, position, gname, gid, uid)
    local cId = countryId or country.id.USA
    local ok, err = ctld.utils.spawnFromDescriptor(desc, cId, unitDef)
    if not ok then
        local errStr = type(err) == "table" and ctld.utils.p(err) or tostring(err)
        ctld.utils.log("WARNING",
            "CTLDJTACManager:deployAirJTAC — spawnFromDescriptor failed: " .. errStr)
        return false
    end
    self:startLase(gname, nil, nil, nil, nil, nil, descriptor.specificParams)
    ctld.utils.log("INFO",
        string.format("CTLDJTACManager:deployAirJTAC — spawned %s as %s spawnAs=%s",
            gname, descriptor.unit, desc.spawnAs))
    return true
end

--- Activate auto-lase for an existing DCS JTAC group (MM DO SCRIPT).
-- Equivalent to legacy ctld.JTACAutoLase(). Wraps spawnJTAC with converted params.
-- @param groupName  string   DCS group name
-- @param laserCode  number   laser code 1111-1688 (nil = auto-assigned)
-- @param smoke      boolean  enable smoke on target
-- @param lock       string   "all" | "vehicle" | "troop" (nil = "all")
-- @param colour     number   trigger.smokeColor.* (nil = Red)
-- @param radio      table    { freq, mod, name } (nil = auto)
-- @param orbitParams table   { speed, alti, orbitRadiusNoLase, orbitRadiusOnLase } (nil = config defaults)
-- @return CTLDJTAC|nil
function CTLDJTACManager:autoLase(groupName, laserCode, smoke, lock, colour, radio, orbitParams)
    if self.jtacs[groupName] then
        ctld.utils.log("WARN", "CTLDJTACManager:autoLase — JTAC already active: %s", groupName)
        return self.jtacs[groupName]
    end
    local cfg = {
        laserCode    = laserCode and tonumber(laserCode) or nil,
        smokeEnabled = smoke == true,
        lockMode     = (lock == "vehicle" or lock == "troop") and lock or "all",
        smokeColor   = colour or trigger.smokeColor.Red,
        radio        = radio,
        orbitParams  = orbitParams,
    }
    return self:spawnJTAC(groupName, cfg, nil)
end

--- Activate auto-lase with a 1-second delay (legacy ctld.JTACStart behaviour).
-- @param groupName  string
-- @param laserCode  number
-- @param smoke      boolean
-- @param lock       string
-- @param colour     number
-- @param radio      table
-- @param orbitParams table  { speed, alti, orbitRadiusNoLase, orbitRadiusOnLase } (nil = config defaults)
function CTLDJTACManager:startLase(groupName, laserCode, smoke, lock, colour, radio, orbitParams)
    timer.scheduleFunction(
        function(args, t)
            CTLDJTACManager.getInstance():autoLase(
                args[1], args[2], args[3], args[4], args[5], args[6], args[7])
        end,
        { groupName, laserCode, smoke, lock, colour, radio, orbitParams },
        timer.getTime() + 1
    )
end

--- Register and start auto-lase for a JTAC infantry unit within a composite troop group.
-- Unlike spawnJTAC/startLase (which operate on single-unit DCS groups keyed by groupName),
-- this function targets a specific DCS unit by unitName (part of a composite group).
-- Registry key: unitName. Auto-lase loop uses Unit.getByName() instead of Group.getByName().
-- Death detection: handled by S_EVENT_DEAD → onUnitDead → deregisterJTAC (no killJTAC).
-- @param unitName  string   DCS unit name (JTAC-role infantry in a composite troop group)
-- @param cfg       table    { laserCode, smokeEnabled, smokeColor, lockMode } (all optional)
-- @return CTLDJTAC or nil
function CTLDJTACManager:startLaseTroopUnit(unitName, cfg)
    if self.jtacs[unitName] then
        ctld.utils.log("WARN", "CTLDJTACManager:startLaseTroopUnit — already active: %s", unitName)
        return self.jtacs[unitName]
    end

    local dcsUnit = Unit.getByName(unitName)
    if not dcsUnit or not dcsUnit:isExist() then
        ctld.utils.log("WARN", "CTLDJTACManager:startLaseTroopUnit — unit not found: %s", tostring(unitName))
        return nil
    end

    local laserCode = (cfg and cfg.laserCode) or self:_assignLaserCode()
    if not laserCode then
        ctld.logError("CTLDJTACManager:startLaseTroopUnit — laser code pool exhausted")
        return nil
    end

    local coalitionId = dcsUnit:getCoalition()
    local attrs       = dcsUnit:getDesc().attributes or {}
    local isInfantry  = attrs["Infantry"] == true

    local smokeEnabled
    if cfg and cfg.smokeEnabled ~= nil then
        smokeEnabled = cfg.smokeEnabled
    elseif coalitionId == coalition.side.RED then
        smokeEnabled = ctld.gs("JTAC_smokeOn_RED") or false
    else
        smokeEnabled = ctld.gs("JTAC_smokeOn_BLUE") or false
    end

    local smokeColor
    if cfg and cfg.smokeColor ~= nil then
        smokeColor = cfg.smokeColor
    elseif coalitionId == coalition.side.RED then
        smokeColor = ctld.gs("JTAC_smokeColour_RED") or trigger.smokeColor.Red
    else
        smokeColor = ctld.gs("JTAC_smokeColour_BLUE") or trigger.smokeColor.Red
    end

    local lockMode = (cfg and cfg.lockMode) or ctld.gs("JTAC_lock") or "all"

    local jtac = CTLDJTAC:new({
        groupName    = unitName,   -- registry key (= unitName for troop JTACs)
        unitName     = unitName,   -- marks as unit-keyed; drives Unit.getByName() in _autoLaseLoop
        laserCode    = laserCode,
        isFlying     = false,
        isInfantry   = isInfantry,
        coalitionId  = coalitionId,
        smokeEnabled = smokeEnabled,
        smokeColor   = smokeColor,
        lockMode     = lockMode,
    })

    self.jtacs[unitName] = jtac

    timer.scheduleFunction(
        function(un, t) return CTLDJTACManager.getInstance():_autoLaseLoop(un, t) end,
        unitName,
        timer.getTime() + 1
    )

    self:_publishEvent("OnJTACSpawned", {
        jtac = {
            groupName  = unitName,
            unitName   = unitName,
            laserCode  = laserCode,
            coalition  = coalitionId,
            isFlying   = false,
            isInfantry = isInfantry,
        },
        timestamp = timer.getAbsTime(),
    })

    ctld.utils.log("INFO",
        "CTLDJTACManager:startLaseTroopUnit — '%s' registered (code=%d)", unitName, laserCode)
    return jtac
end

--- Stop auto-lase for a JTAC group without firing the Dead event.
-- Sets the JTAC to standby mode; the auto-lase loop will stop lasing and idle.
-- @param groupName string
function CTLDJTACManager:stopAutoLase(groupName)
    local jtac = self.jtacs[groupName]
    if not jtac then
        ctld.utils.log("WARN", "CTLDJTACManager:stopAutoLase — JTAC not found: %s", tostring(groupName))
        return
    end
    jtac.standbyMode = true
    ctld.utils.log("INFO", "CTLDJTACManager:stopAutoLase — '%s' set to standby", groupName)
end

--- Destroy all active JTACs and reset state.
function CTLDJTACManager:cleanup()
    for _, jtac in pairs(self.jtacs) do
        jtac:destroy()
    end
    self.jtacs           = {}
    self._claimedTargets = {}
    self._laserPool      = {}
    self:_initLaserPool()
    self._orbitScheduleId = nil
end


-- ──────────────────────────────────────────────────
-- Private
-- ──────────────────────────────────────────────────

--- Main auto-lase loop for one JTAC. Self-rescheduling via timer.scheduleFunction.
-- Interval: JTAC_laseIntervalSeconds when lasing, JTAC_searchIntervalSeconds when searching.
-- @param groupName string
-- @param t         number  timer.getTime() at call time (provided by scheduleFunction)
-- @return number or nil    next schedule time (nil stops the loop)
function CTLDJTACManager:_autoLaseLoop(groupName, t)
    local jtac = self.jtacs[groupName]
    if not jtac then return nil end
    if jtac.state == CTLDJTAC.STATE.DEAD then return nil end

    local searchInterval = ctld.gs("JTAC_searchIntervalSeconds")
    local laseInterval   = ctld.gs("JTAC_laseIntervalSeconds")

    -- In transit: unit intentionally absent from map — do not probe DCS group existence.
    -- (virtual load: unit destroyed; dcs_native load: unit inside aircraft — both absent from ground)
    if jtac.state == CTLDJTAC.STATE.IN_TRANSIT then
        return t + searchInterval
    end

    -- Standby mode: stop lasing if active, wait
    if jtac.standbyMode then
        if jtac.currentTarget then
            self:_stopLaseAndPublish(jtac, CTLDJTAC.STOP_REASON.STANDBY_MODE)
        end
        return t + searchInterval
    end

    -- Resolve JTAC unit:
    --   unit-keyed (infantry in composite troop group): Unit.getByName(jtac.unitName)
    --   group-keyed (drone, vehicle — single-unit DCS group): Group.getByName():getUnits()[1]
    local jtacUnit
    if jtac.unitName then
        jtacUnit = Unit.getByName(jtac.unitName)
        if not jtacUnit or not jtacUnit:isExist() then
            -- Unit dead — S_EVENT_DEAD → onUnitDead → deregisterJTAC already handles cleanup.
            -- Just stop the loop; do NOT call killJTAC (would destroy the whole composite group).
            return nil
        end
    else
        local dcsGroup = Group.getByName(groupName)
        if not dcsGroup or not dcsGroup:isExist() then
            self:killJTAC(groupName, nil)
            return nil
        end
        jtacUnit = dcsGroup:getUnits()[1]
        if not jtacUnit or not jtacUnit:isExist() then
            -- Unit gone but group still reported alive — treat as dead
            self:killJTAC(groupName, nil)
            return nil
        end
    end

    -- ── Check existing target ──────────────────────────────────
    if jtac.currentTarget then
        local targetUnit = Unit.getByName(jtac.currentTarget.unitName)

        -- Target destroyed?
        if not targetUnit or not targetUnit:isExist() or targetUnit:getLife() <= 1 then
            self:_stopLaseAndPublish(jtac, CTLDJTAC.STOP_REASON.TARGET_DESTROYED)
            -- Fall through to search below
        else
            -- LOS still valid?
            local jtacPos   = jtacUnit:getPoint()
            local targetPos = targetUnit:getPoint()
            local offsetA   = { x = jtacPos.x,   y = jtacPos.y   + 2, z = jtacPos.z   }
            local offsetB   = { x = targetPos.x, y = targetPos.y + 2, z = targetPos.z }

            if not CTLDJTACDetector.checkLOS(offsetA, offsetB) then
                self:_stopLaseAndPublish(jtac, CTLDJTAC.STOP_REASON.TARGET_LOST)
                -- Fall through to search below
            else
                -- Target still valid — update spot position
                local correctedPos = targetPos
                if jtac.laseSpotCorrections then
                    local vel  = targetUnit:getVelocity()
                    local wind = atmosphere.getWind(targetPos)
                    correctedPos = CTLDJTACDetector.calculateCorrectedSpot(targetPos, vel, wind)
                end
                jtac:updateLaseSpot(correctedPos)

                self:_publishEvent("OnJTACTargetLased", {
                    jtac   = { groupName = groupName, unitName = jtacUnit:getName(), coalition = jtac.coalitionId },
                    target = { unitName = jtac.currentTarget.unitName, position = correctedPos },
                    laserCode = jtac.laserCode,
                    timestamp = timer.getAbsTime(),
                })
                return t + laseInterval
            end
        end
    end

    -- ── Search for new target (with deconfliction) ────────────
    -- findAllVisibleEnemies returns candidates sorted by priority then distance.
    -- With deconfliction enabled, iterate until a non-claimed target is found.
    -- jtacKey identifies this JTAC's slot in _claimedTargets.
    local jtacKey    = jtac.unitName or groupName
    local candidates = CTLDJTACDetector.findAllVisibleEnemies(
        jtacUnit, jtac.lockMode, ctld.gs("JTAC_maxDistance"))
    local found = nil

    if ctld.gs("JTAC_targetDeconfliction") ~= false then
        for _, candidate in ipairs(candidates) do
            if not self._claimedTargets[candidate.unitName] then
                found = candidate
                break
            end
        end
    else
        found = candidates[1]
    end

    if not found then
        return t + searchInterval
    end

    -- Claim the target before creating DCS spots — prevents a concurrent JTAC loop
    -- from selecting the same target in the same scheduler tick.
    self:_claimTarget(jtacKey, found.unitName)

    -- Stop ground unit movement while lasing.
    -- Use jtacUnit:getGroup() — works for both unit-keyed (infantry) and group-keyed (vehicle/drone)
    -- paths, because dcsGroup is scoped to the else-block above and not accessible here.
    if not jtac.isFlying then
        local stopGroup = jtacUnit:getGroup()
        if stopGroup then trigger.action.groupStopMoving(stopGroup) end
    end

    -- Compute lase position (with correction if enabled)
    local lasePos = found.position
    if jtac.laseSpotCorrections then
        local vel  = found.dcsUnit:getVelocity()
        local wind = atmosphere.getWind(found.position)
        lasePos = CTLDJTACDetector.calculateCorrectedSpot(found.position, vel, wind)
    end

    -- Create DCS Spot objects
    -- API: Spot.createLaser, Spot.createInfraRed — verified CTLD_jtac.lua source
    local spotOffset = { x = 0, y = 2, z = 0 }
    local laserSpot  = Spot.createLaser(jtacUnit, spotOffset, lasePos, jtac.laserCode)
    local irSpot     = Spot.createInfraRed(jtacUnit, spotOffset, lasePos)

    jtac:startLase(found, laserSpot, irSpot)

    -- Auto-smoke on target
    if jtac.smokeEnabled then
        trigger.action.smoke(lasePos, jtac.smokeColor)
    end

    -- Build and send player notification
    local msg = CTLDJTACMessage.build({
        event       = "new_target",
        jtacName    = groupName,
        targetType  = found.unitType,
        laserCode   = jtac.laserCode,
        positionStr = ctld.utils.getPositionString(found.dcsUnit),
        wasSelected = (jtac.selectedTarget == found.unitName),
        standby     = jtac.standbyMode,
    })
    ctld.utils.notifyCoalition(msg.full, 10, jtac.coalitionId, jtac.radio, msg.short)

    self:_publishEvent("OnJTACLaseStart", {
        jtac = {
            groupName = groupName,
            unitName  = jtacUnit:getName(),
            position  = jtacUnit:getPoint(),
            coalition = jtac.coalitionId,
        },
        target = {
            unitName            = found.unitName,
            unitId              = found.unitId,
            unitType            = found.unitType,
            coalition           = found.dcsUnit:getCoalition(),
            position            = found.position,
            priority            = found.priority,
            selectionMethod     = "auto_nearest",
            wasManuallySelected = false,
        },
        laserCode   = jtac.laserCode,
        lockMode    = jtac.lockMode,
        distance    = found.distance,
        lineOfSight = true,
        radio       = jtac.radio,
        message     = msg,
        timestamp   = timer.getAbsTime(),
    })

    return t + laseInterval
end

--- Shared orbit loop for all flying JTACs. Runs every 3 seconds.
-- Handles: orbit start, orbit update (every 60s), orbit stop + backToRoute.
-- API: Unit:getController():popTask(), Group:getController():pushTask()
--      verified CTLD_jtac.lua source (ctld.StartOrbitGroup / backToRoute)
-- @param t number  timer.getTime()
-- @return number or nil
function CTLDJTACManager:_orbitLoop(t)
    if ctld.gs("enableAutoOrbitingFlyingJtacOnTarget") == false then
        return t + 3  -- autoOrbit disabled
    end
    local hasFlying = false
    for groupName, jtac in pairs(self.jtacs) do
        if jtac.isFlying and jtac.state ~= CTLDJTAC.STATE.DEAD then
            self:_updateOrbit(groupName, jtac, t)
            hasFlying = true
        end
    end
    if not hasFlying then
        self._orbitScheduleId = nil
        return nil
    end
    return t + 3
end

--- Update orbit state for one flying JTAC.
-- Legacy pattern (pushTask/popTask):
--   • spawn → setTask(Mission loop) — initial circular route with SwitchWaypoint
--   • target acquired → pushTask(Orbit/Circle) — stacks on top of route
--   • target lost     → popTask()              — DCS restores the Mission route underneath
-- jtac.onTargetOrbit tracks which mode is active.
function CTLDJTACManager:_updateOrbit(groupName, jtac, t)
    local hasCurrent    = jtac.currentTarget ~= nil
    local inOrbit       = jtac.state == CTLDJTAC.STATE.ORBITING
    local onTargetOrbit = jtac.onTargetOrbit == true

    local dcsGroup = Group.getByName(groupName)
    if not dcsGroup then return end
    local jtacUnit = dcsGroup:getUnits()[1]
    if not jtacUnit then return end

    -- onTargetOrbit (not inOrbit/state) is the discriminator for all branches:
    --   false = drone on initial waypoint loop (or just spawned)
    --   true  = drone has a Circle pushTask on top of its initial Mission route

    if hasCurrent and not onTargetOrbit then
        -- Target acquired (or re-acquired after recovery) — pushTask Circle on initial route
        local targetUnit = Unit.getByName(jtac.currentTarget.unitName)
        if not targetUnit or not targetUnit:isExist() then return end

        local rOnLase = jtac.orbitParams and jtac.orbitParams.orbitRadiusOnLase or ctld.gs("JTAC_droneRadius") or 1000
        self:_setOrbitTask(dcsGroup, jtacUnit, targetUnit:getPoint(), jtac.orbitParams, rOnLase)
        jtac.onTargetOrbit = true
        jtac:startOrbit(t)

        self:_publishEvent("OnJTACOrbitStart", {
            jtac      = { groupName = groupName, coalition = jtac.coalitionId },
            target    = { unitName = jtac.currentTarget.unitName, position = jtac.currentTarget.position },
            timestamp = timer.getAbsTime(),
        })

    elseif hasCurrent and onTargetOrbit then
        -- Already on target orbit — update centre every 60s if target moved
        if jtac.orbitStartTime and (t - jtac.orbitStartTime) >= 60 then
            local targetUnit = Unit.getByName(jtac.currentTarget.unitName)
            if targetUnit and targetUnit:isExist() then
                local rOnLase = jtac.orbitParams and jtac.orbitParams.orbitRadiusOnLase or ctld.gs("JTAC_droneRadius") or 1000
                self:_setOrbitTask(dcsGroup, jtacUnit, targetUnit:getPoint(), jtac.orbitParams, rOnLase)
                jtac.orbitStartTime = t
            end
        end

    elseif not hasCurrent and onTargetOrbit then
        -- Target lost/destroyed:
        --   1. popTask on group controller → removes the pushed Circle orbit
        --   2. setTask(Mission) on group controller → replays stored initial route
        -- Both operate on group controller (same level as pushTask in _setOrbitTask).
        dcsGroup:getController():popTask()
        if jtac.initialRoute then
            dcsGroup:getController():setTask({
                id     = "Mission",
                params = { route = { points = jtac.initialRoute } },
            })
            ctld.utils.log("INFO", "[JTAC] _updateOrbit: target lost, route restored for %s", groupName)
        end
        jtac.onTargetOrbit = false
        jtac:stopOrbit()   -- back to IDLE: ORBITING is reserved for "following a lased target"

    elseif not hasCurrent and not inOrbit and not jtac.initialRouteAssigned then
        -- Just spawned, initialPosition captured — assign initial looping route (once only)
        if jtac.initialPosition then
            local rNoLase = jtac.orbitParams and jtac.orbitParams.orbitRadiusNoLase or ctld.gs("JTAC_droneRadius") or 1000
            self:_setOrbitRoute(dcsGroup, groupName, jtac.initialPosition, jtac.orbitParams, rNoLase)
            jtac.initialRouteAssigned = true
            jtac.onTargetOrbit        = false
            -- state stays IDLE: drone is "on route", not orbiting a target
        end
    end
end

--- Build and assign a looping circular Mission route as initial orbit.
-- Uses SwitchWaypoint on last WP to loop back to WP 1 (same as legacy editor route).
-- @param dcsGroup    DCS Group
-- @param groupName   string
-- @param center      vec3 or vec2  orbit center (= initialPosition)
-- @param orbitParams table or nil
-- @param radius      number meters (informational — DCS turn physics control effective radius)
local ORBIT_ROUTE_PTS = 8   -- 8 waypoints = 45° segments, reasonable turn radius
function CTLDJTACManager:_setOrbitRoute(dcsGroup, groupName, center, orbitParams, radius)
    local speedKmh = orbitParams and orbitParams.speed or 100
    local altiAGL  = orbitParams and orbitParams.alti  or ctld.gs("JTAC_droneAltitude") or 4000
    local vec2     = ctld.utils.makeVec2FromVec3OrVec2("_setOrbitRoute", center)
    local cx, cz   = vec2.x, vec2.y
    local terrainH = land.getHeight({ x = cx, y = cz })
    local altASL   = terrainH + altiAGL
    local speedMs  = speedKmh / 3.6
    local n        = ORBIT_ROUTE_PTS

    -- Find nearest WP to drone current position → start there
    local u = dcsGroup:getUnits()[1]
    local nearestIdx = 1
    if u then
        local upos = u:getPoint()
        local minD = math.huge
        for i = 1, n do
            local angle = 2 * math.pi * (i - 1) / n
            local dx = (cx + radius * math.cos(angle)) - upos.x
            local dz = (cz + radius * math.sin(angle)) - upos.z
            local d  = dx*dx + dz*dz
            if d < minD then minD = d; nearestIdx = i end
        end
    end

    -- Build n WPs with empty tasks, then rotate so nearest WP is first.
    -- SwitchWaypoint is placed on rotated[n] AFTER rotation so it always lands
    -- on the physically-last WP regardless of nearestIdx.
    local pts = {}
    for i = 1, n do
        local angle = 2 * math.pi * (i - 1) / n
        pts[i] = {
            x            = cx + radius * math.cos(angle),
            y            = cz + radius * math.sin(angle),
            alt          = altASL,
            alt_type     = "BARO",
            speed        = speedMs,
            speed_locked = true,
            type         = "Turning Point",
            action       = "Turning Point",
            ETA          = 0,
            ETA_locked   = false,
            task         = { id = "ComboTask", params = { tasks = {} } },
        }
    end

    -- Rotate so nearest WP is first → drone heads straight to it
    local rotated = {}
    for i = 1, n do
        rotated[i] = pts[((nearestIdx + i - 2) % n) + 1]
    end

    -- Attach SwitchWaypoint to the last rotated WP so the full circle loops correctly
    rotated[n].task = {
        id     = "ComboTask",
        params = {
            tasks = {
                [1] = {
                    enabled = true,
                    auto    = false,
                    id      = "WrappedAction",
                    number  = 1,
                    params  = {
                        action = {
                            id     = "SwitchWaypoint",
                            params = { goToWaypointIndex = 1, fromWaypointIndex = n },
                        },
                    },
                },
            },
        },
    }

    -- Store route for explicit replay on target loss (popTask is unreliable)
    local jtac = self.jtacs[groupName]
    if jtac then jtac.initialRoute = rotated end

    dcsGroup:getController():setTask({
        id     = "Mission",
        params = { route = { points = rotated } },
    })
    ctld.utils.log("INFO", "[JTAC] _setOrbitRoute %s center(%.0f,%.0f) r=%d altASL=%.0f start_wp=%d",
        groupName, cx, cz, radius, altASL, nearestIdx)
end

--- Push an Orbit/Circle task on top of the initial Mission route (legacy pushTask pattern).
-- popTask() first removes any previously pushed orbit, then pushTask() adds the new one.
-- The initial Mission route remains in the task stack — popTask() restores it on target loss.
-- @param dcsGroup    DCS Group
-- @param jtacUnit    DCS Unit  (used for popTask on the unit controller)
-- @param center      vec3 or vec2  orbit center (target position)
-- @param orbitParams table or nil  { speed(km/h), alti(m AGL) }
-- @param _radius     number  unused (DCS Circle radius is speed-controlled)
function CTLDJTACManager:_setOrbitTask(dcsGroup, jtacUnit, center, orbitParams, _radius)
    local orbitPoint = ctld.utils.makeVec2FromVec3OrVec2("_setOrbitTask", center)
    local speedKmh = orbitParams and orbitParams.speed or 100
    local altiAGL  = orbitParams and orbitParams.alti  or ctld.gs("JTAC_droneAltitude") or 4000
    local terrainH = land.getHeight({ x = orbitPoint.x, y = orbitPoint.y })
    local orbit = {
        id     = "Orbit",
        params = {
            pattern  = "Circle",
            point    = orbitPoint,
            altitude = terrainH + altiAGL,
            speed    = speedKmh / 3.6,
        },
    }
    -- Push orbit on GROUP controller so GROUP setTask(Mission) can cleanly replace it.
    -- popTask on UNIT first removes any stale unit-level task before group-level push.
    jtacUnit:getController():popTask()
    dcsGroup:getController():pushTask(orbit)
end

--- Record that jtacKey is actively lasing enemyUnitName.
-- Prevents other JTACs from selecting the same target.
-- @param jtacKey      string  unitName (infantry) or groupName (vehicle/drone)
-- @param enemyUnitName string  DCS unit name of the lased target
function CTLDJTACManager:_claimTarget(jtacKey, enemyUnitName)
    self._claimedTargets[enemyUnitName] = jtacKey
    ctld.utils.log("INFO", "[JTAC] claim: '%s' → '%s'", jtacKey, enemyUnitName)
end

--- Release the claim on a target (called when lasing stops for any reason).
-- @param enemyUnitName string
function CTLDJTACManager:_releaseTarget(enemyUnitName)
    if self._claimedTargets[enemyUnitName] then
        ctld.utils.log("INFO", "[JTAC] release claim on '%s' (was: '%s')",
            enemyUnitName, tostring(self._claimedTargets[enemyUnitName]))
        self._claimedTargets[enemyUnitName] = nil
    end
end

--- Release all target claims owned by jtacKey (called on deregister/cleanup).
-- Collects keys first to avoid mutating the table during iteration (Lua 5.1).
-- @param jtacKey string
function CTLDJTACManager:_releaseAllTargetsFor(jtacKey)
    local toRemove = {}
    for enemyUnitName, owner in pairs(self._claimedTargets) do
        if owner == jtacKey then
            toRemove[#toRemove + 1] = enemyUnitName
        end
    end
    for _, enemyUnitName in ipairs(toRemove) do
        self._claimedTargets[enemyUnitName] = nil
    end
    if #toRemove > 0 then
        ctld.utils.log("INFO", "[JTAC] _releaseAllTargetsFor '%s': %d claim(s) released", jtacKey, #toRemove)
    end
end

--- Stop lasing and publish OnJTACLaseStop event.
-- @param jtac   CTLDJTAC
-- @param reason string
function CTLDJTACManager:_stopLaseAndPublish(jtac, reason)
    local prevTarget = jtac.currentTarget
    -- Release target claim before stopLase() nils currentTarget
    if prevTarget then
        self:_releaseTarget(prevTarget.unitName)
    end
    jtac:stopLase(reason)

    -- Notify player on target events (not on internal transitions like standby/transit)
    if reason == CTLDJTAC.STOP_REASON.TARGET_LOST or reason == CTLDJTAC.STOP_REASON.TARGET_DESTROYED then
        local msg = CTLDJTACMessage.build({
            event       = reason,
            jtacName    = jtac.groupName,
            targetType  = prevTarget and prevTarget.unitType or nil,
            wasSelected = prevTarget ~= nil and (prevTarget.unitName == jtac.selectedTarget),
        })
        ctld.utils.notifyCoalition(msg.full, 10, jtac.coalitionId, jtac.radio, msg.short)
    end

    self:_publishEvent("OnJTACLaseStop", {
        jtac = {
            groupName = jtac.groupName,
            coalition = jtac.coalitionId,
            laserCode = jtac.laserCode,
        },
        target = prevTarget and {
            unitName          = prevTarget.unitName,
            unitType          = prevTarget.unitType,
            lastKnownPosition = prevTarget.position,
        } or nil,
        reason    = reason,
        timestamp = timer.getAbsTime(),
    })
end

--- Attempt to consume one JTAC slot for a coalition.
-- The quota is definitive (legacy behaviour): slots are never refilled when a JTAC dies.
-- Does NOT apply to MM JTACs (registerMMJTAC) or infantry JTAC soldiers.
-- @param coalitionId number  coalition.side.RED (1) or BLUE (2)
-- @return boolean, string|nil   true on success; false + i18n message when limit reached
function CTLDJTACManager:_consumeJTACSlot(coalitionId)
    local key   = (coalitionId == coalition.side.RED) and "JTAC_LIMIT_RED" or "JTAC_LIMIT_BLUE"
    local limit = ctld.gs(key) or 10
    local used  = self._jtacSlotsUsed[coalitionId] or 0
    if used >= limit then
        return false, ctld.tr("JTAC limit reached for your coalition.")
    end
    self._jtacSlotsUsed[coalitionId] = used + 1
    return true
end

--- Fill the laser pool with all valid codes (1111–1688). Called at init and cleanup.
function CTLDJTACManager:_initLaserPool()
    self._laserPool = {}
    for code = LASER_CODE_MIN, LASER_CODE_MAX do
        self._laserPool[#self._laserPool + 1] = code
    end
end

--- Assign next laser code from the pool. O(1) — removes from tail.
-- @return number or nil  (nil = pool exhausted)
function CTLDJTACManager:_assignLaserCode()
    return table.remove(self._laserPool)
end

--- Return a laser code to the pool.
-- @param code number
function CTLDJTACManager:_freeLaserCode(code)
    if code then
        self._laserPool[#self._laserPool + 1] = code
    end
end

--- Publish an event via EventDispatcher.
function CTLDJTACManager:_publishEvent(eventName, payload)
    EventDispatcher.getInstance():publish(eventName, payload)
end

--- Register a pre-placed MM JTAC group (reuses spawnJTAC logic).
-- Called by CTLDCoreManager:_initMMJTACs() for active groups,
-- and by onBirth() for late-activation groups.
-- @param group Group  DCS group object (must be active and exist)
-- @return CTLDJTAC or nil
function CTLDJTACManager:registerMMJTAC(group)
    return self:spawnJTAC(group:getName(), nil, "mission_maker")
end

--- Mark a JTAC group as pending late activation.
-- @param groupName string
function CTLDJTACManager:markPendingJTAC(groupName)
    self._pendingJTACs[groupName] = true
end

--- Return true if groupName is marked as pending.
-- @param groupName string
-- @return boolean
function CTLDJTACManager:_isPendingJTAC(groupName)
    return self._pendingJTACs[groupName] == true
end

--- Clear the pending flag for groupName.
-- @param groupName string
function CTLDJTACManager:_clearPendingJTAC(groupName)
    self._pendingJTACs[groupName] = nil
end

--- S_EVENT_BIRTH handler: activate pending late-activation JTAC groups.
-- Registered in CTLDDCSEventBridge by CTLDCoreManager.
function CTLDJTACManager:onBirth(event)
    local unit = event.initiator
    if not unit then return end
    local group = (unit.getGroup and unit:getGroup()) or nil
    if not group then return end
    local groupName = group:getName()
    if self:_isPendingJTAC(groupName) then
        self:registerMMJTAC(group)
        self:_clearPendingJTAC(groupName)
    end
end

-- ============================================================
-- F10 Menu section
-- ============================================================

--- Rebuild the "Request JTAC Equipment" dynamic submenu for playerObj.
-- Shows available types when landed in a logistics zone; placeholder otherwise.
-- Called from buildMenuSection and on landing/takeoff/FOB events.
-- @param playerObj CTLDPlayer
function CTLDJTACManager:refreshJtacEquipmentSection(playerObj)
    if ctld.gs("JTAC_dropEnabled") == false then return end
    if not playerObj.isTransport then return end

    -- Derive available JTAC types from spawnableCrates descriptors (isJTAC=true)
    -- rather than a separate JTAC_unitTypeNames list — single source of truth.
    local descs = CTLDCrateManager.getInstance():getJTACDescriptors(playerObj.coalition)
    if #descs == 0 then return end

    local mm   = ctld.MenuManager:getInstance()
    local menu = mm:getMenuByGroupId(playerObj.groupId)
    if not menu then return end

    local root    = ctld.tr("CTLD")
    local jtacSub = ctld.tr("JTAC")
    local reqSub  = ctld.tr("Request JTAC Equipment")
    menu:clearBranch({ root, jtacSub, reqSub })

    local transport = Unit.getByName(playerObj.unitName)
    if not (transport and transport:isExist()) or ctld.utils.inAir(transport) then
        menu:addCommand({ root, jtacSub, reqSub },
            ctld.tr("Land near logistics to request equipment"), function() end, {})
        menu:refresh()
        return
    end

    local zm   = CTLDZoneManager.getInstance()
    local zone = zm:getLogisticZoneAtPoint(transport:getPoint(), playerObj.coalition)
    if not zone then
        menu:addCommand({ root, jtacSub, reqSub },
            ctld.tr("No logistics in range"), function() end, {})
        menu:refresh()
        return
    end

    for _, desc in ipairs(descs) do
        menu:addCommand({ root, jtacSub, reqSub }, desc.desc,
            function(arg)
                local t = Unit.getByName(arg.unitName)
                if not (t and t:isExist()) then return end
                local z = CTLDZoneManager.getInstance()
                    :getLogisticZoneAtPoint(t:getPoint(), arg.coalition)
                if not z then
                    trigger.action.outTextForGroup(arg.groupId,
                        ctld.tr("You are not close enough to friendly logistics."), 10)
                    return
                end
                local result = CTLDVehicleSpawner.getInstance()
                    :spawnJTACFromDescriptor(arg.desc, t, z)
                if result then
                    trigger.action.outTextForGroup(arg.groupId,
                        ctld.tr("%1 is ready for pickup.", arg.desc.desc), 10)
                end
            end,
            { unitName  = playerObj.unitName,
              groupId   = playerObj.groupId,
              coalition = playerObj.coalition,
              desc      = desc })
    end
    menu:refresh()
end

--- Build the "JTAC" F10 submenu for a player.
--- Toggle standby mode for a JTAC.
-- standbyMode=false → true : stop lasing (STANDBY_MODE reason), announce deactivated.
-- standbyMode=true  → false: resume lasing via startLase, announce activated.
-- Rebuilds the per-JTAC command branch for all coalition players.
-- @param groupName string
-- @param groupId   number  player group id for confirmation message
function CTLDJTACManager:toggleStandby(groupName, groupId)
    local jtac = self.jtacs[groupName]
    if not jtac then
        trigger.action.outTextForGroup(groupId, ctld.tr("JTAC not found."), 8)
        return
    end
    if jtac.standbyMode then
        jtac.standbyMode = false
        self:startLase(groupName)
        trigger.action.outTextForGroup(groupId,
            ctld.tr("Lasing activated: %1", groupName), 8)
    else
        jtac.standbyMode = true
        if jtac.currentTarget then
            self:_stopLaseAndPublish(jtac, CTLDJTAC.STOP_REASON.STANDBY_MODE)
        end
        trigger.action.outTextForGroup(groupId,
            ctld.tr("Lasing deactivated (standby): %1", groupName), 8)
    end
    self:_rebuildJTACCommandBranch(groupName)
end

--- Toggle spot corrections for a JTAC.
-- @param groupName string
-- @param groupId   number  player group id for confirmation message
function CTLDJTACManager:toggleSpotCorrections(groupName, groupId)
    local jtac = self.jtacs[groupName]
    if not jtac then
        trigger.action.outTextForGroup(groupId, ctld.tr("JTAC not found."), 8)
        return
    end
    jtac.laseSpotCorrections = not jtac.laseSpotCorrections
    local msg = jtac.laseSpotCorrections
        and ctld.tr("Spot corrections activated: %1", groupName)
        or  ctld.tr("Spot corrections deactivated: %1", groupName)
    trigger.action.outTextForGroup(groupId, msg, 8)
    self:_rebuildJTACCommandBranch(groupName)
end

--- Rebuild the per-JTAC command submenu for all coalition players of this JTAC.
-- Called after toggleStandby / toggleSpotCorrections to update dynamic labels.
-- @param jtacGroupName string
function CTLDJTACManager:_rebuildJTACCommandBranch(jtacGroupName)
    local jtac = self.jtacs[jtacGroupName]
    if not jtac then return end
    local mm      = ctld.MenuManager:getInstance()
    local root    = ctld.tr("CTLD")
    local jtacSub = ctld.tr("JTAC")
    for _, playerObj in pairs(CTLDPlayerManager.getInstance()._players) do
        if playerObj.coalition == jtac.coalitionId then
            local menu = mm:getMenuByGroupId(playerObj.groupId)
            if menu then
                menu:clearBranch({ root, jtacSub, jtacGroupName })
                self:_buildJTACCommandsForGroup(jtacGroupName, jtac, menu, playerObj.groupId)
                menu:refresh()
            end
        end
    end
end

--- Build (or rebuild) the commands inside a per-JTAC submenu.
-- Labels for Toggle Lasing and Spot Corrections are dynamic (state-dependent).
-- @param groupName    string
-- @param jtac         CTLDJTAC
-- @param menu         ctld.Menu
-- @param playerGroupId number
function CTLDJTACManager:_buildJTACCommandsForGroup(groupName, jtac, menu, playerGroupId)
    local root    = ctld.tr("CTLD")
    local jtacSub = ctld.tr("JTAC")

    if ctld.gs("JTAC_allowStandbyMode") then
        local label = jtac.standbyMode
            and ctld.tr("Lasing [activate]")
            or  ctld.tr("Lasing [deactivate]")
        menu:addCommand({ root, jtacSub, groupName }, label,
            function(arg)
                CTLDJTACManager.getInstance():toggleStandby(arg.groupName, arg.groupId)
            end,
            { groupName = groupName, groupId = playerGroupId })
    end

    if ctld.gs("JTAC_laseSpotCorrections") ~= nil then
        local label = jtac.laseSpotCorrections
            and ctld.tr("Spot Corrections [deactivate]")
            or  ctld.tr("Spot Corrections [activate]")
        menu:addCommand({ root, jtacSub, groupName }, label,
            function(arg)
                CTLDJTACManager.getInstance():toggleSpotCorrections(arg.groupName, arg.groupId)
            end,
            { groupName = groupName, groupId = playerGroupId })
    end

    if ctld.gs("JTAC_allowSmokeRequest") then
        menu:addCommand({ root, jtacSub, groupName }, ctld.tr("Request Smoke on Target"),
            function(arg)
                CTLDJTACManager.getInstance():requestSmoke(arg.groupName)
            end,
            { groupName = groupName })
    end

    if ctld.gs("JTAC_allow9Line") then
        menu:addCommand({ root, jtacSub, groupName }, ctld.tr("Request 9-Line"),
            function(arg)
                ctld.utils.log("INFO", "9-Line for " .. arg.groupName)
            end,
            { groupName = groupName })
    end
end

-- Requires JTAC_jtacStatusF10 = true (configKey gate).
-- Adds "JTAC Status" command + per-active-JTAC submenus for player coalition.
-- On JTAC state changes (spawn/dead/transit), CTLDPlayerManager:refreshAll()
-- triggers a full wipe+rebuild, keeping this content current.
-- @param playerObj CTLDPlayer
-- @param menu      ctld.Menu
function CTLDJTACManager:buildMenuSection(playerObj, menu)
    local root    = ctld.tr("CTLD")
    local jtacSub = ctld.tr("JTAC")
    menu:addSubMenu({ root }, jtacSub, { order = 90 })

    -- Request JTAC Equipment: dynamic section rebuilt on landing/takeoff/FOB events.
    -- Populated from spawnableCrates descriptors with isJTAC=true (no separate type list).
    if ctld.gs("JTAC_dropEnabled") ~= false and playerObj.isTransport then
        local descs = CTLDCrateManager.getInstance():getJTACDescriptors(playerObj.coalition)
        if #descs > 0 then
            menu:addSubMenu({ root, jtacSub }, ctld.tr("Request JTAC Equipment"))
            self:refreshJtacEquipmentSection(playerObj)
        end
    end

    menu:addCommand({ root, jtacSub }, ctld.tr("JTAC Status"),
        function(arg)
            local mgr   = CTLDJTACManager.getInstance()
            local lines = {}
            for gname, j in pairs(mgr.jtacs) do
                if j.coalitionId == arg.coalition and j.state ~= CTLDJTAC.STATE.DEAD then
                    local target = j.currentTarget and j.currentTarget.unitName or ctld.tr("no target")
                    table.insert(lines, string.format("%s [%s] → %s (code %s)",
                        gname, tostring(j.state), target, tostring(j.laserCode or "?")))
                end
            end
            local msg = #lines > 0 and table.concat(lines, "\n") or ctld.tr("No active JTACs.")
            trigger.action.outTextForGroup(arg.groupId, msg, 15)
        end,
        { groupId = playerObj.groupId, coalition = playerObj.coalition })

    -- Per-active-JTAC submenus for this coalition
    for groupName, jtac in pairs(self.jtacs) do
        if jtac.coalitionId == playerObj.coalition and jtac.state ~= CTLDJTAC.STATE.DEAD then
            menu:addSubMenu({ root, jtacSub }, groupName)
            self:_buildJTACCommandsForGroup(groupName, jtac, menu, playerObj.groupId)
        end
    end
end
