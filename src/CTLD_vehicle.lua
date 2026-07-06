-- ============================================================
-- CTLD_vehicle.lua
-- CTLDVehicle entity + CTLDVehicleSpawner singleton
--
-- Vehicle lifecycle:
--   WAITING   — spawned on the ground, awaiting pick-up
--   LOADED    — loaded into a transport (DCS unit destroyed / bbox-tracked)
--   DELIVERED — unloaded from transport (DCS unit respawned)
--
-- Load methods:
--   "menu_ctld"  — virtual load via CTLD F10 menu: unit destroyed on load,
--                  respawned on unload using the original group / unit names
--   "dcs_native" — detected via bounding-box overlap with a C-130 / Il-76
--                  (vehicleTransportEnabled list)
--
-- Unload methods:
--   "menu_ctld"  — virtual unload: unit respawned near transport
--   "dcs_native" — bbox exit while transport is on the ground
--   "parachute"  — bbox exit while transport is airborne
--
-- Spawn position for spawnVehicleForTransport / unloadVehicle:
--   Uses the transport's own bounding box to compute a collision-free offset
--   (same logic as ctld.getSecureDistanceFromUnit), then places the unit in the
--   front sector (±45 ° of heading) of the transport.
--
-- Group / unit naming:
--   spawnVehicleForTransport assigns  groupName = "CTLD_VEH_<type>_<id>"
--   and                               unitName  = same as groupName
--   These names are preserved in spawnData and reused verbatim on unload so
--   that the unit re-appears under its original name on the F10 map.
--
-- Events published:
--   OnVehicleSpawnedForTransport  — vehicle spawned by spawnVehicleForTransport
--   OnVehicleLoaded               — vehicle loaded into a transport
--   OnVehicleUnloaded             — vehicle unloaded / dropped from a transport
--   OnVehicleDead                 — tracked vehicle destroyed (combat / accident)
--
-- Dependencies: class (lib/class.lua), ctld.utils, ctld.gs,
--               EventDispatcher, CTLDDCSEventBridge
-- DCS API: coalition, Group, Unit, land.getHeight, timer,
--          Unit:getTransformation, Unit:getDesc
-- ============================================================

---@diagnostic disable
ctld = ctld or {}

-- ============================================================
-- CTLDVehicle  (entity)
-- ============================================================

CTLDVehicle = class()

--- Valid states (class-level constants).
CTLDVehicle.STATE = {
    WAITING   = "WAITING",
    LOADED    = "LOADED",
    DELIVERED = "DELIVERED",
}

--- Constructor.
-- @param data table
--   Required: id (string), vehicleType (string), spawner (DCS Unit),
--             logisticZone (CTLDLogisticZone|nil), countryId (number),
--             coalitionId (number), spawnData (table — see below)
--   spawnData:  { groupName, unitName, vehicleType, countryId, coalitionId }
--   Optional:   unit (DCS Unit)   — the live DCS unit when in WAITING state
function CTLDVehicle:init(data)
    self.id           = data.id
    self.vehicleType  = data.vehicleType
    self.state        = CTLDVehicle.STATE.WAITING
    self.unit         = data.unit         or nil
    self.spawner      = data.spawner      or nil
    self.logisticZone = data.logisticZone or nil
    self.spawnData    = data.spawnData           -- preserved for respawn on unload
    self.spawnTime    = timer.getTime()
    self.loadTime     = nil
    self.loadMethod   = nil
    self.loadTransportName = nil
end

--- Transition to a new state.  No validation — callers are responsible.
-- @param newState string  CTLDVehicle.STATE.*
function CTLDVehicle:setState(newState)
    self.state = newState
end

--- Returns the current state string.
function CTLDVehicle:getState()
    return self.state
end


-- ============================================================
-- CTLDVehicleSpawner  (singleton)
-- ============================================================

CTLDVehicleSpawner = class()
CTLDVehicleSpawner._instance = nil

function CTLDVehicleSpawner.getInstance()
    if not CTLDVehicleSpawner._instance then
        local o = setmetatable({}, CTLDVehicleSpawner)
        o:init()
        CTLDVehicleSpawner._instance = o
    end
    return CTLDVehicleSpawner._instance
end

function CTLDVehicleSpawner:init()
    self._vehicles        = {}   -- id         → CTLDVehicle
    self._unitToVehicle   = {}   -- unitName   → vehicleId   (reverse lookup)
    self._vehicleCount    = 0
    self._parachuteEffect = CTLDNullParachuteEffect:new()
    -- nativeTracked: transportName → { vehicleId, wasInBbox }
    -- populated by _checkNativeLoading to avoid re-firing on same entry
    self._nativeTracked = {}

    local ok, bridge = pcall(CTLDDCSEventBridge.getInstance)
    if ok and bridge then
        bridge:register(self, world.event.S_EVENT_DEAD, "onDead")
    end

    -- Start periodic native-load detection (1 s cadence)
    timer.scheduleFunction(function(_, t)
        local inst = CTLDVehicleSpawner._instance
        if inst then inst:_checkNativeLoading() end
        return t + 1
    end, nil, timer.getTime() + 1)

    CTLDPlayerManager.getInstance():registerMenuSection({
        key     = "vehicles",
        manager = self,
        method  = "buildMenuSection",
        order   = 30,
    })

    -- Pack menu refresh: detect inAir→landed transition every 3 s
    self._prevInAir = {}
    timer.scheduleFunction(function(_, t)
        local inst = CTLDVehicleSpawner._instance
        if inst then inst:_checkPackingLanding() end
        return t + 3
    end, nil, timer.getTime() + 3)

    -- Hover hint: notify player to land when hovering in slingload window above a WAITING vehicle
    self._hoverHintSent = {}  -- unitName → last hint time
    timer.scheduleFunction(function(_, t)
        local inst = CTLDVehicleSpawner._instance
        if inst then inst:_checkVehicleHoverHint() end
        return t + 5
    end, nil, timer.getTime() + 5)

    -- Auto-refresh Pack Vehicle menu when ground units appear or disappear nearby
    local ed = EventDispatcher.getInstance()
    ed:subscribe("OnGroundUnitSpawned", function(payload)
        if payload and payload.position then
            CTLDVehicleSpawner.getInstance():_refreshNearbyPackPlayers(payload.position)
        end
    end)
    ed:subscribe("OnGroundUnitRemoved", function(payload)
        if payload and payload.position then
            CTLDVehicleSpawner.getInstance():_refreshNearbyPackPlayers(payload.position)
        end
    end)
    -- Request Vehicle also triggers a pack-menu refresh (vehicle appears on ground)
    ed:subscribe("OnVehicleSpawnedForTransport", function(payload)
        if payload and payload.position then
            CTLDVehicleSpawner.getInstance():_refreshNearbyPackPlayers(payload.position)
        end
    end)

    -- Load / Unload vehicle: refresh all vehicle submenus for the transport player
    ed:subscribe("OnVehicleLoaded", function(payload)
        local t = payload and payload.transportUnitObject
        if t then CTLDVehicleSpawner.getInstance():refreshVehicleMenuSectionsForUnit(t:getName()) end
    end)
    ed:subscribe("OnVehicleUnloaded", function(payload)
        local t = payload and payload.transportUnitObject
        if t then CTLDVehicleSpawner.getInstance():refreshVehicleMenuSectionsForUnit(t:getName()) end
    end)

    ctld.utils.log("INFO", "CTLDVehicleSpawner: init complete")
end

-- ============================================================
-- Helpers (module-local)
-- ============================================================

--- Secure spawn offset in metres derived from the transport's bounding box.
-- The minimum collision-free distance for a ±45° sector is the bounding box
-- diagonal sqrt(halfLen² + halfWid²).  A safety factor of ×2 is applied so
-- the spawned vehicle clears both the airframe and the rotor disk.
-- Falls back to 60 m if desc.box is unavailable.
local function _secureOffset(transport)
    local ok, box = pcall(function() return transport:getDesc().box end)
    if ok and box then
        local halfLen = math.max(math.abs(box.max.x), math.abs(box.min.x))
        local halfWid = math.max(math.abs(box.max.z), math.abs(box.min.z))
        return math.sqrt(halfLen * halfLen + halfWid * halfWid) * 2 + 10
    end
    return 60
end

--- Compute a spawn position near transport.
-- @param transport  DCS Unit
-- @param rearSector boolean  true = rear sector (behind transport, safe for AI takeoff)
-- @return vec3
local function _computeSpawnPosition(transport, rearSector)
    local hdg    = ctld.utils.getHeadingInRadians("CTLDVehicleSpawner._computeSpawnPosition",
                       transport, true)
    -- Rear sector: 180° offset so vehicle appears behind the helicopter,
    -- clear of the takeoff path when the AI resumes its route.
    local baseHdg = rearSector and (hdg + math.pi) or hdg
    local offset = _secureOffset(transport)
    local angle  = ctld.utils.RandomReal("CTLDVehicleSpawner._computeSpawnPosition",
                       baseHdg - math.pi / 4, baseHdg + math.pi / 4)
    local pos    = transport:getPoint()
    local px     = pos.x + math.cos(angle) * offset
    local pz     = pos.z + math.sin(angle) * offset
    local py     = land.getHeight({ x = px, y = pz })
    return { x = px, y = py, z = pz }
end

--- Public wrapper around _computeSpawnPosition for use by CTLDCoreManager.
-- @param transport  DCS Unit
-- @param rearSector boolean  true = rear sector
-- @return vec3
function CTLDVehicleSpawner:computeSafeDropPos(transport, rearSector)
    return _computeSpawnPosition(transport, rearSector)
end

--- True if the unit type has canTransportWholeVehicle=true in capabilitiesByType.
local function _isNativeCargoCapable(unit)
    local caps = (ctld.gs("capabilitiesByType") or {})[unit:getTypeName()]
    return caps ~= nil and caps.canTransportWholeVehicle == true
end

-- ============================================================
-- spawnVehicleForTransport
-- ============================================================

--- Spawn a vehicle on the ground near a transport, in the front sector.
-- Creates a CTLDVehicle in WAITING state and publishes OnVehicleSpawnedForTransport.
--
-- @param vehicleType  string        DCS type name (e.g. "M1045 HMMWV TOW")
-- @param spawner      DCS Unit      transport aircraft requesting the vehicle
-- @param logisticZone table|nil     CTLDLogisticZone from which the request is made
-- @return CTLDVehicle or nil on spawn failure
function CTLDVehicleSpawner:spawnVehicleForTransport(vehicleType, spawner, logisticZone)
    self._vehicleCount = self._vehicleCount + 1
    local id       = string.format("veh_%d", self._vehicleCount)
    local baseName = string.format("CTLD_VEH_%s_%s", vehicleType, id)
    -- Replace characters that DCS does not accept in group/unit names
    baseName = baseName:gsub("[%s/\\]", "_")

    local spawnPos   = _computeSpawnPosition(spawner)
    local countryId  = spawner:getCountry()
    local spawnHdg   = ctld.utils.getHeadingInRadians(
                           "CTLDVehicleSpawner:spawnVehicleForTransport", spawner, true)

    local groupData = {
        visible  = true,
        hidden   = false,
        category = Group.Category.GROUND,
        country  = countryId,
        name     = baseName,
        task     = {},
        units    = {
            {
                type           = vehicleType,
                name           = baseName,
                x              = spawnPos.x,
                y              = spawnPos.z,   -- dynAdd: y == world Z
                heading        = spawnHdg,
                skill          = "Random",
                playerCanDrive = false,
            }
        },
    }

    local result = ctld.utils.dynAdd("CTLDVehicleSpawner:spawnVehicleForTransport", groupData)
    if not result then
        ctld.utils.log("ERROR",
            "CTLDVehicleSpawner: dynAdd failed for vehicle type=" .. tostring(vehicleType))
        return nil
    end

    local spawnedGroup = Group.getByName(result.name)
    local spawnedUnit  = spawnedGroup and spawnedGroup:getUnit(1) or nil

    local spawnData = {
        groupName   = baseName,
        unitName    = baseName,
        vehicleType = vehicleType,
        countryId   = countryId,
        coalitionId = spawner:getCoalition(),
    }

    local vehicle = CTLDVehicle:new({
        id           = id,
        vehicleType  = vehicleType,
        unit         = spawnedUnit,
        spawner      = spawner,
        logisticZone = logisticZone,
        spawnData    = spawnData,
    })

    self._vehicles[id] = vehicle
    if spawnedUnit then
        self._unitToVehicle[spawnedUnit:getName()] = id
    end

    EventDispatcher.getInstance():publish("OnVehicleSpawnedForTransport", {
        vehicleId    = id,
        vehicle      = spawnedUnit,
        vehicleType  = vehicleType,
        spawner      = spawner,
        logisticZone = logisticZone,
        spawnMethod  = "request_vehicle",
        position     = spawnPos,
        timestamp    = timer.getAbsTime(),
    })

    ctld.utils.log("INFO", string.format(
        "CTLDVehicleSpawner: spawned %s id=%s at (%.0f,%.0f,%.0f)",
        vehicleType, id, spawnPos.x, spawnPos.y, spawnPos.z))

    return vehicle
end

--- Register an externally-spawned JTAC vehicle (from unpack or Request JTAC Equipment)
-- into the CTLDVehicleSpawner registry so that load/unload can track it.
-- @param groupName   string   DCS group name of the spawned unit
-- @param vehicleType string   DCS type name
-- @param spawner     DCS Unit transport that requested it (or nil for unpack)
-- @param logisticZone table|nil
-- @return CTLDVehicle or nil
function CTLDVehicleSpawner:registerJTACVehicle(groupName, vehicleType, spawner, logisticZone)
    self._vehicleCount = self._vehicleCount + 1
    local id      = string.format("veh_%d", self._vehicleCount)
    local g       = Group.getByName(groupName)
    local unit    = g and g:getUnit(1) or nil
    local coa     = unit and unit:getCoalition() or (spawner and spawner:getCoalition() or 2)
    local country = unit and unit:getCountry()   or (spawner and spawner:getCountry()   or 2)

    local spawnData = {
        groupName   = groupName,
        unitName    = groupName,
        vehicleType = vehicleType,
        countryId   = country,
        coalitionId = coa,
    }

    local vehicle = CTLDVehicle:new({
        id           = id,
        vehicleType  = vehicleType,
        unit         = unit,
        spawner      = spawner,
        logisticZone = logisticZone,
        spawnData    = spawnData,
    })

    self._vehicles[id] = vehicle
    if unit then
        self._unitToVehicle[unit:getName()] = id
    end

    ctld.utils.log("INFO", string.format(
        "CTLDVehicleSpawner:registerJTACVehicle — %s id=%s group=%s",
        vehicleType, id, groupName))
    return vehicle
end

--- Spawn a JTAC unit from a crate descriptor (Request JTAC Equipment menu action).
-- Handles both ground vehicles (spawnAs=nil/"GROUND") and drones (spawnAs="AIRPLANE").
-- Consumes one JTAC quota slot before spawning (definitive, non-refillable — legacy behaviour).
-- @param desc         table             crate descriptor with isJTAC=true
-- @param spawner      DCS Unit          requesting transport
-- @param logisticZone CTLDLogisticZone
-- @return CTLDVehicle|true|nil   CTLDVehicle for ground, true for air, nil on failure
function CTLDVehicleSpawner:spawnJTACFromDescriptor(desc, spawner, logisticZone)
    -- Quota check — same slot pool as the crate unpack path
    local coa = spawner:getCoalition()
    local ok, reason = CTLDJTACManager.getInstance():_consumeJTACSlot(coa)
    if not ok then
        local pObj = CTLDPlayerManager.getInstance()._players[spawner:getName()]
        if pObj then trigger.action.outTextForGroup(pObj.groupId, reason, 10) end
        ctld.utils.log("WARN", "CTLDVehicleSpawner:spawnJTACFromDescriptor — quota: %s", tostring(reason))
        return nil
    end

    local spawnAs = desc.spawnAs or "GROUND"
    if spawnAs ~= "GROUND" and spawnAs ~= "STATIC" then
        -- Air JTAC (drone): delegate to deployAirJTAC with transport position
        CTLDJTACManager.getInstance():deployAirJTAC(spawner, spawner:getPoint(), desc, spawner:getCountry())
        return true
    else
        -- Ground JTAC vehicle: spawn then register + start lasing
        local vehicle = self:spawnVehicleForTransport(desc.unit, spawner, logisticZone)
        if not vehicle then return nil end
        CTLDJTACManager.getInstance():startLase(vehicle.spawnData.groupName)
        return vehicle
    end
end

-- ============================================================
-- loadVehicle
-- ============================================================

--- Load a vehicle into a transport.
-- The DCS unit is destroyed from the map.  spawnData is preserved for respawn.
-- Publishes OnVehicleLoaded.
--
-- @param vehicle   CTLDVehicle
-- @param transport DCS Unit
-- @param player    string|nil  player name
-- @param method    string      "menu_ctld" | "dcs_native"
function CTLDVehicleSpawner:loadVehicle(vehicle, transport, player, method)
    if vehicle:getState() ~= CTLDVehicle.STATE.WAITING then
        ctld.utils.log("WARNING", "CTLDVehicleSpawner:loadVehicle — vehicle "
            .. vehicle.id .. " not in WAITING state")
        return
    end

    -- Guard: enforce per-type vehicle capacity limit (menu_ctld only;
    -- dcs_native capacity is managed by DCS itself).
    if method == "menu_ctld" then
        local caps_t      = (ctld.gs("capabilitiesByType") or {})[transport:getTypeName()]
        local maxVehicles = (caps_t and caps_t.maxWholeVehiclesOnboard) or 1
        local loaded      = self:findLoadedVehicles(transport)
        if #loaded >= maxVehicles then
            local pObj = CTLDPlayerManager.getInstance()._players[transport:getName()]
            if pObj then
                trigger.action.outTextForGroup(pObj.groupId,
                    ctld.tr("Cannot load more vehicles (%1/%2).", #loaded, maxVehicles), 8)
            end
            ctld.utils.log("WARNING",
                "CTLDVehicleSpawner:loadVehicle — transport %s at vehicle capacity (%d)",
                transport:getName(), maxVehicles)
            return
        end
    end

    local unitPos = vehicle.unit and vehicle.unit:getPoint() or transport:getPoint()

    -- Suspend JTAC lasing if this vehicle is a registered JTAC (any load method).
    -- For menu_ctld: unit is about to be destroyed so lasing must stop immediately.
    -- For dcs_native: unit stays alive inside aircraft but lasing from inside a soute is nonsensical.
    local groupName = vehicle.spawnData and vehicle.spawnData.groupName
    if groupName then
        CTLDJTACManager.getInstance():setJTACInTransit(groupName,
            { unitName = transport:getName(), playerName = player })
    end

    if method == "dcs_native" then
        -- DCS manages the unit physically (linked inside aircraft) — do not destroy it.
        -- Remove from reverse lookup so onDead doesn't misfire if DCS sends a stale event.
        if vehicle.unit then
            self._unitToVehicle[vehicle.unit:getName()] = nil
        end
    else
        -- Virtual load: destroy the DCS unit from the map.
        if vehicle.unit and vehicle.unit:isExist() then
            vehicle.unit:destroy()
            EventDispatcher.getInstance():publish("OnGroundUnitRemoved", {
                vehicleType = vehicle.vehicleType,
                position    = unitPos,
                reason      = "loaded",
                timestamp   = timer.getAbsTime(),
            })
        end
        if vehicle.unit then
            self._unitToVehicle[vehicle.unit:getName()] = nil
        end
        vehicle.unit = nil
    end

    vehicle.loadMethod        = method
    vehicle.loadTransportName = transport:getName()
    vehicle.loadTime          = timer.getTime()
    vehicle:setState(CTLDVehicle.STATE.LOADED)

    -- Update DCS internal cargo weight (menu_ctld only; dcs_native is physical).
    if method == "menu_ctld" then
        self:_updateVehicleCargo(transport:getName())
    end

    -- Confirmation message to player (menu_ctld only; dcs_native load is confirmed by DCS itself).
    if method == "menu_ctld" then
        local pObj = CTLDPlayerManager.getInstance()._players[transport:getName()]
        if pObj then
            local desc  = CTLDCrateManager.getInstance():findDescriptorByUnitType(vehicle.vehicleType)
            local label = desc and desc.desc or vehicle.vehicleType
            trigger.action.outTextForGroup(pObj.groupId,
                ctld.tr("Vehicle loaded: %1.", label), 8)
        end
    end

    EventDispatcher.getInstance():publish("OnVehicleLoaded", {
        vehicleId            = vehicle.id,
        ctldVehicleObject    = vehicle,
        dcsUnitObject        = method == "dcs_native" and vehicle.unit or nil,
        vehicleType          = vehicle.vehicleType,
        transportUnitObject  = transport,
        player               = player,
        method               = method,
        spawnMethod          = "request_vehicle",
        position             = unitPos,
        transportPosition    = transport:getPoint(),
        timestamp            = timer.getAbsTime(),
    })

    ctld.utils.log("INFO", string.format(
        "CTLDVehicleSpawner: loaded %s id=%s method=%s into %s",
        vehicle.vehicleType, vehicle.id, method, transport:getName()))
end

-- ============================================================
-- unloadVehicle
-- ============================================================

--- Unload a vehicle from a transport.
-- For menu_ctld / parachute: respawns DCS unit near transport via dynAdd.
-- For dcs_native: DCS has already placed the unit on the ground — just refresh the ref.
-- Publishes OnVehicleUnloaded.
--
-- @param vehicle    CTLDVehicle
-- @param transport  DCS Unit
-- @param player     string|nil
-- @param method     string      "menu_ctld" | "dcs_native" | "parachute"
-- @param rearSector boolean|nil true = spawn behind transport (AI dropoff use case)
function CTLDVehicleSpawner:unloadVehicle(vehicle, transport, player, method, rearSector)
    if vehicle:getState() ~= CTLDVehicle.STATE.LOADED then
        ctld.utils.log("WARNING", "CTLDVehicleSpawner:unloadVehicle — vehicle "
            .. vehicle.id .. " not in LOADED state")
        return
    end

    local sd       = vehicle.spawnData
    local spawnPos = _computeSpawnPosition(transport, rearSector)
    local unloadedUnit

    if method == "dcs_native" then
        -- DCS has already placed the unit on the ground — recover the live ref.
        local g = Group.getByName(sd.groupName)
        unloadedUnit = g and g:getUnit(1) or nil
    else
        -- Virtual unload: respawn unit near transport immediately.
        local spawnHdg = ctld.utils.getHeadingInRadians(
                             "CTLDVehicleSpawner:unloadVehicle", transport, true)
        local groupData = {
            visible  = true,
            hidden   = false,
            category = Group.Category.GROUND,
            country  = sd.countryId,
            name     = sd.groupName,
            -- Group-level position must match unit position for coalition.addGroup
            x        = spawnPos.x,
            y        = spawnPos.z,
            task     = {},
            units    = {
                {
                    type           = sd.vehicleType,
                    name           = sd.unitName,
                    x              = spawnPos.x,
                    y              = spawnPos.z,
                    heading        = spawnHdg,
                    skill          = "Random",
                    playerCanDrive = false,
                }
            },
        }
        local result = ctld.utils.dynAdd("CTLDVehicleSpawner:unloadVehicle", groupData)
        if not result then
            ctld.utils.log("ERROR", "CTLDVehicleSpawner:unloadVehicle — dynAdd failed for id="
                .. vehicle.id)
            return
        end
        local respawnedGroup = Group.getByName(result.name)
        unloadedUnit = respawnedGroup and respawnedGroup:getUnit(1) or nil
    end

    vehicle.unit = unloadedUnit
    -- Vehicle is physically back on the ground — return to WAITING so it can be re-loaded.
    -- DELIVERED is reserved for parachute delivery (_parachuteVehicle).
    vehicle:setState(CTLDVehicle.STATE.WAITING)

    -- Re-register reverse lookup
    if unloadedUnit then
        self._unitToVehicle[unloadedUnit:getName()] = vehicle.id
    end

    -- Update DCS internal cargo weight (dcs_native weight is managed by DCS itself).
    if method ~= "dcs_native" then
        self:_updateVehicleCargo(transport:getName())
    end

    -- Resume JTAC lasing if this vehicle is a registered JTAC.
    local groupName = sd and sd.groupName
    if groupName then
        CTLDJTACManager.getInstance():resumeJTAC(groupName)
    end

    -- Confirmation message to player (menu_ctld only; dcs_native unload is confirmed by DCS itself).
    if method == "menu_ctld" then
        local pObj = CTLDPlayerManager.getInstance()._players[transport:getName()]
        if pObj then
            local desc  = CTLDCrateManager.getInstance():findDescriptorByUnitType(vehicle.vehicleType)
            local label = desc and desc.desc or vehicle.vehicleType
            trigger.action.outTextForGroup(pObj.groupId,
                ctld.tr("Vehicle unloaded: %1.", label), 8)
        end
    end

    EventDispatcher.getInstance():publish("OnVehicleUnloaded", {
        vehicleId            = vehicle.id,
        ctldVehicleObject    = vehicle,
        dcsUnitObject        = unloadedUnit,
        vehicleType          = vehicle.vehicleType,
        transportUnitObject  = transport,
        player               = player,
        method               = method,
        spawnMethod          = "request_vehicle",
        position             = spawnPos,
        timestamp            = timer.getAbsTime(),
    })

    ctld.utils.log("INFO", string.format(
        "CTLDVehicleSpawner: unloaded %s id=%s method=%s from %s",
        vehicle.vehicleType, vehicle.id, method, transport:getName()))
end

-- ============================================================
-- Bbox helpers (_worldToLocal, _isInBbox)
-- ============================================================

--- Convert a world-frame point to the local frame of a DCS unit.
-- @param worldPoint vec3  { x, y, z } in world coordinates
-- @param transform  table Unit:getTransformation() result
--                   { p={x,y,z}, x={x,y,z}, y={x,y,z}, z={x,y,z} }
-- @return vec3  local-frame coordinates
function CTLDVehicleSpawner:_worldToLocal(worldPoint, transform)
    local dx = worldPoint.x - transform.p.x
    local dy = worldPoint.y - transform.p.y
    local dz = worldPoint.z - transform.p.z
    return {
        x = dx * transform.x.x + dy * transform.x.y + dz * transform.x.z,
        y = dx * transform.y.x + dy * transform.y.y + dz * transform.y.z,
        z = dx * transform.z.x + dy * transform.z.y + dz * transform.z.z,
    }
end

--- True if a local-frame point lies within a DCS bounding box.
-- @param localPoint vec3  result of _worldToLocal
-- @param box        table desc.box  { min={x,y,z}, max={x,y,z} }
-- @return boolean
function CTLDVehicleSpawner:_isInBbox(localPoint, box)
    return  localPoint.x >= box.min.x and localPoint.x <= box.max.x
        and localPoint.y >= box.min.y and localPoint.y <= box.max.y
        and localPoint.z >= box.min.z and localPoint.z <= box.max.z
end

-- ============================================================
-- _checkNativeLoading  (periodic, every 1 s)
-- ============================================================

--- Periodic check for DCS-native C-130 / Il-76 bbox load / unload detection.
-- For every transport in vehicleTransportEnabled that exists on the map:
--   • WAITING vehicle enters bbox  → loadVehicle (method="dcs_native")
--   • LOADED  vehicle exits  bbox  → unloadVehicle (method depends on inAir flag)
function CTLDVehicleSpawner:_checkNativeLoading()

    -- Collect all active WAITING vehicles with live units
    local waitingVehicles = {}
    for id, veh in pairs(self._vehicles) do
        if veh:getState() == CTLDVehicle.STATE.WAITING
            and veh.unit and veh.unit:isExist() then
            waitingVehicles[id] = veh
        end
    end

    -- Collect all LOADED vehicles tracked via dcs_native
    local nativeLoaded = {}
    for id, veh in pairs(self._vehicles) do
        if veh:getState() == CTLDVehicle.STATE.LOADED
            and veh.loadMethod == "dcs_native" then
            nativeLoaded[id] = veh
        end
    end

    if not next(waitingVehicles) and not next(nativeLoaded) then return end

    -- Iterate transports currently known as player units (via CTLDPlayerTracker)
    -- and check each capable-transport unit that we can find by name
    -- Simple approach: scan all groups of both coalitions for matching type
    for _, side in ipairs({ coalition.side.BLUE, coalition.side.RED }) do
        local groups = coalition.getGroups(side, Group.Category.AIRPLANE) or {}
        for _, grp in ipairs(groups) do
            local units = grp:getUnits() or {}
            for _, transport in ipairs(units) do
                if transport:isExist() and _isNativeCargoCapable(transport) then
                    local ok, transform = pcall(function()
                        return transport:getTransformation()
                    end)
                    local ok2, box
                    if ok and transform then
                        ok2, box = pcall(function()
                            return transport:getDesc().box
                        end)
                    end

                    if ok and transform and ok2 and box then
                        local tName = transport:getName()

                        -- Check WAITING vehicles for bbox entry
                        for id, veh in pairs(waitingVehicles) do
                            if veh.unit and veh.unit:isExist() then
                                local uPos = veh.unit:getPoint()
                                local lp   = self:_worldToLocal(uPos, transform)
                                if self:_isInBbox(lp, box) then
                                    -- Vehicle entered bbox → load
                                    self:loadVehicle(veh, transport, nil, "dcs_native")
                                    -- Track transport for exit detection
                                    self._nativeTracked[tName] = self._nativeTracked[tName] or {}
                                    self._nativeTracked[tName][id] = true
                                    waitingVehicles[id] = nil  -- prevent double-fire
                                end
                            end
                        end

                        -- Check LOADED (native) vehicles for bbox exit
                        for id, veh in pairs(nativeLoaded) do
                            if veh.loadTransportName == tName then
                                -- Vehicle is LOADED but we can't query its position (unit destroyed)
                                -- Use the tracked entry: if transport still alive, consider still loaded
                                -- Exit is detected by the transport being gone or in a different state
                                -- NOTE: When DCS ejects cargo the unit reappears; we detect the
                                -- re-appearance via the unit's new existence on next tick.
                                -- For parachute / ground exit we check if the spawned unit exists again.
                            end
                        end
                    end
                end
            end
        end
    end
end

-- ============================================================
-- INIT-D — MM vehicle detection
-- ============================================================

--- Register a single live DCS Unit as a WAITING CTLDVehicle if its type
-- has a spawnableCrates descriptor and is not already tracked.
-- Called both at startup (scanMMVehicles) and on S_EVENT_BIRTH (late activation).
-- @param unit  DCS Unit
function CTLDVehicleSpawner:_registerMMVehicleUnit(unit)
    if not (unit and unit:isExist()) then return end
    local unitName = unit:getName()
    if self._unitToVehicle[unitName] then return end  -- already tracked

    local typeName   = unit:getTypeName()
    local descriptor = CTLDCrateManager.getInstance():findDescriptorByUnitType(typeName)
    if not descriptor then return end  -- not a CTLD-known vehicle type

    self._vehicleCount = self._vehicleCount + 1
    local id = string.format("veh_mm_%d", self._vehicleCount)

    local grp = unit:getGroup()
    local spawnData = {
        groupName   = grp and grp:getName() or unitName,
        unitName    = unitName,
        vehicleType = typeName,
        coalitionId = unit:getCoalition(),
        countryId   = unit:getCountry(),
    }

    local vehicle = CTLDVehicle:new({
        id          = id,
        vehicleType = typeName,
        unit        = unit,
        spawnData   = spawnData,
    })

    self._vehicles[id]          = vehicle
    self._unitToVehicle[unitName] = id

    ctld.utils.log("INFO",
        "CTLDVehicleSpawner: INIT-D registered MM vehicle id=%s type=%s unit=%s",
        id, typeName, unitName)
end

--- INIT-D: scan all active ground groups for MM-placed vehicles with CTLD descriptors.
-- Only registers units that are alive (isExist=true) — late-activation groups are skipped.
function CTLDVehicleSpawner:scanMMVehicles()
    local sides = { coalition.side.RED, coalition.side.BLUE }
    local count = 0
    for _, side in ipairs(sides) do
        local groups = coalition.getGroups(side, Group.Category.GROUND) or {}
        for _, grp in ipairs(groups) do
            for _, unit in ipairs(grp:getUnits() or {}) do
                if unit:isExist() then
                    local before = self._vehicleCount
                    self:_registerMMVehicleUnit(unit)
                    if self._vehicleCount > before then count = count + 1 end
                end
            end
        end
    end
    ctld.utils.log("INFO", "CTLDVehicleSpawner: INIT-D complete — %d MM vehicle(s) registered", count)
end

--- S_EVENT_BIRTH handler: register late-activation MM ground vehicles.
-- S_EVENT_BIRTH fires synchronously inside coalition.addGroup, before the calling
-- CTLD spawn function (spawnVehicleForTransport, registerJTACVehicle, etc.) has had
-- time to register the vehicle. Processing is therefore deferred by one frame via
-- timer.scheduleFunction so that all CTLD registrations complete first.
function CTLDVehicleSpawner:onBirth(event)
    if not event or not event.initiator then return end
    local ok, unit = pcall(function() return event.initiator end)
    if not ok or not unit then return end
    local okCat, cat = pcall(function() return Object.getCategory(unit) end)
    if not okCat or cat ~= Object.Category.UNIT then return end
    local okGrp, grp = pcall(function() return unit:getGroup() end)
    if not okGrp or not grp then return end
    if grp:getCategory() ~= Group.Category.GROUND then return end

    -- Capture ref for the deferred callback (unit object stays valid across frames).
    local capturedUnit = unit
    timer.scheduleFunction(function()
        local inst = CTLDVehicleSpawner._instance
        if inst then inst:_onBirthDeferred(capturedUnit) end
    end, nil, timer.getTime())
end

--- Deferred S_EVENT_BIRTH processing — runs one frame after the birth event.
-- By this point every CTLD spawn function has registered its vehicle in _vehicles,
-- so _unitToVehicle guards work correctly without any name-prefix assumptions.
function CTLDVehicleSpawner:_onBirthDeferred(unit)
    if not (unit and unit:isExist()) then return end
    local unitName = unit:getName()

    -- Already tracked by a CTLD spawn function — nothing to do.
    if self._unitToVehicle[unitName] then return end

    -- Post-unload MM vehicle respawn: _unitToVehicle was cleared on load but the
    -- CTLDVehicle object is still in _vehicles (state LOADED → WAITING after unload).
    for _, veh in pairs(self._vehicles) do
        if veh.spawnData and veh.spawnData.unitName == unitName then
            veh.unit = unit
            self._unitToVehicle[unitName] = veh.id
            ctld.utils.log("INFO",
                "CTLDVehicleSpawner:_onBirthDeferred — updated ref for existing vehicle id=%s unit=%s",
                veh.id, unitName)
            return
        end
    end

    -- Unknown unit — register as a new MM vehicle if it has a CTLD descriptor.
    self:_registerMMVehicleUnit(unit)
end

-- ============================================================
-- onDead  (S_EVENT_DEAD handler)
-- ============================================================

--- Handle S_EVENT_DEAD: if the dead unit is a tracked vehicle, publish OnVehicleDead.
-- Also handles transport destruction: if the dead unit is a transport carrying LOADED
-- vehicles, each vehicle is considered lost — JTAC is deregistered and OnVehicleDead
-- is published for each.
function CTLDVehicleSpawner:onDead(event)
    if not event or not event.initiator then return end
    local ok, unitName = pcall(function() return event.initiator:getName() end)
    if not ok then return end

    local vehicleId = self._unitToVehicle[unitName]
    if vehicleId then
        -- Dead unit is a tracked ground vehicle.
        local vehicle = self._vehicles[vehicleId]
        if not vehicle then return end

        local pos      = vehicle.unit and vehicle.unit:getPoint() or { x = 0, y = 0, z = 0 }
        local spawnedAt = vehicle.spawnTime or 0

        self._vehicles[vehicleId]    = nil
        self._unitToVehicle[unitName] = nil

        EventDispatcher.getInstance():publish("OnVehicleDead", {
            vehicleId     = vehicleId,
            vehicle       = event.initiator,
            vehicleType   = vehicle.vehicleType,
            coalition     = vehicle.spawnData and vehicle.spawnData.coalitionId or nil,
            position      = pos,
            durationAlive = timer.getTime() - spawnedAt,
            timestamp     = timer.getAbsTime(),
        })
        EventDispatcher.getInstance():publish("OnGroundUnitRemoved", {
            vehicleType = vehicle.vehicleType,
            position    = pos,
            reason      = "dead",
            timestamp   = timer.getAbsTime(),
        })

        ctld.utils.log("INFO", string.format(
            "CTLDVehicleSpawner: vehicle %s (%s) dead",
            vehicleId, vehicle.vehicleType))
        return
    end

    -- Dead unit is not a tracked vehicle — check if it is a transport carrying LOADED vehicles.
    -- Collect all vehicles loaded on this transport before iterating (safe pairs modification).
    local lost = {}
    for id, veh in pairs(self._vehicles) do
        if veh:getState() == CTLDVehicle.STATE.LOADED
            and veh.loadTransportName == unitName then
            table.insert(lost, { id = id, veh = veh })
        end
    end

    if #lost == 0 then return end

    local transportPos = { x = 0, y = 0, z = 0 }
    local ok2, pos2 = pcall(function() return event.initiator:getPoint() end)
    if ok2 and pos2 then transportPos = pos2 end

    local jtacMgr = CTLDJTACManager.getInstance()
    for _, entry in ipairs(lost) do
        local id  = entry.id
        local veh = entry.veh

        -- Deregister JTAC silently (frees laser code + claim, no OnJTACDead).
        local gname = veh.spawnData and veh.spawnData.groupName
        if gname and jtacMgr.jtacs and jtacMgr.jtacs[gname] then
            jtacMgr:deregisterJTAC(gname)
        end

        -- Clear reverse lookup if still present (dcs_native load keeps unit alive briefly).
        if veh.unit then
            self._unitToVehicle[veh.unit:getName()] = nil
        end
        self._vehicles[id] = nil

        EventDispatcher.getInstance():publish("OnVehicleDead", {
            vehicleId     = id,
            vehicle       = nil,   -- unit was inside transport, no live DCS ref
            vehicleType   = veh.vehicleType,
            coalition     = veh.spawnData and veh.spawnData.coalitionId or nil,
            position      = transportPos,
            durationAlive = timer.getTime() - (veh.spawnTime or 0),
            timestamp     = timer.getAbsTime(),
        })

        ctld.utils.log("INFO", string.format(
            "CTLDVehicleSpawner: vehicle %s (%s) lost — transport %s destroyed",
            id, veh.vehicleType, unitName))
    end
end

-- ============================================================
-- Feature A — Virtual parachute
-- ============================================================

--- Replace the parachute visual effect handler.
-- @param effect CTLDParachuteEffect
function CTLDVehicleSpawner:setParachuteEffect(effect)
    self._parachuteEffect = effect
end

--- Parachute a vehicle currently loaded on a transport.
-- Altitude AGL is checked at call time. If below parachuteMinAltitudeVehicles,
-- a message is sent and nothing happens.
-- Computes landing position, unloads the vehicle from the transport,
-- fires OnVehicleParachuting, then after descentTime spawns the vehicle
-- at the computed position and fires OnVehicleParachuteLanded.
-- @param transport  Unit    DCS transport unit
-- @param vehicleId  number  vehicle ID to drop (first loaded vehicle if nil)
-- @param playerObj  table   CTLDPlayer-like {groupId, unitName, coalition}
function CTLDVehicleSpawner:parachuteVehicle(transport, vehicleId, playerObj)
    local dropPos     = transport:getPoint()
    local groundUnder = land.getHeight({ x = dropPos.x, y = dropPos.z })
    local altAGL      = dropPos.y - groundUnder
    local minAlt      = ctld.gs("parachuteMinAltitudeVehicles") or 30

    if altAGL < minAlt then
        trigger.action.outTextForGroup(playerObj.groupId,
            ctld.tr("Altitude too low for parachute drop. Minimum: %1m AGL (current: %2m AGL)",
                math.floor(minAlt), math.floor(altAGL)), 10)
        return
    end

    -- Resolve vehicle: use provided vehicleId or find first vehicle loaded on this transport
    local vehicle
    if vehicleId then
        vehicle = self._vehicles[vehicleId]
    else
        for _, v in pairs(self._vehicles) do
            if v.state == CTLDVehicle.STATE.LOADED and v.loadTransportName == transport:getName() then
                vehicle = v
                break
            end
        end
    end

    if not vehicle then
        trigger.action.outTextForGroup(playerObj.groupId, ctld.tr("No vehicle loaded."), 8)
        return
    end

    local descentRate = ctld.gs("parachuteDescentRateVehicles") or 8
    local landPos, descentTime = ctld.utils.calcDropPosition(transport, descentRate)

    -- Announce drop to the player group
    trigger.action.outTextForGroup(playerObj.groupId,
        ctld.tr("Parachuting vehicle %1 — landing in ~%2s",
            vehicle.vehicleType, math.floor(descentTime)), 10)

    -- Unload from transport — vehicle will be re-spawned at landing position.
    -- State is set to WAITING (not DELIVERED) so the vehicle can be reloaded after landing.
    local spawnData = vehicle.spawnData
    vehicle:setState(CTLDVehicle.STATE.WAITING)
    vehicle.loadTransportName = nil
    vehicle.loadMethod        = nil
    self:_updateVehicleCargo(transport:getName())

    local dropData = {
        type          = "vehicle",
        unitName      = vehicle.vehicleType,
        dropPosition  = dropPos,
        landPositions = { landPos },
        altitude      = altAGL,
        descentTime   = descentTime,
        transport     = transport,
        player        = playerObj.unitName,
    }
    self._parachuteEffect:onStart(dropData)

    EventDispatcher.getInstance():publish("OnVehicleParachuting", {
        vehicle              = vehicle,
        transport            = transport:getName(),
        player               = playerObj.unitName,
        altitude             = altAGL,
        dropPosition         = dropPos,
        estimatedLandingPos  = landPos,
        estimatedLandingTime = timer.getAbsTime() + descentTime,
        timestamp            = timer.getAbsTime(),
    })

    local _vehicle       = vehicle
    local _landPos       = landPos
    local _dropData      = dropData
    local _spawnData     = spawnData
    local _transportName = transport:getName()
    timer.scheduleFunction(function()
        -- Spawn vehicle at computed landing position
        local spawnPos = { x = _landPos.x, y = _landPos.y, z = _landPos.z }
        if _spawnData then
            self:spawnVehicleAt(_spawnData, spawnPos)
        end

        -- Resume JTAC lasing if this vehicle is a registered JTAC (was set IN_TRANSIT on load).
        local gname = _spawnData and _spawnData.groupName
        if gname then
            local jtacMgr = CTLDJTACManager.getInstance()
            if jtacMgr.jtacs and jtacMgr.jtacs[gname] then
                jtacMgr:resumeJTAC(gname)
            end
        end

        self._parachuteEffect:onLanded(_dropData)

        EventDispatcher.getInstance():publish("OnVehicleParachuteLanded", {
            vehicle       = _vehicle,
            position      = _landPos,
            transport     = _transportName,
            player        = playerObj.unitName,
            startAltitude = altAGL,
            timestamp     = timer.getAbsTime(),
        })
    end, {}, timer.getTime() + descentTime)
end

--- Low-level ground unit factory.
-- Calls ctld.utils.spawnFromDescriptor (GROUND) and publishes OnGroundUnitSpawned so that
-- nearby Pack Vehicle menus refresh automatically.
-- @param spawnData  table  { vehicleType, groupName, unitName, coalitionId, country }
-- @param position   vec3   world position {x, y, z}
function CTLDVehicleSpawner:_spawnGroundUnit(spawnData, position)
    if not spawnData then return end
    local cId     = spawnData.country or spawnData.coalitionId or 2
    local unitDef = {
        name    = spawnData.groupName or (spawnData.vehicleType .. "_spawn_" .. timer.getAbsTime()),
        task    = "Ground Nothing",
        units   = {{
            type    = spawnData.vehicleType,
            name    = spawnData.unitName or spawnData.vehicleType,
            x       = position.x,
            y       = position.z,
            heading = 0,
        }},
    }
    local ok, err = ctld.utils.spawnFromDescriptor(nil, cId, unitDef)
    if not ok then
        ctld.utils.log("WARNING", "CTLDVehicleSpawner:_spawnGroundUnit - spawnFromDescriptor failed: " .. tostring(err))
        return
    end
    EventDispatcher.getInstance():publish("OnGroundUnitSpawned", {
        vehicleType = spawnData.vehicleType,
        position    = position,
        coalitionId = spawnData.coalitionId or 2,
        timestamp   = timer.getAbsTime(),
    })
end

--- Spawn a vehicle at an explicit world position (used by unpack and parachute drop).
-- @param spawnData  table   vehicle spawn descriptor
-- @param position   vec3    world position {x, y, z}
function CTLDVehicleSpawner:spawnVehicleAt(spawnData, position)
    self:_spawnGroundUnit(spawnData, position)
end

--- Refresh Pack Vehicle and Load Vehicle menus for all players within
-- maximumDistancePackableUnitsSearch of a position.
-- @param position vec3
function CTLDVehicleSpawner:_refreshNearbyPackPlayers(position)
    if not position then return end
    local maxDist = ctld.gs("maximumDistancePackableUnitsSearch") or 200
    local pm      = CTLDPlayerManager.getInstance()
    for unitName in pairs(pm._players) do
        local unit = Unit.getByName(unitName)
        if unit and unit:isExist() then
            if ctld.utils.getDistance("_refreshNearbyPackPlayers", unit:getPoint(), position) <= maxDist then
                self:refreshPackSectionForUnit(unitName)
                self:refreshLoadSectionForUnit(unitName)
            end
        end
    end
end

-- ============================================================
-- F10 Menu section
-- ============================================================

-- ============================================================
-- Pack Vehicle
-- ============================================================

--- Detect inAir→landed transition for each player and refresh their menu.
-- Mirrors ctld.updatePackMenuOnlanding; called every 3 s from init timer.
function CTLDVehicleSpawner:_checkPackingLanding()
    if ctld.gs("enablePackingVehicles") ~= true then return end
    local players = CTLDPlayerManager.getInstance()._players
    for unitName, _ in pairs(players) do
        local unit = Unit.getByName(unitName)
        if unit and unit:isExist() then
            local inAirNow = ctld.utils.inAir(unit)
            if self._prevInAir[unitName] == true and not inAirNow then
                -- Rescan packable / loadable vehicles before rebuilding DCS menu.
                self:refreshPackSectionForUnit(unitName)
                self:refreshLoadSectionForUnit(unitName)
                CTLDPlayerManager.getInstance():refreshForUnit(unitName)
            end
            self._prevInAir[unitName] = inAirNow
        else
            self._prevInAir[unitName] = nil
        end
    end
end

--- Periodic hint: send "Land to load vehicles" when a canCarryVehicles player hovers
-- between 3 m and maximumHoverHeight above a WAITING vehicle.
-- Called every 5 s; per-player cooldown of 30 s.
function CTLDVehicleSpawner:_checkVehicleHoverHint()
    local now      = timer.getTime()
    local cooldown = 30
    local minH     = 3.0
    local maxH     = ctld.gs("maximumHoverHeight") or 12.0
    local maxDist  = 5.0  -- tight horizontal window for hover detection (m)
    local players  = CTLDPlayerManager.getInstance()._players

    for unitName, playerObj in pairs(players) do
        if playerObj.canCarryVehicles then
            local unit = Unit.getByName(unitName)
            if unit and unit:isExist() and ctld.utils.inAir(unit) then
                local lastHint = self._hoverHintSent[unitName] or 0
                if (now - lastHint) >= cooldown then
                    local tPos = unit:getPoint()
                    for _, veh in pairs(self._vehicles) do
                        if veh:getState() == CTLDVehicle.STATE.WAITING
                            and veh.unit and veh.unit:isExist() then
                            local vPos  = veh.unit:getPoint()
                            local dist2d = ctld.utils.getDistance(
                                "CTLDVehicleSpawner:_checkVehicleHoverHint", tPos, vPos)
                            local altDiff = tPos.y - vPos.y
                            if dist2d <= maxDist and altDiff >= minH and altDiff <= maxH then
                                self._hoverHintSent[unitName] = now
                                trigger.action.outTextForGroup(playerObj.groupId,
                                    ctld.tr("Land to load vehicles"), 8)
                                break
                            end
                        end
                    end
                end
            end
        end
    end
end

--- Return packable vehicles within maximumDistancePackableUnitsSearch of a transport.
-- Only considers CTLD-managed vehicles in WAITING state — not arbitrary coalition ground units.
-- This prevents scene props (guards, workers) from polluting the Pack Vehicle menu.
-- @param transport DCS Unit
-- @return table  array of { unitName (string), descriptor (table) }
function CTLDVehicleSpawner:findPackableVehicles(transport)
    local maxDist = ctld.gs("maximumDistancePackableUnitsSearch") or 200
    local tPos    = transport:getPoint()
    local result  = {}

    for _, veh in pairs(self._vehicles) do
        if veh:getState() == CTLDVehicle.STATE.WAITING then
            local uName = veh.spawnData and veh.spawnData.unitName
            if uName then
                local liveRef = Unit.getByName(uName)
                if liveRef and liveRef:isExist() then
                    local dist = ctld.utils.getDistance(
                        "CTLDVehicleSpawner:findPackableVehicles", tPos, liveRef:getPoint())
                    if dist <= maxDist then
                        local descriptor = CTLDCrateManager.getInstance()
                            :findDescriptorByUnitType(liveRef:getTypeName())
                        if descriptor then
                            table.insert(result, { unitName = uName, descriptor = descriptor })
                        end
                    end
                end
            end
        end
    end
    return result
end

--- Pack a vehicle back into crate(s).
-- Destroys the vehicle DCS unit and spawns cratesRequired static crates near the transport.
-- Front sector (heli) or rear sector (C-130/Il-76, dynamic cargo capable).
-- Publishes OnVehiclePacked and refreshes the player menu.
-- @param transportUnitName  string
-- @param packableUnitName   string
-- @param playerObj          table  { groupId, unitName, coalition }
function CTLDVehicleSpawner:packVehicle(transportUnitName, packableUnitName, playerObj)
    local transport = Unit.getByName(transportUnitName)
    if not (transport and transport:isExist()) then
        ctld.utils.log("WARNING", "CTLDVehicleSpawner:packVehicle - transport not found: "
            .. tostring(transportUnitName))
        return
    end

    local packableUnit = Unit.getByName(packableUnitName)
    if not (packableUnit and packableUnit:isExist()) then
        trigger.action.outTextForGroup(playerObj.groupId, ctld.tr("Vehicle no longer exists."), 8)
        return
    end

    local descriptor = CTLDCrateManager.getInstance()
        :findDescriptorByUnitType(packableUnit:getTypeName())
    if not descriptor then
        trigger.action.outTextForGroup(playerObj.groupId, ctld.tr("Cannot pack this vehicle type."), 8)
        return
    end

    local isDynamic    = _isNativeCargoCapable(transport)
    local hdg          = ctld.utils.getHeadingInRadians("CTLDVehicleSpawner:packVehicle", transport, true)
    local offset       = _secureOffset(transport)
    local cratesReq    = descriptor.cratesRequired or 1
    local modelKey     = isDynamic and "dynamic" or "load"
    local coa          = transport:getCoalition()
    local cId          = transport:getCountry()
    local tPos         = transport:getPoint()
    local packPos      = packableUnit:getPoint()   -- capture before destroy

    -- Silently deregister JTAC before destroy to prevent false OnJTACDead event.
    local packGroup = packableUnit:getGroup()
    if packGroup then
        CTLDJTACManager.getInstance():deregisterJTAC(packGroup:getName())
    end

    packableUnit:destroy()
    EventDispatcher.getInstance():publish("OnGroundUnitRemoved", {
        vehicleType = packableUnit:getTypeName(),
        position    = packPos,
        reason      = "packed",
        timestamp   = timer.getAbsTime(),
    })

    -- Spawn crates in a straight line; spawnCratesAligned picks a random axis
    -- within the front sector (standard) or rear sector (native-cargo-capable).
    local descriptors = {}
    for _ = 1, cratesReq do table.insert(descriptors, descriptor) end
    CTLDCrateManager.getInstance():spawnCratesAligned(
        descriptors, transport, coa,
        playerObj and playerObj.unitName or nil,
        CTLDCrate.SPAWN_METHOD.VEHICLE_PACK)

    trigger.action.outTextForGroup(playerObj.groupId,
        ctld.tr("%1 packed into %2 crate(s).", descriptor.desc, cratesReq), 10)

    EventDispatcher.getInstance():publish("OnVehiclePacked", {
        vehicleType  = packableUnit:getTypeName(),
        descriptor   = descriptor,
        transport    = transportUnitName,
        player       = playerObj and playerObj.unitName or nil,
        cratesSpawned = cratesReq,
        timestamp    = timer.getAbsTime(),
    })

    -- Defer menu rebuild by one frame: coalition.getGroups() has a 1-frame lag after
    -- unit:destroy(), so a same-tick rebuild would still find the (now dead) unit and
    -- re-add it to the Pack Vehicle menu, causing a "Vehicle no longer exists" error
    -- when the player clicks it later.
    local _tName = transportUnitName
    timer.scheduleFunction(function()
        CTLDPlayerManager.getInstance():refreshForUnit(_tName)
    end, nil, timer.getTime())
end

--- Delegates to CTLDCrateManager:refreshPackEquiptSection for a single player by unit name.
-- @param unitName string
function CTLDVehicleSpawner:refreshPackSectionForUnit(unitName)
    local playerObj = CTLDPlayerManager.getInstance()._players[unitName]
    if playerObj then
        CTLDCrateManager.getInstance():refreshPackEquiptSection(playerObj)
    end
end

--- Delegates to CTLDCrateManager:refreshPackEquiptSection (unified Pack Equipt menu).
-- @param playerObj CTLDPlayer
function CTLDVehicleSpawner:refreshPackSection(playerObj)
    CTLDCrateManager.getInstance():refreshPackEquiptSection(playerObj)
end

-- ============================================================
-- GAP-1 — Load / Unload vehicle via menu
-- ============================================================

--- Return loadable (WAITING) vehicles within maximumDistancePackableUnitsSearch of a transport.
-- Performs a lazy unit-reference resolution for vehicles registered before their DCS group
-- was fully available (coalition.addGroup has a 1-frame delay before Group.getByName works).
-- @param transport DCS Unit
-- @return table  array of CTLDVehicle
--- Returns true if vehicleType is in the loadable list for transportTypeName + coalition.
-- @param vehicleType       string   DCS unit type name
-- @param transportTypeName string   transport unit type
-- @param coalition         number   1=RED 2=BLUE
-- @return bool
function CTLDVehicleSpawner:_isTypeLoadable(vehicleType, transportTypeName, coalition)
    local caps = (ctld.gs("capabilitiesByType") or {})[transportTypeName]
    if not (caps and caps.canTransportWholeVehicle) then return false end
    local list = (coalition == 1) and caps.loadableVehiclesRED or caps.loadableVehiclesBLUE
    if not list then return false end
    for _, t in ipairs(list) do
        if t == vehicleType then return true end
    end
    return false
end

--- Return WAITING vehicles that this transport can load (whole-vehicle method).
-- Filters: distance <= maximumDistancePackableUnitsSearch
--          + same coalition as transport (GAP-Q1)
--          + vehicleType in loadableVehiclesRED/BLUE for this transport (GAP-Q2)
-- Returns {} immediately if canTransportWholeVehicle is not set for this transport.
function CTLDVehicleSpawner:findLoadableVehicles(transport)
    local tTypeName = transport:getTypeName()
    local tCoa      = transport:getCoalition()
    local caps      = (ctld.gs("capabilitiesByType") or {})[tTypeName]
    if not (caps and caps.canTransportWholeVehicle) then return {} end

    local maxDist = ctld.gs("maximumDistancePackableUnitsSearch") or 200
    local tPos    = transport:getPoint()
    local result  = {}
    for id, veh in pairs(self._vehicles) do
        if veh:getState() == CTLDVehicle.STATE.WAITING then
            -- Coalition filter (GAP-Q1)
            if veh.spawnData and veh.spawnData.coalitionId ~= tCoa then
                -- skip: wrong coalition
            else
                -- Lazy resolve: unit ref may be nil if registered before DCS group was ready.
                if not veh.unit and veh.spawnData and veh.spawnData.groupName then
                    local g = Group.getByName(veh.spawnData.groupName)
                    local u = g and g:getUnit(1) or nil
                    if u and u:isExist() then
                        veh.unit = u
                        self._unitToVehicle[u:getName()] = id
                    end
                end
                if veh.unit and veh.unit:isExist() then
                    -- Type filter (GAP-Q2)
                    if self:_isTypeLoadable(veh.vehicleType, tTypeName, tCoa) then
                        local dist = ctld.utils.getDistance(
                            "CTLDVehicleSpawner:findLoadableVehicles", tPos, veh.unit:getPoint())
                        if dist <= maxDist then
                            table.insert(result, veh)
                        end
                    end
                end
            end
        end
    end
    return result
end

--- Return vehicles currently LOADED on a transport (by unit name).
-- @param transport DCS Unit
-- @return table  array of CTLDVehicle
function CTLDVehicleSpawner:findLoadedVehicles(transport)
    local tName  = transport:getName()
    local result = {}
    for _, veh in pairs(self._vehicles) do
        if veh:getState() == CTLDVehicle.STATE.LOADED
            and veh.loadTransportName == tName then
            table.insert(result, veh)
        end
    end
    return result
end

--- Returns total weight of CTLD-loaded (menu_ctld) vehicles on a transport.
--- dcs_native vehicles are excluded: DCS manages their physical weight.
--- @param transportUnitName string
--- @return number  kg
function CTLDVehicleSpawner:getLoadedVehicleWeight(transportUnitName)
    local weights = ctld.gs("groundVehicleWeights") or {}
    local total   = 0
    for _, veh in pairs(self._vehicles) do
        if veh:getState() == CTLDVehicle.STATE.LOADED
            and veh.loadTransportName == transportUnitName
            and veh.loadMethod == "menu_ctld" then
            total = total + (weights[veh.vehicleType] or 2500)
        end
    end
    return total
end

--- Updates DCS internal cargo weight for a transport.
--- Delegates to ctld.utils.updateTransportWeight to aggregate all cargo sources
--- (troops + crates + vehicles) into a single setUnitInternalCargo call.
--- @param transportUnitName string
function CTLDVehicleSpawner:_updateVehicleCargo(transportUnitName)
    ctld.utils.updateTransportWeight(transportUnitName)
end

--- Rebuild the "Load / Extract Vehicles" dynamic submenu for playerObj.
-- Transport must be landed; lists nearby WAITING vehicles.
-- @param playerObj CTLDPlayer
function CTLDVehicleSpawner:refreshLoadSection(playerObj)
    if not playerObj.canCarryVehicles then return end

    local mm   = ctld.MenuManager:getInstance()
    local menu = mm:getMenuByGroupId(playerObj.groupId)
    if not menu then return end

    local root    = ctld.tr("CTLD")
    local vehSub  = ctld.tr("Vehicle Commands")
    local loadSub = ctld.tr("Load / Extract Vehicles")

    menu:clearBranch({ root, vehSub, loadSub })

    local transport = Unit.getByName(playerObj.unitName)
    if not (transport and transport:isExist()) or ctld.utils.inAir(transport) then
        menu:setBranchEnabled({ root, vehSub, loadSub }, false)
        menu:refresh()
        return
    end
    menu:setBranchEnabled({ root, vehSub, loadSub }, true)

    local loadable = self:findLoadableVehicles(transport)
    if #loadable == 0 then
        menu:addCommand({ root, vehSub, loadSub },
            ctld.tr("No vehicles nearby"), function() end, {})
    else
        for _, veh in ipairs(loadable) do
            local desc  = CTLDCrateManager.getInstance():findDescriptorByUnitType(veh.vehicleType)
            local label = desc and desc.desc or veh.vehicleType
            menu:addCommand({ root, vehSub, loadSub }, label,
                function(arg)
                    local t = Unit.getByName(arg.unitName)
                    if not (t and t:isExist()) then return end
                    if ctld.utils.inAir(t) then
                        trigger.action.outTextForGroup(arg.groupId,
                            ctld.tr("Land to load vehicles"), 8)
                        return
                    end
                    local v = CTLDVehicleSpawner.getInstance()._vehicles[arg.vehicleId]
                    if not v or v:getState() ~= CTLDVehicle.STATE.WAITING then
                        trigger.action.outTextForGroup(arg.groupId,
                            ctld.tr("Vehicle no longer available."), 8)
                        return
                    end
                    CTLDVehicleSpawner.getInstance():loadVehicle(v, t, arg.unitName, "menu_ctld")
                    CTLDPlayerManager.getInstance():refreshForUnit(arg.unitName)
                end,
                { unitName  = playerObj.unitName,
                  groupId   = playerObj.groupId,
                  vehicleId = veh.id,
                  coalition = playerObj.coalition })
        end
    end
    menu:refresh()
end

--- Rebuild the "Unload Vehicles" dynamic submenu for playerObj.
-- Hidden entirely when no vehicle is loaded; shows "Land to unload" when in air + loaded;
-- shows the vehicle list when on the ground + loaded.
-- @param playerObj CTLDPlayer
function CTLDVehicleSpawner:refreshUnloadSection(playerObj)
    if not playerObj.canCarryVehicles then return end

    local mm   = ctld.MenuManager:getInstance()
    local menu = mm:getMenuByGroupId(playerObj.groupId)
    if not menu then return end

    local root      = ctld.tr("CTLD")
    local vehSub    = ctld.tr("Vehicle Commands")
    local unloadSub = ctld.tr("Unload Vehicles")

    menu:clearBranch({ root, vehSub, unloadSub })

    local transport = Unit.getByName(playerObj.unitName)
    local inAir     = (transport and transport:isExist()) and ctld.utils.inAir(transport) or false
    local loaded    = (transport and transport:isExist()) and self:findLoadedVehicles(transport) or {}

    if #loaded == 0 then
        -- No vehicle loaded: hide the entire submenu
        menu:setBranchEnabled({ root, vehSub, unloadSub }, false)
        menu:refresh()
        return
    end

    menu:setBranchEnabled({ root, vehSub, unloadSub }, true)

    if inAir then
        menu:addCommand({ root, vehSub, unloadSub },
            ctld.tr("Land to unload vehicles"), function() end, {})
    else
        for _, veh in ipairs(loaded) do
            local desc  = CTLDCrateManager.getInstance():findDescriptorByUnitType(veh.vehicleType)
            local label = desc and desc.desc or veh.vehicleType
            menu:addCommand({ root, vehSub, unloadSub }, label,
                function(arg)
                    local t = Unit.getByName(arg.unitName)
                    if not (t and t:isExist()) then return end
                    local v = CTLDVehicleSpawner.getInstance()._vehicles[arg.vehicleId]
                    if not v or v:getState() ~= CTLDVehicle.STATE.LOADED then
                        trigger.action.outTextForGroup(arg.groupId,
                            ctld.tr("Vehicle no longer loaded."), 8)
                        return
                    end
                    CTLDVehicleSpawner.getInstance():unloadVehicle(v, t, arg.unitName, "menu_ctld")
                    CTLDPlayerManager.getInstance():refreshForUnit(arg.unitName)
                end,
                { unitName  = playerObj.unitName,
                  groupId   = playerObj.groupId,
                  vehicleId = veh.id,
                  coalition = playerObj.coalition })
        end
    end
    menu:refresh()
end

--- Refresh the "Load / Extract Vehicles" submenu for a player by unit name.
-- @param unitName string
function CTLDVehicleSpawner:refreshLoadSectionForUnit(unitName)
    ctld.utils.log("INFO", string.format("CTLDVehicleSpawner:refreshLoadSectionForUnit unitName=%s", unitName))
    local playerObj = CTLDPlayerManager.getInstance()._players[unitName]
    if playerObj then self:refreshLoadSection(playerObj) end
end

--- Refresh the "Unload Vehicles" submenu for a player by unit name.
-- @param unitName string
function CTLDVehicleSpawner:refreshUnloadSectionForUnit(unitName)
    local playerObj = CTLDPlayerManager.getInstance()._players[unitName]
    if playerObj then self:refreshUnloadSection(playerObj) end
end

--- Refresh "Parachute Vehicle" visibility: shown only when in air + vehicle loaded.
-- @param playerObj CTLDPlayer
function CTLDVehicleSpawner:refreshParachuteVehicleSection(playerObj)
    local caps = (ctld.gs("capabilitiesByType") or {})[playerObj.typeName]
    if not (playerObj.canCarryVehicles and caps and caps.canParachuteDrop) then return end

    local mm   = ctld.MenuManager:getInstance()
    local menu = mm:getMenuByGroupId(playerObj.groupId)
    if not menu then return end

    local root   = ctld.tr("CTLD")
    local vehSub = ctld.tr("Vehicle Commands")

    local transport = Unit.getByName(playerObj.unitName)
    local inAir     = transport and transport:isExist() and ctld.utils.inAir(transport) or false
    local loaded    = (transport and transport:isExist()) and self:findLoadedVehicles(transport) or {}

    menu:setBranchEnabled({ root, vehSub, ctld.tr("Parachute Vehicle") }, inAir and #loaded > 0)
    menu:refresh()
end

--- Refresh all Vehicle Commands submenus (load, unload, parachute) for a player.
-- @param playerObj CTLDPlayer
function CTLDVehicleSpawner:refreshVehicleMenuSections(playerObj)
    self:refreshLoadSection(playerObj)
    self:refreshUnloadSection(playerObj)
    self:refreshParachuteVehicleSection(playerObj)
end

--- Refresh all Vehicle Commands submenus for a player identified by unit name.
-- @param unitName string
function CTLDVehicleSpawner:refreshVehicleMenuSectionsForUnit(unitName)
    local playerObj = CTLDPlayerManager.getInstance()._players[unitName]
    if playerObj then self:refreshVehicleMenuSections(playerObj) end
end

--- Build the "Vehicle Commands" F10 submenu for a player.
-- Added only when the unit can carry vehicles (canCarryVehicles = true).
-- @param playerObj CTLDPlayer
-- @param menu      ctld.Menu
function CTLDVehicleSpawner:buildMenuSection(playerObj, menu)
    if not playerObj.canCarryVehicles then return end

    local root   = ctld.tr("CTLD")
    local vehSub = ctld.tr("Vehicle Commands")
    menu:addSubMenu({ root }, vehSub, { order = 30 })

    -- Dynamic load submenu (rebuilt by refreshLoadSection)
    menu:addSubMenu({ root, vehSub }, ctld.tr("Load / Extract Vehicles"))
    self:refreshLoadSection(playerObj)

    -- Dynamic unload submenu (rebuilt by refreshUnloadSection)
    menu:addSubMenu({ root, vehSub }, ctld.tr("Unload Vehicles"))
    self:refreshUnloadSection(playerObj)

    -- Parachute Vehicle: only if canParachuteDrop=true for this unit type.
    -- Created disabled; refreshParachuteVehicleSection enables it only when in air + vehicle loaded.
    local caps = (ctld.gs("capabilitiesByType") or {})[playerObj.typeName]
    if caps and caps.canParachuteDrop then
        menu:addCommand({ root, vehSub }, ctld.tr("Parachute Vehicle"),
            function(arg)
                local transport = Unit.getByName(arg.unitName)
                if not transport then return end
                CTLDVehicleSpawner.getInstance():parachuteVehicle(transport, nil, arg)
            end,
            { unitName = playerObj.unitName, groupId = playerObj.groupId,
              coalition = playerObj.coalition })
        menu:setBranchEnabled({ root, vehSub, ctld.tr("Parachute Vehicle") }, false)
    end
end
