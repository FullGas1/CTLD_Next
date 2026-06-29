---@diagnostic disable
-- CTLD_objectRegistry.lua
-- CTLDObjectRegistry — catalog of enriched DCS object descriptors + spawnObject() factory.
--
-- SCOPE RULE:
--   This registry is NOT a general catalog of all DCS typeNames.
--   It contains only objects that require descriptor enrichment beyond a plain typeName:
--     - STATIC objects with mandatory DCS params  (FARP frequency, helipad callsign, shape_name...)
--     - GROUND groups with multi-unit formation   (guard infantry, circle/linear layouts)
--     - Any object referenced by scene steps      (registryKey field in scene step tables)
--   Standard crate contents (single DCS unit spawned at unpack) bypass this registry
--   and call coalition.addStaticObject / coalition.addGroup directly with the typeName.
--
-- Dynamic registration:
--   Managers may insert entries at INIT time (e.g. CTLDTroopManager._registerTemplates).
--   All entries — static and dynamic — share the same _db table and spawnObject() path.
--
-- Each entry contains only fields specific to the object type; standard fields
-- (name, groupId, unitId, x, z, heading, start_time, transportable, skill)
-- are injected automatically by spawnObject().
--
-- For GROUND groups, intra-unit offsets (dx, dz, dh) are defined per unit
-- in the descriptor and applied by spawnObject() relative to the spawn point
-- and heading. Coordinates passed to spawnObject() are always absolute (world).
--
-- Coalition-aware entries use unitType = function(coalitionId) ... end.
--
-- Dependencies: CTLDUtils (ctld.utils.getNextUniqId, ctld.utils.log)
-- DCS API: coalition.addStaticObject, coalition.addGroup
-- ====================================================================================================

CTLDObjectRegistry = {}

-- ====================================================================================================
-- Internal DB
-- ====================================================================================================

CTLDObjectRegistry._db = {

    -- ------------------------------------------------------------------
    -- HELIPORTS
    -- ------------------------------------------------------------------
    ["FARP"] = {
        groupType            = "STATIC",
        namePrefix           = "FARP",
        type                 = "FARP",
        category             = "Heliports",
        shape_name           = "FARPS",
        heliport_frequency   = "127.5",
        heliport_callsign_id = 1,
        heliport_modulation  = 0,
    },

    ["SINGLE_HELIPAD"] = {
        groupType            = "STATIC",
        namePrefix           = "SINGLE_HELIPAD",
        type                 = "SINGLE_HELIPAD",
        category             = "Heliports",
        shape_name           = "FARP",
        heliport_frequency   = "127.5",
        heliport_callsign_id = 1,
        heliport_modulation  = 0,
    },

    ["Invisible_FARP"] = {  -- invisible DCS heliport — no 3D model but full airbase (F10 label + warehouse). Params from mission Farp Invisible-1.
        groupType            = "STATIC",
        namePrefix           = "CS_FARP",
        type                 = "Invisible FARP",
        shape_name           = "invisiblefarp",
        category             = "Heliports",
        heliport_frequency   = "127.5",
        heliport_callsign_id = 1,
        heliport_modulation  = 0,
        rate                 = 100,
    },

    ["Farp_FG_Petit_Helipad"] = {  -- specific mod
        groupType            = "STATIC",
        namePrefix           = "FARP_Helipad",
        type                 = "Farp_FG_Petit_Helipad",
        category             = "Heliports",
        shape_name           = "Farp_FG_Petit_Helipad.edm",
        heliport_frequency   = "127.5",
        heliport_callsign_id = 1,
        heliport_modulation  = 0,
        -- DCS scripting API limitation: for custom mod heliports, getDesc().life == 0 whether the mod
        -- is installed or not (identical to an invalid type). No reliable discriminant exists.
        -- probeSkip suppresses the false NOT FOUND alarm; the mod cannot be validated at runtime.
        probeSkip            = true,
    },

    -- ------------------------------------------------------------------
    -- FORTIFICATIONS
    -- ------------------------------------------------------------------
    ["FARP_Tent"] = {
        groupType  = "STATIC",
        namePrefix = "FARP_Tent",
        type       = "FARP Tent",
        category   = "Fortifications",
    },

    ["FARP_Ammo_Storage"] = {
        groupType  = "STATIC",
        namePrefix = "FARP_Ammo_Storage",
        type       = "FARP Ammo Dump Coating",
        category   = "Fortifications",
    },

    ["Tower Crane"] = {
        groupType  = "STATIC",
        namePrefix = "TowerCrane",
        type       = "Tower Crane",
        category   = "Fortifications",
        shape_name = "TowerCrane_01",
        rate       = 100,
    },

    ["NF-2_LightOn"] = {
        groupType  = "STATIC",
        namePrefix = "LightOn",
        type       = "NF-2_LightOn",
        category   = "Fortifications",
        shape_name = "M92_NF-2_LightOn",
        rate       = 100,
    },

    ["Windsock"] = {
        groupType  = "STATIC",
        namePrefix = "Windsock",
        type       = "Windsock",
        category   = "Fortifications",
        shape_name = "H-Windsock_RW",
        rate       = 3,
    },

    ["Landmine"] = {
        groupType  = "STATIC",
        namePrefix = "Mine",
        type       = "Landmine",
        category   = "Fortifications",
    },

    -- FOB components (used as scene steps by CTLDFOBManager)
    ["FOB_container"] = {
        groupType  = "STATIC",
        namePrefix = "FOB_Outpost",
        type       = "outpost",
        category   = "Fortifications",
        canCargo   = false,
    },

    ["FOB_watchtower"] = {
        groupType  = "STATIC",
        namePrefix = "FOB_Watchtower",
        type       = "house2arm",
        category   = "Fortifications",
        canCargo   = false,
        rate       = 100,
    },

    -- ------------------------------------------------------------------
    -- CARGOS
    -- ------------------------------------------------------------------
    ["barrels_cargo"] = {
        groupType  = "STATIC",
        namePrefix = "barrels_cargo",
        type       = "barrels_cargo",
        category   = "Cargos",
        shape_name = "barrels_cargo",
        rate       = 100,
    },

    ["ammo_cargo"] = {
        groupType  = "STATIC",
        namePrefix = "ammo_box_cargo",
        type       = "ammo_cargo",
        category   = "Cargos",
        shape_name = "ammo_box_cargo",
        rate       = 1,
    },

    ["Cargo06"] = {
        groupType  = "STATIC",
        namePrefix = "ammo_box06",
        type       = "Cargo06",
        category   = "Cargos",
        shape_name = "M92_Cargo06",
        rate       = 1,
    },

    -- ------------------------------------------------------------------
    -- PERSONNEL
    -- ------------------------------------------------------------------
    ["us carrier shooter"] = {
        groupType  = "STATIC",
        namePrefix = "carrier_shooter",
        type       = "us carrier shooter",
        category   = "Personnel",
        shape_name = "carrier_shooter",
        livery_id  = "blue",
        rate       = 20,
    },

    -- ------------------------------------------------------------------
    -- GROUND UNITS (coalition-aware)
    -- ------------------------------------------------------------------
    ["Fuel_Truck"] = {
        groupType  = "GROUND",
        namePrefix = "Fuel_Truck_Grp",
        task       = "Ground Nothing",
        category   = Unit.Category.GROUND_UNIT,
        units = {
            {
                namePrefix     = "Fuel_Truck_Unit",
                unitType       = function(cid)
                    return cid == coalition.side.RED and "ATZ-10" or "M978 HEMTT Tanker"
                end,
                playerCanDrive = false,
                dx = 0, dz = 0, dh = 0,
            },
        },
    },

    ["repare_Truck"] = {
        groupType  = "GROUND",
        namePrefix = "repare_Truck_Grp",
        task       = "Ground Nothing",
        category   = Unit.Category.GROUND_UNIT,
        units = {
            {
                namePrefix     = "repare_Truck_Unit",
                unitType       = function(cid)
                    return cid == coalition.side.RED and "Ural-375" or "M 818"
                end,
                playerCanDrive = false,
                dx = 0, dz = 0, dh = 0,
            },
        },
    },

    ["CS_FARP_Guards"] = {  -- Countryside FARP: 1 infantry + 1 MANPAD
        groupType  = "GROUND",
        namePrefix = "CS_FARP_Guard_Grp",
        task       = "Ground Nothing",
        category   = Unit.Category.GROUND_UNIT,
        units = {
            {
                namePrefix     = "CS_Guard_Infantry",
                unitType       = function(cid)
                    return cid == coalition.side.RED and "Infantry AK" or "Soldier M4"
                end,
                playerCanDrive = false,
                dx = 0, dz = 0, dh = 0,
            },
            {
                namePrefix     = "CS_Guard_Manpad",
                unitType       = function(cid)
                    return cid == coalition.side.RED and "SA-18 Igla manpad" or "Soldier stinger"
                end,
                playerCanDrive = false,
                dx = 3, dz = 0, dh = 0,
            },
        },
    },

    ["FARP_Security_Guard"] = {
        groupType  = "GROUND",
        namePrefix = "FARP_Guard_Grp",
        task       = "Ground Nothing",
        category   = Unit.Category.GROUND_UNIT,
        units = {
            {
                namePrefix     = "Guard_Infantry",
                unitType       = function(cid)
                    return cid == coalition.side.RED and "Infantry AK" or "Soldier M4"
                end,
                playerCanDrive = false,
                dx = 0, dz = 0, dh = 0,
            },
            {
                namePrefix     = "Guard_Infantry",
                unitType       = function(cid)
                    return cid == coalition.side.RED and "Infantry AK" or "Soldier M4"
                end,
                playerCanDrive = false,
                dx = 3, dz = 1, dh = 0.610865,
            },
            {
                namePrefix     = "Guard_Infantry",
                unitType       = function(cid)
                    return cid == coalition.side.RED and "Infantry AK" or "Soldier M4"
                end,
                playerCanDrive = false,
                dx = 6, dz = 0, dh = 3.49066,
            },
        },
    },

}

-- ====================================================================================================
-- Public API
-- ====================================================================================================

-- Returns a descriptor from the DB, or nil if not found.
function CTLDObjectRegistry.get(objectKey)
    return CTLDObjectRegistry._db[objectKey]
end

-- Registers a descriptor only if the key is not already present.
-- Used by scene files to declare their required entries in a self-contained way.
-- If multiple scenes share the same registryKey, only the first registration wins.
-- @param objectKey string   registry key (must be unique)
-- @param desc      table    descriptor table (same format as _db entries)
-- @return true if registered, false if key already existed
function CTLDObjectRegistry.registerIfAbsent(objectKey, desc)
    if CTLDObjectRegistry._db[objectKey] then
        return false
    end
    CTLDObjectRegistry._db[objectKey] = desc
    return true
end

--- Reverse lookup: find the registry key and descriptor whose `type` field
--- matches dcsTypeName (the DCS typeName of a static/cargo object).
--- Used by CTLDCrateManager:registerMMCrate() for MM crate detection (INIT-B).
--- @param dcsTypeName string   e.g. "ammo_cargo", "Cargo06"
--- @return string|nil key, table|nil descriptor
function CTLDObjectRegistry.findByDCSType(dcsTypeName)
    if not dcsTypeName then return nil, nil end
    for key, desc in pairs(CTLDObjectRegistry._db) do
        if desc.type == dcsTypeName then
            return key, desc
        end
    end
    return nil, nil
end

-- Spawns a DCS object described by objectKey at absolute world position (x, z).
--
-- @param objectKey   string    Key in CTLDObjectRegistry._db
-- @param coalitionId number    coalition.side.BLUE or coalition.side.RED
-- @param countryId   number    DCS country id
-- @param x           number    World X coordinate (North axis)
-- @param z           number    World Z coordinate (East axis)
-- @param headingRad  number    Heading in radians (0 = North). Default 0.
-- @param overrides   table|nil Fields merged over injected values (optional)
--
-- @return DCS object handle (StaticObject or Group), or nil on failure.
--
-- For GROUND groups, units[i].dx/dz/dh offsets in the descriptor are rotated
-- by headingRad and added to (x, z) to compute each unit's absolute position.
function CTLDObjectRegistry.spawnObject(objectKey, coalitionId, countryId, x, z, headingRad, overrides)
    local desc = CTLDObjectRegistry._db[objectKey]
    if not desc then
        ctld.utils.log("WARN", "spawnObject: unknown objectKey '%s'", tostring(objectKey))
        return nil
    end

    headingRad = headingRad or 0
    overrides  = overrides  or {}

    -- ----------------------------------------------------------------
    -- STATIC objects
    -- ----------------------------------------------------------------
    if desc.groupType == "STATIC" then
        local uid  = ctld.utils.getNextUniqId()
        local name = string.format("%s-%d", desc.namePrefix, uid)

        -- Build groupData: start with descriptor fields, inject standard fields
        local groupData = {}
        for k, v in pairs(desc) do
            if k ~= "groupType" and k ~= "namePrefix" then
                groupData[k] = v
            end
        end
        -- Standard injected fields
        groupData.name          = name
        groupData.x             = x
        groupData.y             = z   -- DCS static uses y = world Z
        groupData.heading       = headingRad
        groupData.start_time    = 0
        groupData.transportable = { randomTransportable = false }
        -- Caller overrides
        for k, v in pairs(overrides) do groupData[k] = v end

        local ok, result = ctld.utils.spawnAs("STATIC", countryId, groupData)
        if not ok then
            ctld.utils.log("ERROR", "spawnObject: coalition.addStaticObject failed for '%s': %s",
                objectKey, tostring(result))
            return nil
        end
        ctld.utils.log("INFO", "spawnObject: STATIC '%s' spawned at (%.1f, %.1f)", name, x, z)
        return result

    -- ----------------------------------------------------------------
    -- GROUND groups
    -- ----------------------------------------------------------------
    elseif desc.groupType == "GROUND" then
        local gid       = ctld.utils.getNextUniqId()
        local groupName = string.format("%s-%d", desc.namePrefix, gid)
        local cosH      = math.cos(headingRad)
        local sinH      = math.sin(headingRad)

        -- Circle formation: offsets computed dynamically from overrides.circleRadius.
        -- Linear formation: offsets come from uDesc.dx / uDesc.dz (static per descriptor).
        -- Units marked svntOf=true (mortar servants) are excluded from the circle count and
        -- positioned 1 m from the preceding unit instead of on the circle arc.
        local useCircle  = desc.formation and desc.formation.type == "circle"
        local circleR    = (overrides and overrides.circleRadius) or 10

        -- Count only non-servant units for the circle arc distribution.
        local circleCount = 0
        if useCircle then
            for _, uD in ipairs(desc.units) do
                if not uD.svntOf then circleCount = circleCount + 1 end
            end
            if circleCount == 0 then circleCount = 1 end
        end

        local units      = {}
        local circleIdx  = 0           -- index among non-svnt units (0-based)
        local lastUx, lastUz = x, z    -- position of the last non-svnt unit spawned

        for i, uDesc in ipairs(desc.units) do
            local uid      = ctld.utils.getNextUniqId()
            local uName    = string.format("%s-%d", uDesc.namePrefix, uid)
            local uType    = type(uDesc.unitType) == "function"
                             and uDesc.unitType(coalitionId)
                             or  uDesc.unitType
            local ux, uz
            if useCircle then
                if uDesc.svntOf then
                    -- Servant: placed 1 m to the right of the preceding mortar (world frame)
                    ux = lastUx + 1
                    uz = lastUz
                else
                    local angle = circleIdx * (2 * math.pi / circleCount)
                    circleIdx   = circleIdx + 1
                    local dx    = circleR * math.cos(angle)
                    local dz    = circleR * math.sin(angle)
                    ux = x + dx * cosH - dz * sinH
                    uz = z + dx * sinH + dz * cosH
                    lastUx, lastUz = ux, uz
                end
            else
                local dx = uDesc.dx or 0
                local dz = uDesc.dz or 0
                ux = x + dx * cosH - dz * sinH
                uz = z + dx * sinH + dz * cosH
            end

            local unit = {
                name           = uName,
                type           = uType,
                x              = ux,
                y              = uz,  -- DCS ground unit uses y = world Z
                heading        = headingRad + (uDesc.dh or 0),
                skill          = "High",
                playerCanDrive = uDesc.playerCanDrive or false,
                transportable  = { randomTransportable = false },
                unitId         = uid,
            }
            -- Unit-level overrides
            if overrides.units and overrides.units[i] then
                for k, v in pairs(overrides.units[i]) do unit[k] = v end
            end
            units[i] = unit
        end

        local groupData = {
            name       = groupName,
            task       = desc.task or "Ground Nothing",
            start_time = 0,
            groupId    = gid,
            visible    = false,
            hidden     = false,
            units      = units,
        }
        -- Group-level overrides (excluding units table)
        for k, v in pairs(overrides) do
            if k ~= "units" then groupData[k] = v end
        end

        local ok, result = ctld.utils.spawnAs(desc.category, countryId, groupData)
        if not ok then
            ctld.utils.log("ERROR", "spawnObject: coalition.addGroup failed for '%s': %s",
                objectKey, tostring(result))
            return nil
        end
        ctld.utils.log("INFO", "spawnObject: GROUND '%s' spawned at (%.1f, %.1f)", groupName, x, z)
        return result

    else
        ctld.utils.log("WARN", "spawnObject: unknown groupType '%s' for key '%s'",
            tostring(desc.groupType), tostring(objectKey))
        return nil
    end
end
