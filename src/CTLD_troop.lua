-- ============================================================
-- CTLD_troop.lua
-- CTLDTroopGroup entity + CTLDTroopManager singleton
--
-- Dependencies: CTLDConfig (ctld.gs), CTLDUtils, CTLDObjectRegistry, CTLDZoneManager
-- DCS API: coalition.addGroup, Group, Unit, land, trigger.action, missionCommands
--
-- TroopGroup lifecycle states:
--   TRZ_LOADED     : troops onboard a transport (loaded from a TroopZone)
--   DEPLOYED       : troops on the ground as a live DCS group
--   FIELD_LOADED   : troops onboard a transport (recovered from field)
--   DEPLOYED_EXZ   : silent drop into EXZ_ — DCS group never spawned, flag counter only
--   RETURNED_TO_TRZ: troops returned to TroopZone — instance discarded
-- ============================================================

---@diagnostic disable
ctld = ctld or {}

-- ============================================================
-- CTLDTroopGroup  (entity)
-- ============================================================

CTLDTroopGroup = class()

CTLDTroopGroup.STATE = {
    TRZ_LOADED     = "TRZ_LOADED",
    DEPLOYED       = "deployed",
    FIELD_LOADED   = "FIELD_LOADED",
    DEPLOYED_EXZ   = "DEPLOYED_EXZ",
    RETURNED_TO_TRZ = "RETURNED_TO_TRZ",
}

--- Constructor.
-- @param data table:
--   templateKey   (string|nil)  CTLDObjectRegistry key (nil for recovered groups)
--   templateName   (string)      display name
--   unitTotal      (number)      total unit count (alive at construction time)
--   weight         (number)      total cargo weight (kg)
--   coalitionId    (number)      coalition.side.*
--   countryId      (number)      DCS country id
--   state          (string|nil)  CTLDTroopGroup.STATE.* — defaults to TRZ_LOADED
--   _aliveUnits    (table|nil)   map[unitName] = dcsUnit (references, not indices)
--   _jtacUnits     (table|nil)   map[unitName] = true (subset of _aliveUnits flagged JTAC)
function CTLDTroopGroup:init(data)
    self.templateKey  = data.templateKey
    self.templateName = data.templateName
    self.unitTotal    = data.unitTotal
    self.weight       = data.weight
    self.coalitionId  = data.coalitionId
    self.countryId    = data.countryId
    self.state       = data.state or CTLDTroopGroup.STATE.TRZ_LOADED
    self.dcsGroup    = nil
    self.loadTime    = timer.getAbsTime()
    self._aliveUnits    = data._aliveUnits    or {}  -- map[unitName] = dcsUnit (DCS Unit reference)
    self._jtacUnits     = data._jtacUnits     or {}  -- map[unitName] = true
    self.specificParams = data.specificParams or {}   -- { task = "gotoNearestWPZ" | "AttackNearestEnemyOnLos" }
end

--- Transition to DEPLOYED: record the spawned DCS group.
-- @param dcsGroup Group|nil  spawned DCS group (nil for objective-zone silent drops)
function CTLDTroopGroup:deploy(dcsGroup)
    self.state    = CTLDTroopGroup.STATE.DEPLOYED
    self.dcsGroup = dcsGroup
end

--- Returns true if troops are onboard the transport (TRZ_LOADED or FIELD_LOADED).
function CTLDTroopGroup:isInTransit()
    return self.state == CTLDTroopGroup.STATE.TRZ_LOADED
        or self.state == CTLDTroopGroup.STATE.FIELD_LOADED
end

--- Returns the count of alive JTAC units in this group.
function CTLDTroopGroup:getJtacCount()
    local n = 0
    for _ in pairs(self._jtacUnits) do n = n + 1 end
    return n
end

--- Returns true if this group has at least one alive JTAC unit.
function CTLDTroopGroup:hasAliveJtac()
    return self:getJtacCount() > 0
end

--- Syncs _aliveUnits / _jtacUnits from the current DCS group.
-- Fully rebuilds both maps from actual DCS unit names.
-- JTAC units are identified by the "JTAC" name prefix (set by _registerOneTemplate).
-- This prefix is exclusive to jtac-role units — all other roles use INF/MG/AT/AA/MORTAR.
-- @param dcsGroup Group|nil  the DCS group (nil to clear refs)
function CTLDTroopGroup:_syncFromDCSGroup(dcsGroup)
    self._aliveUnits = {}
    self._jtacUnits  = {}  -- full reset: rebuild from real DCS unit names
    if not dcsGroup or not dcsGroup:isExist() then
        self.unitTotal = 0
        return
    end
    local units = dcsGroup:getUnits() or {}
    for _, unit in ipairs(units) do
        if unit:isExist() then
            local name = unit:getName()
            -- SVNT units are mortar servants (cosmetic crew); exclude from tracking and count.
            if not name:match("^SVNT") then
                self._aliveUnits[name] = unit
                if name:match("^JTAC") then
                    self._jtacUnits[name] = true
                end
            end
        end
    end
    self.unitTotal = 0
    for _ in pairs(self._aliveUnits) do self.unitTotal = self.unitTotal + 1 end
end

--- Removes a dead unit from _aliveUnits and _jtacUnits.
-- Called by CTLDTroopManager:onUnitDead() on S_EVENT_DEAD.
-- @param unitName string
function CTLDTroopGroup:_removeDeadUnit(unitName)
    self._aliveUnits[unitName] = nil
    self._jtacUnits[unitName]  = nil
    self.unitTotal = 0
    for _ in pairs(self._aliveUnits) do self.unitTotal = self.unitTotal + 1 end
end

--- Transition to DEPLOYED: record the spawned DCS group and sync unit refs.
-- @param dcsGroup Group|nil  spawned DCS group (nil for DEPLOYED_EXZ silent drops)
function CTLDTroopGroup:disembark(dcsGroup)
    self.state    = CTLDTroopGroup.STATE.DEPLOYED
    self.dcsGroup = dcsGroup
    if dcsGroup then
        self:_syncFromDCSGroup(dcsGroup)
    end
end

--- Alias for backward compatibility during transition.
CTLDTroopGroup.deploy = CTLDTroopGroup.disembark

--- Transition to TRZ_LOADED: troops loaded from TroopZone (new load).
-- @param template table  loadableGroup template (used to init _aliveUnits from composition)
function CTLDTroopGroup:setTRZLoaded(template)
    self.state    = CTLDTroopGroup.STATE.TRZ_LOADED
    self.dcsGroup = nil
    self:_initFromTemplate(template)
end

--- Build _aliveUnits / _jtacUnits from a template at load time (before DCS group exists).
-- @param template table  loadableGroup template
function CTLDTroopGroup:_initFromTemplate(template)
    self._aliveUnits = {}
    self._jtacUnits  = {}
    local idx = 0
    for _, role in ipairs(CTLDTroopManager._ROLE_ORDER) do
        local n = template[role] or 0
        for i = 1, n do
            idx = idx + 1
            local unitName = string.format("%s_u%d", template.name or "Troop", idx)
            self._aliveUnits[unitName] = idx  -- placeholder: slot number, not a DCS Unit ref yet
            if role == "jtac" then
                self._jtacUnits[unitName] = true
            end
        end
    end
end

-- ============================================================
-- CTLDTroopManager  (singleton)
-- ============================================================

CTLDTroopManager = class()

CTLDTroopManager._instance = nil

-- ============================================================
-- Unit types per role per coalition
-- ============================================================

-- Default DCS typeNames per role, indexed by coalition (1=RED, 2=BLUE).
-- MMs can override per-template via tmpl.componentTypes = { roleName = {[1]=tn,[2]=tn} }.
-- Custom role names (e.g. civ1, civ2) are also supported via componentTypes.
CTLDTroopManager._ROLE_TYPENAMES = {
    inf    = { [1] = "Infantry AK",        [2] = "Soldier M4 GRG"    },
    mg     = { [1] = "Paratrooper AKS-74", [2] = "Soldier M249"      },
    at     = { [1] = "Paratrooper RPG-16", [2] = "Paratrooper RPG-16"},
    aa     = { [1] = "SA-18 Igla manpad",  [2] = "Soldier stinger"   },
    mortar = { [1] = "2B11 mortar",        [2] = "2B11 mortar"       },
    jtac   = { [1] = "Infantry AK",        [2] = "Soldier M4 GRG"    },  -- same model, name prefix = "JTAC"
    civ    = { [1] = "Civilian",           [2] = "Civilian"           },  -- generic civilian (no weapon weight)
}

-- Equipment-only weight (kg) per role, used as additive on top of base+kit.
-- Fallback defaults — overridden at init() time from ctld.gs() config keys.
CTLDTroopManager._ROLE_EQUIP_WEIGHTS = {
    inf    = 5,    -- RIFLE_WEIGHT
    mg     = 10,   -- MG_WEIGHT
    at     = 7.6,  -- RPG_WEIGHT
    aa     = 18,   -- MANPAD_WEIGHT
    mortar = 26,   -- MORTAR_WEIGHT
    jtac   = 20,   -- JTAC_WEIGHT + RIFLE_WEIGHT
    civ    = 2,    -- CIV_WEIGHT (light personal items)
}

-- Processing order for standard roles. Custom roles declared in componentTypes are
-- appended dynamically per template in _registerOneTemplate.
CTLDTroopManager._ROLE_ORDER = { "aa", "inf", "mg", "at", "mortar", "jtac", "civ" }

-- ============================================================
-- Singleton
-- ============================================================

function CTLDTroopManager.getInstance()
    if CTLDTroopManager._instance == nil then
        CTLDTroopManager._instance = setmetatable({}, CTLDTroopManager)
        CTLDTroopManager._instance:init()
    end
    return CTLDTroopManager._instance
end

-- ============================================================
-- Init
-- ============================================================

function CTLDTroopManager:init()
    self._inTransit        = {}              -- [unitName] = { CTLDTroopGroup, ... } (always a list)
    self._droppedGroups    = { [1]={}, [2]={} }  -- [coalition] = { groupName, ... }
    self._droppedTemplates = {}              -- [groupName] = templateKey (for re-deploy after extract)
    self._parachuteEffect  = CTLDNullParachuteEffect:new()
    self._templates        = {}              -- mutable runtime list (standard + custom)
    self:_registerTemplates()
    self:_loadUserConfig()
    self:_initWeightConfig()
    self._templateCount = #self._templates
    CTLDPlayerManager.getInstance():registerMenuSection({
        key    = "troops",
        manager = self,
        method  = "buildMenuSection",
        order   = 20,
    })
    ctld.utils.log("INFO", "CTLDTroopManager initialized — %d templates registered",
        self._templateCount)
    return self
end

--- Replace the parachute visual effect handler.
-- @param effect CTLDParachuteEffect
function CTLDTroopManager:setParachuteEffect(effect)
    self._parachuteEffect = effect
end

-- ============================================================
-- Template registration → CTLDObjectRegistry entries
-- ============================================================

local function _sanitizeKey(name)
    return (name:gsub("[^%w]", "_"))
end

-- Populates self._templates from config and registers each standard template.
-- Mutates source objects (adds _dbKey, total, hasJtac, custom, disabled) — consistent with legacy.
function CTLDTroopManager:_registerTemplates()
    local cfgTemplates = ctld.gs("loadableGroups") or {}
    for _, tmpl in ipairs(cfgTemplates) do
        tmpl.custom   = false
        tmpl.disabled = false
        table.insert(self._templates, tmpl)
        self:_registerOneTemplate(tmpl)
    end
end

-- Computes total/hasJtac, assigns _dbKey, and inserts a GROUND descriptor into CTLDObjectRegistry.
-- Safe to call at init or at runtime (createLoadableGroup).
-- Supports tmpl.componentTypes = { roleName = {[1]=typeName,[2]=typeName} } to override
-- DCS typeNames per role. Custom role names not in _ROLE_ORDER (e.g. civ1, civ2) are also
-- supported: their quantities come from tmpl[roleName] and their typeNames from componentTypes.
function CTLDTroopManager:_registerOneTemplate(tmpl)
    local ct = type(tmpl.componentTypes) == "table" and tmpl.componentTypes or nil

    -- Build set of standard roles for fast lookup
    local standardRoles = {}
    for _, r in ipairs(CTLDTroopManager._ROLE_ORDER) do standardRoles[r] = true end

    -- Collect custom roles: declared in componentTypes but not in _ROLE_ORDER
    local customRoles = {}
    if ct then
        for role, _ in pairs(ct) do
            if not standardRoles[role] then
                customRoles[#customRoles + 1] = role
            end
        end
        table.sort(customRoles)  -- deterministic order
    end

    local total   = 0
    local hasJtac = false
    for _, role in ipairs(CTLDTroopManager._ROLE_ORDER) do
        local n = tmpl[role] or 0
        total   = total + n
        if role == "jtac" and n > 0 then hasJtac = true end
    end
    for _, role in ipairs(customRoles) do
        total = total + (tmpl[role] or 0)
    end
    tmpl.total   = total
    tmpl.hasJtac = hasJtac

    -- Resolve typeName for a role/coalition, with componentTypes override and mod fallback.
    local function resolveTypeName(role, componentTypes)
        return function(cid)
            -- componentTypes override (per-template)
            local desired = componentTypes and componentTypes[role]
                and componentTypes[role][cid]
            if desired then
                local validator = CTLDModValidator._instance
                if validator and validator:isGroundInvalid(desired) then
                    ctld.utils.log("WARN",
                        "_registerOneTemplate: typeName '%s' (role=%s) not in DCS — fallback to standard soldier",
                        desired, role)
                    return CTLDTroopManager._ROLE_TYPENAMES["inf"][cid]
                        or CTLDTroopManager._ROLE_TYPENAMES["inf"][2]
                end
                return desired
            end
            -- Standard table fallback
            local roleTypes = CTLDTroopManager._ROLE_TYPENAMES[role]
            if roleTypes then
                return roleTypes[cid] or roleTypes[2]
            end
            -- Last-resort: standard soldier for unknown custom roles with no componentTypes entry
            return CTLDTroopManager._ROLE_TYPENAMES["inf"][cid]
                or CTLDTroopManager._ROLE_TYPENAMES["inf"][2]
        end
    end

    -- Build the units array (no dx/dz: circle formation computes them at spawn time)
    -- Each mortar system spawns an additional servant soldier (crew member).
    -- The servant does not count toward tmpl.total or weight.
    local units = {}

    -- Standard roles (with special behaviors for mortar/jtac)
    for _, role in ipairs(CTLDTroopManager._ROLE_ORDER) do
        local n      = tmpl[role] or 0
        local isJtac = (role == "jtac")
        for _ = 1, n do
            table.insert(units, {
                namePrefix = isJtac and "JTAC" or string.upper(role),
                unitType   = resolveTypeName(role, ct),
            })
            if role == "mortar" then
                -- svntOf = true: spawnObject anchors this unit 1 m from the preceding mortar
                -- instead of placing it in the circle; it does not count toward the circle spread.
                table.insert(units, {
                    namePrefix = "SVNT",
                    svntOf     = true,
                    unitType   = resolveTypeName("inf", nil),
                })
            end
        end
    end

    -- Custom roles (no special spawn behavior)
    for _, role in ipairs(customRoles) do
        local n = tmpl[role] or 0
        for _ = 1, n do
            table.insert(units, {
                namePrefix = string.upper(role),
                unitType   = resolveTypeName(role, ct),
            })
        end
    end

    local key   = "troop_" .. _sanitizeKey(tmpl.name)
    tmpl._dbKey = key

    CTLDObjectRegistry._db[key] = {
        groupType  = "GROUND",
        namePrefix = "TroopGrp_" .. _sanitizeKey(tmpl.name),
        task       = "Ground Nothing",
        category   = Unit.Category.GROUND_UNIT,
        formation  = { type = "circle" },
        units      = units,
    }

    ctld.utils.log("INFO", "_registerOneTemplate: '%s' → key='%s' (%d units)",
        tmpl.name, key, total)
end

-- Applies ctld_config_user.customLoadableGroups and ctld_config_user.disableLoadableGroups.
-- Reads weight config keys and caches runtime values on the instance.
-- Called once at init() after config is loaded.
function CTLDTroopManager:_initWeightConfig()
    self._soldierWeight = ctld.gs("SOLDIER_WEIGHT") or 80
    self._kitWeight     = ctld.gs("KIT_WEIGHT")     or 20
    self._roleEquipWeights = {
        inf    = ctld.gs("RIFLE_WEIGHT")   or CTLDTroopManager._ROLE_EQUIP_WEIGHTS.inf,
        mg     = ctld.gs("MG_WEIGHT")      or CTLDTroopManager._ROLE_EQUIP_WEIGHTS.mg,
        at     = ctld.gs("RPG_WEIGHT")     or CTLDTroopManager._ROLE_EQUIP_WEIGHTS.at,
        aa     = ctld.gs("MANPAD_WEIGHT")  or CTLDTroopManager._ROLE_EQUIP_WEIGHTS.aa,
        mortar = ctld.gs("MORTAR_WEIGHT")  or CTLDTroopManager._ROLE_EQUIP_WEIGHTS.mortar,
        jtac   = (ctld.gs("JTAC_WEIGHT") or 15) + (ctld.gs("RIFLE_WEIGHT") or 5),
        civ    = ctld.gs("CIV_WEIGHT")     or CTLDTroopManager._ROLE_EQUIP_WEIGHTS.civ,
    }
end

-- Computes total weight (kg) for a troop group template.
-- Each soldier's base weight is randomised in [SOLDIER_WEIGHT×0.9, SOLDIER_WEIGHT×1.2].
-- KIT_WEIGHT and role-specific equipment are then added.
-- @param template  table  group template with role count fields (inf, mg, at, aa, mortar, jtac)
-- @return number  total weight in kg
function CTLDTroopManager:_weightForGroup(template)
    local sw    = self._soldierWeight   or 80
    local kit   = self._kitWeight       or 20
    local equip = self._roleEquipWeights or CTLDTroopManager._ROLE_EQUIP_WEIGHTS
    local civW  = ctld.gs("CIV_WEIGHT") or CTLDTroopManager._ROLE_EQUIP_WEIGHTS.civ
    local total = 0

    local function addRoleWeight(role, n)
        local w = equip[role]
        if not w then
            -- Custom role: civ* → CIV_WEIGHT, others → RIFLE_WEIGHT
            w = (role:sub(1, 3) == "civ") and civW or (equip.inf or 5)
        end
        for _ = 1, n do
            local base = sw * (0.9 + math.random() * 0.3)
            total = total + base + kit + w
        end
    end

    for _, role in ipairs(CTLDTroopManager._ROLE_ORDER) do
        addRoleWeight(role, template[role] or 0)
    end

    -- Custom roles from componentTypes
    local ct = template.componentTypes
    if type(ct) == "table" then
        local standardRoles = {}
        for _, r in ipairs(CTLDTroopManager._ROLE_ORDER) do standardRoles[r] = true end
        for role, _ in pairs(ct) do
            if not standardRoles[role] then
                addRoleWeight(role, template[role] or 0)
            end
        end
    end

    return total
end

function CTLDTroopManager:_loadUserConfig()
    local cfg = (type(ctld_config_user) == "table") and ctld_config_user or {}

    local customs = cfg.customLoadableGroups
    if type(customs) == "table" then
        for _, entry in ipairs(customs) do
            local ok, err = self:createLoadableGroup(entry)
            if not ok then
                ctld.utils.log("WARN", "_loadUserConfig: skipped custom group — %s", err)
            end
        end
    end

    local disables = cfg.disableLoadableGroups
    if type(disables) == "table" then
        for _, name in ipairs(disables) do
            local ok, err = self:disableLoadableGroup(name)
            if not ok then
                ctld.utils.log("WARN", "_loadUserConfig: could not disable '%s' — %s", name, err)
            end
        end
    end
end

-- ============================================================
-- Public API — LoadableGroup management
-- ============================================================

-- Returns the template entry with this name, or nil.
function CTLDTroopManager:_findTemplate(name)
    for _, tmpl in ipairs(self._templates) do
        if tmpl.name == name then return tmpl end
    end
    return nil
end

-- Creates and registers a custom loadable group template.
-- @param config table  { name, composition={inf,mg,at,aa,mortar,jtac}, side }
-- @return boolean, string|nil
function CTLDTroopManager:createLoadableGroup(config)
    if type(config) ~= "table" then
        return false, "config must be a table"
    end
    if not config.name or config.name == "" then
        return false, "name is required"
    end
    if type(config.composition) ~= "table" then
        return false, "composition is required"
    end

    local comp = config.composition
    local inf    = comp.inf    or 0
    local mg     = comp.mg     or 0
    local at     = comp.at     or 0
    local aa     = comp.aa     or 0
    local mortar = comp.mortar or 0
    local jtac   = comp.jtac   or 0
    local total  = inf + mg + at + aa + mortar + jtac

    if total == 0 then
        return false, "composition must have at least 1 soldier"
    end

    if self:_findTemplate(config.name) then
        ctld.utils.log("WARN", "createLoadableGroup: '%s' already exists, skipping", config.name)
        return false, "template name already exists"
    end

    local tmpl = {
        name     = config.name,
        inf      = inf,  mg = mg,  at = at,  aa = aa,  mortar = mortar,  jtac = jtac,
        side     = config.side,
        custom   = true,
        disabled = false,
    }
    table.insert(self._templates, tmpl)
    self:_registerOneTemplate(tmpl)

    ctld.utils.log("INFO", "createLoadableGroup: '%s' (%d soldiers, side=%s)",
        tmpl.name, tmpl.total, tostring(tmpl.side or "both"))
    return true
end

-- Removes a template (standard or custom).
-- @param name string
-- @return boolean, string|nil
function CTLDTroopManager:removeLoadableGroup(name)
    for i, tmpl in ipairs(self._templates) do
        if tmpl.name == name then
            CTLDObjectRegistry._db[tmpl._dbKey] = nil
            table.remove(self._templates, i)
            ctld.utils.log("INFO", "removeLoadableGroup: '%s' removed", name)
            return true
        end
    end
    return false, "template not found: " .. tostring(name)
end

-- Edits a custom template's composition and/or side restriction.
-- Standard templates cannot be edited (use createLoadableGroup instead).
-- @param name   string
-- @param config table  { composition={...}, side }
-- @return boolean, string|nil
function CTLDTroopManager:editLoadableGroup(name, config)
    local tmpl = self:_findTemplate(name)
    if not tmpl then
        return false, "template not found: " .. tostring(name)
    end
    if not tmpl.custom then
        return false, "cannot edit standard template '" .. name .. "' — create a custom one instead"
    end
    if type(config) ~= "table" then
        return false, "config must be a table"
    end

    if type(config.composition) == "table" then
        local comp = config.composition
        local inf    = comp.inf    or 0
        local mg     = comp.mg     or 0
        local at     = comp.at     or 0
        local aa     = comp.aa     or 0
        local mortar = comp.mortar or 0
        local jtac   = comp.jtac   or 0
        if inf + mg + at + aa + mortar + jtac == 0 then
            return false, "composition must have at least 1 soldier"
        end
        tmpl.inf = inf; tmpl.mg = mg; tmpl.at = at
        tmpl.aa  = aa;  tmpl.mortar = mortar; tmpl.jtac = jtac
    end

    if config.side ~= nil then
        tmpl.side = config.side
    end

    -- Re-register to update ObjectRegistry and recompute total/hasJtac
    self:_registerOneTemplate(tmpl)

    ctld.utils.log("INFO", "editLoadableGroup: '%s' updated (%d soldiers, side=%s)",
        tmpl.name, tmpl.total, tostring(tmpl.side or "both"))
    return true
end

-- Hides a template from the F10 menu without removing it.
-- @param name string
-- @return boolean, string|nil
function CTLDTroopManager:disableLoadableGroup(name)
    local tmpl = self:_findTemplate(name)
    if not tmpl then return false, "template not found: " .. tostring(name) end
    tmpl.disabled = true
    ctld.utils.log("INFO", "disableLoadableGroup: '%s' hidden from menu", name)
    return true
end

-- Restores a previously disabled template in the F10 menu.
-- @param name string
-- @return boolean, string|nil
function CTLDTroopManager:enableLoadableGroup(name)
    local tmpl = self:_findTemplate(name)
    if not tmpl then return false, "template not found: " .. tostring(name) end
    tmpl.disabled = false
    ctld.utils.log("INFO", "enableLoadableGroup: '%s' restored to menu", name)
    return true
end

-- ============================================================
-- Public API — cargo queries
-- ============================================================

-- Returns the list of CTLDTroopGroup in transit for unitName, or nil.
function CTLDTroopManager:getInTransit(unitName)
    local list = self._inTransit[unitName]
    return (list and #list > 0) and list or nil
end

-- Returns true if unitName has at least one troop group onboard.
function CTLDTroopManager:hasTroops(unitName)
    local list = self._inTransit[unitName]
    return list ~= nil and #list > 0
end

-- Returns total troop cargo weight (kg) across all groups for unitName, or 0.
function CTLDTroopManager:getWeight(unitName)
    local list = self._inTransit[unitName]
    if not list then return 0 end
    local total = 0
    for _, grp in ipairs(list) do total = total + grp.weight end
    return total
end

--- Updates DCS internal cargo weight for this transport.
--- Delegates to ctld.utils.updateTransportWeight to aggregate all cargo sources
--- (troops + crates + vehicles) into a single setUnitInternalCargo call.
function CTLDTroopManager:_updateWeight(unitName)
    ctld.utils.updateTransportWeight(unitName)
end

-- ============================================================
-- loadFromZone
-- ============================================================

-- Loads a troop template onto unit from the TRZ pickup zone the unit is currently in.
-- @param unit      DCS Unit object
-- @param zone      CtldZone (zoneType == "pickup")
-- @param template  entry from ctld.gs("loadableGroups") (must have _dbKey, total, hasJtac set)
-- @return bool
function CTLDTroopManager:embarkFromTroopZone(unit, zone, template)
    local unitName  = unit:getName()
    local coalition = unit:getCoalition()
    local typeName  = unit:getTypeName()

    -- Zone coalition check
    if zone.coalition ~= 0 and zone.coalition ~= coalition then
        trigger.action.outTextForGroup(ctld.utils.getGroupId(unit),
            ctld.tr("This pickup zone is not available to your coalition."), 10)
        return false
    end

    -- Position check: unit must be inside the zone
    if not zone:isInZone(unit:getPoint()) then
        trigger.action.outTextForGroup(ctld.utils.getGroupId(unit),
            ctld.tr("You must land inside the pickup zone to load troops."), 10)
        return false
    end

    -- Zone active check
    if not zone.active then
        trigger.action.outTextForGroup(ctld.utils.getGroupId(unit),
            ctld.tr("This pickup zone is not active."), 10)
        return false
    end

    -- Zone stock check (TRZ native: pickCurrentStock; 0=unlimited if pickMaxStock==0)
    if zone:hasPickup() and zone.pickMaxStock ~= 0 and zone.pickCurrentStock < template.total then
        trigger.action.outTextForGroup(ctld.utils.getGroupId(unit),
            ctld.tr("This pickup zone is empty."), 10)
        return false
    end

    -- Compute weight from role counts (needed for capacity check)
    local weight = self:_weightForGroup(template)

    -- Capacity check: always cumulative via _canEmbark (multiple groups allowed up to transport limit).
    do
        local ok, reason = self:_canEmbark(typeName, unitName, template.total, weight)
        if not ok then
            trigger.action.outTextForGroup(ctld.utils.getGroupId(unit), reason, 10)
            return false
        end
    end

    -- Global infantry limit check per coalition
    local limits = ctld.gs("nbLimitSpawnedTroops") or { 0, 0 }
    if limits[1] ~= 0 or limits[2] ~= 0 then
        local inGame = self:_countDroppedTroops(coalition)
        if inGame + template.total > (limits[coalition] or 0) then
            trigger.action.outTextForGroup(ctld.utils.getGroupId(unit),
                ctld.tr("Infantry coalition limit reached, cannot load more troops."), 10)
            return false
        end
    end

    -- Build _aliveUnits / _jtacUnits from template role composition
    local _aliveUnits = {}
    local _jtacUnits  = {}
    local idx = 0
    for _, role in ipairs(CTLDTroopManager._ROLE_ORDER) do
        local n = template[role] or 0
        for i = 1, n do
            idx = idx + 1
            local slotName = string.format("%s_u%d", template.name, idx)
            _aliveUnits[slotName] = idx  -- placeholder: slot ref until DCS spawn
            if role == "jtac" then
                _jtacUnits[slotName] = true
            end
        end
    end

    -- Store transit group entity (append to list)
    local troopGroup = CTLDTroopGroup:new({
        templateKey    = template._dbKey,
        templateName   = template.name,
        unitTotal      = template.total,
        weight         = weight,
        coalitionId    = coalition,
        countryId      = unit:getCountry(),
        state          = CTLDTroopGroup.STATE.TRZ_LOADED,
        _aliveUnits    = _aliveUnits,
        _jtacUnits     = _jtacUnits,
        specificParams = template.specificParams or {},
    })
    troopGroup.dcsGroup = nil
    if not self._inTransit[unitName] then self._inTransit[unitName] = {} end
    table.insert(self._inTransit[unitName], troopGroup)

    -- Consume pickup stock (TRZ native API; no-op for unlimited zones)
    zone:consumeStock(template.total)

    trigger.action.outTextForGroup(ctld.utils.getGroupId(unit),
        ctld.tr("Loaded: %1 (%2 troops).", template.name, template.total), 10)

    ctld.utils.log("INFO", "embarkFromTroopZone: '%s' loaded '%s' (%d units, %.0f kg)",
        unitName, template.name, template.total, weight)

    local _wok, _werr = pcall(self._updateWeight, self, unitName)
    if not _wok then ctld.utils.log("WARN", "CTLDTroopManager: _updateWeight failed for '%s': %s", unitName, tostring(_werr)) end

    local _pObj = CTLDPlayerManager.getInstance():getPlayer(unitName)
    if _pObj then self:refreshMenuSection(_pObj) end

    return true
end

-- ============================================================
-- disembark (fast-rope or combat drop)
-- ============================================================

-- Deploys troops from unit into combat (fast-rope if conditions met, else ground drop).
-- If inside a TRZ with objectiveFlag: troops are counted only (flag increment), no DCS group spawned.
-- @param unit  DCS Unit object
-- @return bool
function CTLDTroopManager:disembark(unit)
    local unitName = unit:getName()
    local list     = self._inTransit[unitName]
    local group    = list and list[1]

    if not group then
        trigger.action.outTextForGroup(ctld.utils.getGroupId(unit),
            ctld.tr("No troops onboard."), 10)
        return false
    end

    local canFastRope = self:_safeToFastRope(unit)
    local onGround    = not self:_isInAir(unit)

    if not canFastRope and not onGround then
        trigger.action.outTextForGroup(ctld.utils.getGroupId(unit),
            ctld.tr("Too high or too fast to drop troops! Hover below %1 ft or land.",
                math.floor((ctld.gs("fastRopeMaximumHeight") or 18.28) * 3.2808399)), 10)
        return false
    end

    local pt  = unit:getPoint()
    local hdg = ctld.utils.getHeadingInRadians("TroopManager.deploy", unit, true)

    -- TRZ objective check: if zone has objectiveFlag, count troops silently (no DCS group spawn)
    local exzZone = CTLDZoneManager.getInstance():isUnitInZone(unitName, "extract")
    if exzZone then
        local current = trigger.misc.getUserFlag(exzZone.objectiveFlag) or 0
        trigger.action.setUserFlag(exzZone.objectiveFlag, current + group.unitTotal)
        group:deploy(nil)
        ctld.utils.log("INFO", "deploy: %d troops sent to objective TRZ '%s' (flag %s = %d)",
            group.unitTotal, exzZone.zoneName, exzZone.objectiveFlag, current + group.unitTotal)
    else
        -- Place group center at (safeR + spreadR) from the aircraft in a random direction.
        -- This guarantees the closest unit in the circle stays at least safeR (≥10m)
        -- from the transport, and successive disembark calls do not spawn on top of each other.
        local safeR     = ctld.utils.getSecureDistanceFromUnit(unitName) or 10
        local spreadR   = ctld.gs("spawnDistanceInCircle") or 10
        local randAngle = math.random() * 2 * math.pi
        local centerDist = safeR + spreadR
        local spawnX    = pt.x + math.sin(randAngle) * centerDist
        local spawnZ    = pt.z + math.cos(randAngle) * centerDist

        local dcsGroup = CTLDObjectRegistry.spawnObject(
            group.templateKey,
            group.coalitionId,
            group.countryId,
            spawnX, spawnZ, hdg,
            { circleRadius = spreadR }
        )

        if not dcsGroup then
            ctld.utils.log("ERROR", "deploy: spawnObject failed for key '%s'", group.templateKey)
            return false
        end

        group:deploy(dcsGroup)
        table.insert(self._droppedGroups[group.coalitionId], dcsGroup:getName())
        -- Store both key and display name to restore templateName correctly after field pickup (BUG-06)
        -- Store original weight and total for accurate weight estimation after unit losses (BUG-07)
        self._droppedTemplates[dcsGroup:getName()] = {
            key            = group.templateKey,
            name           = group.templateName,
            weight         = group.weight,
            total          = group.unitTotal,
            specificParams = group.specificParams,
        }

        if group:hasAliveJtac() then
            local jm = CTLDJTACManager.getInstance()
            for jtacName, _ in pairs(group._jtacUnits) do
                -- JTACs are tracked at unit level (unitName) within a composite group.
                -- Use startLaseTroopUnit (Unit.getByName) — not startLase (Group.getByName).
                jm:startLaseTroopUnit(jtacName)
                ctld.utils.log("INFO", "deploy: startLaseTroopUnit('%s') for JTAC unit", jtacName)
            end
        end

        local grpName = dcsGroup:getName()

        -- WPZ check: if deploy point is inside a waypoint zone, march troops to zone center.
        -- Skip when specificParams.task overrides routing (Feature I takes priority).
        local _hasPostTask = group.specificParams and group.specificParams.task
        local wpzZone = (not _hasPostTask) and
            CTLDZoneManager.getInstance():getWaypointZoneAt(pt, group.coalitionId)
        if wpzZone then
            local dest    = wpzZone:getCenter()
            local wpFrom  = ctld.utils.buildWP("TroopManager.deploy.WPZ", pt,   'Off Road', 50)
            local wpDest  = ctld.utils.buildWP("TroopManager.deploy.WPZ", dest, 'Off Road', 50)
            if wpFrom and wpDest then
                local mission = {
                    id = 'Mission',
                    params = { route = { points = { wpFrom, wpDest } } },
                }
                -- Delay 2 s: DCS group controller may be empty immediately after spawn
                timer.scheduleFunction(function(arg)
                    local grp = Group.getByName(arg.grpName)
                    if not grp or not grp:isExist() then return end
                    local ctrl = grp:getController()
                    ctrl:setOption(AI.Option.Ground.id.ALARM_STATE,
                                   AI.Option.Ground.val.ALARM_STATE.AUTO)
                    ctrl:setOption(AI.Option.Ground.id.ROE,
                                   AI.Option.Ground.val.ROE.OPEN_FIRE)
                    ctrl:setTask(arg.mission)
                end, { grpName = grpName, mission = mission }, timer.getTime() + 2)
                ctld.utils.log("INFO",
                    "deploy: WPZ '%s' — group '%s' ordered to march to zone center",
                    wpzZone.zoneName, grpName)
            end
        end

        -- Feature I: specificParams.task post-spawn route assignment
        self:_assignPostSpawnTask(grpName, pt, group.coalitionId, group.specificParams)
    end

    table.remove(list, 1)
    if #list == 0 then self._inTransit[unitName] = nil end
    local _wok, _werr = pcall(self._updateWeight, self, unitName)
    if not _wok then ctld.utils.log("WARN", "CTLDTroopManager: _updateWeight failed for '%s': %s", unitName, tostring(_werr)) end

    local _pObj = CTLDPlayerManager.getInstance():getPlayer(unitName)
    if _pObj then self:refreshMenuSection(_pObj) end

    -- Confirm message
    local method = (canFastRope and self:_isInAir(unit)) and "fast-roped" or "dropped"
    local dest   = exzZone and ctld.tr("into %1", exzZone.zoneName) or ctld.tr("into combat")
    trigger.action.outTextForGroup(ctld.utils.getGroupId(unit),
        ctld.tr("%1 [%2] %3.", method, group.templateName, dest), 10)

    return true
end

-- Deploys the group at 1-based index idx (multi-group: used by submenu items).
-- Falls back to disembark() if idx == 1 or nil.
-- @param unit DCS Unit, idx number
function CTLDTroopManager:disembarkIndex(unit, idx)
    idx = idx or 1
    if idx == 1 then return self:disembark(unit) end
    local unitName = unit:getName()
    local list     = self._inTransit[unitName]
    if not list or not list[idx] then
        trigger.action.outTextForGroup(ctld.utils.getGroupId(unit),
            ctld.tr("No troops onboard."), 10)
        return false
    end
    -- Swap target to front and call disembark (reuses all checks there)
    list[1], list[idx] = list[idx], list[1]
    return self:disembark(unit)
end

-- Deploys all onboard groups in sequence (multi-group "Unload All").
-- @param unit DCS Unit
function CTLDTroopManager:disembarkAll(unit)
    if not self:hasTroops(unit:getName()) then
        trigger.action.outTextForGroup(ctld.utils.getGroupId(unit),
            ctld.tr("No troops onboard."), 10)
        return false
    end
    while self:hasTroops(unit:getName()) do
        if not self:disembark(unit) then break end
    end
    return true
end

-- ============================================================
-- returnToBase (TRZ pickup zone: troops returned to zone stock)
-- ============================================================

-- Returns troops to the pickup zone the unit is currently in.
-- Increments zone.limit and updates the DCS flag.
-- @param unit  DCS Unit object
-- @param zone  CtldZone (zoneType == "pickup")
-- @return bool
function CTLDTroopManager:returnToTroopZone(unit, zone)
    local unitName  = unit:getName()
    local list      = self._inTransit[unitName]
    local coalition = unit:getCoalition()

    if not list or #list == 0 then
        trigger.action.outTextForGroup(ctld.utils.getGroupId(unit),
            ctld.tr("No troops onboard."), 10)
        return false
    end

    local jm          = CTLDJTACManager.getInstance()
    local totalTroops = 0
    for _, group in ipairs(list) do
        -- Restore pickup stock (TRZ native API; no-op for unlimited zones)
        zone:restoreStock(group.unitTotal)
        totalTroops = totalTroops + group.unitTotal
        for jtacName, _ in pairs(group._jtacUnits or {}) do
            jm:deregisterJTAC(jtacName)
            ctld.utils.log("INFO", "returnToTroopZone: deregisterJTAC('%s')", jtacName)
        end
        ctld.utils.log("INFO", "returnToBase: '%s' returned [%s] to TRZ '%s'",
            unitName, group.templateName, zone.zoneName)
    end

    self._inTransit[unitName] = nil
    local _wok, _werr = pcall(self._updateWeight, self, unitName)
    if not _wok then ctld.utils.log("WARN", "CTLDTroopManager: _updateWeight failed for '%s': %s", unitName, tostring(_werr)) end

    local _pObj = CTLDPlayerManager.getInstance():getPlayer(unitName)
    if _pObj then self:refreshMenuSection(_pObj) end

    trigger.action.outTextForGroup(ctld.utils.getGroupId(unit),
        ctld.tr("Troops returned to base."), 10)
    return true
end

-- ============================================================
-- embarkFromField
-- ============================================================

-- Extracts the nearest friendly dropped troop group (unit must be on the ground).
-- JTAC units are deregistered BEFORE group destruction to avoid spurious killJTAC
-- from the S_EVENT_DEAD that DCS fires on group:destroy().
-- @param unit  DCS Unit object
-- @return bool
function CTLDTroopManager:embarkFromField(unit)
    local unitName  = unit:getName()
    local coalition = unit:getCoalition()
    local typeName  = unit:getTypeName()

    if self:_isInAir(unit) then
        trigger.action.outTextForGroup(ctld.utils.getGroupId(unit),
            ctld.tr("You must land to extract troops."), 10)
        return false
    end

    local nearest = self:_findNearestDropped(unit, coalition)
    if not nearest then
        trigger.action.outTextForGroup(ctld.utils.getGroupId(unit),
            ctld.tr("No extractable troops nearby!"), 10)
        return false
    end

    local groupSize = #nearest.group:getUnits()
    local country  = nearest.group:getUnit(1):getCountry()
    local stored   = self._droppedTemplates[nearest.groupName] or {}

    -- Logical troop count: prefer stored.total (excludes mortar servants) so that servants
    -- do not inflate the capacity check on re-embark (Bug 2).
    local logicalCount = (stored.total and stored.total > 0) and stored.total or groupSize

    -- Weight: proportional to surviving logical units using original avg weight (BUG-07)
    local avgWeight = (stored.weight and stored.total and stored.total > 0)
                      and (stored.weight / stored.total) or 130
    local weight    = math.floor(avgWeight * logicalCount)

    -- Capacity check: always use _canEmbark (cumulative); multi-group flag controls UI only.
    local ok, reason = self:_canEmbark(typeName, unitName, logicalCount, weight)
    if not ok then
        trigger.action.outTextForGroup(ctld.utils.getGroupId(unit), reason, 10)
        return false
    end

    -- Sync _aliveUnits / _jtacUnits from current DCS group before destroy.
    -- JTAC units identified by "JTAC" prefix — exclusive to jtac-role units (BUG-03 / BUG-05).
    local _aliveUnits = {}
    local _jtacUnits  = {}
    local dcsUnits = nearest.group:getUnits()
    for i = 1, #dcsUnits do
        local dcsUnit = dcsUnits[i]
        if dcsUnit and dcsUnit:isExist() then
            local name = dcsUnit:getName()
            _aliveUnits[name] = dcsUnit
            if name:match("^JTAC") then
                _jtacUnits[name] = true
            end
        end
    end

    -- Deregister JTACs BEFORE group:destroy() to avoid spurious killJTAC from S_EVENT_DEAD
    local jm = CTLDJTACManager.getInstance()
    for jtacName, _ in pairs(_jtacUnits) do
        jm:deregisterJTAC(jtacName)
        ctld.utils.log("INFO", "embarkFromField: deregisterJTAC('%s') called before group destroy", jtacName)
    end

    if not self._inTransit[unitName] then self._inTransit[unitName] = {} end
    table.insert(self._inTransit[unitName], CTLDTroopGroup:new({
        templateKey    = stored.key,
        templateName   = stored.name or nearest.groupName,  -- restore original template name (BUG-06)
        unitTotal      = logicalCount,   -- logical count (no mortar servants) for capacity/stock
        weight         = weight,
        coalitionId    = coalition,
        countryId      = country,
        state          = CTLDTroopGroup.STATE.FIELD_LOADED,
        _aliveUnits    = _aliveUnits,
        _jtacUnits     = _jtacUnits,
        specificParams = stored.specificParams or {},
    }))

    self:_removeFromDropped(coalition, nearest.groupName)
    nearest.group:destroy()

    local _wok, _werr = pcall(self._updateWeight, self, unitName)
    if not _wok then ctld.utils.log("WARN", "CTLDTroopManager: _updateWeight failed for '%s': %s", unitName, tostring(_werr)) end

    local _pObj = CTLDPlayerManager.getInstance():getPlayer(unitName)
    if _pObj then self:refreshMenuSection(_pObj) end

    trigger.action.outTextForGroup(ctld.utils.getGroupId(unit),
        ctld.tr("Extracted [%1] (%2 troops).", nearest.groupName, logicalCount), 10)

    ctld.utils.log("INFO", "extract: '%s' extracted group '%s' (%d logical troops, %d DCS units)",
        unitName, nearest.groupName, logicalCount, groupSize)
    return true
end

-- ============================================================
-- Polling / cleanup (called by CTLDCore)
-- ============================================================

-- Removes dead/empty groups from _droppedGroups.
function CTLDTroopManager:cleanupDeadGroups()
    for coa = 1, 2 do
        local alive = {}
        for _, name in ipairs(self._droppedGroups[coa]) do
            local g = Group.getByName(name)
            if g and g:isExist() and #g:getUnits() > 0 then
                table.insert(alive, name)
            else
                -- Also purge from _droppedTemplates to avoid stale entries (BUG-08)
                self._droppedTemplates[name] = nil
            end
        end
        self._droppedGroups[coa] = alive
    end
end

-- Removes entries for destroyed transports from _inTransit.
-- JTAC lifecycle: multi-JTAC per group (JTAC units identified by name prefix "JTAC")
-- JTAC managers keep one entry per JTAC unit, not per group.
-- When the last JTAC of a group dies, the whole group is considered "non-JTAC".

--- Finds a CTLDTroopGroup that has a live unit matching `unitName`.
-- Used by `onUnitDead` to locate the owning group after a unit is destroyed.
-- @param unitName string  DCS unit name
-- @return CTLDTroopGroup|nil
function CTLDTroopManager:_findGroupByAliveUnit(unitName)
    for _, list in pairs(self._inTransit) do
        for _, grp in ipairs(list) do
            if grp._aliveUnits and grp._aliveUnits[unitName] then
                return grp
            end
        end
    end
    for coa = 1, 2 do
        for _, gname in ipairs(self._droppedGroups[coa]) do
            local g = Group.getByName(gname)
            if g and g:isExist() then
                local units = g:getUnits()
                for i = 1, #units do
                    if units[i]:isExist() and units[i]:getName() == unitName then
                        local stored  = self._droppedTemplates[gname] or {}
                        local aliveUnits = {}
                        local jtacUnits = {}
                        for j = 1, #units do
                            local u = units[j]
                            if u:isExist() then
                                local uname = u:getName()
                                aliveUnits[uname] = u
                                if uname:match("^JTAC") then
                                    jtacUnits[uname] = true
                                end
                            end
                        end
                        local grp = CTLDTroopGroup:new({
                            templateKey  = stored.key,
                            templateName = stored.name or gname,
                            unitTotal = 0,
                            weight = 0,
                            coalitionId = coa,
                            countryId = g:getUnit(1):getCountry(),
                            state = CTLDTroopGroup.STATE.DEPLOYED,
                            _aliveUnits = aliveUnits,
                            _jtacUnits = jtacUnits,
                        })
                        grp.dcsGroup = g
                        return grp
                    end
                end
            end
        end
    end
    return nil
end

--- Called from CTLDDCSEventBridge on S_EVENT_DEAD.
-- Removes the dead unit from _aliveUnits and _jtacUnits of the owning group.
-- Deregisters the JTAC from CTLDJTACManager if the dead unit was a JTAC.
-- NOTE: wasJtac is captured BEFORE _removeDeadUnit clears _jtacUnits[unitName].
-- @param unitName string  DCS unit name
function CTLDTroopManager:onUnitDead(unitName)
    local grp = self:_findGroupByAliveUnit(unitName)
    if not grp then
        ctld.utils.log("INFO", "onUnitDead: no group found for unit '%s' — skipping", unitName)
        return
    end
    -- Capture JTAC status before _removeDeadUnit erases the entry
    local wasJtac = grp._jtacUnits ~= nil and grp._jtacUnits[unitName] ~= nil
    grp:_removeDeadUnit(unitName)
    ctld.utils.log("INFO", "onUnitDead: '%s' removed from group (aliveUnits=%d, jtacUnits=%d)",
        unitName, grp:getAliveCount(), grp:getJtacCount())
    if wasJtac then
        CTLDJTACManager.getInstance():deregisterJTAC(unitName)
        ctld.utils.log("INFO", "onUnitDead: JTAC unit '%s' deregistered", unitName)
    end
end

--- Returns the count of alive units (helper for onUnitDead logging).
-- @return number
function CTLDTroopGroup:getAliveCount()
    local n = 0
    for _ in pairs(self._aliveUnits) do n = n + 1 end
    return n
end

function CTLDTroopManager:cleanupDeadTransports()
    local jm = CTLDJTACManager.getInstance()
    for unitName, list in pairs(self._inTransit) do
        local u = Unit.getByName(unitName)
        if not u or not u:isExist() then
            for _, grp in ipairs(list) do
                for jtacName, _ in pairs(grp._jtacUnits or {}) do
                    jm:deregisterJTAC(jtacName)
                    ctld.utils.log("INFO", "cleanupDeadTransports: JTAC '%s' deregistered (orphan)", jtacName)
                end
            end
            self._inTransit[unitName] = nil
            ctld.utils.log("INFO", "cleanupDeadTransports: removed stale entry for '%s'", unitName)
        end
    end
end

--- Called from CTLDDCSEventBridge on S_EVENT_DEAD (transport aircraft).
-- Triggers immediate cleanup of any orphaned transit entries for the dead unit.
-- @param event DCS event object
function CTLDTroopManager:onTransportDead(event)
    local u = event and event.initiator
    if not u then return end
    local ok, alive = pcall(u.isExist, u)
    if ok and alive then return end  -- unit still alive (group death event), skip
    self:cleanupDeadTransports()
end

-- ============================================================
-- Private helpers
-- ============================================================

-- Returns the maximum number of troops this aircraft type can carry.
function CTLDTroopManager:_transportLimit(typeName)
    local caps = (ctld.gs("capabilitiesByType") or {})[typeName]
    if caps and caps.maxTroopsOnboard then return caps.maxTroopsOnboard end
    return ctld.gs("numberOfTroops") or 10
end

-- Returns the total number of troops currently onboard unitName (sum across all groups).
function CTLDTroopManager:_currentTroopCount(unitName)
    local list = self._inTransit[unitName]
    if not list then return 0 end
    local total = 0
    for _, grp in ipairs(list) do total = total + grp.unitTotal end
    return total
end

-- Returns true if newTotal troops (and optionally newWeight kg) can be added to unitName.
-- Checks per-aircraft troop count limit and optional maxTransportWeight.
-- @param typeName  string  aircraft type name
-- @param unitName  string  transport unit name
-- @param newTotal  number  troop count to add
-- @param newWeight number|nil  weight to add (kg); omit to skip weight check
-- @return bool, string|nil  (ok, errorMessage)
function CTLDTroopManager:_canEmbark(typeName, unitName, newTotal, newWeight)
    local limit   = self:_transportLimit(typeName)
    local current = self:_currentTroopCount(unitName)
    if current + newTotal > limit then
        return false, ctld.tr("Group too large for this aircraft (%1/%2 troops).", current, limit)
    end
    if newWeight and newWeight > 0 then
        local maxW = ctld.gs("maxTransportWeight") or 0
        if maxW > 0 then
            local currentW = self:getWeight(unitName)
            if currentW + newWeight > maxW then
                return false, ctld.tr("Transport weight limit exceeded (%1 kg max).", maxW)
            end
        end
    end
    return true
end

-- Returns true if unit is airborne (delegates to ctld.utils.inAir for consistent
-- high-chassis detection across all aircraft types).
function CTLDTroopManager:_isInAir(unit)
    return ctld.utils.inAir(unit)
end

-- Returns true if fast-rope conditions are met.
function CTLDTroopManager:_safeToFastRope(unit)
    if not ctld.gs("enableFastRopeInsertion") then return false end
    local maxH   = (ctld.gs("fastRopeMaximumHeight") or 18.28) + 3.0
    local pt     = unit:getPoint()
    local gndH   = land.getHeight({ x = pt.x, y = pt.z })  -- vec2: y = world-Z
    local altAGL = pt.y - gndH
    local vel    = unit:getVelocity()
    local speed  = math.sqrt(vel.x^2 + vel.y^2 + vel.z^2)
    return altAGL <= maxH and speed < 2.2
end

-- Returns total alive unit count for all dropped groups of given coalition.
function CTLDTroopManager:_countDroppedTroops(coalition)
    local count = 0
    for _, name in ipairs(self._droppedGroups[coalition]) do
        local g = Group.getByName(name)
        if g and g:isExist() then
            count = count + #g:getUnits()
        end
    end
    return count
end

-- Returns { groupName, group, distM } for the nearest dropped group within maxExtractDistance, or nil.
function CTLDTroopManager:_findNearestDropped(unit, coalition)
    local pt      = unit:getPoint()
    local maxDist = ctld.gs("maxExtractDistance") or 125
    local best, bestDist = nil, maxDist

    for _, name in ipairs(self._droppedGroups[coalition]) do
        local g = Group.getByName(name)
        if g and g:isExist() and #g:getUnits() > 0 then
            local leader = g:getUnit(1)
            if leader then
                local gpt  = leader:getPoint()
                local dist = math.sqrt((pt.x - gpt.x)^2 + (pt.z - gpt.z)^2)
                if dist < bestDist then
                    bestDist = dist
                    best = { groupName = name, group = g, distM = dist }
                end
            end
        end
    end
    return best
end

-- Removes a group name from the coalition's dropped list.
function CTLDTroopManager:_removeFromDropped(coalition, groupName)
    local list = self._droppedGroups[coalition]
    for i, name in ipairs(list) do
        if name == groupName then
            table.remove(list, i)
            self._droppedTemplates[groupName] = nil
            return
        end
    end
end

-- Returns a display name for the unit (player name or callsign).
function CTLDTroopManager:_callsign(unit)
    local player = unit:getPlayerName()
    return (player and player ~= "") and player or unit:getTypeName()
end

-- ============================================================
-- Menu action handlers
-- ============================================================

-- "Unload / Extract Troops" button:
--   On ground + nearest dropped group + no troops → embarkFromField
--   Has troops + in TRZ pickup-only               → returnToTroopZone
--   Has troops + in TRZ with objectiveFlag        → disembark (flag incremented)
--   Has troops + not in any TRZ                   → disembark to combat
function CTLDTroopManager:_menuUnloadOrExtract(unit)
    local unitName  = unit:getName()
    local coalition = unit:getCoalition()
    local zm        = CTLDZoneManager.getInstance()
    local inAir     = self:_isInAir(unit)

    -- Ground + extractable group nearby + no troops onboard → embarkFromField
    if not inAir and not self:hasTroops(unitName) then
        local nearest = self:_findNearestDropped(unit, coalition)
        if nearest then
            self:embarkFromField(unit)
            return
        end
    end

    -- Has troops: TRZ with objectiveFlag takes priority over pickup-only TRZ.
    -- Mixed TRZ (hasPickup + hasExtract) → disembark to increment objective flag.
    -- Pickup-only TRZ → returnToTroopZone to restore pickup stock.
    if self:hasTroops(unitName) then
        local exzZone = zm:isUnitInZone(unitName, "extract")
        if exzZone then
            self:disembark(unit)
        else
            local pkzZone = zm:isUnitInZone(unitName, "pickup")
            if pkzZone then
                self:returnToTroopZone(unit, pkzZone)
            else
                self:disembark(unit)
            end
        end
        return
    end

    -- In air, no troops: check if there are groups to extract nearby (hint to land)
    if inAir then
        local nearest = self:_findNearestDropped(unit, coalition)
        if nearest then
            trigger.action.outTextForGroup(ctld.utils.getGroupId(unit),
                ctld.tr("Land near troops to extract them (%1m away).", math.floor(nearest.distM)), 10)
            return
        end
    end

    -- No troops, on ground, no nearby group
    trigger.action.outTextForGroup(ctld.utils.getGroupId(unit),
        ctld.tr("No troops onboard and no extractable troops nearby."), 10)
end

--- "Disembark Troops" button handler (pt1).
-- In TRZ pickup → returnToTroopZone; in EXZ → disembark to objective; elsewhere → combat drop.
-- @param unit DCS Unit
function CTLDTroopManager:_menuDisembark(unit)
    local unitName = unit:getName()
    if not self:hasTroops(unitName) then
        trigger.action.outTextForGroup(ctld.utils.getGroupId(unit), ctld.tr("No troops onboard."), 10)
        return
    end
    local zm      = CTLDZoneManager.getInstance()
    local exzZone = zm:isUnitInZone(unitName, "extract")
    if exzZone then
        self:disembark(unit)
    else
        local pkzZone = zm:isUnitInZone(unitName, "pickup")
        if pkzZone then
            self:returnToTroopZone(unit, pkzZone)
        else
            self:disembark(unit)
        end
    end
end

--- Returns all dropped groups within maxExtractDistance of unit, sorted by distance asc (pt3).
-- @param unit      DCS Unit
-- @param coalition number
-- @return table  array of { groupName, group, distM }
function CTLDTroopManager:_findAllNearbyDropped(unit, coalition)
    local pt      = unit:getPoint()
    local maxDist = ctld.gs("maxExtractDistance") or 125
    local found   = {}
    for _, name in ipairs(self._droppedGroups[coalition]) do
        local g = Group.getByName(name)
        if g and g:isExist() and #g:getUnits() > 0 then
            local leader = g:getUnit(1)
            if leader then
                local gpt  = leader:getPoint()
                local dist = math.sqrt((pt.x - gpt.x)^2 + (pt.z - gpt.z)^2)
                if dist <= maxDist then
                    table.insert(found, { groupName = name, group = g, distM = dist })
                end
            end
        end
    end
    table.sort(found, function(a, b) return a.distM < b.distM end)
    return found
end

--- Extract a specific dropped group by name (pt3).
-- Swaps it to the front of _droppedGroups so embarkFromField picks it.
-- @param unit      DCS Unit
-- @param groupName string  DCS group name to extract
-- @return bool
function CTLDTroopManager:embarkFromFieldByGroup(unit, groupName)
    local coalition = unit:getCoalition()
    local list      = self._droppedGroups[coalition]
    for i, name in ipairs(list) do
        if name == groupName then
            table.remove(list, i)
            table.insert(list, 1, groupName)
            break
        end
    end
    return self:embarkFromField(unit)
end

function CTLDTroopManager:_menuCheckCargo(unit)
    local unitName = unit:getName()
    local list     = self._inTransit[unitName]
    local msg
    if list and #list > 0 then
        if #list == 1 then
            local grp = list[1]
            msg = ctld.tr("Cargo: [%1] — %2 troops, %3 kg",
                grp.templateName, grp.unitTotal, math.floor(grp.weight))
        else
            local lines    = {}
            local totalT   = 0
            local totalW   = 0
            for i, grp in ipairs(list) do
                table.insert(lines, string.format("[%d] %s — %d troops, %d kg",
                    i, grp.templateName, grp.unitTotal, math.floor(grp.weight)))
                totalT = totalT + grp.unitTotal
                totalW = totalW + grp.weight
            end
            table.insert(lines, string.format("TOTAL: %d troops, %d kg", totalT, math.floor(totalW)))
            msg = table.concat(lines, "\n")
        end
    else
        msg = ctld.tr("No troops onboard.")
    end
    trigger.action.outTextForGroup(ctld.utils.getGroupId(unit), msg, 10)
end

-- ============================================================
-- Feature I — Post-spawn task assignment
-- ============================================================

--- Assign a post-spawn route/task to a ground group based on specificParams.task.
-- Scheduled 2 s after spawn (DCS group controller needs one frame to initialise).
--
-- Supported tasks:
--   "gotoNearestWPZ"                — march toward center of nearest active WPZ for the coalition
--   "AttackNearestEnemyOnLos"        — advance toward nearest enemy unit with LOS (world.searchObjects)
--
-- No task is assigned if specificParams.task is nil, or if no suitable target is found.
--
-- @param grpName       string   DCS group name (after spawn)
-- @param spawnPt       Vec3     world position where the group was spawned
-- @param coalitionId   number   coalition.side.*
-- @param specificParams table   template specificParams table (may be nil or empty)
function CTLDTroopManager:_assignPostSpawnTask(grpName, spawnPt, coalitionId, specificParams)
    local task = specificParams and specificParams.task
    if not task then return end

    timer.scheduleFunction(function(arg)
        local grp = Group.getByName(arg.grpName)
        if not grp or not grp:isExist() then return end
        local ctrl = grp:getController()

        local destPt = nil  -- Vec3 destination, set by each branch

        if arg.task == "gotoNearestWPZ" then
            local wpzZone = CTLDZoneManager.getInstance():getNearestWaypointZone(
                arg.spawnPt, arg.coalitionId)
            if wpzZone then
                destPt = wpzZone:getCenter()
                ctld.utils.log("INFO",
                    "_assignPostSpawnTask: '%s' gotoNearestWPZ → '%s'",
                    arg.grpName, wpzZone.zoneName)
            end

        elseif arg.task == "AttackNearestEnemyOnLos" then
            local enemyCoa = (arg.coalitionId == coalition.side.RED)
                             and coalition.side.BLUE or coalition.side.RED
            local offsetA  = { x = arg.spawnPt.x, y = arg.spawnPt.y + 2, z = arg.spawnPt.z }
            local bestDist = math.huge
            local bestPos  = nil

            world.searchObjects(
                Object.Category.UNIT,
                { id = world.VolumeType.SPHERE,
                  params = { point = arg.spawnPt, radius = ctld.gs("maximumSearchDistance") or 10000 } },
                function(unit, _)
                    if not unit:isExist() or unit:getLife() <= 1 then return true end
                    if unit:getCoalition() ~= enemyCoa then return true end
                    local uPos    = unit:getPoint()
                    local offsetB = { x = uPos.x, y = uPos.y + 2, z = uPos.z }
                    if not land.isVisible(offsetA, offsetB) then return true end
                    local dist = ctld.utils.getDistance(
                        "CTLDTroopManager._assignPostSpawnTask", arg.spawnPt, uPos)
                    if dist < bestDist then
                        bestDist = dist
                        bestPos  = uPos
                    end
                    return true
                end
            )

            if bestPos then
                destPt = bestPos
                ctld.utils.log("INFO",
                    "_assignPostSpawnTask: '%s' AttackNearestEnemyOnLos → (%.1f, %.1f)",
                    arg.grpName, bestPos.x, bestPos.z)
            else
                ctld.utils.log("WARN",
                    "_assignPostSpawnTask: '%s' AttackNearestEnemyOnLos → no target in LOS (radius=%.0f)",
                    arg.grpName, ctld.gs("maximumSearchDistance") or 10000)
            end
        end

        if not destPt then return end  -- no valid target found

        local wpFrom = ctld.utils.buildWP("_assignPostSpawnTask", arg.spawnPt, 'Off Road', 50)
        local wpDest = ctld.utils.buildWP("_assignPostSpawnTask", destPt,      'Off Road', 50)
        if not (wpFrom and wpDest) then return end

        ctrl:setOption(AI.Option.Ground.id.ALARM_STATE, AI.Option.Ground.val.ALARM_STATE.AUTO)
        ctrl:setOption(AI.Option.Ground.id.ROE,         AI.Option.Ground.val.ROE.OPEN_FIRE)
        ctrl:setTask({ id = 'Mission',
                       params = { route = { points = { wpFrom, wpDest } } } })
    end, { grpName = grpName, spawnPt = spawnPt, coalitionId = coalitionId, task = task },
         timer.getTime() + 2)
end

-- ============================================================
-- Feature A — Virtual parachute
-- ============================================================

--- Parachute troops currently loaded on a transport.
-- Altitude AGL is checked at call time. If below parachuteMinAltitudeTroops,
-- a message is sent to the group and nothing happens.
-- Each unit in the group gets its own independent landing position.
-- The DCS ground group is spawned with all unit positions after descentTime.
-- Publishes OnTroopsDeployed (trigger="parachute") immediately,
-- and OnTroopsParachuteLanded after descentTime.
-- @param transport  Unit    DCS transport unit
-- @param playerObj  table   CTLDPlayer-like {groupId, unitName}
function CTLDTroopManager:parachuteTroops(transport, playerObj)
    local dropPos     = transport:getPoint()
    local groundUnder = land.getHeight({ x = dropPos.x, y = dropPos.z })
    local altAGL      = dropPos.y - groundUnder
    local minAlt      = ctld.gs("parachuteMinAltitudeTroops") or 50

    if altAGL < minAlt then
        trigger.action.outTextForGroup(playerObj.groupId,
            ctld.tr("Altitude too low for parachute drop. Minimum: %1m AGL (current: %2m AGL)",
                math.floor(minAlt), math.floor(altAGL)), 10)
        return
    end

    local _list = self._inTransit[playerObj.unitName]
    local troopGroup = _list and _list[1]
    if not troopGroup then
        trigger.action.outTextForGroup(playerObj.groupId, ctld.tr("No troops onboard."), 8)
        return
    end

    local descentRate = ctld.gs("parachuteDescentRateTroops") or 5
    local unitDefs    = {}
    local landPositions = {}

    -- Resolve unit type from template registry (fallback to generic infantry)
    local template    = troopGroup.templateKey and CTLDObjectRegistry._db[troopGroup.templateKey]
    local unitCount   = troopGroup.unitTotal or 1
    local unitType    = (template and template.units and template.units[1] and template.units[1].type)
                        or "Soldier AK"

    -- Compute one landing position per unit
    local firstDescentTime = nil
    for i = 1, unitCount do
        local landPos, descentTime = ctld.utils.calcDropPosition(transport, descentRate)
        table.insert(landPositions, landPos)
        unitDefs[i] = {
            type    = unitType,
            name    = troopGroup.templateName .. "_unit" .. i,
            x       = landPos.x,
            y       = landPos.z,   -- DCS ground group: position.y = world Z axis
            heading = math.random(0, 360) * math.pi / 180,
        }
        if i == 1 then firstDescentTime = descentTime end
    end

    local descentTime = firstDescentTime or
        select(2, ctld.utils.calcDropPosition(transport, descentRate))

    -- Announce drop to the player group
    trigger.action.outTextForGroup(playerObj.groupId,
        ctld.tr("Parachuting %1 (%2 troops) — landing in ~%3s",
            troopGroup.templateName, troopGroup.unitTotal, math.floor(descentTime)), 10)

    -- Unload first group from transport cargo
    table.remove(_list, 1)
    if #_list == 0 then self._inTransit[playerObj.unitName] = nil end
    -- Rebuild menu immediately so remaining groups reflect the updated list.
    -- playerObj may be a raw arg table (from menu callback) — fetch the real CTLDPlayer.
    local _pObj = CTLDPlayerManager.getInstance():getPlayer(playerObj.unitName)
    if _pObj then self:refreshMenuSection(_pObj) end

    local dropData = {
        type          = "troop",
        unitName      = troopGroup.templateName,
        dropPosition  = dropPos,
        landPositions = landPositions,
        altitude      = altAGL,
        descentTime   = descentTime,
        transport     = transport,
        player        = playerObj.unitName,
    }
    self._parachuteEffect:onStart(dropData)

    EventDispatcher.getInstance():publish("OnTroopsDeployed", {
        troops          = troopGroup,
        carrierUnitName = transport:getName(),
        player          = playerObj.unitName,
        trigger         = "parachute",
        destination     = { type = "combat", troopZone = nil },
        timestamp       = timer.getAbsTime(),
    })

    -- Capture for timer closure
    local _troopGroup    = troopGroup
    local _unitDefs      = unitDefs
    local _landPositions = landPositions
    local _dropData      = dropData
    local _coalition     = playerObj.coalition or 2
    local _countryId     = troopGroup.countryId  -- captured here; coalition.getCountryCoalition does not exist in DCS API

    timer.scheduleFunction(function()
        local _, spawnedGroup = ctld.utils.spawnAs("GROUND", _countryId, {
            name  = _troopGroup.templateName,
            task  = "Ground Nothing",
            units = _unitDefs,
        })

        local grp = Group.getByName(_troopGroup.templateName)
        if grp then
            table.insert(self._droppedGroups[_coalition] or {}, _troopGroup.templateName)
            -- Mirror _droppedTemplates so embarkFromField can restore template info
            self._droppedTemplates[_troopGroup.templateName] = {
                key            = _troopGroup.templateKey,
                name           = _troopGroup.templateName,
                weight         = _troopGroup.weight,
                total          = _troopGroup.unitTotal,
                specificParams = _troopGroup.specificParams,
            }
            -- Register any JTAC units with CTLDJTACManager.
            -- _jtacUnits slot names end with "_u<idx>" — map to spawned unit by position.
            if _troopGroup:hasAliveJtac() then
                local jtacSlots = {}
                for slotName, _ in pairs(_troopGroup._jtacUnits) do
                    local idx = tonumber(slotName:match("_u(%d+)$"))
                    if idx then jtacSlots[idx] = true end
                end
                local jm = CTLDJTACManager.getInstance()
                local spawnedUnits = grp:getUnits()
                for pos, u in ipairs(spawnedUnits) do
                    if jtacSlots[pos] and u:isExist() then
                        jm:startLaseTroopUnit(u:getName())
                        ctld.utils.log("INFO", "parachuteTroops: startLaseTroopUnit('%s') slot %d", u:getName(), pos)
                    end
                end
            end

            -- Feature I: specificParams.task post-spawn route assignment
            local _landPt = _landPositions and _landPositions[1]
            if _landPt then
                self:_assignPostSpawnTask(
                    _troopGroup.templateName, _landPt,
                    _coalition, _troopGroup.specificParams)
            end
        end

        self._parachuteEffect:onLanded(_dropData)

        EventDispatcher.getInstance():publish("OnTroopsParachuteLanded", {
            troops        = _troopGroup,
            spawnedGroup  = spawnedGroup,
            positions     = _landPositions,
            transport     = transport:getName(),
            player        = playerObj.unitName,
            startAltitude = altAGL,
            timestamp     = timer.getAbsTime(),
        })
    end, {}, timer.getTime() + descentTime)
end

-- Parachutes all onboard groups in sequence (multi-group "Parachute All").
-- @param transport Unit, playerObj table
function CTLDTroopManager:parachuteAll(transport, playerObj)
    if not self:hasTroops(playerObj.unitName) then
        trigger.action.outTextForGroup(playerObj.groupId, ctld.tr("No troops onboard."), 8)
        return
    end
    while self:hasTroops(playerObj.unitName) do
        self:parachuteTroops(transport, playerObj)
    end
end

-- Parachutes the group at 1-based index idx (multi-group submenu item).
-- @param transport Unit, playerObj table, idx number
function CTLDTroopManager:parachuteTroopsIndex(transport, playerObj, idx)
    idx = idx or 1
    if idx == 1 then return self:parachuteTroops(transport, playerObj) end
    local list = self._inTransit[playerObj.unitName]
    if not list or not list[idx] then
        trigger.action.outTextForGroup(playerObj.groupId, ctld.tr("No troops onboard."), 8)
        return
    end
    -- Swap target to front and parachute
    list[1], list[idx] = list[idx], list[1]
    self:parachuteTroops(transport, playerObj)
end

-- ============================================================
-- F10 Menu section
-- ============================================================

--- Build the "Troop Commands" F10 submenu for a player (called once at spawn).
-- Creates the submenu container then delegates to refreshMenuSection for content.
-- @param playerObj CTLDPlayer
-- @param menu      ctld.Menu
function CTLDTroopManager:buildMenuSection(playerObj, menu)
    local caps = (ctld.gs("capabilitiesByType") or {})[playerObj.typeName]
    if not (playerObj.isTransport and caps and caps.troopsEnabled) then return end

    local root     = ctld.tr("CTLD")
    local troopSub = ctld.tr("Troop Commands")
    -- Create the container node (idempotent). Content is populated by refreshMenuSection.
    menu:addSubMenu({ root }, troopSub, { order = 20 })
    self:refreshMenuSection(playerObj)
end

--- Rebuild the "Troop Commands" menu branch for playerObj.
-- Called on S_EVENT_LAND and S_EVENT_TAKEOFF to reflect the player's current
-- state (in air / on ground / zone membership).
-- @param playerObj CTLDPlayer
function CTLDTroopManager:refreshMenuSection(playerObj)
    local caps = (ctld.gs("capabilitiesByType") or {})[playerObj.typeName]
    if not (playerObj.isTransport and caps and caps.troopsEnabled) then return end

    local mm   = ctld.MenuManager:getInstance()
    local menu = mm:getMenuByGroupId(playerObj.groupId)
    if not menu then return end

    local root     = ctld.tr("CTLD")
    local troopSub = ctld.tr("Troop Commands")

    -- Clear dynamic content; the "Troop Commands" submenu container is preserved.
    menu:clearBranch({ root, troopSub })

    local unit  = Unit.getByName(playerObj.unitName)
    local inAir = not unit or self:_isInAir(unit)

    local hasTroops = self:hasTroops(playerObj.unitName)

    if not inAir and unit then
        local pt            = unit:getPoint()
        local inTransitList = self._inTransit[playerObj.unitName]
        local nearbyGroups  = self:_findAllNearbyDropped(unit, playerObj.coalition)
        local limit         = self:_transportLimit(playerObj.typeName)

        -- ── Disembark Troops ─────────────────────────────────────────────────
        if hasTroops then
            if inTransitList and #inTransitList > 1 then
                -- Multi-group: one entry per group + "Disembark All"
                local disembarkSub = ctld.tr("Disembark Troops")
                menu:addSubMenu({ root, troopSub }, disembarkSub, { order = 10 })
                menu:addCommand({ root, troopSub, disembarkSub }, ctld.tr("Disembark All"),
                    function(arg)
                        local u = Unit.getByName(arg.unitName)
                        if not u then return end
                        CTLDTroopManager.getInstance():disembarkAll(u)
                    end,
                    { unitName = playerObj.unitName })
                for i, grp in ipairs(inTransitList) do
                    local capturedIdx = i
                    menu:addCommand({ root, troopSub, disembarkSub },
                        string.format("[%d] %s", i, grp.templateName),
                        function(arg)
                            local u = Unit.getByName(arg.unitName)
                            if not u then return end
                            CTLDTroopManager.getInstance():disembarkIndex(u, arg.idx)
                        end,
                        { unitName = playerObj.unitName, idx = capturedIdx })
                end
            else
                -- Single group
                menu:addCommand({ root, troopSub }, ctld.tr("Disembark Troops"),
                    function(arg)
                        local u = Unit.getByName(arg.unitName)
                        if not u then return end
                        CTLDTroopManager.getInstance():_menuDisembark(u)
                    end,
                    { unitName = playerObj.unitName }, { order = 10 })
            end
        end

        -- ── Embark / Extract Troops ───────────────────────────────────────────
        -- Container created first so its order is set before children are added.
        local embarkSub        = ctld.tr("Embark / Extract Troops")
        local hasEmbarkContent = false
        menu:addSubMenu({ root, troopSub }, embarkSub, { order = 20 })

        -- TRZ submenus (one per zone the player is physically inside)
        for _, zone in pairs(CTLDZoneManager.getInstance():getTroopZonesForCoalition(playerObj.coalition)) do
            if zone:hasPickup() and zone:isInZone(pt) then
                hasEmbarkContent = true
                local zName     = zone.zoneName
                local zoneSub   = ctld.tr("Load from %1", "TRZ_" .. zName)
                local zoneStock = (zone.pickMaxStock == 0) and math.huge or zone.pickCurrentStock
                menu:addSubMenu({ root, troopSub, embarkSub }, zoneSub)
                for _, tmpl in ipairs(self._templates) do
                    local sideOk  = (tmpl.side == nil or tmpl.side == playerObj.coalition)
                    local sizeOk  = (tmpl.total <= limit)
                    local stockOk = (tmpl.total <= zoneStock)
                    if not tmpl.disabled and sideOk and sizeOk and stockOk then
                        local capturedTmpl  = tmpl
                        local capturedZName = zName
                        menu:addCommand({ root, troopSub, embarkSub, zoneSub },
                            ctld.tr("Load ") .. tmpl.name,
                            function(arg)
                                local u = Unit.getByName(arg.unitName)
                                if not u then return end
                                local z = CTLDZoneManager.getInstance():getTroopZone(arg.zoneName)
                                if not z then
                                    trigger.action.outTextForGroup(ctld.utils.getGroupId(u),
                                        ctld.tr("Zone not found."), 10)
                                    return
                                end
                                CTLDTroopManager.getInstance():embarkFromTroopZone(u, z, arg.tmpl)
                            end,
                            { unitName = playerObj.unitName, zoneName = capturedZName, tmpl = capturedTmpl })
                    end
                end
            end
        end

        -- Extract from field: shown when no troops onboard, or when there is still
        -- troop capacity available (field rescue is always allowed if capacity permits).
        local _canExtract = not hasTroops
            or self:_currentTroopCount(playerObj.unitName) < limit
        if _canExtract and #nearbyGroups > 0 then
            hasEmbarkContent = true
            if #nearbyGroups == 1 then
                -- Single nearby group: direct button
                local capturedName = nearbyGroups[1].groupName
                menu:addCommand({ root, troopSub, embarkSub },
                    ctld.tr("Extract: %1", nearbyGroups[1].groupName),
                    function(arg)
                        local u = Unit.getByName(arg.unitName)
                        if not u then return end
                        CTLDTroopManager.getInstance():embarkFromFieldByGroup(u, arg.groupName)
                    end,
                    { unitName = playerObj.unitName, groupName = capturedName })
            else
                -- Multiple nearby groups: submenu with distance hints
                local extractSub = ctld.tr("Extract from field")
                menu:addSubMenu({ root, troopSub, embarkSub }, extractSub)
                for _, entry in ipairs(nearbyGroups) do
                    local capturedName = entry.groupName
                    menu:addCommand({ root, troopSub, embarkSub, extractSub },
                        string.format("%s (%dm)", entry.groupName, math.floor(entry.distM)),
                        function(arg)
                            local u = Unit.getByName(arg.unitName)
                            if not u then return end
                            CTLDTroopManager.getInstance():embarkFromFieldByGroup(u, arg.groupName)
                        end,
                        { unitName = playerObj.unitName, groupName = capturedName })
                end
            end
        end

        -- Hide the container if nothing to show inside
        if not hasEmbarkContent then
            menu:setBranchEnabled({ root, troopSub, embarkSub }, false)
        end

        -- ── Check Cargo ───────────────────────────────────────────────────────
        menu:addCommand({ root, troopSub }, ctld.tr("Check Cargo"),
            function(arg)
                local u = Unit.getByName(arg.unitName)
                if not u then return end
                CTLDTroopManager.getInstance():_menuCheckCargo(u)
            end,
            { unitName = playerObj.unitName }, { order = 30 })

    end

    -- "Parachute Troops" — in-flight only, if capable and troops onboard
    if unit and inAir then
        local caps2 = (ctld.gs("capabilitiesByType") or {})[playerObj.typeName]
        if caps2 and caps2.canParachuteDrop and hasTroops then
            local inTransitList = self._inTransit[playerObj.unitName]
            if inTransitList and #inTransitList > 1 then
                -- Multi-group: submenu per group + "Parachute All"
                local parachuteSub = ctld.tr("Parachute Troops")
                menu:addSubMenu({ root, troopSub }, parachuteSub)
                menu:addCommand({ root, troopSub, parachuteSub }, ctld.tr("Parachute All"),
                    function(arg)
                        local transport = Unit.getByName(arg.unitName)
                        if not transport then return end
                        CTLDTroopManager.getInstance():parachuteAll(transport, arg)
                    end,
                    { unitName = playerObj.unitName, groupId = playerObj.groupId,
                      coalition = playerObj.coalition })
                for i, grp in ipairs(inTransitList) do
                    local capturedIdx = i
                    menu:addCommand({ root, troopSub, parachuteSub },
                        string.format("[%d] %s", i, grp.templateName),
                        function(arg)
                            local transport = Unit.getByName(arg.unitName)
                            if not transport then return end
                            CTLDTroopManager.getInstance():parachuteTroopsIndex(transport, arg, arg.idx)
                        end,
                        { unitName = playerObj.unitName, groupId = playerObj.groupId,
                          coalition = playerObj.coalition, idx = capturedIdx })
                end
            else
                menu:addCommand({ root, troopSub }, ctld.tr("Parachute Troops"),
                    function(arg)
                        local transport = Unit.getByName(arg.unitName)
                        if not transport then return end
                        CTLDTroopManager.getInstance():parachuteTroops(transport, arg)
                    end,
                    { unitName = playerObj.unitName, groupId = playerObj.groupId,
                      coalition = playerObj.coalition })
            end
        end
    end

    menu:refresh()
    ctld.utils.log("INFO", "CTLDTroopManager:refreshMenuSection — unit=%s inAir=%s",
        playerObj.unitName, tostring(inAir))
end

-- ============================================================
-- Public ctld.* API — LoadableGroup wrappers
-- ============================================================

--- Create a custom loadable group template.
-- @param config table  { name, composition={inf,mg,at,aa,mortar,jtac}, side }
-- @return boolean, string|nil
function ctld.createLoadableGroup(config)
    return CTLDTroopManager.getInstance():createLoadableGroup(config)
end

--- Remove a loadable group template (standard or custom).
-- @param name string
-- @return boolean, string|nil
function ctld.removeLoadableGroup(name)
    return CTLDTroopManager.getInstance():removeLoadableGroup(name)
end

--- Edit a custom loadable group template.
-- Standard templates are refused.
-- @param name   string
-- @param config table  { composition={...}, side }
-- @return boolean, string|nil
function ctld.editLoadableGroup(name, config)
    return CTLDTroopManager.getInstance():editLoadableGroup(name, config)
end

--- Hide a template from the F10 menu.
-- @param name string
-- @return boolean, string|nil
function ctld.disableLoadableGroup(name)
    return CTLDTroopManager.getInstance():disableLoadableGroup(name)
end

--- Restore a disabled template in the F10 menu.
-- @param name string
-- @return boolean, string|nil
function ctld.enableLoadableGroup(name)
    return CTLDTroopManager.getInstance():enableLoadableGroup(name)
end

-- ============================================================
-- Legacy-compatible public API (called by compat/legacy_api.lua)
-- ============================================================

--- Resolve a count or composition table to the closest available template.
-- integer → template whose total is nearest; table {inf,mg,...} → sum totals then match.
-- @param coalitionId number  (unused — templates are coalition-agnostic)
-- @param number      number|table
-- @return table|nil  template
function CTLDTroopManager:_resolveTemplateForLegacy(coalitionId, number)
    if #self._templates == 0 then return nil end
    if type(number) == "table" then
        local total = 0
        for _, role in ipairs(CTLDTroopManager._ROLE_ORDER) do
            total = total + (number[role] or 0)
        end
        number = total
    end
    local n = tonumber(number) or 1
    local best, bestDelta = nil, math.huge
    for _, tmpl in ipairs(self._templates) do
        if not tmpl.disabled then
            local delta = math.abs((tmpl.total or 0) - n)
            if delta < bestDelta then bestDelta = delta; best = tmpl end
        end
    end
    return best
end

--- Spawn a deployable troop group at a DCS trigger zone (MM DO SCRIPT).
-- @param side        string         "red" | "blue"
-- @param number      number|table   troop count or composition {inf=N,mg=N,...}
-- @param triggerName string         DCS trigger zone name
-- @param radius      number         random spread radius in metres (0 = at center)
-- @return boolean
function CTLDTroopManager:spawnGroupAtTrigger(side, number, triggerName, radius)
    local trig = trigger.misc.getZone(triggerName)
    if not trig then
        ctld.utils.log("ERROR", "CTLDTroopManager:spawnGroupAtTrigger — zone not found: %s", tostring(triggerName))
        return false
    end
    local p2 = { x = trig.point.x, y = trig.point.z }
    local pt = { x = p2.x, y = land.getHeight(p2), z = p2.y }
    return self:spawnGroupAtPoint(side, number, pt, radius)
end

--- Spawn a deployable troop group at a Vec3 point (MM DO SCRIPT).
-- The closest template by unit count is used; group is registered as droppable.
-- @param side    string         "red" | "blue"
-- @param number  number|table   troop count or composition table
-- @param point   table          vec3 {x, y, z}
-- @param radius  number         random spread radius in metres
-- @return boolean
function CTLDTroopManager:spawnGroupAtPoint(side, number, point, radius)
    local coalitionId = (side == "red") and coalition.side.RED or coalition.side.BLUE
    local countryId   = (coalitionId == coalition.side.RED) and country.id.RUSSIA or country.id.USA
    radius = math.max(0, radius or 0)

    local tmpl = self:_resolveTemplateForLegacy(coalitionId, number)
    if not tmpl then
        ctld.utils.log("ERROR", "CTLDTroopManager:spawnGroupAtPoint — no template available")
        return false
    end

    local dcsGroup = CTLDObjectRegistry.spawnObject(
        tmpl._dbKey, coalitionId, countryId,
        point.x, point.z, 0,
        { circleRadius = radius }
    )
    if not dcsGroup then
        ctld.utils.log("ERROR", "CTLDTroopManager:spawnGroupAtPoint — spawnObject failed for key '%s'", tostring(tmpl._dbKey))
        return false
    end
    table.insert(self._droppedGroups[coalitionId], dcsGroup:getName())
    ctld.utils.log("INFO", "CTLDTroopManager:spawnGroupAtPoint — '%s' spawned (%s, %d units)",
        dcsGroup:getName(), side, tmpl.total)
    return true
end

--- Pre-load a named transport with troops, replacing any existing cargo.
-- Uses the template closest to number for the transport's coalition.
-- @param unitName string         DCS unit name of the transport
-- @param number   number|table   troop count or composition
-- @param troops   boolean        legacy param (ignored — always loads infantry template)
-- @return boolean
function CTLDTroopManager:preLoadTransport(unitName, number, troops)
    local unit = Unit.getByName(unitName)
    if not unit or not unit:isExist() then
        ctld.utils.log("WARN", "CTLDTroopManager:preLoadTransport — unit not found: %s", tostring(unitName))
        return false
    end
    local coalitionId = unit:getCoalition()
    local tmpl = self:_resolveTemplateForLegacy(coalitionId, number)
    if not tmpl then
        ctld.utils.log("ERROR", "CTLDTroopManager:preLoadTransport — no template for '%s'", unitName)
        return false
    end
    local weight = self:_weightForGroup(tmpl)

    local _aliveUnits = {}
    local _jtacUnits  = {}
    local idx = 0
    for _, role in ipairs(CTLDTroopManager._ROLE_ORDER) do
        local n = tmpl[role] or 0
        for i = 1, n do
            idx = idx + 1
            local slotName = string.format("%s_u%d", tmpl.name, idx)
            _aliveUnits[slotName] = idx
            if role == "jtac" then
                _jtacUnits[slotName] = true
            end
        end
    end

    self._inTransit[unitName] = { CTLDTroopGroup:new({
        templateKey  = tmpl._dbKey,
        templateName = tmpl.name,
        unitTotal    = tmpl.total,
        weight       = weight,
        coalitionId  = coalitionId,
        countryId    = unit:getCountry(),
        state        = CTLDTroopGroup.STATE.TRZ_LOADED,
        _aliveUnits  = _aliveUnits,
        _jtacUnits   = _jtacUnits,
    }) }
    self:_updateWeight(unitName)
    ctld.utils.log("INFO", "CTLDTroopManager:preLoadTransport — '%s' loaded [%s]", unitName, tmpl.name)
    return true
end

--- Force-deploy all troops from a named transport.
-- @param unitName string  DCS unit name
-- @return boolean
function CTLDTroopManager:unloadTransport(unitName)
    local unit = Unit.getByName(unitName)
    if not unit or not unit:isExist() then
        ctld.utils.log("WARN", "CTLDTroopManager:unloadTransport — unit not found: %s", tostring(unitName))
        return false
    end
    if not self:hasTroops(unitName) then return false end
    return self:deploy(unit)
end

--- Force-load troops into a named transport from the nearest active pickup zone.
-- Uses the first available template. No-op if no pickup zone found.
-- @param unitName string  DCS unit name
-- @return boolean
function CTLDTroopManager:loadTransport(unitName)
    local unit = Unit.getByName(unitName)
    if not unit or not unit:isExist() then
        ctld.utils.log("WARN", "CTLDTroopManager:loadTransport — unit not found: %s", tostring(unitName))
        return false
    end
    local zone = CTLDZoneManager.getInstance():getTroopZoneForUnit(unitName)
    if not zone or not zone:hasPickup() then
        ctld.utils.log("WARN", "CTLDTroopManager:loadTransport — no pickup zone for '%s'", unitName)
        return false
    end
    local tmpl = self._templates[1]
    if not tmpl then return false end
    return self:embarkFromTroopZone(unit, zone, tmpl)
end

--- Unload troops from a named AI transport when an enemy is detected within distance.
-- No-op for player-controlled units. Requires CTLDJTACDetector (LOS check).
-- @param unitName string  DCS unit name
-- @param distance number  detection radius in metres
-- @return boolean  true if troops were unloaded
function CTLDTroopManager:unloadInProximityToEnemy(unitName, distance)
    local unit = Unit.getByName(unitName)
    if not unit or not unit:isExist() then return false end
    local player = unit:getPlayerName()
    if player and player ~= "" then return false end  -- AI only
    if not self:hasTroops(unitName) then return false end
    local enemy = CTLDJTACDetector.findNearestVisibleEnemy(unit, "all", distance)
    if not enemy then return false end
    return self:deploy(unit)
end

--- Start a recurring watcher counting dropped groups in a zone, writing DCS flags.
-- Reschedules every 5 seconds. Call once from a DO SCRIPT trigger.
-- @param zoneName string          DCS trigger zone name
-- @param blueFlag number|string   flag for BLUE group count (nil = skip)
-- @param redFlag  number|string   flag for RED group count (nil = skip)
function CTLDTroopManager:startGroupCountWatcher(zoneName, blueFlag, redFlag)
    local trig = trigger.misc.getZone(zoneName)
    if not trig then
        ctld.utils.log("ERROR", "CTLDTroopManager:startGroupCountWatcher — zone not found: %s", tostring(zoneName))
        return
    end
    local center = { x = trig.point.x, y = trig.point.y, z = trig.point.z }
    local radius = trig.radius
    local self_ref = self
    local function _tick()
        local blueCount, redCount = 0, 0
        for _, name in ipairs(self_ref._droppedGroups[coalition.side.BLUE] or {}) do
            local g = Group.getByName(name)
            if g and g:isExist() and #g:getUnits() > 0 then
                local u = g:getUnit(1)
                if u and ctld.utils.getDistance("groupWatcher", u:getPoint(), center) <= radius then
                    blueCount = blueCount + 1
                end
            end
        end
        for _, name in ipairs(self_ref._droppedGroups[coalition.side.RED] or {}) do
            local g = Group.getByName(name)
            if g and g:isExist() and #g:getUnits() > 0 then
                local u = g:getUnit(1)
                if u and ctld.utils.getDistance("groupWatcher", u:getPoint(), center) <= radius then
                    redCount = redCount + 1
                end
            end
        end
        if blueFlag then trigger.action.setUserFlag(blueFlag, blueCount) end
        if redFlag  then trigger.action.setUserFlag(redFlag,  redCount)  end
        timer.scheduleFunction(function()
            self_ref:startGroupCountWatcher(zoneName, blueFlag, redFlag)
        end, nil, timer.getTime() + 5)
    end
    _tick()
end

--- Start a recurring watcher counting dropped units in a zone, writing DCS flags.
-- @param zoneName string          DCS trigger zone name
-- @param blueFlag number|string   flag for BLUE unit count (nil = skip)
-- @param redFlag  number|string   flag for RED unit count (nil = skip)
function CTLDTroopManager:startUnitCountWatcher(zoneName, blueFlag, redFlag)
    local trig = trigger.misc.getZone(zoneName)
    if not trig then
        ctld.utils.log("ERROR", "CTLDTroopManager:startUnitCountWatcher — zone not found: %s", tostring(zoneName))
        return
    end
    local center = { x = trig.point.x, y = trig.point.y, z = trig.point.z }
    local radius = trig.radius
    local self_ref = self
    local function _tick()
        local blueCount, redCount = 0, 0
        for _, name in ipairs(self_ref._droppedGroups[coalition.side.BLUE] or {}) do
            local g = Group.getByName(name)
            if g and g:isExist() then
                for _, u in ipairs(g:getUnits()) do
                    if u:isExist() and ctld.utils.getDistance("unitWatcher", u:getPoint(), center) <= radius then
                        blueCount = blueCount + 1
                    end
                end
            end
        end
        for _, name in ipairs(self_ref._droppedGroups[coalition.side.RED] or {}) do
            local g = Group.getByName(name)
            if g and g:isExist() then
                for _, u in ipairs(g:getUnits()) do
                    if u:isExist() and ctld.utils.getDistance("unitWatcher", u:getPoint(), center) <= radius then
                        redCount = redCount + 1
                    end
                end
            end
        end
        if blueFlag then trigger.action.setUserFlag(blueFlag, blueCount) end
        if redFlag  then trigger.action.setUserFlag(redFlag,  redCount)  end
        timer.scheduleFunction(function()
            self_ref:startUnitCountWatcher(zoneName, blueFlag, redFlag)
        end, nil, timer.getTime() + 5)
    end
    _tick()
end
