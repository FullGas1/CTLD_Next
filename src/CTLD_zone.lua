-- ============================================================
-- CTLD_zone.lua
-- CTLDTroopZone + CTLDLogisticZone entities + CTLDZoneManager singleton
--
-- Dependencies : class (lib/class.lua), CTLDUtils (ctld.utils),
--                CTLDConfig (ctld.gs), EventDispatcher
-- DCS API      : env.mission.triggers.zones, trigger.misc.getZone,
--                trigger.action.smoke, trigger.action.setUserFlag,
--                trigger.misc.getUserFlag, land.getHeight,
--                Unit.getByName, StaticObject.getByName
--
-- Zone naming conventions:
--
--   TRZ  (TroopZone) — troops pickup / extract / mixed
--     TRZ_<name>_<A|R|B|N>_<stock>_<flag>_<target>   (all 5 fields required)
--     stock  : 0=no pickup, 1-998=limited, 999=unlimited
--     flag   : DCS flag name (string) or reserved word "nil"
--     target : 0=no win condition, N≥1=soldier threshold
--
--   LGZ  (LogisticZone) — crate/vehicle services
--     LGZ_name_[R|B|N]
--
-- Legacy fallback: missions using the old PKZ/IAZ/WPZ/EXZ prefix
-- or the ctld.gs config tables (pickupZones, dropOffZones, wpZones,
-- logisticUnits) are loaded after TRZ/LGZ discovery; existing entries
-- are never overwritten.
--
-- Events published:
--   OnZoneSmokeRefreshed  — every smokeRefreshInterval seconds
--   OnLogisticZoneUpdated — at init + on dynamic unit death
-- ============================================================

---@diagnostic disable
ctld = ctld or {}

-- ============================================================
-- CTLDTroopZone  (entity)
-- ============================================================

CTLDTroopZone = class()

--- Constructor.
-- @param data table
--   Required : dcsName, zoneName, coalition, center (vec3), radius
--   Optional : verticies, pickMaxStock, objectiveFlag, objectiveTarget,
--              smoke (trigger.smokeColor.* or -1), active,
--              isWaypoint (bool), isDropoff (bool),
--              isAIPickup (bool), isAIDropoff (bool)
function CTLDTroopZone:init(data)
    self.dcsName          = data.dcsName
    self.zoneName         = data.zoneName
    self.coalition        = data.coalition  or 0
    self.center           = data.center
    self.radius           = data.radius     or 0
    self.verticies        = data.verticies  or nil

    -- Pickup stock (nil = this zone has no pickup function for players)
    self.pickMaxStock     = data.pickMaxStock    -- nil | number  (0 = unlimited)
    self.pickCurrentStock = (data.pickMaxStock ~= nil and data.pickMaxStock ~= 0)
                            and data.pickMaxStock or 0
    -- Optional DCS flag name: mirrors pickCurrentStock to a mission flag when set.
    -- Legacy troopZones auto-derive it as zoneName.."_count" (e.g. "pickzone1_count").
    self.stockFlagName    = data.stockFlagName or nil

    -- Extract objective (nil = this zone has no extract function)
    self.objectiveFlag    = data.objectiveFlag   -- nil | string
    self.objectiveTarget  = data.objectiveTarget -- nil | number

    -- WPZ: troops deployed inside march to zone center
    self.isWaypoint  = data.isWaypoint  or false
    -- IAZ legacy: AI transport landing here auto-deploys its troops (isDropoff → hasDropoff)
    self.isDropoff   = data.isDropoff   or false
    -- IAZ v2: AI-only pickup / dropoff (not visible to player menus)
    self.isAIPickup  = data.isAIPickup  or false
    self.isAIDropoff = data.isAIDropoff or false
    -- Drop mode for AIZ_D zones: "G"=ground only, "P"=parachute only, "GP"=both (default)
    self.aiDropMode  = data.aiDropMode  or "GP"
    -- AIZ_P cargo type: "T"=troops only, "V"=vehicles only, "TV"=both (default "T")
    self.aiCargoType         = data.aiCargoType          or "T"
    self.pickMaxTroopStock   = data.pickMaxTroopStock    -- nil | number (0=unlimited)
    self.pickMaxVehicleStock = data.pickMaxVehicleStock  -- nil | number (0=unlimited)
    self.pickCurrentVehicleStock = (data.pickMaxVehicleStock and data.pickMaxVehicleStock > 0)
                                   and data.pickMaxVehicleStock or nil
    -- Feature S: AIZ config-only fields
    -- troopTemplates: nil/{}=all compatible templates ; {name,...}=strict whitelist
    self.troopTemplates      = data.troopTemplates  or nil
    -- vehicleTypes: nil=all DCS vehicles present in zone ; {typeName,...}=whitelist
    self.vehicleTypes        = data.vehicleTypes    or nil
    -- Feature T: per-template/per-type stock tables
    -- _aiTroopStock   = nil | { isAll=bool, init={name=N}, current={name=N} }
    -- _aiVehicleStock = nil | { isAll=bool, init={type=N}, current={type=N} }
    self._aiTroopStock   = data._aiTroopStock   or nil
    self._aiVehicleStock = data._aiVehicleStock or nil

    self.smoke  = (data.smoke ~= nil) and data.smoke or -1
    self.active = (data.active ~= nil) and data.active or true
end

--- True if this zone acts as a pickup zone (troops can board here).
function CTLDTroopZone:hasPickup()
    return self.pickMaxStock ~= nil
end

--- True if this zone acts as an extract / objective zone.
function CTLDTroopZone:hasExtract()
    return self.objectiveFlag ~= nil
end

--- True if this zone redirects deployed troops toward its center (WPZ).
function CTLDTroopZone:hasWaypoint()
    return self.isWaypoint == true
end

--- True if this zone is an AI auto-drop point (IAZ legacy).
function CTLDTroopZone:hasDropoff()
    return self.isDropoff == true
end

--- True if this zone is an AI-exclusive pickup point (IAZ v2 P role).
function CTLDTroopZone:hasAIPickup()
    return self.isAIPickup == true
end

--- True if this zone is an AI-exclusive dropoff point (IAZ v2 D role).
function CTLDTroopZone:hasAIDropoff()
    return self.isAIDropoff == true
end

--- True if point is inside the zone (circular or polygonal).
function CTLDTroopZone:isInZone(point)
    if self.verticies and #self.verticies >= 3 then
        return CTLDTroopZone._raycast(point, self.verticies)
    end
    return ctld.utils.getDistance("CTLDTroopZone:isInZone", point, self.center) <= self.radius
end

--- Jordan ray-casting for polygonal zones.
-- verticies[i].x / .y are mission-file coordinates (mission Y = world Z).
function CTLDTroopZone._raycast(point, verts)
    local px, pz = point.x, point.z
    local inside = false
    local n = #verts
    local j = n
    for i = 1, n do
        local xi, zi = verts[i].x, verts[i].y
        local xj, zj = verts[j].x, verts[j].y
        if ((zi > pz) ~= (zj > pz)) and
           (px < (xj - xi) * (pz - zi) / (zj - zi) + xi) then
            inside = not inside
        end
        j = i
    end
    return inside
end

--- Sync pickCurrentStock to the DCS flag (stockFlagName), if set.
function CTLDTroopZone:_syncStockFlag()
    if self.stockFlagName then
        trigger.action.setUserFlag(self.stockFlagName, self.pickCurrentStock)
    end
end

--- Consume n troops from pickup stock. Returns true on success.
-- Unlimited stock (pickMaxStock == 0) always succeeds.
-- @param n number   troops to consume
-- @return boolean
function CTLDTroopZone:consumeStock(n)
    if not self:hasPickup() then return false end
    if self.pickMaxStock == 0 then return true end  -- unlimited
    if self.pickCurrentStock < n then return false end
    self.pickCurrentStock = self.pickCurrentStock - n
    self:_syncStockFlag()
    return true
end

--- Restore n troops to pickup stock (capped at pickMaxStock).
-- No-op for unlimited or non-pickup zones.
-- @param n number
function CTLDTroopZone:restoreStock(n)
    if not self:hasPickup() or self.pickMaxStock == 0 then return end
    self.pickCurrentStock = math.min(self.pickMaxStock, self.pickCurrentStock + n)
    self:_syncStockFlag()
end

-- ────────────────────────────────────────────────────────────────────────────
-- Feature T: per-template / per-type AI stock management
-- ────────────────────────────────────────────────────────────────────────────

--- AI troop pickup: pick the best template from available stock respecting capacity.
-- Returns a template table or nil if none eligible.
-- @param teams    table   list of template tables (from _aiTeams[coa])
-- @param typeName string  DCS type of the transport (for _canEmbark)
-- @param unitName string  unit name (for _canEmbark)
-- @param tm       CTLDTroopManager instance
function CTLDTroopZone:aiPickTroopTemplate(teams, typeName, unitName, tm)
    local stock = self._aiTroopStock
    if not stock then return nil end  -- no per-template stock; caller falls back to legacy path
    local eligible = {}
    for _, tmpl in ipairs(teams) do
        local s
        if stock.isAll then
            s = math.huge
        else
            local raw = stock.current[tmpl.name]
            if raw == nil then
                s = nil  -- not in stock → ineligible
            elseif raw == -1 then
                s = math.huge
            else
                s = raw
            end
        end
        if s and s > 0 then
            local w = tm:_weightForGroup(tmpl)
            local canEmb = tm:_canEmbark(typeName, unitName, tmpl.total, w)
            if canEmb then
                eligible[#eligible + 1] = { tmpl = tmpl, stock = s }
            end
        end
    end
    if #eligible == 0 then return nil end
    -- C: prefer templates with highest current stock; random among ex-aequo
    local maxS = 0
    for _, e in ipairs(eligible) do if e.stock > maxS then maxS = e.stock end end
    local top = {}
    for _, e in ipairs(eligible) do if e.stock == maxS then top[#top + 1] = e.tmpl end end
    return top[math.random(#top)]
end

--- Consume 1 troop stock unit for the given template name.
-- No-op if isAll or template not in stock.
-- @param templateName string
function CTLDTroopZone:aiConsumeTroopStock(templateName)
    local stock = self._aiTroopStock
    if not stock or stock.isAll then return end
    local s = stock.current[templateName]
    if s and s > 0 then stock.current[templateName] = s - 1 end
end

--- Restore n units to troop stock for the given template name (capped at init).
-- @param templateName string
-- @param n            number  (default 1)
function CTLDTroopZone:aiRestoreTroopStock(templateName, n)
    local stock = self._aiTroopStock
    if not stock or stock.isAll then return end
    local maxS = stock.init[templateName]
    if not maxS or maxS == -1 then return end
    local cur = stock.current[templateName] or 0
    stock.current[templateName] = math.min(maxS, cur + (n or 1))
end

--- AI vehicle pickup: pick the best entry from vehicle stock.
-- Returns { type=string, isScene=bool, isAASystem=bool } or nil.
-- nil means caller should use legacy physical-scan path (isAll) or no stock defined.
-- Priority: CTLDSceneManager (isScene=true) > CTLDCrateAssemblyManager (isAASystem=true) > DCS native.
function CTLDTroopZone:aiPickVehicleEntry()
    local stock = self._aiVehicleStock
    if not stock then return nil end
    if stock.isAll then return nil end  -- isAll → physical scan (legacy path)
    local sm  = CTLDSceneManager.getInstance()
    local aam = CTLDCrateAssemblyManager.getInstance()
    local eligible = {}
    for typeName, s in pairs(stock.current) do
        local avail = (s == -1) and math.huge or s
        if avail > 0 then
            local isScene    = sm:getModel(typeName) ~= nil
            local isAASystem = not isScene and (aam:getTemplateByName(typeName) ~= nil)
            eligible[#eligible + 1] = {
                type      = typeName,
                stock     = avail,
                isScene   = isScene,
                isAASystem = isAASystem,
            }
        end
    end
    if #eligible == 0 then return nil end
    local maxS = 0
    for _, e in ipairs(eligible) do if e.stock > maxS then maxS = e.stock end end
    local top = {}
    for _, e in ipairs(eligible) do if e.stock == maxS then top[#top + 1] = e end end
    local picked = top[math.random(#top)]
    return { type = picked.type, isScene = picked.isScene, isAASystem = picked.isAASystem }
end

--- Consume 1 vehicle stock for the given type name.
-- No-op if isAll or type not in stock.
-- @param typeName string
function CTLDTroopZone:aiConsumeVehicleStock(typeName)
    local stock = self._aiVehicleStock
    if not stock or stock.isAll then return end
    local s = stock.current[typeName]
    if s and s > 0 then stock.current[typeName] = s - 1 end
end

--- Restore 1 vehicle stock for the given type name (capped at init).
-- @param typeName string
function CTLDTroopZone:aiRestoreVehicleStock(typeName)
    local stock = self._aiVehicleStock
    if not stock or stock.isAll then return end
    local maxS = stock.init[typeName]
    if not maxS or maxS == -1 then return end
    local cur = stock.current[typeName] or 0
    stock.current[typeName] = math.min(maxS, cur + 1)
end

--- Increment the objective flag by soldierCount and check win condition.
-- @param soldierCount number
-- @return boolean incremented, number valueBefore, number valueAfter
function CTLDTroopZone:incrementObjective(soldierCount)
    if not self.objectiveFlag then return false, 0, 0 end
    local before = trigger.misc.getUserFlag(self.objectiveFlag)
    local after  = before + soldierCount
    trigger.action.setUserFlag(self.objectiveFlag, after)
    if self.objectiveTarget and after >= self.objectiveTarget then
        ctld.utils.log("INFO", "CTLDTroopZone: objective '%s' COMPLETE (%d/%d)",
            self.objectiveFlag, after, self.objectiveTarget)
    end
    return true, before, after
end

function CTLDTroopZone:getCenter() return self.center end
function CTLDTroopZone:activate()   self.active = true  end
function CTLDTroopZone:deactivate() self.active = false end


-- ============================================================
-- CTLDLogisticZone  (entity)
-- ============================================================

CTLDLogisticZone = class()

--- Constructor.
-- @param data table
--   Required : name, coalition, center (vec3), radius
--   Optional : linkedUnit (Unit — dynamic zone follows this unit),
--              active, services table
function CTLDLogisticZone:init(data)
    self.name        = data.name
    self.coalition   = data.coalition or 0
    self._center     = data.center
    self.radius      = data.radius   or 200
    self._linkedUnit = data.linkedUnit or nil
    self.active      = (data.active ~= nil) and data.active or true
    self.services    = data.services or {
        cratesPickup  = true,
        cratesDropoff = true,
        vehicleSpawn  = true,
    }
end

--- Return current center. Dynamic zones follow their linked unit.
function CTLDLogisticZone:getCenter()
    if self._linkedUnit and self._linkedUnit:isExist() then
        return self._linkedUnit:getPoint()
    end
    return self._center
end

--- True if this zone is anchored to a moving DCS unit.
function CTLDLogisticZone:isDynamic()
    return self._linkedUnit ~= nil
end

--- True if the linked unit is still alive (always true for static zones).
function CTLDLogisticZone:isAlive()
    if not self._linkedUnit then return true end
    return self._linkedUnit:isExist()
end

--- True if point is inside the zone (circular only — logistic zones are always circular).
function CTLDLogisticZone:isInZone(point)
    return ctld.utils.getDistance("CTLDLogisticZone:isInZone", point, self:getCenter()) <= self.radius
end

function CTLDLogisticZone:activate()   self.active = true  end
function CTLDLogisticZone:deactivate() self.active = false end


-- ============================================================
-- CTLDZoneManager  (singleton)
-- ============================================================

CTLDZoneManager = class()
CTLDZoneManager._instance = nil

local _TROOP_SMOKE_COLOR = {
    [0] = trigger.smokeColor.Green,
    [1] = trigger.smokeColor.Red,
    [2] = trigger.smokeColor.White,
    [3] = trigger.smokeColor.Orange,
    [4] = trigger.smokeColor.Blue,
}
-- Legacy smoke string to number
local _LEGACY_SMOKE_STR = { green=0, red=1, white=2, orange=3, blue=4 }

--- Return (or create) the singleton instance.
-- Triggers full init (discovery + legacy load + smoke schedule + bridge registration).
function CTLDZoneManager.getInstance()
    if not CTLDZoneManager._instance then
        local o = setmetatable({}, CTLDZoneManager)
        o:init()
        CTLDZoneManager._instance = o
    end
    return CTLDZoneManager._instance
end

function CTLDZoneManager:init()
    self._troopZones    = {}   -- zoneName -> CTLDTroopZone
    self._logisticZones = {}   -- name     -> CTLDLogisticZone

    -- Register S_EVENT_DEAD for dynamic logistic zone tracking
    local ok, bridge = pcall(CTLDDCSEventBridge.getInstance)
    if ok and bridge then
        bridge:register(self, world.event.S_EVENT_DEAD, "onDead")
    end

    self:_validateZoneNames()
    self:_discoverTRZ()
    self:_loadAIZonesFromConfig()
    self:_discoverWPZ()
    self:_discoverLGZ()
    self:_loadLegacyZones()
    self:_scheduleSmoke()

    -- Publish initial state
    self:_publishLogisticZoneUpdated({}, {})

    ctld.utils.log("INFO",
        "CTLDZoneManager ready — troop:%d logistic:%d",
        self:_count(self._troopZones), self:_count(self._logisticZones))
end

-- ============================================================
-- Helpers
-- ============================================================

local function _split(str, sep)
    local parts = {}
    for p in string.gmatch(str, "[^" .. sep .. "]+") do
        parts[#parts + 1] = p
    end
    return parts
end

local function _buildCenter(zd)
    local x = zd.x
    local z = zd.y   -- mission-file Y = world Z
    local y = land.getHeight({ x = x, y = z })
    return { x = x, y = y, z = z }
end

function CTLDZoneManager:_count(tbl)
    local n = 0
    for _ in pairs(tbl) do n = n + 1 end
    return n
end

-- ============================================================
-- TRZ parser
-- ============================================================

-- Parse TRZ_<name>_<A|R|B|N>_<stock>_<flag>_<target>   strict positional, all 5 fields required.
-- stock  : integer 0-999  — 0=no pickup (nil), 999=unlimited (internal 0), 1-998=limited
-- flag   : string or reserved word "nil" (= no objective flag)
-- target : integer ≥0     — 0=no win condition (nil), N≥1=soldier threshold
-- Returns a table on success, nil + error string on failure.
function CTLDZoneManager:_parseTRZ(name)
    local parts = _split(name, "_")
    if parts[1] ~= "TRZ" then return nil, "not a TRZ" end

    -- field 2: zoneName (required, not a reserved word)
    local zoneName = parts[2]
    if not zoneName or zoneName == "" then return nil, "missing zoneName" end
    local _reserved = { ["nil"]=true, A=true, R=true, B=true, N=true }
    if _reserved[zoneName] then
        return nil, "zoneName cannot be a reserved word: " .. zoneName
    end

    -- field 3: coalition (required — A=all, R=RED, B=BLUE, N=NEUTRAL)
    local coalStr = parts[3]
    if not coalStr then return nil, "missing coalition (A|R|B|N)" end
    local coalitionId
    if     coalStr == "A" then coalitionId = 0
    elseif coalStr == "R" then coalitionId = coalition.side.RED
    elseif coalStr == "B" then coalitionId = coalition.side.BLUE
    elseif coalStr == "N" then coalitionId = coalition.side.NEUTRAL
    else return nil, "invalid coalition '" .. coalStr .. "' — expected A, R, B or N" end

    -- field 4: stock (required, integer 0-999)
    local stockStr = parts[4]
    local stockRaw = tonumber(stockStr)
    if not stockRaw or math.floor(stockRaw) ~= stockRaw or stockRaw < 0 or stockRaw > 999 then
        return nil, "invalid stock '" .. tostring(stockStr) .. "' — expected integer 0-999 (0=no pickup, 999=unlimited)"
    end
    local pickMaxStock
    if     stockRaw == 0   then pickMaxStock = nil  -- no pickup capability
    elseif stockRaw == 999 then pickMaxStock = 0    -- unlimited (internal 0)
    else                        pickMaxStock = stockRaw
    end

    -- field 5: flag (required, string or reserved word "nil")
    local flagStr = parts[5]
    if not flagStr then return nil, "missing flag (DCS flag name or 'nil')" end
    if tonumber(flagStr) then
        return nil, "flag must be a string or 'nil', not a number"
    end
    local objectiveFlag
    if flagStr ~= "nil" then objectiveFlag = flagStr end

    -- field 6: target (required, integer ≥0)
    local targetStr = parts[6]
    local targetRaw = tonumber(targetStr)
    if not targetRaw or math.floor(targetRaw) ~= targetRaw or targetRaw < 0 then
        return nil, "invalid target '" .. tostring(targetStr) .. "' — expected integer ≥0 (0=no win condition)"
    end
    local objectiveTarget
    if targetRaw > 0 then objectiveTarget = targetRaw end

    return {
        zoneName        = zoneName,
        coalition       = coalitionId,
        pickMaxStock    = pickMaxStock,
        objectiveFlag   = objectiveFlag,
        objectiveTarget = objectiveTarget,
    }
end

-- Parse LGZ_name_[R|B|N]
function CTLDZoneManager:_parseLGZ(name)
    local parts = _split(name, "_")
    if parts[1] ~= "LGZ" then return nil end
    local lgzName     = parts[2]
    local coalitionId = 0
    if     parts[3] == "R" then coalitionId = coalition.side.RED
    elseif parts[3] == "B" then coalitionId = coalition.side.BLUE
    elseif parts[3] == "N" then coalitionId = coalition.side.NEUTRAL end
    return { name = lgzName, coalition = coalitionId }
end

-- Parse AIZ_name_[R|B|N]  (AI auto-drop zone)
-- Parse WPZ_name_[R|B|N]  (waypoint zone — troops march to center)
-- Shared logic: prefix must match, second field = zoneName, optional third = coalition.
local function _parseSimpleZone(prefix, name)
    local parts = _split(name, "_")
    if parts[1] ~= prefix then return nil, "wrong prefix" end
    local zoneName = parts[2]
    if not zoneName then return nil, "missing zoneName" end
    local coalitionId = 0
    if     parts[3] == "R" then coalitionId = coalition.side.RED
    elseif parts[3] == "B" then coalitionId = coalition.side.BLUE
    elseif parts[3] == "N" then coalitionId = coalition.side.NEUTRAL end
    return { zoneName = zoneName, coalition = coalitionId }
end

function CTLDZoneManager:_parseWPZ(name) return _parseSimpleZone("WPZ", name) end

-- ============================================================
-- Discovery
-- ============================================================

function CTLDZoneManager:_discoverTRZ()
    if not (env.mission and env.mission.triggers and env.mission.triggers.zones) then
        ctld.utils.log("WARN", "CTLDZoneManager: env.mission.triggers.zones not accessible")
        return
    end
    for _, zd in pairs(env.mission.triggers.zones) do
        local name = zd.name or ""
        if string.sub(name, 1, 4) == "TRZ_" then
            local parsed, err = self:_parseTRZ(name)
            if not parsed then
                ctld.utils.log("WARN", "CTLDZoneManager: cannot parse TRZ '%s': %s", name, tostring(err))
            elseif not self._troopZones[parsed.zoneName] then
                local zone = CTLDTroopZone:new({
                    dcsName        = name,
                    zoneName       = parsed.zoneName,
                    coalition      = parsed.coalition,
                    center         = _buildCenter(zd),
                    radius         = zd.radius or 500,
                    verticies      = zd.verticies or nil,
                    pickMaxStock   = parsed.pickMaxStock,
                    objectiveFlag  = parsed.objectiveFlag,
                    objectiveTarget= parsed.objectiveTarget,
                    smoke          = ctld.gs("troopZoneSmokeColor") and
                                     ctld.gs("troopZoneSmokeColor")[parsed.coalition] or -1,
                    active         = true,
                })
                if zone.objectiveFlag then
                    trigger.action.setUserFlag(zone.objectiveFlag, 0)
                end
                self._troopZones[parsed.zoneName] = zone
                ctld.utils.log("INFO",
                    "CTLDZoneManager: TRZ '%s' coalition=%d stock=%s flag=%s target=%s",
                    parsed.zoneName, parsed.coalition,
                    tostring(parsed.pickMaxStock), tostring(parsed.objectiveFlag),
                    tostring(parsed.objectiveTarget))
            end
        end
    end
end

function CTLDZoneManager:_discoverLGZ()
    if not (env.mission and env.mission.triggers and env.mission.triggers.zones) then return end
    for _, zd in pairs(env.mission.triggers.zones) do
        local name = zd.name or ""
        if string.sub(name, 1, 4) == "LGZ_" then
            local parsed = self:_parseLGZ(name)
            if parsed and not self._logisticZones[parsed.name] then
                local zone = CTLDLogisticZone:new({
                    name      = parsed.name,
                    coalition = parsed.coalition,
                    center    = _buildCenter(zd),
                    radius    = ctld.gs("dynamicZoneRadius") or 200,
                    active    = true,
                })
                self._logisticZones[parsed.name] = zone
                ctld.utils.log("INFO", "CTLDZoneManager: LGZ '%s' coalition=%d",
                    parsed.name, parsed.coalition)
            end
        end
    end
end

--- Feature S/T: Load AI zones from cfg.settings["aiZones"] config table.
-- troopStock / vehicleStock must be tables: { [name] = N } where N=-1=unlimited, N>0=limited.
-- Special key "All" = all templates/types, unlimited (isAll=true).
-- Validation errors/warns are accumulated in _validateZoneNames; this method only creates valid zones.
function CTLDZoneManager:_loadAIZonesFromConfig()
    local entries = ctld.gs("aiZones")
    if not entries or #entries == 0 then return end
    local skip = self._aiZoneErrors or {}

    local function parseStockTable(raw)
        -- raw must be a table {[name]=N}; returns { isAll, init, current } or nil
        if type(raw) ~= "table" then return nil end
        local isAll = false
        local init  = {}
        for k, v in pairs(raw) do
            if k == "All" then
                isAll = true
            else
                local n = tonumber(v)
                init[k] = (n == -1) and -1 or math.max(0, n or 0)
            end
        end
        local current = {}
        if not isAll then
            for k, v in pairs(init) do current[k] = v end
        end
        return { isAll = isAll, init = init, current = current }
    end

    for _, entry in ipairs(entries) do
        local dzn = entry.dcsZoneName
        if dzn and not skip[dzn] and not self._troopZones[dzn] then
            local trig = trigger.misc.getZone(dzn)
            if not trig then
                ctld.utils.log("WARN", "CTLDZoneManager: aiZones '%s' not found in ME — skipped", dzn)
            else
                local coaStr = entry.coalition or ""
                local coaId
                if     coaStr == "RED"     then coaId = coalition.side.RED
                elseif coaStr == "BLUE"    then coaId = coalition.side.BLUE
                elseif coaStr == "NEUTRAL" then coaId = coalition.side.NEUTRAL
                else coaId = 0 end

                local aiTroopStock   = parseStockTable(entry.troopStock)
                local aiVehicleStock = parseStockTable(entry.vehicleStock)

                -- pickMaxStock=0 (unlimited) so embarkFromTroopZone never blocks on stock;
                -- per-template stock is managed by _aiTroopStock.
                local troopTemplates = (entry.troopTemplates and #entry.troopTemplates > 0)
                                       and entry.troopTemplates or nil

                local zone = CTLDTroopZone:new({
                    dcsName          = dzn,
                    zoneName         = dzn,
                    coalition        = coaId,
                    center           = { x = trig.point.x, y = trig.point.y, z = trig.point.z },
                    radius           = trig.radius or 500,
                    isAIPickup       = entry.isPickup  == true,
                    isAIDropoff      = entry.isDropoff == true,
                    aiCargoType      = entry.cargoType or "T",
                    pickMaxStock     = 0,  -- unlimited; per-template stock via _aiTroopStock
                    troopTemplates   = troopTemplates,
                    vehicleTypes     = (entry.vehicleTypes and #entry.vehicleTypes > 0)
                                       and entry.vehicleTypes or nil,
                    aiDropMode       = (entry.aiDropMode == "G" or entry.aiDropMode == "P"
                                        or entry.aiDropMode == "GP") and entry.aiDropMode or "GP",
                    _aiTroopStock    = aiTroopStock,
                    _aiVehicleStock  = aiVehicleStock,
                    active           = true,
                })
                self._troopZones[dzn] = zone

                local tsLog = aiTroopStock
                    and (aiTroopStock.isAll and "All" or table.concat(
                        (function() local t={} for k,v in pairs(aiTroopStock.init) do t[#t+1]=k.."="..tostring(v) end return t end)(), ","))
                    or "none"
                local vsLog = aiVehicleStock
                    and (aiVehicleStock.isAll and "All" or table.concat(
                        (function() local t={} for k,v in pairs(aiVehicleStock.init) do t[#t+1]=k.."="..tostring(v) end return t end)(), ","))
                    or "none"
                ctld.utils.log("INFO",
                    "CTLDZoneManager: aiZones '%s' coa=%s P=%s D=%s cargo=%s troops={%s} vehicles={%s}",
                    dzn, coaStr,
                    tostring(entry.isPickup == true),
                    tostring(entry.isDropoff == true),
                    tostring(entry.cargoType or "T"),
                    tsLog, vsLog)
            end
        end
    end
    self._aiZoneErrors = nil
end

function CTLDZoneManager:_discoverWPZ()
    if not (env.mission and env.mission.triggers and env.mission.triggers.zones) then return end
    for _, zd in pairs(env.mission.triggers.zones) do
        local name = zd.name or ""
        if string.sub(name, 1, 4) == "WPZ_" then
            local parsed, err = self:_parseWPZ(name)
            if not parsed then
                ctld.utils.log("WARN", "CTLDZoneManager: cannot parse WPZ '%s': %s", name, tostring(err))
            elseif not self._troopZones[parsed.zoneName] then
                local zone = CTLDTroopZone:new({
                    dcsName    = name,
                    zoneName   = parsed.zoneName,
                    coalition  = parsed.coalition,
                    center     = _buildCenter(zd),
                    radius     = zd.radius or 500,
                    verticies  = zd.verticies or nil,
                    isWaypoint = true,
                    active     = true,
                })
                self._troopZones[parsed.zoneName] = zone
                ctld.utils.log("INFO", "CTLDZoneManager: WPZ '%s' coalition=%d",
                    parsed.zoneName, parsed.coalition)
            end
        end
    end
end

-- ============================================================
-- Legacy fallback
-- ============================================================

function CTLDZoneManager:_loadLegacyZones()

    -- troopZones → CTLDTroopZone (player pickup only — not visible to AI)
    -- Supports both DCS trigger zones and ship unit names (mobile pickup point).
    for _, zd in pairs(ctld.gs("troopZones") or {}) do
        if not self._troopZones[zd[1]] then
            local smoke = -1
            if zd[2] then
                local n = tonumber(_LEGACY_SMOKE_STR[zd[2]] or zd[2])
                smoke = _TROOP_SMOKE_COLOR[n] or -1
            end
            local stock  = (zd[3] == -1 or zd[3] == nil) and 0 or tonumber(zd[3])
            local active = (zd[4] == "yes" or zd[4] == 1)
            local coal   = tonumber(zd[5]) or 0

            local trig = trigger.misc.getZone(zd[1])
            if trig then
                self._troopZones[zd[1]] = CTLDTroopZone:new({
                    dcsName       = zd[1], zoneName = zd[1],
                    coalition     = coal,
                    center        = { x=trig.point.x, y=trig.point.y, z=trig.point.z },
                    radius        = trig.radius,
                    pickMaxStock  = stock,
                    smoke         = smoke,
                    active        = active,
                    stockFlagName = zd[1] .. "_count",
                })
            else
                -- Fallback: ship unit name — snapshot position at init
                local ship = Unit.getByName(zd[1])
                if ship and ship:isExist() then
                    local pt = ship:getPoint()
                    local r  = ctld.gs("maximumDistancePackableUnitsSearch") or 200
                    self._troopZones[zd[1]] = CTLDTroopZone:new({
                        dcsName       = zd[1], zoneName = zd[1],
                        coalition     = coal,
                        center        = { x=pt.x, y=pt.y, z=pt.z },
                        radius        = r,
                        pickMaxStock  = stock,
                        smoke         = smoke,
                        active        = active,
                        stockFlagName = zd[1] .. "_count",
                    })
                end
            end
        end
    end

    -- wpZones → CTLDTroopZone (waypoint: troops march to center)
    for _, zd in pairs(ctld.gs("wpZones") or {}) do
        local trig = trigger.misc.getZone(zd[1])
        if trig and not self._troopZones[zd[1]] then
            local smoke = -1
            if zd[2] then
                local n = tonumber(_LEGACY_SMOKE_STR[zd[2]] or zd[2])
                smoke = _TROOP_SMOKE_COLOR[n] or -1
            end
            self._troopZones[zd[1]] = CTLDTroopZone:new({
                dcsName    = zd[1], zoneName = zd[1],
                coalition  = tonumber(zd[4]) or 0,
                center     = { x=trig.point.x, y=trig.point.y, z=trig.point.z },
                radius     = trig.radius,
                isWaypoint = true,
                smoke      = smoke,
                active     = (zd[3] == "yes" or zd[3] == 1),
            })
        end
    end

    -- logisticUnits → CTLDLogisticZone (dynamic, linked to unit/static)
    local maxDist = ctld.gs("maximumDistanceLogistic") or 500
    local added, removed = {}, {}
    for _, unitName in pairs(ctld.gs("logisticUnits") or {}) do
        if not self._logisticZones[unitName] then
            local obj = StaticObject.getByName(unitName) or Unit.getByName(unitName)
            if obj then
                local coal = obj:getCoalition()
                self._logisticZones[unitName] = CTLDLogisticZone:new({
                    name        = unitName,
                    coalition   = coal,
                    center      = obj:getPoint(),
                    radius      = maxDist,
                    linkedUnit  = obj,
                    active      = true,
                })
                added[#added + 1] = { unitName = unitName, coalition = coal }
                ctld.utils.log("INFO", "CTLDZoneManager: logistic unit '%s'", unitName)
            else
                ctld.utils.log("WARN",
                    "CTLDZoneManager: logisticUnits '%s' not found in mission", unitName)
            end
        end
    end
    if #added > 0 then
        self:_publishLogisticZoneUpdated(added, removed)
    end
end

-- ============================================================
-- Smoke scheduler
-- ============================================================

function CTLDZoneManager:_scheduleSmoke()
    local interval = ctld.gs("smokeRefreshInterval") or 300
    local self_ref = self

    local function refresh()
        if ctld.gs("disableAllSmoke") == true then
            timer.scheduleFunction(refresh, nil, timer.getTime() + interval)
            return
        end

        local tZoneData, lZoneData = {}, {}

        -- Smoke troop zones
        for _, zone in pairs(self_ref._troopZones) do
            if zone.active and zone.smoke and zone.smoke >= 0 then
                trigger.action.smoke(zone.center, zone.smoke)
                tZoneData[#tZoneData + 1] = {
                    fullName        = zone.dcsName,
                    zoneName        = zone.zoneName,
                    coalition       = zone.coalition,
                    position        = zone.center,
                    radius          = zone.radius,
                    hasPickup       = zone:hasPickup(),
                    hasExtract      = zone:hasExtract(),
                    pickMaxStock    = zone.pickMaxStock,
                    pickCurrentStock= zone.pickCurrentStock,
                    objectiveFlag   = zone.objectiveFlag,
                    objectiveTarget = zone.objectiveTarget,
                    objectiveCurrent= zone.objectiveFlag
                                      and trigger.misc.getUserFlag(zone.objectiveFlag) or nil,
                    smokeColor      = zone.smoke,
                }
            end
        end

        -- Smoke logistic zones (optional per config)
        for _, zone in pairs(self_ref._logisticZones) do
            if zone.active then
                local smokeColors = ctld.gs("logisticZoneSmokeColor")
                local color = smokeColors and smokeColors[zone.coalition]
                if color then
                    trigger.action.smoke(zone:getCenter(), color)
                end
                lZoneData[#lZoneData + 1] = {
                    name       = zone.name,
                    coalition  = zone.coalition,
                    position   = zone:getCenter(),
                    radius     = zone.radius,
                    type       = zone:isDynamic() and "dynamic" or "static",
                    linkedUnit = zone._linkedUnit,
                    smokeColor = color,
                }
            end
        end

        EventDispatcher.getInstance():publish("OnZoneSmokeRefreshed", {
            troopZones    = tZoneData,
            logisticZones = lZoneData,
            timestamp     = timer.getAbsTime(),
            refreshInterval = interval,
        })

        timer.scheduleFunction(refresh, nil, timer.getTime() + interval)
    end

    timer.scheduleFunction(refresh, nil, timer.getTime() + interval)
end

-- ============================================================
-- Events
-- ============================================================

function CTLDZoneManager:_publishLogisticZoneUpdated(added, removed)
    local zones = {}
    for _, zone in pairs(self._logisticZones) do
        zones[#zones + 1] = {
            name       = zone.name,
            type       = "logistic",
            linkedUnit = zone._linkedUnit,
            position   = zone:getCenter(),
            coalition  = zone.coalition,
            radius     = zone.radius,
            services   = zone.services,
        }
    end
    EventDispatcher.getInstance():publish("OnLogisticZoneUpdated", {
        zones        = zones,
        unitsAdded   = added,
        unitsRemoved = removed,
        timestamp    = timer.getAbsTime(),
    })
end

--- S_EVENT_DEAD: remove dynamic logistic zones whose linked unit died.
function CTLDZoneManager:onDead(event)
    local unit = event.initiator
    if not unit then return end
    local unitName = unit:getName()
    local zone = self._logisticZones[unitName]
    if zone and zone:isDynamic() then
        self._logisticZones[unitName] = nil
        ctld.utils.log("INFO", "CTLDZoneManager: dynamic logistic zone '%s' removed (unit dead)", unitName)
        self:_publishLogisticZoneUpdated({}, { { unitName = unitName, coalition = zone.coalition, reason = "dead" } })
    end
end

-- ============================================================
-- Dynamic registration (FOB, external callers)
-- ============================================================

--- Register a deployed FOB as a logistic zone.
-- @param fobName   string
-- @param point     vec3
-- @param radius    number  (default 150)
-- @param coalitionId number
function CTLDZoneManager:registerFOBAsLogistic(fobName, point, radius, coalitionId)
    local zone = CTLDLogisticZone:new({
        name      = fobName,
        coalition = coalitionId or 0,
        center    = point,
        radius    = radius or 150,
        active    = true,
    })
    self._logisticZones[fobName] = zone
    ctld.utils.log("INFO", "CTLDZoneManager: FOB logistic zone '%s' r=%dm", fobName, radius or 150)
    self:_publishLogisticZoneUpdated({ { unitName = fobName, coalition = coalitionId } }, {})
end

--- Remove a logistic zone (e.g. FOB destroyed).
function CTLDZoneManager:unregisterLogistic(name)
    local zone = self._logisticZones[name]
    if zone then
        self._logisticZones[name] = nil
        ctld.utils.log("INFO", "CTLDZoneManager: logistic zone '%s' unregistered", name)
        self:_publishLogisticZoneUpdated({}, { { unitName = name, coalition = zone.coalition, reason = "removed" } })
    end
end

--- Deactivate a logistic zone by name (reversible — simulates capture or temporary loss).
-- Works for both LGZ_ trigger zones and logisticUnits-based zones.
-- Deactivated zones are ignored by all getters until reactivated.
-- @param name  string   zone name (as registered in _logisticZones)
function CTLDZoneManager:deactivateLogisticZone(name)
    local zone = self._logisticZones[name]
    if not zone then
        ctld.utils.log("WARN", "CTLDZoneManager:deactivateLogisticZone — zone '%s' not found", name)
        return
    end
    zone:deactivate()
    ctld.utils.log("INFO", "CTLDZoneManager: logistic zone '%s' deactivated", name)
    self:_publishLogisticZoneUpdated({}, { { unitName = name, coalition = zone.coalition, reason = "deactivated" } })
end

--- Reactivate a previously deactivated logistic zone.
-- @param name  string
function CTLDZoneManager:activateLogisticZone(name)
    local zone = self._logisticZones[name]
    if not zone then
        ctld.utils.log("WARN", "CTLDZoneManager:activateLogisticZone — zone '%s' not found", name)
        return
    end
    zone:activate()
    ctld.utils.log("INFO", "CTLDZoneManager: logistic zone '%s' activated", name)
    self:_publishLogisticZoneUpdated({ { unitName = name, coalition = zone.coalition } }, {})
end

-- ============================================================
-- Query API — TroopZones
-- ============================================================

--- Return CTLDTroopZone by zoneName, or nil.
function CTLDZoneManager:getTroopZone(zoneName)
    return self._troopZones[zoneName]
end

--- Return all active troop zones matching coalition (0 = both).
-- @param coalition  number   coalition.side.*
-- @return table of CTLDTroopZone
function CTLDZoneManager:getTroopZonesForCoalition(coalition)
    local result = {}
    for _, zone in pairs(self._troopZones) do
        if zone.active and (zone.coalition == coalition or zone.coalition == 0) then
            result[#result + 1] = zone
        end
    end
    return result
end

--- Return the troop zone containing point, or nil.
-- AI-only pickup zones (isAIPickup) are excluded — use getAIPickupZoneAt for AI logic.
-- @param point     vec3
-- @param coalition number  (0 = accept all)
-- @return CTLDTroopZone or nil
function CTLDZoneManager:getTroopZoneAtPoint(point, coalition)
    for _, zone in pairs(self._troopZones) do
        if zone.active and not zone.isAIPickup
        and (coalition == 0 or zone.coalition == 0 or zone.coalition == coalition) then
            if zone:isInZone(point) then return zone end
        end
    end
    return nil
end

--- Return the troop zone containing unitName, or nil.
-- @param unitName  string
-- @return CTLDTroopZone or nil
function CTLDZoneManager:getTroopZoneForUnit(unitName)
    local unit = Unit.getByName(unitName)
    if not unit or not unit:isExist() then return nil end
    return self:getTroopZoneAtPoint(unit:getPoint(), unit:getCoalition())
end

--- Return the active WPZ zone containing point for the given coalition, or nil.
-- @param point     vec3
-- @param coalition number  (coalition.side.* — 0 = accept all)
-- @return CTLDTroopZone or nil
function CTLDZoneManager:getWaypointZoneAt(point, coalition)
    for _, zone in pairs(self._troopZones) do
        if zone.active and zone:hasWaypoint()
        and (coalition == 0 or zone.coalition == 0 or zone.coalition == coalition)
        and zone:isInZone(point) then
            return zone
        end
    end
    return nil
end

--- Return the nearest active WPZ zone for the given coalition, or nil.
-- Unlike getWaypointZoneAt, does not require the point to be inside the zone.
-- Used by Feature I (_assignPostSpawnTask / "gotoNearestWPZ").
-- @param point     vec3
-- @param coalition number  (coalition.side.* — 0 = accept all)
-- @return CTLDTroopZone or nil
function CTLDZoneManager:getNearestWaypointZone(point, coalition)
    local best     = nil
    local bestDist = math.huge
    for _, zone in pairs(self._troopZones) do
        if zone.active and zone:hasWaypoint()
        and (coalition == 0 or zone.coalition == 0 or zone.coalition == coalition) then
            local dist = ctld.utils.getDistance("getNearestWaypointZone", point, zone:getCenter())
            if dist < bestDist then
                bestDist = dist
                best     = zone
            end
        end
    end
    return best
end

--- Return the active IAZ zone containing point for the given coalition, or nil.
-- Used by AI transport auto-drop logic.
-- @param point     vec3
-- @param coalition number  (coalition.side.* — 0 = accept all)
-- @return CTLDTroopZone or nil
function CTLDZoneManager:getDropoffZoneAt(point, coalition)
    for _, zone in pairs(self._troopZones) do
        if zone.active and zone:hasDropoff()
        and (coalition == 0 or zone.coalition == 0 or zone.coalition == coalition)
        and zone:isInZone(point) then
            return zone
        end
    end
    return nil
end

--- Return the active AIZ_P zone containing point for the given coalition, or nil.
-- Used by AI transport auto-pickup logic (_checkAIStatus).
-- @param point     vec3
-- @param coalition number  (coalition.side.* — 0 = accept all)
-- @return CTLDTroopZone or nil
function CTLDZoneManager:getAIPickupZoneAt(point, coalition)
    local best, bestR = nil, math.huge
    for _, zone in pairs(self._troopZones) do
        if zone.active and zone:hasAIPickup()
        and (coalition == 0 or zone.coalition == 0 or zone.coalition == coalition)
        and zone:isInZone(point) then
            local r = zone.radius or math.huge
            if r < bestR then best = zone; bestR = r end
        end
    end
    return best
end

--- Return the active AIZ_D zone containing point for the given coalition, or nil.
-- Used by AI transport auto-dropoff logic (_checkAIStatus).
-- @param point     vec3
-- @param coalition number  (coalition.side.* — 0 = accept all)
-- @return CTLDTroopZone or nil
function CTLDZoneManager:getAIDropoffZoneAt(point, coalition)
    local best, bestR = nil, math.huge
    for _, zone in pairs(self._troopZones) do
        if zone.active and zone:hasAIDropoff()
        and (coalition == 0 or zone.coalition == 0 or zone.coalition == coalition)
        and zone:isInZone(point) then
            local r = zone.radius or math.huge
            if r < bestR then best = zone; bestR = r end
        end
    end
    return best
end

-- ============================================================
-- Query API — LogisticZones
-- ============================================================

--- Return CTLDLogisticZone by name, or nil.
function CTLDZoneManager:getLogisticZone(name)
    return self._logisticZones[name]
end

--- Return all active logistic zones matching coalition.
function CTLDZoneManager:getLogisticZonesForCoalition(coalition)
    local result = {}
    for _, zone in pairs(self._logisticZones) do
        if zone.active and zone:isAlive()
           and (zone.coalition == coalition or zone.coalition == 0) then
            result[#result + 1] = zone
        end
    end
    return result
end

--- Return the logistic zone containing point, or nil.
-- @param point     vec3
-- @param coalition number
-- @return CTLDLogisticZone or nil
function CTLDZoneManager:getLogisticZoneAtPoint(point, coalition)
    for _, zone in pairs(self._logisticZones) do
        if zone.active and zone:isAlive()
           and (coalition == 0 or zone.coalition == 0 or zone.coalition == coalition) then
            if zone:isInZone(point) then return zone end
        end
    end
    return nil
end

--- Return the logistic zone containing unitName, or nil.
function CTLDZoneManager:getLogisticZoneForUnit(unitName)
    local unit = Unit.getByName(unitName) or StaticObject.getByName(unitName)
    if not unit or not unit:isExist() then return nil end
    return self:getLogisticZoneAtPoint(unit:getPoint(), unit:getCoalition())
end

--- Return ALL active logistic zones containing point (not just the first one).
-- Filters on coalition (0 = any). Optionally filters on a services key.
-- @param point      vec3
-- @param coalition  number
-- @param serviceKey string|nil   e.g. "cratesPickup" — if provided, zone.services[key] must be truthy
-- @return table  array of CTLDLogisticZone (may be empty)
function CTLDZoneManager:getLogisticZonesAtPoint(point, coalition, serviceKey)
    local result = {}
    for _, zone in pairs(self._logisticZones) do
        if zone.active and zone:isAlive()
           and (coalition == 0 or zone.coalition == 0 or zone.coalition == coalition)
           and zone:isInZone(point) then
            if not serviceKey or (zone.services and zone.services[serviceKey] ~= false) then
                result[#result + 1] = zone
            end
        end
    end
    return result
end

-- ============================================================
-- Misc helpers
-- ============================================================

--- Activate / deactivate a troop zone.
function CTLDZoneManager:setTroopZoneActive(zoneName, active)
    local zone = self._troopZones[zoneName]
    if zone then
        if active then zone:activate() else zone:deactivate() end
    end
end

-- ============================================================
-- Legacy-compatible public API (called by compat/legacy_api.lua)
-- ============================================================

--- Return the first troop zone of the given capability containing unitName.
-- zoneType: "extract" (hasExtract), "pickup" (hasPickup), nil (any active zone).
-- @param unitName string
-- @param zoneType string|nil
-- @return CTLDTroopZone or nil
function CTLDZoneManager:isUnitInZone(unitName, zoneType)
    local unit = Unit.getByName(unitName)
    if not unit or not unit:isExist() then return nil end
    local pt = unit:getPoint()
    for _, zone in pairs(self._troopZones) do
        if zone.active and zone:isInZone(pt) then
            if zoneType == "extract" then
                if zone:hasExtract() then return zone end
            elseif zoneType == "pickup" then
                if zone:hasPickup() then return zone end
            else
                return zone
            end
        end
    end
    return nil
end

--- Create a dynamic extract zone at a DCS trigger zone (MM DO SCRIPT).
-- Troops deployed inside will be counted silently and increment flagNumber.
-- smoke: trigger.smokeColor.* or -1 for no smoke.
-- @param zoneName   string          DCS trigger zone name
-- @param flagNumber number|string   DCS user flag to set to troop count
-- @param smoke      number          smoke color or -1
-- @return boolean
function CTLDZoneManager:createExtractZone(zoneName, flagNumber, smoke)
    local trig = trigger.misc.getZone(zoneName)
    if not trig then
        ctld.utils.log("ERROR", "CTLDZoneManager:createExtractZone — zone not found: %s", tostring(zoneName))
        return false
    end
    if self._troopZones[zoneName] then
        ctld.utils.log("WARN", "CTLDZoneManager:createExtractZone — zone already registered: %s", zoneName)
        return false
    end
    local p2 = { x = trig.point.x, y = trig.point.z }
    local pt = { x = p2.x, y = land.getHeight(p2), z = p2.y }
    local smokeColor = (smoke ~= nil and tonumber(smoke) and tonumber(smoke) >= 0) and tonumber(smoke) or -1
    self._troopZones[zoneName] = CTLDTroopZone:new({
        dcsName       = zoneName,
        zoneName      = zoneName,
        coalition     = 0,
        center        = pt,
        radius        = trig.radius,
        objectiveFlag = tostring(flagNumber),
        smoke         = smokeColor,
        active        = true,
    })
    if smokeColor >= 0 then trigger.action.smoke(pt, smokeColor) end
    ctld.utils.log("INFO", "CTLDZoneManager:createExtractZone — '%s' flag=%s", zoneName, tostring(flagNumber))
    return true
end

--- Remove a dynamic extract zone.
-- flagNumber is accepted for API compatibility but ignored.
-- @param zoneName   string
-- @param flagNumber number|string  (ignored)
-- @return boolean
function CTLDZoneManager:removeExtractZone(zoneName, flagNumber)
    if self._troopZones[zoneName] then
        self._troopZones[zoneName] = nil
        ctld.utils.log("INFO", "CTLDZoneManager:removeExtractZone — '%s' removed", zoneName)
        return true
    end
    ctld.utils.log("WARN", "CTLDZoneManager:removeExtractZone — not found: %s", tostring(zoneName))
    return false
end

--- Activate a waypoint zone (troops deployed inside will move toward zone center).
-- @param zoneName string
function CTLDZoneManager:activateWaypointZone(zoneName)
    return self:setTroopZoneActive(zoneName, true)
end

--- Deactivate a waypoint zone.
-- @param zoneName string
function CTLDZoneManager:deactivateWaypointZone(zoneName)
    return self:setTroopZoneActive(zoneName, false)
end

--- Adjust the available pickup stock for a troop zone by amount (positive or negative).
-- @param zoneName string
-- @param amount   number
-- @return boolean
function CTLDZoneManager:changeRemainingGroups(zoneName, amount)
    local zone = self._troopZones[zoneName]
    if not zone then
        ctld.utils.log("WARN", "CTLDZoneManager:changeRemainingGroups — not found: %s", tostring(zoneName))
        return false
    end
    if zone.pickMaxStock == nil then
        ctld.utils.log("WARN", "CTLDZoneManager:changeRemainingGroups — '%s' has no pickup stock", zoneName)
        return false
    end
    zone.pickCurrentStock = math.max(0, zone.pickCurrentStock + amount)
    ctld.utils.log("INFO", "CTLDZoneManager:changeRemainingGroups — '%s' stock=%d", zoneName, zone.pickCurrentStock)
    return true
end

-- ============================================================
-- Zone name validation (developer tool — reports to DCS log + screen)
-- ============================================================

function CTLDZoneManager:_validateZoneNames()
    local errors  = {}   -- parse errors / config errors
    local warns   = {}   -- semantic warnings

    -- ── TRZ / WPZ / LGZ naming validation ────────────────────
    if env.mission and env.mission.triggers and env.mission.triggers.zones then
        for _, zd in pairs(env.mission.triggers.zones) do
            local name = zd.name or ""
            if string.sub(name, 1, 4) == "TRZ_" then
                local parsed, err = self:_parseTRZ(name)
                if not parsed then
                    errors[#errors + 1] = "  TRZ ERROR '" .. name .. "': " .. tostring(err)
                end
            elseif string.sub(name, 1, 4) == "WPZ_" then
                local parsed, err = self:_parseWPZ(name)
                if not parsed then
                    errors[#errors + 1] = "  WPZ ERROR '" .. name .. "': " .. tostring(err)
                end
            elseif string.sub(name, 1, 4) == "LGZ_" then
                local parsed = self:_parseLGZ(name)
                if not parsed then
                    errors[#errors + 1] = "  LGZ ERROR '" .. name .. "': parse failed"
                end
            end
        end
    end

    -- ── AIZ config validation (Feature S) ────────────────────
    local aiZoneErrors = {}   -- dcsZoneName → true (skip in _loadAIZonesFromConfig)
    local seenDzn      = {}   -- duplicate detection
    local aiZonePickup  = {}  -- for overlap check
    local aiZoneDropoff = {}

    -- Pre-build template name set for WARN checks (lazy — only if aiZones non-empty)
    local knownTemplates = nil
    local function getKnownTemplates()
        if knownTemplates then return knownTemplates end
        knownTemplates = {}
        local okTM, tm = pcall(CTLDTroopManager.getInstance)
        if okTM and tm then
            for _, t in ipairs(tm._templates) do
                knownTemplates[t.name] = true
            end
        end
        return knownTemplates
    end

    -- Pre-build known loadable vehicle typeNames (lazy) — for G4 vehicleTypes whitelist check
    local knownVehicleTypes = nil
    local function getKnownVehicleTypes()
        if knownVehicleTypes then return knownVehicleTypes end
        knownVehicleTypes = {}
        local caps = ctld.gs("capabilitiesByType") or {}
        for _, c in pairs(caps) do
            if c.loadableVehiclesRED then
                for _, t in ipairs(c.loadableVehiclesRED) do knownVehicleTypes[t] = true end
            end
            if c.loadableVehiclesBLUE then
                for _, t in ipairs(c.loadableVehiclesBLUE) do knownVehicleTypes[t] = true end
            end
        end
        return knownVehicleTypes
    end

    -- Check if any transport has canTransportWholeVehicle (lazy) — for G5
    local _hasVehicleTransport = nil
    local function hasVehicleTransport()
        if _hasVehicleTransport ~= nil then return _hasVehicleTransport end
        local caps = ctld.gs("capabilitiesByType") or {}
        for _, c in pairs(caps) do
            if c.canTransportWholeVehicle then _hasVehicleTransport = true; return true end
        end
        _hasVehicleTransport = false
        return false
    end

    local VALID_COALITION = { RED = true, BLUE = true, NEUTRAL = true }
    local VALID_CARGO     = { T = true, V = true, TV = true }
    local VALID_DROP_MODE = { G = true, P = true, GP = true }

    for i, entry in ipairs(ctld.gs("aiZones") or {}) do
        local dzn   = entry.dcsZoneName
        local hasErr = false
        if not dzn or dzn == "" then
            errors[#errors + 1] = ctld.tr("  AIZ[%1] ERROR: missing dcsZoneName", i)
            hasErr = true
        else
            -- Duplicate check
            if seenDzn[dzn] then
                errors[#errors + 1] = ctld.tr("  AIZ[%1] ERROR '%2': duplicate dcsZoneName — entry ignored", i, dzn)
                hasErr = true
            else
                seenDzn[dzn] = true
                -- Zone present in ME?
                local trig = trigger.misc.getZone(dzn)
                if not trig then
                    errors[#errors + 1] = ctld.tr("  AIZ[%1] ERROR '%2': not found in Mission Editor — entry ignored", i, dzn)
                    hasErr = true
                end
            end
            -- Coalition
            if not entry.coalition or not VALID_COALITION[entry.coalition] then
                errors[#errors + 1] = ctld.tr("  AIZ[%1] ERROR '%2': missing or invalid coalition (expected RED/BLUE/NEUTRAL) — entry ignored", i, tostring(dzn))
                hasErr = true
            end
            -- G1: neither isPickup nor isDropoff — zone would do nothing
            if not entry.isPickup and not entry.isDropoff then
                errors[#errors + 1] = ctld.tr("  AIZ[%1] ERROR '%2': neither isPickup nor isDropoff — zone does nothing, entry ignored", i, tostring(dzn))
                hasErr = true
            end
            -- cargoType (Fix 5: WARN, not error — zone created with default "T")
            if entry.cargoType and not VALID_CARGO[entry.cargoType] then
                warns[#warns + 1] = ctld.tr("  AIZ[%1] WARN '%2': invalid cargoType '%3' — defaulting to T", i, tostring(dzn), tostring(entry.cargoType))
            end
            -- G5: cargoType V/TV on a pickup zone but no transport has canTransportWholeVehicle
            local effCargoIsVehicle = (entry.cargoType == "V" or entry.cargoType == "TV")
            if not hasErr and entry.isPickup and effCargoIsVehicle and not hasVehicleTransport() then
                errors[#errors + 1] = ctld.tr("  AIZ[%1] ERROR '%2': cargoType '%3' requires whole-vehicle transport but no aircraft has canTransportWholeVehicle=true — entry ignored", i, tostring(dzn), tostring(entry.cargoType))
                hasErr = true
            end
            -- aiDropMode (Fix 6 applied in _loadAIZonesFromConfig — WARN only here)
            if entry.aiDropMode and not VALID_DROP_MODE[entry.aiDropMode] then
                warns[#warns + 1] = ctld.tr("  AIZ[%1] WARN '%2': invalid aiDropMode '%3' — defaulting to GP", i, tostring(dzn), tostring(entry.aiDropMode))
            end
            -- G3: isPickup + troop cargo + troopStock not defined → troop pickup disabled
            local effCargoHasTroops = (not entry.cargoType or entry.cargoType == "T" or entry.cargoType == "TV")
            if not hasErr and entry.isPickup and effCargoHasTroops and entry.troopStock == nil then
                warns[#warns + 1] = ctld.tr("  AIZ[%1] WARN '%2': isPickup=true with troop cargo but troopStock not defined — troop pickup disabled", i, tostring(dzn))
            end
            -- G6: isPickup + vehicle cargo + vehicleStock not defined → vehicle pickup disabled
            local effCargoHasVehicle = (entry.cargoType == "V" or entry.cargoType == "TV")
            if not hasErr and entry.isPickup and effCargoHasVehicle and entry.vehicleStock == nil then
                warns[#warns + 1] = ctld.tr("  AIZ[%1] WARN '%2': isPickup=true with vehicle cargo but vehicleStock not defined — vehicle pickup disabled", i, tostring(dzn))
            end
            -- troopTemplates: warn on unknown names; G2: all unknown → extra WARN
            if not hasErr and entry.troopTemplates and #entry.troopTemplates > 0 then
                local kt = getKnownTemplates()
                local unknownCount = 0
                for _, tName in ipairs(entry.troopTemplates) do
                    if not kt[tName] then
                        warns[#warns + 1] = ctld.tr("  AIZ[%1] WARN '%2': troopTemplates['%3'] not found in loadableGroups", i, dzn, tName)
                        unknownCount = unknownCount + 1
                    end
                end
                if unknownCount == #entry.troopTemplates then
                    warns[#warns + 1] = ctld.tr("  AIZ[%1] WARN '%2': all troopTemplates are unknown — troop pickup will always be skipped", i, dzn)
                end
            end
            -- G4: vehicleTypes whitelist — all types unknown in configured loadable vehicle lists
            if not hasErr and entry.vehicleTypes and #entry.vehicleTypes > 0 then
                local kvt = getKnownVehicleTypes()
                local unknownCount = 0
                for _, vt in ipairs(entry.vehicleTypes) do
                    if not kvt[vt] then unknownCount = unknownCount + 1 end
                end
                if unknownCount == #entry.vehicleTypes then
                    warns[#warns + 1] = ctld.tr("  AIZ[%1] WARN '%2': all vehicleTypes entries are unknown in loadable vehicle lists — vehicle pickup will always be skipped", i, dzn)
                end
            end
            -- Collect pickup/dropoff for overlap check
            if not hasErr then
                local trig2 = trigger.misc.getZone(dzn)
                if trig2 then
                    local ctr = { x = trig2.point.x, y = trig2.point.y, z = trig2.point.z }
                    local r   = trig2.radius or 500
                    local coa = entry.coalition
                    if entry.isPickup then
                        aiZonePickup[#aiZonePickup + 1] = { name=dzn, center=ctr, radius=r, coa=coa }
                    end
                    if entry.isDropoff then
                        aiZoneDropoff[#aiZoneDropoff + 1] = { name=dzn, center=ctr, radius=r, coa=coa }
                    end
                end
            end
        end
        if hasErr and dzn then aiZoneErrors[dzn] = true end
    end

    -- AIZ P+D overlap check
    for _, p in ipairs(aiZonePickup) do
        for _, d in ipairs(aiZoneDropoff) do
            if p.name ~= d.name and p.coa == d.coa then
                local dx   = p.center.x - d.center.x
                local dz   = p.center.z - d.center.z
                local dist = math.sqrt(dx*dx + dz*dz)
                if dist < (p.radius + d.radius) then
                    warns[#warns + 1] = ctld.tr("  AIZ WARN: '%1' (P) overlaps '%2' (D) same coalition — risk of instant pickup+dropoff loop", p.name, d.name)
                end
            end
        end
    end

    -- Store error set for _loadAIZonesFromConfig
    self._aiZoneErrors = aiZoneErrors

    -- ── Emit single grouped report ────────────────────────────
    local all = {}
    for _, e in ipairs(errors) do all[#all + 1] = e end
    for _, w in ipairs(warns)  do all[#all + 1] = w end

    if #all > 0 then
        local report = ctld.tr("[CTLD] Zone validation — %1 error(s), %2 warning(s):", #errors, #warns)
                    .. "\n" .. table.concat(all, "\n")
        trigger.action.outText(report, 30)
        ctld.utils.log("WARN", report)
        env.warning(report)
    else
        ctld.utils.log("INFO", ctld.tr("CTLDZoneManager: zone config valid"))
    end
end
