---@diagnostic disable
-- CTLD_modValidator.lua
-- Probes all DCS typeNames declared in CTLD configuration at mission start.
-- Detects missing mods (unknown typeNames) before any player-facing spawn occurs.
--
-- Detection methods (validated empirically):
--   GROUND: coalition.addGroup → unit:getTypeName() ~= requested → invalid (DCS silently substitutes)
--   STATIC: coalition.addStaticObject → returns nil → invalid
--
-- Usage:
--   CTLDModValidator.getInstance():run()   -- call once in CTLDCoreManager:init()
--   CTLDModValidator.getInstance():isGroundInvalid(typeName) → bool
--   CTLDModValidator.getInstance():isStaticInvalid(typeName) → bool

CTLDModValidator = {}
CTLDModValidator.__index = CTLDModValidator
CTLDModValidator._instance = nil

-- ============================================================
-- Singleton
-- ============================================================

function CTLDModValidator.getInstance()
    if not CTLDModValidator._instance then
        CTLDModValidator._instance = setmetatable({}, CTLDModValidator)
        CTLDModValidator._instance:_initState()
    end
    return CTLDModValidator._instance
end

function CTLDModValidator:_initState()
    self._cache    = {}   -- ["G:typeName"] / ["S:typeName"] = true|false
    self._probeIdx = 0
    self._probePos = nil
end

-- ============================================================
-- Public API
-- ============================================================

--- Returns true if the ground typeName was probed and found invalid.
function CTLDModValidator:isGroundInvalid(typeName)
    return self._cache["G:" .. typeName] == false
end

--- Returns true if the static typeName was probed and found invalid.
function CTLDModValidator:isStaticInvalid(typeName)
    return self._cache["S:" .. typeName] == false
end

--- Main entry point. Collect all typeNames, probe each, emit a unified report.
-- Safe to call multiple times (cached results are reused).
function CTLDModValidator:run()
    self._probePos = self:_getProbePos()

    local entries  = self:_collectTypeNames()
    local invalids = {}

    for _, entry in ipairs(entries) do
        local valid
        if entry.probeType == "GROUND" then
            valid = self:_probeGround(entry.typeName)
        elseif entry.probeType == "HELIPORT" then
            valid = self:_probeHeliport(entry.typeName, entry.category, entry.extras)
        else
            valid = self:_probeStatic(entry.typeName, entry.category, entry.extras)
        end
        if not valid then
            invalids[#invalids + 1] = entry
        end
    end

    if #invalids > 0 then
        local lines = { string.format("[CTLD] Mod validation — %d type(s) not found in DCS:", #invalids) }
        for _, inv in ipairs(invalids) do
            local suffix = inv.role and (" role=" .. inv.role) or ""
            lines[#lines + 1] = string.format("  %s '%s' (source: %s)%s",
                inv.probeType, inv.typeName, inv.source, suffix)
        end
        local msg = table.concat(lines, "\n")
        ctld.utils.log("WARN", msg)
        trigger.action.outText(msg, 30)
    else
        ctld.utils.log("INFO",
            "CTLDModValidator: all %d probed type(s) present in DCS", #entries)
    end
end

-- ============================================================
-- TypeName collection
-- ============================================================

function CTLDModValidator:_collectTypeNames()
    local entries = {}
    local seen    = {}

    -- Reserved keys not forwarded to addStaticObject
    local _skipDescKeys = {
        groupType=true, namePrefix=true, type=true, category=true, probeSkip=true,
    }

    local function add(typeName, probeType, category, source, role, extras)
        if not typeName or typeName == "" then return end
        local key = probeType .. ":" .. typeName
        if seen[key] then return end
        seen[key] = true
        entries[#entries + 1] = {
            typeName  = typeName,
            probeType = probeType,
            category  = category,
            source    = source,
            role      = role,
            extras    = extras,   -- optional: extra descriptor fields for static spawn
        }
    end

    -- 1. CTLDObjectRegistry._db ─────────────────────────────────────────────
    for regKey, desc in pairs(CTLDObjectRegistry._db) do
        if desc.groupType == "STATIC" and desc.type then
            -- Heliport detection: DCS substitutes unknown types with SINGLE_HELIPAD visually,
            -- but getTypeName() returns the requested name (not the substitute).
            -- Detection via StaticObject:getDesc().life: valid type → life>0, invalid → life==0.
            -- Spawned off-map (+800 km east) to keep any ghost outside the visible play area.
            if desc.category == "Heliports" then
                if desc.probeSkip then
                    -- Custom mod heliport: DCS scripting API cannot distinguish installed from missing
                    -- (getDesc().life == 0 for both valid mod and invalid type). Skip to avoid false alarm.
                    ctld.utils.log("INFO",
                        "ModValidator HELIPORT '%s' skipped (probeSkip=true — custom mod, DCS API limitation)",
                        desc.type)
                else
                    local extras = {}
                    for k, v in pairs(desc) do
                        if not _skipDescKeys[k] then extras[k] = v end
                    end
                    add(desc.type, "HELIPORT", desc.category, "Registry[" .. regKey .. "]", nil, extras)
                end
            else
                -- Collect extra descriptor fields needed by addStaticObject (e.g. shape_name, livery_id)
                local extras = {}
                for k, v in pairs(desc) do
                    if not _skipDescKeys[k] then extras[k] = v end
                end
                add(desc.type, "STATIC", desc.category, "Registry[" .. regKey .. "]", nil, extras)
            end
        elseif desc.groupType == "GROUND" and desc.units then
            for _, u in ipairs(desc.units) do
                if u.unitType then
                    for _, cid in ipairs({ 1, 2 }) do
                        local ok, tn = pcall(u.unitType, cid)
                        if ok and tn then
                            add(tn, "GROUND", nil, "Registry[" .. regKey .. "]", nil)
                        end
                    end
                end
            end
        end
    end

    -- 2. spawnableCrates (Combat Vehicles and other sections) ────────────────
    -- Skip FOB sentinel, scene sentinels (auto-detected via CTLDSceneManager registry),
    -- repair entries and aircraft — none of these are DCS unit typeNames.
    local _sm = (type(CTLDSceneManager) == "table") and CTLDSceneManager.getInstance() or nil
    local buildable = ctld.gs("spawnableCrates") or {}
    for sectionName, items in pairs(buildable) do
        if type(items) == "table" then
            for _, item in ipairs(items) do
                local isSceneSentinel = _sm and (_sm:getModel(item.unit) ~= nil)
                if item.unit and not isSceneSentinel
                    and not item._repairFor
                    and not item.spawnAs       -- aircraft (spawnAs="AIRPLANE"/"HELICOPTER") probed separately
                then
                    add(item.unit, "GROUND", nil,
                        "spawnableCrates[" .. tostring(sectionName) .. "]", nil)
                end
            end
        end
    end

    -- 3. CTLDCrateAssemblyManager.TEMPLATES (AA systems) ────────────────────
    -- Only probe part.DCSTypename — real DCS unit types spawned by spawnSystemAt.
    -- tmpl.repair is a struct {desc,weight,side}, not a DCS typeName — never probed.
    local _aaTmpls = (type(CTLDCrateAssemblyManager) == "table")
        and CTLDCrateAssemblyManager.TEMPLATES or {}
    for _, tmpl in ipairs(_aaTmpls) do
        if tmpl.parts then
            for _, part in ipairs(tmpl.parts) do
                if part.DCSTypename then
                    add(part.DCSTypename, "GROUND", nil,
                        "AASystem[" .. tostring(tmpl.name) .. "]", nil)
                end
            end
        end
    end

    -- 4. loadableGroups[].componentTypes (custom troop roles) ────────────────
    local loadable = ctld.gs("loadableGroups") or {}
    for _, tmpl in ipairs(loadable) do
        local ct = tmpl.componentTypes
        if type(ct) == "table" then
            for role, coaTable in pairs(ct) do
                if type(coaTable) == "table" then
                    for _, tn in pairs(coaTable) do
                        add(tn, "GROUND", nil,
                            "loadableGroups[" .. tostring(tmpl.name) .. "]", role)
                    end
                end
            end
        end
    end

    return entries
end

-- ============================================================
-- Probe helpers
-- ============================================================

function CTLDModValidator:_getProbePos()
    for _, coa in ipairs({ coalition.side.BLUE, coalition.side.RED }) do
        local ok, groups = pcall(coalition.getGroups, coa)
        if ok and groups and #groups > 0 then
            local units = groups[1]:getUnits()
            if units and #units > 0 then
                local pt = units[1]:getPoint()
                return { x = pt.x, z = pt.z }
            end
        end
    end
    return { x = 0, z = 0 }
end

function CTLDModValidator:_nextIdx()
    self._probeIdx = self._probeIdx + 1
    return self._probeIdx
end

function CTLDModValidator:_probeGround(typeName)
    local cacheKey = "G:" .. typeName
    if self._cache[cacheKey] ~= nil then return self._cache[cacheKey] end

    local idx = self:_nextIdx()
    local pos = self._probePos
    local groupData = {
        task  = "Ground Nothing",
        name  = "CTLD_MVP_G" .. idx,
        units = {{
            type    = typeName,
            name    = "CTLD_MVP_G" .. idx .. "_u1",
            x       = pos.x + idx * 3,
            y       = pos.z + idx * 3,
            heading = 0,
            skill   = "Average",
        }}
    }

    local ok, grp = pcall(coalition.addGroup, country.id.USA, Group.Category.GROUND, groupData)
    local valid = false
    if ok and grp then
        local units = grp:getUnits()
        if #units > 0 then
            local okT, actual = pcall(function() return units[1]:getTypeName() end)
            valid = okT and (actual == typeName)
        end
        local _okD1 = pcall(function() grp:destroy() end)

        if not _okD1 then ctld.utils.log("WARN", "ModValidator: failed to destroy test group") end
    end

    self._cache[cacheKey] = valid
    ctld.utils.log("INFO", "ModValidator GROUND '%s' → %s", typeName, valid and "OK" or "NOT FOUND")
    return valid
end

function CTLDModValidator:_probeStatic(typeName, category, extras)
    local cacheKey = "S:" .. typeName
    if self._cache[cacheKey] ~= nil then return self._cache[cacheKey] end

    local idx = self:_nextIdx()
    local pos = self._probePos

    -- Base fields
    local staticData = {
        name          = "CTLD_MVP_S" .. idx,
        type          = typeName,
        category      = category or "Fortifications",
        x             = pos.x + idx * 3,
        y             = pos.z + idx * 3,
        heading       = 0,
        start_time    = 0,
        transportable = { randomTransportable = false },
        dead          = false,
    }
    -- Forward extra descriptor fields (shape_name, livery_id, rate, …)
    if extras then
        for k, v in pairs(extras) do staticData[k] = v end
    end

    local ok, obj = pcall(coalition.addStaticObject, country.id.USA, staticData)
    local valid = ok and (obj ~= nil)
    if ok and obj then
        local _okD2 = pcall(function() obj:destroy() end)

        if not _okD2 then ctld.utils.log("WARN", "ModValidator: failed to destroy test static object") end
    end

    self._cache[cacheKey] = valid
    ctld.utils.log("INFO", "ModValidator STATIC '%s' → %s", typeName, valid and "OK" or "NOT FOUND")
    return valid
end

function CTLDModValidator:_probeHeliport(typeName, category, extras)
    local cacheKey = "S:" .. typeName
    if self._cache[cacheKey] ~= nil then return self._cache[cacheKey] end

    local idx  = self:_nextIdx()
    local pos  = self._probePos
    local name = "CTLD_MVP_H" .. idx

    -- Spawn off-map (+800 km east) so the unavoidable ghost stays outside the visible play area.
    local staticData = {
        name          = name,
        type          = typeName,
        category      = category or "Heliports",
        x             = pos.x + idx * 3,
        y             = pos.z + 800000,
        heading       = 0,
        start_time    = 0,
        transportable = { randomTransportable = false },
        dead          = false,
    }
    if extras then
        for k, v in pairs(extras) do staticData[k] = v end
    end

    local ok, obj = pcall(coalition.addStaticObject, country.id.USA, staticData)
    -- Detection: DCS substitutes unknown Heliport types visually but getTypeName() is unreliable.
    -- getDesc().life == 0 when the type is unknown; valid types have life > 0.
    local valid = false
    if ok and obj ~= nil then
        local so = StaticObject.getByName(name)
        if so then
            local okD, d = pcall(function() return so:getDesc() end)
            valid = okD and type(d) == "table" and (d.life or 0) > 0
        end
        local ab = Airbase.getByName(name)
        if ab then
            local _okD3 = pcall(function() ab:destroy() end)
            if not _okD3 then ctld.utils.log("WARN", "ModValidator: failed to destroy test airbase") end
        end
    end

    self._cache[cacheKey] = valid
    ctld.utils.log("INFO", "ModValidator HELIPORT '%s' → %s (off-map probe, life-check)",
        typeName, valid and "OK" or "NOT FOUND")
    return valid
end

