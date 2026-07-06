-- ============================================================
-- CTLD_crate.lua
-- CTLDCrate entity + CTLDCrateManager singleton
--
-- Dependencies: CTLDConfig (ctld.gs), CTLDUtils, EventDispatcher
--
-- Crate lifecycle states:
--   spawned  : on ground, freshly created (never moved)
--   loaded   : inside / attached to a transport
--   falling  : in air, descending (drop or parachute)
--   landed   : on ground after a transport cycle
--   unpacked : contents deployed (terminal state)
--
-- spawnMethod values:
--   crate_spawn   : spawned from F10 menu (logistics pool)
--   vehicle_pack  : result of packing a vehicle
--   mission_maker : pre-placed by mission maker (detected via INIT-B)
--
-- NOTE: Feature A (virtual parachute) stubs are present but
--       not implemented. Search "Feature A" to locate them.
-- ============================================================

---@diagnostic disable
ctld = ctld or {}

-- ============================================================
-- CTLDCrate  (entity)
-- ============================================================

CTLDCrate = class()

CTLDCrate.STATE = {
    SPAWNED  = "spawned",
    LOADED   = "loaded",
    FALLING  = "falling",
    LANDED   = "landed",
    UNPACKED = "unpacked",
}

CTLDCrate.SPAWN_METHOD = {
    CRATE_SPAWN   = "crate_spawn",
    VEHICLE_PACK  = "vehicle_pack",
    MISSION_MAKER = "mission_maker",
    MENU_CTLD     = "menu_ctld",
}

--- Constructor.
-- @param data table:
--   crateName (string)          DCS unitName of the StaticObject
--   descriptor (table)          CTLD crate descriptor (from spawnableCrates)
--   spawnMethod (string)        CTLDCrate.SPAWN_METHOD.*
--   position (vec3)
--   coalition (number)          coalition.side.*
--   heading (number|nil)        radians, defaults to 0
--   spawnedBy (string|nil)      player name if spawned via menu
--   dcsStatic (StaticObject|nil)
function CTLDCrate:init(data)
    self.crateName    = data.crateName
    self.descriptor   = data.descriptor
    self.state        = CTLDCrate.STATE.SPAWNED
    self.spawnMethod  = data.spawnMethod
    self.spawnedBy    = data.spawnedBy or nil
    self.spawnTime    = timer.getAbsTime()
    self.position     = data.position
    self.heading      = data.heading or 0
    self.coalition    = data.coalition
    self.loadedBy     = nil
    self.loadTime     = nil
    self.dcsStatic    = data.dcsStatic or nil
    self.modelKey     = data.modelKey  or "load"
    self.canBeUnpacked = true
    -- Feature A: virtual parachute
    self.fromParachute          = false   -- true → eligible for autoUnpack on landing
    self.loadedByDCSNative      = false   -- true → loaded via DCS standard UI (not CTLD menu); excluded from parachute
    -- Feature B: virtual slingload
    self.inTransitOnSlingload   = false
    self.timestamp              = timer.getAbsTime()
    self.metadata               = {}   -- arbitrary key/value bag (e.g. warehouseSnapshot from repack)
end

--- Load the crate into a transport unit.
-- @param transport Unit
function CTLDCrate:load(transport)
    self.state         = CTLDCrate.STATE.LOADED
    self.loadedBy      = transport
    self.loadTime      = timer.getAbsTime()
    self.fromParachute = false   -- reset: a new load clears any prior parachute flag
end

--- Unload the crate to the ground (transport is landed).
-- @param position vec3
function CTLDCrate:unload(position)
    self.state            = CTLDCrate.STATE.LANDED
    self.position         = position
    self.loadedBy         = nil
    self.loadTime         = nil
    self.loadedByDCSNative = false
end

--- Drop the crate in flight (transitions to falling).
-- @param position vec3  current air position at drop time
function CTLDCrate:drop(position)
    self.state    = CTLDCrate.STATE.FALLING
    self.position = position
    self.loadedBy = nil
    self.loadTime = nil
end

--- Mark crate as parachuting. Physics (descent rate, lateral drift, wind) are
-- computed by CTLDCrateManager:parachuteCrates() before this call.
-- @param altitude number  current altitude AGL (metres)
function CTLDCrate:startParachute(altitude)
    self.state                   = CTLDCrate.STATE.FALLING
end

--- Crate touches the ground (after falling or parachuting).
-- @param position vec3
function CTLDCrate:land(position)
    self.state         = CTLDCrate.STATE.LANDED
    self.position      = position
end

--- Mark crate as unpacked (contents deployed).
function CTLDCrate:unpack()
    self.state = CTLDCrate.STATE.UNPACKED
end

--- Destroy the associated DCS static object.
function CTLDCrate:destroy()
    if self.dcsStatic and self.dcsStatic:isExist() then
        self.dcsStatic:destroy()
    end
    self.dcsStatic = nil
end

--- Returns true if the crate is on the ground and interactable.
function CTLDCrate:isOnGround()
    if self.state ~= CTLDCrate.STATE.SPAWNED
       and self.state ~= CTLDCrate.STATE.LANDED then
        return false
    end
    -- Also verify the DCS static still physically exists (guards against crates
    -- destroyed by combat before S_EVENT_DEAD could unregister them).
    if self.dcsStatic then
        return self.dcsStatic:isExist()
    end
    -- No DCS ref (parachuted crate landing pending): trust state only
    return true
end

--- Returns true if the crate is currently in a transport.
function CTLDCrate:isLoaded()
    return self.state == CTLDCrate.STATE.LOADED
end

--- Returns true if the crate is in LOADED state (managed by CTLD).
-- Applies to both CTLD-menu loads and DCS-native loads migrated to CTLD.
-- Use loadedByDCSNative to further distinguish the two sub-cases.
-- Use this to guard Drop/Parachute/Unpack CTLD menu actions.
function CTLDCrate:isLoadedByCTLD()
    return self.state == CTLDCrate.STATE.LOADED
end

--- Returns true if this crate can be unpacked.
-- A complete crate set anywhere on the ground can be unpacked at any time.
function CTLDCrate:canUnpack()
    if not self:isOnGround()  then return false end
    if not self.canBeUnpacked then return false end
    return true
end

-- ============================================================
-- ============================================================
-- CTLDSmokeManager  (Feature H — Smoke auto-resume)
-- Singleton. Tracks smokes dropped via CTLD menus per player.
-- When a player enables auto-resume, their smokes are re-triggered
-- every smokeAutoResumeInterval seconds (default 270s, DCS lasts ~5min).
-- ============================================================

CTLDSmokeManager = class()
local _smInstance = nil

function CTLDSmokeManager.getInstance()
    if _smInstance == nil then
        _smInstance = setmetatable({}, CTLDSmokeManager)
        -- Per-player state: { active=bool, smokes=[{pos,color,launchTime}] }
        _smInstance._players = {}
        -- Start the periodic check (every 15s — lightweight, no re-trigger unless interval reached)
        timer.scheduleFunction(function(_, t)
            CTLDSmokeManager.getInstance():_tick()
            return t + 15
        end, nil, timer.getTime() + 15)
    end
    return _smInstance
end

--- Returns true if the player has auto-resume enabled.
function CTLDSmokeManager:isActive(playerName)
    local p = self._players[playerName]
    if p == nil then return ctld.gs("smokeAutoResume") == true end
    return p.active == true
end

--- Toggle auto-resume for a player. Returns new state (bool).
-- Deactivating clears the stored smoke list so stale smokes are not
-- replayed if the player re-activates later.
function CTLDSmokeManager:toggle(playerName)
    if not self._players[playerName] then
        self._players[playerName] = { active = false, smokes = {} }
    end
    local newState = not self._players[playerName].active
    self._players[playerName].active = newState
    if not newState then
        self._players[playerName].smokes = {}
    end
    return newState
end

--- Register a smoke dropped by a player (called from doSmoke).
-- @param playerName string
-- @param pos        table  {x,y,z} world position (on ground)
-- @param color      number trigger.smokeColor.*
function CTLDSmokeManager:registerSmoke(playerName, pos, color)
    if not self._players[playerName] then
        self._players[playerName] = { active = ctld.gs("smokeAutoResume") == true, smokes = {} }
    end
    local list = self._players[playerName].smokes
    list[#list + 1] = { pos = pos, color = color, launchTime = timer.getTime() }
end

--- Remove all tracked smokes for a player (e.g. on disconnect).
function CTLDSmokeManager:clearSmokes(playerName)
    if self._players[playerName] then
        self._players[playerName].smokes = {}
    end
end

--- Periodic tick: re-trigger smokes whose interval has elapsed (per active player).
function CTLDSmokeManager:_tick()
    local interval = ctld.gs("smokeAutoResumeInterval") or 270
    local now      = timer.getTime()
    for playerName, pState in pairs(self._players) do
        if pState.active then
            local list    = pState.smokes
            local newList = {}
            for _, entry in ipairs(list) do
                if now - entry.launchTime >= interval then
                    -- Re-trigger and reset the timer
                    local _sok, _serr = pcall(trigger.action.smoke, entry.pos, entry.color)
                    if not _sok then ctld.utils.log("WARN", "CTLDSmokeManager: smoke trigger failed for '%s': %s", playerName, tostring(_serr)) end
                    ctld.utils.log("INFO", "CTLDSmokeManager: auto-resume smoke for '%s'", playerName)
                    newList[#newList + 1] = { pos = entry.pos, color = entry.color, launchTime = now }
                else
                    newList[#newList + 1] = entry
                end
            end
            pState.smokes = newList
        end
    end
end

-- ============================================================
-- CTLDCrateManager  (singleton)
-- ============================================================

CTLDCrateManager = class()

local _cmInstance = nil
CTLDCrateManager._instance = nil  -- class-level mirror for test isolation (reset via CTLDCrateManager._instance = nil)

function CTLDCrateManager.getInstance()
    -- Support test reset: if class-level _instance was set to nil externally, mirror that to the local var.
    if CTLDCrateManager._instance == nil then _cmInstance = nil end
    if _cmInstance == nil then
        _cmInstance = setmetatable({}, CTLDCrateManager)
        _cmInstance.crates            = {}   -- [crateName] = CTLDCrate
        _cmInstance._parachuteEffect  = CTLDNullParachuteEffect:new()
        _cmInstance._hoverStatus      = {}   -- [unitName] = secondsRemaining
        _cmInstance._nativeCrateLink  = {}   -- [crateName] = {lx,ly,lz} local-frame offset at DCS-native load time
        local pm = CTLDPlayerManager.getInstance()
        pm:registerMenuSection({ key = "crates", manager = _cmInstance, method = "buildMenuSection",  configKey = "enableCrates",    order = 40 })
        pm:registerMenuSection({ key = "smoke",  manager = _cmInstance, method = "buildSmokeSection", configKey = "enableSmokeDrop", order = 80 })
        -- Refresh "Load Crate" submenu for all players near a crate when it appears or disappears.
        local ed = EventDispatcher.getInstance()
        ed:subscribe("OnCrateSpawned", function(payload)
            CTLDCrateManager.getInstance():_refreshNearbyPlayers(payload.position)
        end)
        ed:subscribe("OnCrateCleared", function(payload)
            CTLDCrateManager.getInstance():_refreshNearbyPlayers(payload.position)
        end)
        -- Feature B: start hover-slingload polling (1s tick)
        timer.scheduleFunction(function()
            CTLDCrateManager.getInstance():checkHoverStatus()
        end, {}, timer.getTime() + 1)
        -- LGZ ground-position poller (10s tick): refreshes Request Equipment only
        -- when the player's logistic zone set changes (entry/exit). Avoids rebuilding
        -- the DCS menu on a fixed cadence, which would eject players from sub-menus.
        local function _lgzZoneKey(zones)
            if not next(zones) then return "" end
            local names = {}
            for _, z in ipairs(zones) do names[#names + 1] = z.name end
            table.sort(names)
            return table.concat(names, ",")
        end
        local function _lgzGroundPoll(_, t)
            local pm_ref = CTLDPlayerManager.getInstance()
            local cm_ref = CTLDCrateManager.getInstance()
            local zm_ref = CTLDZoneManager.getInstance()
            for _, pObj in pairs(pm_ref._players) do
                if pObj._isFlying == false then
                    local unit = Unit.getByName(pObj.unitName)
                    if unit and unit:isExist() and not ctld.utils.inAir(unit) then
                        local zones  = zm_ref:getLogisticZonesAtPoint(
                            unit:getPoint(), pObj.coalition, "cratesPickup")
                        local newKey = _lgzZoneKey(zones)
                        if pObj._lgzKey ~= newKey then
                            pObj._lgzKey = newKey
                            cm_ref:refreshRequestEquipmentSection(pObj)
                        end
                    end
                end
            end
            return t + 10
        end
        timer.scheduleFunction(_lgzGroundPoll, {}, timer.getTime() + 10)
        -- Detect crates destroyed by combat (S_EVENT_DEAD on the static object).
        local ok, bridge = pcall(CTLDDCSEventBridge.getInstance)
        if ok and bridge then
            bridge:register(_cmInstance, world.event.S_EVENT_DEAD, "onCrateDead")
        end
        -- Pre-process spawnableCrates config (two-pass: singleCrates + auto singleTypeSets + mixedSets validation)
        _cmInstance:_processSpawnableCrates()
        -- Expose singleton reference so CTLDSceneManager can inject late-registered scene crates.
        CTLDCrateManager._instance = _cmInstance
    end
    return _cmInstance
end

--- Remove all scene crate entries from _processedCrates and _weightIndex whose models are
-- marked _disabled by CTLDSceneManager:_auditAfterModValidator().
-- Called once, immediately after the scene audit, before any player menu is built.
function CTLDCrateManager:_purgeDisabledScenes()
    local sm = CTLDSceneManager.getInstance()
    for cat, catData in pairs(self._processedCrates) do
        local kept = {}
        for _, pe in ipairs(catData.singleCrates) do
            local sc = pe.singleCrate
            if sc then
                local model = sm:getModel(sc.unit)
                if model and model._disabled then
                    -- Remove from weight index too
                    if self._weightIndex[sc.weight] and self._weightIndex[sc.weight].unit == sc.unit then
                        self._weightIndex[sc.weight] = nil
                    end
                    ctld.utils.log("WARN",
                        "_purgeDisabledScenes: removed '%s' from Request Equipment menu (missing DCS type)",
                        sc.unit)
                else
                    kept[#kept + 1] = pe
                end
            else
                kept[#kept + 1] = pe
            end
        end
        catData.singleCrates = kept
    end
end

--- Inject a single scene model's crate descriptor into _weightIndex and _processedCrates.
-- Called by _processSpawnableCrates (batch, at init) and by CTLDSceneManager:registerSceneModel
-- (incremental, for scenes registered after CTLDCrateManager is already initialized).
-- Weight collision resolution: if the declared weight is taken by a different unit, the next
-- free slot in the same 1001.xx range is used and a WARN is logged.
-- No-op if the scene is already present in _weightIndex (idempotent).
-- No-op if the scene model is marked _disabled (missing DCS type — suppressed by audit).
-- @param sceneName  string  model.name
-- @param model      table   scene model with model.crate set
function CTLDCrateManager:_injectSceneCrate(sceneName, model)
    if model._disabled then return end  -- scene disabled by mod audit — do not add to menu
    local cd       = model.crate
    local w        = cd.weight
    local existing = self._weightIndex[w]
    if existing then
        if existing.unit ~= sceneName then
            local base = math.floor(w)
            local frac = math.floor((w - base) * 100 + 0.5)
            repeat
                frac = frac + 1
                w    = base + frac / 100
            until not self._weightIndex[w]
            ctld.utils.log("WARN",
                "_injectSceneCrate: scene '%s' weight %.2f taken by '%s' — reassigned to %.2f",
                sceneName, cd.weight, existing.unit, w)
        else
            return  -- same unit already registered — idempotent, skip
        end
    end
    if self._weightIndex[w] then return end  -- still taken after reassign (shouldn't happen)

    local entry = {
        weight         = w,
        desc           = ctld.tr(cd.i18nKey or sceneName),
        unit           = sceneName,
        side           = cd.side,
        cratesRequired = cd.cratesRequired or 1,
        showSets       = (cd.showSets == nil) and true or cd.showSets,
    }
    self._weightIndex[w] = entry

    local cat = (cd.side == "blue") and "BLUE"
             or (cd.side == "red")  and "RED"
             or "Both"
    if not self._processedCrates[cat] then
        self._processedCrates[cat] = { singleCrates = {}, mixedSets = {} }
    end
    local already = false
    for _, pe in ipairs(self._processedCrates[cat].singleCrates) do
        if pe.singleCrate and pe.singleCrate.unit == sceneName then
            already = true; break
        end
    end
    if not already then
        local showCrateSets = ctld.gs("enableAllCrates") ~= false
        local pe = { singleCrate = entry }
        local cr = entry.cratesRequired
        if cr > 1 and showCrateSets and entry.showSets then
            local weights = {}
            for i = 1, cr do weights[i] = w end
            pe.singleTypeSet = {
                multiple       = weights,
                desc           = entry.desc .. " - " .. ctld.tr("All crates"),
                side           = entry.side,
                _autoGenerated = true,
            }
        end
        table.insert(self._processedCrates[cat].singleCrates, pe)
    end
    ctld.utils.log("INFO", "_injectSceneCrate: injected '%s' weight=%.2f", sceneName, w)
end

--- Pre-process spawnableCrates config into an internal structure used by the menu builder.
-- Two-pass:
--   Pass 1 — separate singleCrates (weight field) from mixedSets (mixedSet field).
--   Pass 2 — auto-generate singleTypeSet for each singleCrate with cratesRequired > 1
--             when enableAllCrates AND singleCrate.showSets are both true (default).
-- Pass 3 — validate each mixedSet: all weights must resolve to a known singleCrate in
--           the same category; invalid mixedSets are excluded and trigger a MM warning.
-- Results stored in self._processedCrates[category] and self._weightIndex[weight].
function CTLDCrateManager:_processSpawnableCrates()
    local spawnableCrates = ctld.gs("spawnableCrates") or {}
    -- Inject AA system crate entries (parts + repair) from CTLDCrateAssemblyManager.TEMPLATES.
    -- Must run before the main loop so injected entries enter _processedCrates and _weightIndex.
    CTLDCrateAssemblyManager.injectAACrates(spawnableCrates)
    local showCrateSets   = ctld.gs("enableAllCrates") ~= false
    local allSuffix       = " - " .. ctld.tr("All crates")

    self._processedCrates = {}
    self._weightIndex     = {}
    local warnings        = {}

    for category, entries in pairs(spawnableCrates) do
        local singleCrates  = {}
        local mixedSets     = {}
        local catWeightIdx  = {}

        -- Pass 1: separate entries by type
        for _, entry in ipairs(entries) do
            if entry.weight then
                table.insert(singleCrates, entry)
                catWeightIdx[entry.weight]    = entry
                self._weightIndex[entry.weight] = entry
            elseif entry.mixedSet then
                table.insert(mixedSets, entry)
            else
                ctld.logWarning("_processSpawnableCrates: entry in '%s' has neither weight nor mixedSet — skipped", category)
            end
        end

        -- Pass 2: generate singleTypeSet for qualifying singleCrates
        local processedSingle = {}
        for _, sc in ipairs(singleCrates) do
            local entry = { singleCrate = sc }
            local cr    = sc.cratesRequired or 1
            if cr > 1 and showCrateSets and (sc.showSets ~= false) then
                local weights = {}
                for i = 1, cr do weights[i] = sc.weight end
                entry.singleTypeSet = {
                    multiple       = weights,
                    desc           = sc.desc .. allSuffix,
                    side           = sc.side,
                    isJTAC         = sc.isJTAC,
                    _autoGenerated = true,
                }
            end
            table.insert(processedSingle, entry)
        end

        -- Pass 3: validate mixedSets
        local processedMixed = {}
        for _, ms in ipairs(mixedSets) do
            local valid = true
            for _, w in ipairs(ms.mixedSet) do
                if not catWeightIdx[w] then
                    local msg = string.format(
                        "CTLD config error: mixedSet '%s' references weight %.4f not found in category '%s'",
                        tostring(ms.desc), w, category)
                    ctld.logWarning(msg)
                    table.insert(warnings, msg)
                    valid = false
                end
            end
            if valid then
                -- Build processed entry: alias mixedSet → multiple for spawn compatibility
                local proc = {}
                for k, v in pairs(ms) do proc[k] = v end
                proc.multiple = ms.mixedSet
                table.insert(processedMixed, proc)
            end
        end

        self._processedCrates[category] = {
            singleCrates = processedSingle,
            mixedSets    = processedMixed,
        }
    end

    -- Auto-inject all scene crates registered so far (scenes loaded before CTLDCoreManager init).
    -- Scenes registered afterwards are handled by the callback in CTLDSceneManager:registerSceneModel.
    local sm_auto = CTLDSceneManager.getInstance()
    for sceneName, model in pairs(sm_auto._models) do
        if model.crate then
            self:_injectSceneCrate(sceneName, model)
        end
    end

    -- Display MM startup warnings if any validation errors found
    if #warnings > 0 then
        local msg = "CTLD — spawnableCrates config errors:\n" .. table.concat(warnings, "\n")
        timer.scheduleFunction(function()
            trigger.action.outText(msg, 30)
        end, {}, timer.getTime() + 5)
    end
end

--- Refresh the "Load Crate" submenu for all players within 200 m of a position.
-- Called on OnCrateSpawned and OnCrateCleared so every nearby transport sees
-- the current list regardless of who triggered the action.
-- @param position vec3  reference point (crate position)
function CTLDCrateManager:_refreshNearbyPlayers(position)
    if not position then return end
    local pm = CTLDPlayerManager.getInstance()
    for unitName in pairs(pm._players) do
        local unit = Unit.getByName(unitName)
        if unit and unit:isExist() then
            local dist = ctld.utils.getDistance("_refreshNearbyPlayers", unit:getPoint(), position)
            if dist <= 300 then
                self:refreshLoadCrateSectionForUnit(unitName)
                self:refreshUnpackSectionForUnit(unitName)
            end
        end
    end
end

--- Refresh the "Load Crate" submenu for a single player looked up by unit name.
-- @param unitName string
function CTLDCrateManager:refreshLoadCrateSectionForUnit(unitName)
    local playerObj = CTLDPlayerManager.getInstance()._players[unitName]
    if playerObj then self:refreshLoadCrateSection(playerObj) end
end

--- Rebuild the "Load Crate" dynamic submenu for playerObj.
-- Groups available crates within 50 m by descriptor type with count.
-- Called on land, crate spawn, crate cleared, and after each load action.
-- @param playerObj CTLDPlayer
function CTLDCrateManager:refreshLoadCrateSection(playerObj)
    local caps = (ctld.gs("capabilitiesByType") or {})[playerObj.typeName]
    if not (playerObj.isTransport and caps and caps.cratesEnabled) then return end
    if not ctld.gs("loadCrateFromMenu") then return end

    local mm   = ctld.MenuManager:getInstance()
    local menu = mm:getMenuByGroupId(playerObj.groupId)
    if not menu then return end

    local root      = ctld.tr("CTLD")
    local cratesSub = ctld.tr("Crate Commands")
    local loadSub   = ctld.tr("Load Crate")

    menu:clearBranch({ root, cratesSub, loadSub })

    local transport = Unit.getByName(playerObj.unitName)
    if not (transport and transport:isExist()) or ctld.utils.inAir(transport) then
        menu:addCommand({ root, cratesSub, loadSub },
            ctld.tr("Land to load crates"), function() end, {})
        menu:refresh()
        return
    end

    -- Group nearby crates (50 m) by descriptor type
    local nearby = self:getCratesInRange(transport:getPoint(), 50)
    local byType = {}   -- [desc] = { count, descriptor }
    for _, crate in ipairs(nearby) do
        local desc = crate.descriptor and crate.descriptor.desc or "Unknown"
        if not byType[desc] then
            byType[desc] = { count = 0, descriptor = crate.descriptor }
        end
        byType[desc].count = byType[desc].count + 1
    end

    if not next(byType) then
        menu:addCommand({ root, cratesSub, loadSub },
            ctld.tr("No crates within 50m"), function() end, {})
    else
        for desc, data in pairs(byType) do
            local label = string.format("%s (%d)", desc, data.count)
            menu:addCommand({ root, cratesSub, loadSub }, label,
                function(arg)
                    local t = Unit.getByName(arg.unitName)
                    if not (t and t:isExist()) then return end
                    if ctld.utils.inAir(t) then
                        trigger.action.outTextForGroup(ctld.utils.getGroupId(t),
                            ctld.tr("You must land before you can load a crate!"), 10)
                        return
                    end
                    local caps_t   = (ctld.gs("capabilitiesByType") or {})[t:getTypeName()]
                    local capacity = (caps_t and caps_t.maxCratesOnboard) or 1
                    local onboard  = 0
                    local mgr = CTLDCrateManager.getInstance()
                    for _, c in pairs(mgr.crates) do
                        if c:isLoaded() and c.loadedBy == t then onboard = onboard + 1 end
                    end
                    if onboard >= capacity then
                        trigger.action.outTextForGroup(ctld.utils.getGroupId(t),
                            ctld.tr("Maximum number of crates are on board!", onboard, capacity), 10)
                        return
                    end
                    local candidates = mgr:getCratesInRange(t:getPoint(), 50)
                    local best, bestDist = nil, math.huge
                    for _, c in ipairs(candidates) do
                        if c.descriptor and c.descriptor.desc == arg.crateDesc then
                            local d = ctld.utils.getDistance("loadCrate", t:getPoint(), c.position)
                            if d < bestDist then bestDist = d; best = c end
                        end
                    end
                    if not best then
                        trigger.action.outTextForGroup(ctld.utils.getGroupId(t),
                            ctld.tr("No crates within 50m to load!"), 10)
                        mgr:refreshLoadCrateSectionForUnit(arg.unitName)
                        return
                    end
                    mgr:loadCrate(best.crateName, t)
                    trigger.action.outTextForGroup(ctld.utils.getGroupId(t),
                        ctld.tr("Loaded %1 crate!", best.descriptor.desc), 10)
                end,
                { unitName = playerObj.unitName, crateDesc = desc })
        end
    end
    menu:refresh()
end

--- Refresh the "Unpack Crate" submenu for a single player by unit name.
-- @param unitName string
function CTLDCrateManager:refreshUnpackSectionForUnit(unitName)
    local playerObj = CTLDPlayerManager.getInstance()._players[unitName]
    if not playerObj then return end
    -- Both sub-refreshes update the memory model without triggering a DCS rebuild.
    -- A single refresh() at the end coalesces all changes into one DCS round-trip,
    -- preventing the CH-47 native-cargo tick from ejecting the player from the menu.
    self:refreshUnpackSection(playerObj, true)
    self:refreshPackEquiptSection(playerObj, nil, true)
    local menu = ctld.MenuManager:getInstance():getMenuByGroupId(playerObj.groupId)
    if menu then menu:refresh() end
end

--- Rebuild the "Unpack Crate" dynamic submenu for playerObj.
-- Lists assembleable crate sets (count >= cratesRequired) within 300 m.
-- Each entry spawns the vehicle at unpack time.
-- Called on land, crate spawn, crate cleared.
-- @param playerObj CTLDPlayer
function CTLDCrateManager:refreshUnpackSection(playerObj, _noRefresh)
    local caps = (ctld.gs("capabilitiesByType") or {})[playerObj.typeName]
    if not (playerObj.isTransport and caps and caps.cratesEnabled) then return end

    local mm   = ctld.MenuManager:getInstance()
    local menu = mm:getMenuByGroupId(playerObj.groupId)
    if not menu then return end

    local root      = ctld.tr("CTLD")
    local cratesSub = ctld.tr("Crate Commands")
    local unpackSub = ctld.tr("Unpack Crate")

    menu:clearBranch({ root, cratesSub, unpackSub })

    local transport = Unit.getByName(playerObj.unitName)
    if not (transport and transport:isExist()) or ctld.utils.inAir(transport) then
        menu:addCommand({ root, cratesSub, unpackSub },
            ctld.tr("Land to unpack crates"), function() end, {})
         if not _noRefresh then menu:refresh() end
        return
    end

    local nearby = self:getCratesInRange(transport:getPoint(), 300)

    -- Group ground crates by descriptor.unit.
    -- Scene crates (unit matches a registered CTLDSceneManager model) are counted separately.
    local byUnit      = {}   -- [unitType] = { count, descriptor }
    local unitOrder   = {}
    local sceneCounts = {}   -- [sceneName] = count
    local sm_ref      = CTLDSceneManager.getInstance()
    for _, crate in ipairs(nearby) do
        if crate:isOnGround() and crate.canBeUnpacked
            and crate.descriptor and crate.descriptor.unit
        then
            local ut = crate.descriptor.unit
            if sm_ref:getModel(ut) then
                sceneCounts[ut] = (sceneCounts[ut] or 0) + 1
            else
                if not byUnit[ut] then
                    byUnit[ut] = { count = 0, descriptor = crate.descriptor }
                    table.insert(unitOrder, ut)
                end
                byUnit[ut].count = byUnit[ut].count + 1
            end
        end
    end

    local hasAny = false

    -- Standard vehicle unpack entries (non-FOB)
    for _, ut in ipairs(unitOrder) do
        local info     = byUnit[ut]
        local required = info.descriptor.cratesRequired or 1
        if info.count >= required then
            hasAny = true
            local label = string.format("%s (%d/%d)", info.descriptor.desc, info.count, required)
            menu:addCommand({ root, cratesSub, unpackSub }, label,
                function(arg)
                    local t = Unit.getByName(arg.unitName)
                    if not (t and t:isExist()) then return end
                    local gid = ctld.utils.getGroupId(t)
                    if ctld.utils.inAir(t) then
                        trigger.action.outTextForGroup(gid,
                            ctld.tr("You must land before unpacking crates!"), 10)
                        return
                    end
                    local mgr   = CTLDCrateManager.getInstance()
                    local nearC = mgr:getCratesInRange(t:getPoint(), 300)
                    -- Collect crates for unpack
                    local toUnpack = {}
                    for _, c in ipairs(nearC) do
                        if c:isOnGround() and c.canBeUnpacked
                            and c.descriptor
                            and c.descriptor.unit == arg.unitType
                        then
                            table.insert(toUnpack, c)
                            if #toUnpack >= arg.cratesRequired then break end
                        end
                    end
                    if #toUnpack < arg.cratesRequired then
                        trigger.action.outTextForGroup(gid,
                            ctld.tr("Not enough crates nearby to unpack!"), 10)
                        mgr:refreshUnpackSectionForUnit(arg.unitName)
                        return
                    end
                    -- Delegate to AA assembly manager if this crate belongs to an AA template.
                    -- CTLDCrateAssemblyManager handles repair/rearm/assembly with correct
                    -- DCS type names and its own 100m offset + 50m radius placement.
                    local aaMgr = CTLDCrateAssemblyManager.getInstance()
                    if aaMgr:tryUnpackOrRepair(t, toUnpack[1], mgr.crates) then
                        -- AA manager consumed the action — also destroy the other collected crates
                        -- (tryUnpackOrRepair only destroys what it assembles internally).
                        -- Note: for single-crate AA parts tryUnpackOrRepair already handles destruction.
                        return
                    end

                    -- Standard (non-AA) path: unpack crates, spawn vehicle ≥ 50 m away.
                    for _, c in ipairs(toUnpack) do
                        mgr:unpackCrate(c.crateName, t)
                    end
                    local MIN_UNPACK_DIST = 50
                    local safeDist = math.max(
                        MIN_UNPACK_DIST,
                        (ctld.utils.getSecureDistanceFromUnit(arg.unitName) or 10) + 5)
                    local spawnInfo = ctld.utils.getSpawnObjectPositions(t, 1, safeDist)
                    local spawnPos  = spawnInfo.positions[1]
                    local desc = arg.descriptor
                    if desc and desc.unit and spawnPos then
                        local coa = arg.coalition
                        local cId = (coa == coalition.side.RED) and country.id.RUSSIA or country.id.USA
                        mgr:_spawnUnpacked(desc, spawnPos, coa, cId, playerObj.unitName)
                    end
                    trigger.action.outTextForGroup(gid,
                        ctld.tr("%1 unpacked successfully!", arg.descriptor.desc), 10)
                end,
                {
                    unitName       = playerObj.unitName,
                    groupId        = playerObj.groupId,
                    coalition      = playerObj.coalition,
                    unitType       = ut,
                    cratesRequired = required,
                    descriptor     = info.descriptor,
                })
        end
    end

    -- Generic scene unpack entries: one per registered scene model with enough nearby crates.
    -- Sorted by crate weight for deterministic menu order.
    -- If model.crate.unpack exists, it handles the unpack directly (e.g. FOB → CTLDFOBManager).
    -- Otherwise: ground check + consume cratesRequired crates + CTLDSceneManager:playScene().
    local sortedScenes = {}
    for sceneName, count in pairs(sceneCounts) do
        local model = sm_ref:getModel(sceneName)
        if model and model.crate then
            local cd       = model.crate
            local required = cd.cratesRequired or 1
            if count >= required then
                table.insert(sortedScenes, { name = sceneName, count = count, cd = cd, model = model })
            end
        end
    end
    table.sort(sortedScenes, function(a, b) return (a.cd.weight or 0) < (b.cd.weight or 0) end)

    for _, entry in ipairs(sortedScenes) do
        hasAny = true
        local sceneName = entry.name
        local cd        = entry.cd
        local required  = cd.cratesRequired or 1
        local label     = string.format("%s (%d/%d)", ctld.tr(cd.deployKey or ("Deploy " .. sceneName)), entry.count, required)

        if cd.unpack then
            -- Custom unpack path (e.g. FOB): delegate entirely to the model's unpack function.
            -- sceneName is passed so the handler can filter crates by exact type (multi-FOB support).
            menu:addCommand({ root, cratesSub, unpackSub }, label,
                function(arg)
                    local t = Unit.getByName(arg.unitName)
                    if not (t and t:isExist()) then return end
                    arg.cd.unpack(t, arg.unitName, arg.sceneName)
                end,
                { unitName = playerObj.unitName, cd = cd, sceneName = sceneName })
        else
            -- Generic scene path: ground check + consume crates + playScene.
            local groundErrKey = cd.groundKey or "You must land before unpacking crates!"
            menu:addCommand({ root, cratesSub, unpackSub }, label,
                function(arg)
                    local t = Unit.getByName(arg.unitName)
                    if not (t and t:isExist()) then return end
                    local gid = ctld.utils.getGroupId(t)
                    if ctld.utils.inAir(t) then
                        trigger.action.outTextForGroup(gid, ctld.tr(arg.groundErrKey), 10)
                        return
                    end
                    local mgr      = CTLDCrateManager.getInstance()
                    local nearC     = mgr:getCratesInRange(t:getPoint(), 300)
                    local toConsume = {}
                    for _, c in ipairs(nearC) do
                        if c:isOnGround() and c.canBeUnpacked
                            and c.descriptor and c.descriptor.unit == arg.sceneName
                            and #toConsume < arg.cratesRequired
                        then
                            toConsume[#toConsume + 1] = c
                        end
                    end
                    if #toConsume < arg.cratesRequired then
                        trigger.action.outTextForGroup(gid,
                            ctld.tr("Not enough crates nearby to unpack!"), 10)
                        mgr:refreshUnpackSectionForUnit(arg.unitName)
                        return
                    end
                    -- Extract repackData from crates before unpacking (metadata survives the loop).
                    local repackData = nil
                    for _, c in ipairs(toConsume) do
                        if c.metadata and c.metadata.warehouseSnapshot and not repackData then
                            repackData = { warehouseSnapshot = c.metadata.warehouseSnapshot }
                        end
                        mgr:unpackCrate(c.crateName, t)
                    end
                    local _uName = arg.unitName
                    CTLDSceneManager.getInstance():playScene(t, arg.sceneName,
                        repackData and { repackData = repackData } or nil,
                        function()
                            CTLDCrateManager.getInstance():refreshUnpackSectionForUnit(_uName)
                        end)
                end,
                {
                    unitName      = playerObj.unitName,
                    sceneName     = sceneName,
                    cratesRequired = required,
                    groundErrKey  = groundErrKey,
                })
        end
    end

    if not hasAny then
        menu:addCommand({ root, cratesSub, unpackSub },
            ctld.tr("No complete crate sets nearby"), function() end, {})
    end
     if not _noRefresh then menu:refresh() end
end

--- Rebuild the unified "Pack Equipt" dynamic submenu for playerObj.
-- Appears only when enableFARPRepack or enablePackingVehicles is true.
-- Visible only when on the ground — absent in flight.
-- Lists repackable FARP scenes (within 300 m) and packable vehicles nearby.
-- @param playerObj CTLDPlayer
function CTLDCrateManager:refreshPackEquiptSection(playerObj, overrideInAir, _noRefresh)
    local farpEnabled    = ctld.gs("enableFARPRepack") == true
    local vehicleEnabled = ctld.gs("enablePackingVehicles") == true
    if not (farpEnabled or vehicleEnabled) then return end

    local caps = (ctld.gs("capabilitiesByType") or {})[playerObj.typeName]
    if not (playerObj.isTransport and caps and caps.cratesEnabled) then return end

    local mm   = ctld.MenuManager:getInstance()
    local menu = mm:getMenuByGroupId(playerObj.groupId)
    if not menu then return end

    local root      = ctld.tr("CTLD")
    local cratesSub = ctld.tr("Crate Commands")
    local packSub   = ctld.tr("Pack Equipt")

    -- Ensure Pack Equipt node exists before clearBranch/setBranchEnabled operate on it.
    menu:addSubMenu({ root, cratesSub }, packSub, { order = 25 })
    menu:clearBranch({ root, cratesSub, packSub })

    local transport = Unit.getByName(playerObj.unitName)
    if not (transport and transport:isExist()) then
        if not _noRefresh then menu:refresh() end
        return
    end

    -- In-flight: submenu absent.
    -- overrideInAir: true = force flight, false = force ground, nil = use _isFlying flag / inAir().
    local inAir
    if overrideInAir ~= nil then
        inAir = overrideInAir
    elseif playerObj._isFlying ~= nil then
        inAir = playerObj._isFlying
    else
        inAir = ctld.utils.inAir(transport)
    end
    if inAir then
        -- clearBranch empties children but keeps the node in the tree (enabled=true).
        -- setBranchEnabled hides it from DCS rendering on next refresh().
        menu:setBranchEnabled({ root, cratesSub, packSub }, false)
        if not _noRefresh then menu:refresh() end
        return
    end

    -- On ground: ensure node is visible before (re-)populating it.
    menu:setBranchEnabled({ root, cratesSub, packSub }, true)

    -- Collect FARP scenes to pack.
    local scenes = {}
    if farpEnabled then
        local sm = CTLDSceneManager.getInstance()
        scenes = sm:findNearbyRepackableScenes(transport:getPoint(), 300)
    end

    -- Collect packable vehicles.
    local packableVehicles = {}
    if vehicleEnabled then
        packableVehicles = CTLDVehicleSpawner.getInstance():findPackableVehicles(transport)
    end

    -- If nothing to pack, hide the submenu and return.
    if #scenes == 0 and #packableVehicles == 0 then
        menu:setBranchEnabled({ root, cratesSub, packSub }, false)
        if not _noRefresh then menu:refresh() end
        return
    end

    -- FARP entries
    for _, scene in ipairs(scenes) do
        local label = ctld.tr("Pack %1", scene._modelName)
        menu:addCommand({ root, cratesSub, packSub }, label,
            function(arg)
                ctld.utils.log("INFO", "[PackCallback] ENTER unitName=%s sceneName=%s",
                    tostring(arg.unitName), tostring(arg.sceneName))
                trigger.action.outText("[PackCallback] ENTER "..tostring(arg.unitName), 8)
                local t = Unit.getByName(arg.unitName)
                if not (t and t:isExist()) then
                    ctld.utils.log("INFO", "[PackCallback] unit not found: %s", tostring(arg.unitName))
                    return
                end
                local gid = ctld.utils.getGroupId(t)
                if ctld.utils.inAir(t) then
                    trigger.action.outTextForGroup(gid,
                        ctld.tr("You must be on the ground to pack a FARP."), 10)
                    return
                end
                local smgr = CTLDSceneManager.getInstance()
                local sc   = smgr._active[arg.sceneName]
                if not sc then
                    trigger.action.outTextForGroup(gid,
                        ctld.tr("FARP no longer deployed."), 10)
                    return
                end
                local model = smgr:getModel(sc._modelName)
                local cd    = model and model.crate
                local mgr_c = CTLDCrateManager.getInstance()
                local desc  = mgr_c:findDescriptorByUnitType(sc._modelName)
                if not (cd and desc) then return end
                local repackData = smgr:packScene(sc)
                local required  = cd.cratesRequired or 1
                local safeDist  = (ctld.utils.getSecureDistanceFromUnit(arg.unitName) or 10) + 5
                local spacing   = ctld.gs("crateSpacing") or 5
                local spawnInfo = ctld.utils.getSpawnObjectPositions(t, required, safeDist, spacing)
                local modelKey  = mgr_c:_crateModelKey(t)
                for i = 1, required do
                    local spos = spawnInfo.positions[i]
                    if spos then
                        local crate = mgr_c:spawnCrate(
                            desc, spos, t:getCoalition(), t:getName(),
                            CTLDCrate.SPAWN_METHOD.CRATE_SPAWN, t:getCountry(), modelKey)
                        if crate and repackData and repackData.warehouseSnapshot then
                            crate.metadata.warehouseSnapshot = repackData.warehouseSnapshot
                        end
                    end
                end
                trigger.action.outTextForGroup(gid, ctld.tr("FARP packed successfully!"), 10)
                mgr_c:refreshUnpackSectionForUnit(arg.unitName)
            end,
            { unitName = playerObj.unitName, sceneName = scene._name })
    end

    -- Vehicle entries
    for _, v in ipairs(packableVehicles) do
        menu:addCommand({ root, cratesSub, packSub }, v.descriptor.desc,
            function(arg)
                CTLDVehicleSpawner.getInstance():packVehicle(
                    arg.transportName, arg.packableUnitName, arg)
            end,
            { transportName    = playerObj.unitName,
              packableUnitName = v.unitName,
              groupId          = playerObj.groupId,
              unitName         = playerObj.unitName,
              coalition        = playerObj.coalition })
    end

    if not _noRefresh then menu:refresh() end
end

--- Replace the parachute visual effect handler.
-- @param effect CTLDParachuteEffect
function CTLDCrateManager:setParachuteEffect(effect)
    self._parachuteEffect = effect
end

--- Returns the total CTLD-managed crate weight loaded on a transport.
--- DCS-native loaded crates are excluded (isLoadedByCTLD guard: dcsStatic still alive).
--- @param unitName string  transport unit name
--- @return number  kg
function CTLDCrateManager:getLoadedCrateWeight(unitName)
    local total = 0
    for _, crate in pairs(self.crates) do
        if crate:isLoadedByCTLD()
           and crate.loadedBy and crate.loadedBy:isExist() and crate.loadedBy:getName() == unitName then
            total = total + (crate.descriptor and crate.descriptor.weight or 0)
        end
    end
    return total
end

-- ============================================================
-- Feature B — Virtual Slingload
-- ============================================================

--- Return the first slingloaded crate for a given transport, or nil.
-- @param transport Unit
-- @return CTLDCrate or nil
function CTLDCrateManager:_getSlingloadedCrate(transport)
    for _, crate in pairs(self.crates) do
        if crate.inTransitOnSlingload and crate.loadedBy == transport then
            return crate
        end
    end
    return nil
end

--- Polling tick (1 s). Called by the timer loop started in getInstance().
-- For each active player with canSlingload=true in capabilitiesByType and in-air transport:
--   1. Overspeed check: if speed > maxSlingloadSpeed → crate lost.
--   2. Hover pickup: find nearest eligible ground crate, count down hoverTime,
--      then hook it (load + destroy DCS static + publish OnCrateLoaded).
function CTLDCrateManager:checkHoverStatus()
    -- Reschedule unconditionally
    timer.scheduleFunction(function()
        CTLDCrateManager.getInstance():checkHoverStatus()
    end, {}, timer.getTime() + 1)

    -- Scan for crates destroyed by combat (S_EVENT_DEAD not reliable for statics).
    -- isOnGround() now checks dcsStatic:isExist(), so a stale SPAWNED crate whose
    -- static was destroyed will return false — unregister it and refresh nearby menus.
    for name, crate in pairs(self.crates) do
        if (crate.state == CTLDCrate.STATE.SPAWNED or crate.state == CTLDCrate.STATE.LANDED)
            and crate.dcsStatic
            and not crate.dcsStatic:isExist()
        then
            local pos = crate.position
            self:_unregister(name)
            ctld.utils.log("INFO",
                "CTLDCrateManager:checkHoverStatus — unregistered dead static crate: %s", name)
            if pos then self:_refreshNearbyPlayers(pos) end
        end
    end

    -- DCS-native cargo detection (always, independent of slingload config)
    self:_checkNativeDCSCargo()

    if ctld.gs("enableHoverSlingload") ~= true then return end

    local maxDist     = ctld.gs("maxDistanceFromCrate") or 5.5
    local minH        = ctld.gs("minimumHoverHeight")   or 7.5
    local maxH        = ctld.gs("maximumHoverHeight")   or 12.0
    local hoverTime   = ctld.gs("hoverTime")            or 10
    local maxSpeed    = ctld.gs("maxSlingloadSpeed")    or 50

    local players = CTLDPlayerManager.getInstance()._players

    for unitName, playerObj in pairs(players) do
        local caps = (ctld.gs("capabilitiesByType") or {})[playerObj.typeName]
        if caps and caps.canSlingload then
            local transport = Unit.getByName(unitName)
            if transport and transport:isExist() and ctld.utils.inAir(transport) then

                -- 1. Overspeed check
                local vel   = transport:getVelocity()
                local speed = math.sqrt(vel.x * vel.x + vel.y * vel.y + vel.z * vel.z)
                if speed > maxSpeed then
                    local lost = self:_getSlingloadedCrate(transport)
                    if lost then
                        lost.inTransitOnSlingload = false
                        lost:destroy()
                        self:_unregister(lost.crateName)
                        self:_publish("OnCrateLost", {
                            crate     = lost,
                            crateName = lost.crateName,
                            coalition = lost.coalition,
                            transport = transport,
                            trigger   = "slingload_overspeed",
                            timestamp = timer.getAbsTime(),
                        })
                        trigger.action.outTextForGroup(playerObj.groupId,
                            ctld.tr("Too fast! Slingloaded crate lost: %1", lost.descriptor.desc), 10)
                        CTLDPlayerManager.getInstance():refreshForUnit(unitName)
                    end
                    self._hoverStatus[unitName] = nil

                else
                    -- 2. Hover pickup (only if below capacity)
                    local count = 0
                    for _, c in pairs(self.crates) do
                        if c.inTransitOnSlingload and c.loadedBy == transport then
                            count = count + 1
                        end
                    end
                    local _caps_sl = ((ctld.gs("capabilitiesByType") or {})[playerObj.typeName]) or {}
                    local capacity = _caps_sl.maxCratesOnboard or 1

                    if count < capacity then
                        local transportPos  = transport:getPoint()
                        local nearestCrate  = nil
                        local nearestDist   = math.huge
                        local warnTooLow    = false
                        local warnTooHigh   = false

                        local _sm_sling = CTLDSceneManager.getInstance()
                        for _, crate in pairs(self.crates) do
                            local _unit = crate.descriptor and crate.descriptor.unit
                            if crate:isOnGround()
                                and crate.descriptor
                                and not (_unit and _sm_sling:getModel(_unit))
                            then
                                local cratePos = (crate.dcsStatic and crate.dcsStatic:isExist())
                                    and crate.dcsStatic:getPoint()
                                    or  crate.position
                                local dist = ctld.utils.getDistance("checkHoverStatus", transportPos, cratePos)
                                if dist < maxDist then
                                    local heightDiff = transportPos.y - cratePos.y
                                    if heightDiff >= minH and heightDiff <= maxH then
                                        if dist < nearestDist then
                                            nearestCrate = crate
                                            nearestDist  = dist
                                        end
                                    elseif heightDiff < minH then
                                        warnTooLow = true
                                    else
                                        warnTooHigh = true
                                    end
                                end
                            end
                        end

                        if nearestCrate then
                            if self._hoverStatus[unitName] == nil then
                                self._hoverStatus[unitName] = hoverTime
                            end
                            self._hoverStatus[unitName] = self._hoverStatus[unitName] - 1
                            if self._hoverStatus[unitName] > 0 then
                                trigger.action.outTextForGroup(playerObj.groupId,
                                    string.format(
                                        ctld.tr("Hovering above %s crate.\n\nHold hover for %d seconds!\n\nIf the countdown stops you're too far away!"),
                                        nearestCrate.descriptor.desc,
                                        self._hoverStatus[unitName]), 10, true)
                            else
                                self._hoverStatus[unitName] = nil
                                nearestCrate.inTransitOnSlingload = true
                                nearestCrate:load(transport)
                                if nearestCrate.dcsStatic and nearestCrate.dcsStatic:isExist() then
                                    nearestCrate.dcsStatic:destroy()
                                    nearestCrate.dcsStatic = nil
                                end
                                trigger.action.outTextForGroup(playerObj.groupId,
                                    ctld.tr("Slingloaded %1 crate!", nearestCrate.descriptor.desc), 10, true)
                                ctld.utils.updateTransportWeight(unitName)
                                self:_publish("OnCrateLoaded", {
                                    crate           = nearestCrate,
                                    crateName       = nearestCrate.crateName,
                                    carrierUnitName = transport:getName(),
                                    coalition       = nearestCrate.coalition,
                                    descriptor      = nearestCrate.descriptor,
                                    trigger         = "slingload",
                                    timestamp       = timer.getAbsTime(),
                                })
                                CTLDPlayerManager.getInstance():refreshForUnit(unitName)
                                self:refreshCrateFlightSectionForUnit(unitName)
                            end
                        else
                            if warnTooLow then
                                trigger.action.outTextForGroup(playerObj.groupId,
                                    ctld.tr("Too low to hook crate.\n\nHold hover for %1 seconds", hoverTime), 5, true)
                            elseif warnTooHigh then
                                trigger.action.outTextForGroup(playerObj.groupId,
                                    ctld.tr("Too high to hook crate.\n\nHold hover for %1 seconds", hoverTime), 5, true)
                            end
                            self._hoverStatus[unitName] = nil
                        end
                    else
                        self._hoverStatus[unitName] = nil
                    end
                end

            else
                -- Not in air: reset hover counter
                self._hoverStatus[unitName] = nil
            end
        end
    end
end

--- Return true if world-space point `pt` is inside the bounding box of `unitPos`.
-- unitPos : result of unit:getPosition() = { p=Vec3, x=Vec3, y=Vec3, z=Vec3 }
-- bbox    : { min=Vec3, max=Vec3 } in local coords (from unit:getDesc().box)
-- margin  : extra metres added on every face (default 0)
local function _pointInBBox(unitPos, bbox, pt, margin)
    margin = margin or 0
    local dx = pt.x - unitPos.p.x
    local dy = pt.y - unitPos.p.y
    local dz = pt.z - unitPos.p.z
    local lx = dx * unitPos.x.x + dy * unitPos.x.y + dz * unitPos.x.z
    local ly = dx * unitPos.y.x + dy * unitPos.y.y + dz * unitPos.y.z
    local lz = dx * unitPos.z.x + dy * unitPos.z.y + dz * unitPos.z.z
    return lx >= (bbox.min.x - margin) and lx <= (bbox.max.x + margin)
       and ly >= (bbox.min.y - margin) and ly <= (bbox.max.y + margin)
       and lz >= (bbox.min.z - margin) and lz <= (bbox.max.z + margin)
end

--- Detect DCS-native cargo load/unload via bounding-box containment (1 s tick).
-- Called from checkHoverStatus() unconditionally.
--
-- No S_EVENT_CARGO_LOADED / S_EVENT_CARGO_UNLOADED exists in the DCS API.
-- Detection is purely positional:
--   LOAD  : crate.dcsStatic:getPoint() is inside the transport's 3-D bounding box.
--           Works while the aircraft is still on the ground (before takeoff),
--           so CTLD marks the crate as taken before any other transport sees it.
--   UNLOAD: crate state is LOADED (via dcs_native, so dcsStatic still exists),
--           and the static's current position is now OUTSIDE the transport's bbox.
--
-- CTLD-managed loads call crate:destroy() → dcsStatic = nil: those crates are
-- silently skipped here (outer check `dcsStatic and dcsStatic:isExist()`).
function CTLDCrateManager:_checkNativeDCSCargo()

    -- Build candidate transport list (ALL dynamic transports, ground OR air).
    -- We pre-fetch position and bbox so we don't call getPosition()/getDesc()
    -- more than once per transport per tick.
    local pm         = CTLDPlayerManager.getInstance()
    local transports = {}   -- array of { transport, unitName, playerObj, unitPos, bbox }
    for unitName, playerObj in pairs(pm._players) do
        local transport = Unit.getByName(unitName)
        if transport and transport:isExist() and self:_isDynamicCapable(transport) then
            local desc = transport:getDesc()
            if desc and desc.box then
                transports[#transports + 1] = {
                    transport = transport,
                    unitName  = unitName,
                    playerObj = playerObj,
                    unitPos   = transport:getPosition(),
                    bbox      = desc.box,
                }
            end
        end
    end

    for _, crate in pairs(self.crates) do
        local dcsStatic = crate.dcsStatic
        if dcsStatic and dcsStatic:isExist() then
            local cratePos = dcsStatic:getPoint()

            -- ── LOAD detection ─────────────────────────────────────────────
            -- Crate is on ground AND its static is inside a transport's bbox.
            -- 0.5 m margin to account for attachment offsets.
            -- Speed guard: DCS Dynamic Cargo UI is only accessible when the aircraft
            -- is stationary on the ground.  A transport that is taxiing can sweep its
            -- bbox over a parked crate and trigger a false positive.  We reject any
            -- entry whose ground-speed exceeds 0.5 m/s (speed² > 0.25).
            if crate:isOnGround() then
                for _, entry in ipairs(transports) do
                    local vel  = entry.transport:getVelocity()
                    local spd2 = vel.x * vel.x + vel.y * vel.y + vel.z * vel.z
                    if spd2 <= 0.25 and _pointInBBox(entry.unitPos, entry.bbox, cratePos, 0.5) then
                        local _caps = (ctld.gs("capabilitiesByType") or {})[entry.transport:getTypeName()]
                        local _convertToCTLD = _caps and _caps.convertNativeLoadToCTLD

                        if _convertToCTLD then
                            -- Undo the DCS UI load, then trigger the full CTLD load path
                            -- (identical to the F10 menu): UnloadCargo() releases the DCS
                            -- cargo slot; after DCS processes the release (0.5 s), loadCrate()
                            -- handles state transition, static destruction, weight update,
                            -- OnCrateLoaded + OnCrateCleared events, and menu refresh.
                            local _origStatic = crate.dcsStatic
                            local _crateName  = crate.crateName
                            local _transport  = entry.transport
                            local _unitName   = entry.unitName
                            local _groupId    = entry.playerObj.groupId
                            local _okUL, _errUL = pcall(function() _transport:UnloadCargo(_origStatic) end)
                            if not _okUL then
                                ctld.utils.log("WARN", "CTLDCrateManager: UnloadCargo failed: %s", tostring(_errUL))
                            end
                            timer.scheduleFunction(function()
                                self:loadCrate(_crateName, _transport)
                                local _c = self.crates[_crateName]
                                local _lbl = _c and _c.descriptor and _c.descriptor.desc or _crateName
                                ctld.utils.log("INFO",
                                    "CTLDCrateManager: DCS UI LOAD → CTLD-managed — crate=%s carrier=%s",
                                    _crateName, _unitName)
                                trigger.action.outTextForGroup(_groupId,
                                    string.format("[CTLD] Crate loaded (parachute-ready): %s", _lbl), 8)
                            end, nil, timer.getTime() + 0.5)
                        else
                            -- DCS-native: memorize local-frame offset for drift-based unload
                            -- detection, mark as DCS-managed (no parachute available in-flight).
                            local up = entry.unitPos
                            local dx = cratePos.x - up.p.x
                            local dy = cratePos.y - up.p.y
                            local dz = cratePos.z - up.p.z
                            self._nativeCrateLink[crate.crateName] = {
                                lx = dx * up.x.x + dy * up.x.y + dz * up.x.z,
                                ly = dx * up.y.x + dy * up.y.y + dz * up.y.z,
                                lz = dx * up.z.x + dy * up.z.y + dz * up.z.z,
                            }
                            crate:load(entry.transport)
                            crate.loadedByDCSNative = true
                            self:_publish("OnCrateLoaded", {
                                crate           = crate,
                                crateName       = crate.crateName,
                                carrierUnitName = entry.unitName,
                                coalition       = crate.coalition,
                                descriptor      = crate.descriptor,
                                method          = "dcs_native",
                                timestamp       = timer.getAbsTime(),
                            })
                            pm:refreshForUnit(entry.unitName)
                            self:refreshUnpackSectionForUnit(entry.unitName)
                            self:refreshCrateFlightSectionForUnit(entry.unitName)
                            local _descLabel = crate.descriptor and crate.descriptor.desc or crate.crateName
                            ctld.utils.log("INFO",
                                "CTLDCrateManager: DCS native LOAD (DCS-managed, no parachute) — crate=%s carrier=%s",
                                crate.crateName, entry.unitName)
                            trigger.action.outTextForGroup(entry.playerObj.groupId,
                                string.format("[CTLD] Crate loaded (DCS native): %s", _descLabel), 8)
                        end
                        break
                    end
                end

            -- ── UNLOAD detection ───────────────────────────────────────────
            -- Crate is LOADED and dcsStatic is still alive → DCS-native path.
            -- (CTLD-managed loads destroy the static → dcsStatic = nil, never reach here.)
            -- Detect unload by local-frame offset drift: recompute {lx,ly,lz} each tick
            -- and compare to linkOffsetRef memorised at load time.
            -- DCS places the released crate *behind* the aircraft (collision avoidance),
            -- so the offset changes immediately on release — seuil 1 m is sufficient.
            elseif crate:isLoaded() then
                local transport = crate.loadedBy
                if not transport or not transport:isExist() then
                    -- Transport destroyed while crate was natively loaded: reset.
                    self._nativeCrateLink[crate.crateName] = nil
                    crate.position     = cratePos
                    crate.state        = CTLDCrate.STATE.LANDED
                    crate.loadedBy     = nil
                    crate.loadTime     = nil
                    crate.fromParachute = false
                    ctld.utils.log("INFO",
                        "CTLDCrateManager: DCS native UNLOAD (transport lost) — crate=%s",
                        crate.crateName)
                else
                    local ref = self._nativeCrateLink[crate.crateName]
                    if ref then
                        local up = transport:getPosition()
                        local dx = cratePos.x - up.p.x
                        local dy = cratePos.y - up.p.y
                        local dz = cratePos.z - up.p.z
                        local lx = dx * up.x.x + dy * up.x.y + dz * up.x.z
                        local ly = dx * up.y.x + dy * up.y.y + dz * up.y.z
                        local lz = dx * up.z.x + dy * up.z.y + dz * up.z.z
                        local dlx = lx - ref.lx
                        local dly = ly - ref.ly
                        local dlz = lz - ref.lz
                        local drift = math.sqrt(dlx*dlx + dly*dly + dlz*dlz)
                        if drift > 1.0 then
                            local carrierName = transport:getName()
                            local playerObj   = pm:getPlayer(carrierName)
                            -- Determine if transport is airborne at release time
                            local tp        = transport:getPoint()
                            local groundH   = land.getHeight({ x = tp.x, y = tp.z })
                            local inFlight  = (tp.y - groundH) > 5
                            self._nativeCrateLink[crate.crateName] = nil
                            crate.position = cratePos
                            crate.loadedBy = nil
                            crate.loadTime = nil
                            if inFlight then
                                -- DCS physically simulates the parachute descent.
                                -- Stay FALLING until the static actually touches ground.
                                crate.state         = CTLDCrate.STATE.FALLING
                                crate.fromParachute = true
                            else
                                crate.state = CTLDCrate.STATE.LANDED
                            end
                            self:_publish("OnCrateUnloaded", {
                                crate      = crate,
                                crateName  = crate.crateName,
                                coalition  = crate.coalition,
                                descriptor = crate.descriptor,
                                method     = "dcs_native",
                                timestamp  = timer.getAbsTime(),
                            })
                            if playerObj then
                                pm:refreshForUnit(carrierName)
                                self:refreshUnpackSectionForUnit(carrierName)
                                self:refreshLoadCrateSection(playerObj)
                                self:refreshRequestEquipmentSection(playerObj)
                            end
                            ctld.utils.log("INFO",
                                "CTLDCrateManager: DCS native UNLOAD — crate=%s drift=%.2f inFlight=%s fromParachute=%s",
                                crate.crateName, drift, tostring(inFlight), tostring(crate.fromParachute))
                            local _descLabel2 = crate.descriptor and crate.descriptor.desc or crate.crateName
                            local _unloadMsg  = inFlight
                                and string.format("[CTLD] Crate falling (DCS native parachute): %s", _descLabel2)
                                or  string.format("[CTLD] Crate unloaded (DCS native): %s", _descLabel2)
                            if playerObj then
                                trigger.action.outTextForGroup(playerObj.groupId, _unloadMsg, 8)
                            end
                            if inFlight then
                                -- Poll dcsStatic altitude until ground contact, then auto-unpack.
                                self:_scheduleParachuteLandingPoll(crate)
                            end
                        end
                    end
                end
            end
        end
    end
end

--- Release the slingloaded crate safely (transport at or near ground, AGL ≤ maximumHoverHeight).
-- Refuses if transport AGL > maximumHoverHeight with an informational message.
-- Transitions crate: loaded → landed. Spawns at a position offset ahead of the transport.
-- Publishes OnCrateUnloaded(trigger="slingload_release").
-- @param transport    Unit
-- @param playerObj    table   {groupId, unitName}
function CTLDCrateManager:releaseSlingload(transport, playerObj)
    local crate = self:_getSlingloadedCrate(transport)
    if not crate then
        trigger.action.outTextForGroup(playerObj.groupId, ctld.tr("No slingloaded crate on board."), 8)
        return
    end

    local pos      = transport:getPoint()
    local groundH  = land.getHeight({ x = pos.x, y = pos.z })
    local agl      = pos.y - groundH
    local maxRelH  = ctld.gs("maximumHoverHeight") or 12.0

    if agl > maxRelH then
        trigger.action.outTextForGroup(playerObj.groupId,
            ctld.tr("Too high to release slingload. Descend below %1m AGL (current: %2m AGL).",
                math.floor(maxRelH), math.floor(agl)), 8)
        return
    end

    -- Spawn position: directly below transport on terrain
    local spawnPos = { x = pos.x, y = groundH, z = pos.z }
    crate.inTransitOnSlingload = false
    -- unloadCrate: transitions state, respawns static, publishes OnCrateUnloaded + OnCrateSpawned
    self:unloadCrate(crate.crateName, spawnPos, "slingload_release")
    trigger.action.outTextForGroup(playerObj.groupId,
        ctld.tr("%1 crate safely released.", crate.descriptor.desc), 10)
    CTLDPlayerManager.getInstance():refreshForUnit(playerObj.unitName)
    self:refreshCrateFlightSectionForUnit(playerObj.unitName)
end

--- Cut the slingload (emergency drop, any altitude).
-- AGL > 40m → crate is destroyed (too high, impact damage).
-- AGL ≤ 40m → crate lands at a position computed from transport inertia (no parachute delay).
-- Publishes OnCrateUnloaded(trigger="slingload_cut") or OnCrateLost(trigger="slingload_cut_impact").
-- @param transport    Unit
-- @param playerObj    table   {groupId, unitName}
function CTLDCrateManager:cutSlingload(transport, playerObj)
    local crate = self:_getSlingloadedCrate(transport)
    if not crate then
        trigger.action.outTextForGroup(playerObj.groupId, ctld.tr("No slingloaded crate on board."), 8)
        return
    end

    local pos      = transport:getPoint()
    local groundH  = land.getHeight({ x = pos.x, y = pos.z })
    local agl      = pos.y - groundH

    crate.inTransitOnSlingload = false

    if agl > 40.0 then
        -- Too high: crate destroyed on impact
        local lostPos = crate.position
        crate:destroy()
        self:_unregister(crate.crateName)
        ctld.utils.updateTransportWeight(transport:getName())
        trigger.action.outTextForGroup(playerObj.groupId,
            ctld.tr("Too high! %1 crate destroyed on impact.", crate.descriptor.desc), 10)
        self:_publish("OnCrateLost", {
            crate     = crate,
            crateName = crate.crateName,
            coalition = crate.coalition,
            transport = transport,
            trigger   = "slingload_cut_impact",
            timestamp = timer.getAbsTime(),
        })
        self:_publish("OnCrateCleared", {
            crateName  = crate.crateName,
            position   = lostPos,
            coalition  = crate.coalition,
            descriptor = crate.descriptor,
            reason     = "destroyed",
            timestamp  = timer.getAbsTime(),
        })
    else
        -- Drop with inertia drift (reuses FA calcDropPosition, descentRate=0 → immediate land)
        local landPos, _ = ctld.utils.calcDropPosition(transport, 0)
        crate:land(landPos)
        ctld.utils.updateTransportWeight(transport:getName())
        self:_respawnStatic(crate, landPos)
        trigger.action.outTextForGroup(playerObj.groupId,
            ctld.tr("%1 crate dropped below you.", crate.descriptor.desc), 10)
        self:_publish("OnCrateUnloaded", {
            crate           = crate,
            crateName       = crate.crateName,
            position        = landPos,
            coalition       = crate.coalition,
            method          = "slingload_cut",
            trigger         = "slingload_cut",
            timestamp       = timer.getAbsTime(),
        })
        -- Crate landed: notify nearby players it is loadable.
        self:_publish("OnCrateSpawned", {
            crate      = crate,
            crateName  = crate.crateName,
            position   = landPos,
            coalition  = crate.coalition,
            descriptor = crate.descriptor,
            spawnedBy  = nil,
            spawnMethod = "slingload_cut",
            timestamp  = timer.getAbsTime(),
        })
    end
    CTLDPlayerManager.getInstance():refreshForUnit(playerObj.unitName)
    self:refreshCrateFlightSectionForUnit(playerObj.unitName)
end

-- ============================================================
-- Internal helpers
-- ============================================================

local _log = ctld.utils.log

function CTLDCrateManager:_register(crate)
    self.crates[crate.crateName] = crate
end

--- S_EVENT_DEAD handler: remove a crate destroyed by combat from the registry.
-- Without this, the crate remains in self.crates with state SPAWNED, causing
-- getCratesInRange to count it and the Unpack menu to show wrong counts (e.g. 3/3
-- when only 2 physical crates exist).
function CTLDCrateManager:onCrateDead(event)
    if not event or not event.initiator then return end
    local ok, name = pcall(function() return event.initiator:getName() end)
    if not ok or not name then return end
    local crate = self.crates[name]
    if not crate then return end
    local pos = crate.dcsStatic and crate.dcsStatic:isExist()
        and crate.dcsStatic:getPoint() or nil
    self:_unregister(name)
    ctld.utils.log("INFO", "CTLDCrateManager:onCrateDead — crate destroyed by combat: %s", name)
    if pos then
        self:_refreshNearbyPlayers(pos)
    end
end

function CTLDCrateManager:_unregister(crateName)
    self.crates[crateName] = nil
end

function CTLDCrateManager:_publish(eventName, payload)
    EventDispatcher.getInstance():publish(eventName, payload)
end

-- ============================================================
-- Public API
-- ============================================================

--- Return true if the unit type is listed in dynamicCargoUnits (native DCS cargo system).
-- @param unit DCS Unit
-- @return bool
function CTLDCrateManager:_isDynamicCapable(unit)
    local caps = (ctld.gs("capabilitiesByType") or {})[unit:getTypeName()]
    return caps ~= nil and caps.useNativeDcsCargoSystem == true
end

--- Returns bbox descriptors for all DynamicCargo-capable transports except the requester.
-- Used by spawnCratesAligned to avoid spawning crates inside a neighbour's bbox.
-- @param requester  DCS Unit  the aircraft that requested the spawn (excluded from results)
-- @return array of { unitPos = unit:getPosition(), bbox = desc.box }
function CTLDCrateManager:_getDynamicBBoxes(requester)
    local pm      = CTLDPlayerManager.getInstance()
    local result  = {}
    local reqName = requester:getName()
    for unitName, _ in pairs(pm._players) do
        if unitName ~= reqName then
            local u = Unit.getByName(unitName)
            if u and u:isExist() and self:_isDynamicCapable(u) then
                local desc = u:getDesc()
                if desc and desc.box then
                    result[#result + 1] = { unitPos = u:getPosition(), bbox = desc.box }
                end
            end
        end
    end
    return result
end

--- Resolve the spawnableCratesModels key for a given transport unit.
-- Returns "dynamic" if the unit is in dynamicCargoUnits and slingLoad is off,
-- "sling" if slingLoad is enabled, "load" otherwise.
-- @param unit DCS Unit
-- @return string  "load" | "sling" | "dynamic"
function CTLDCrateManager:_crateModelKey(unit)
    if ctld.gs("slingLoad") then return "sling" end
    if self:_isDynamicCapable(unit) then return "dynamic" end
    return "load"
end

--- Spawn a new crate from the F10 menu or as the result of packing a vehicle.
-- Uses coalition.addStaticObject (Hoggit: DCS_func_addStaticObject).
-- @param descriptor  table         CTLD crate descriptor (from spawnableCrates)
-- @param position    vec3
-- @param coalitionId number        coalition.side.*
-- @param spawnedBy   string|nil    player/trigger name
-- @param spawnMethod string        CTLDCrate.SPAWN_METHOD.*
-- @param countryId   number|nil    DCS country id; if nil, derived from coalition
-- @param modelKey    string|nil    key in spawnableCratesModels ("load"|"sling"|"dynamic"); auto if nil
-- @return CTLDCrate or nil
--- Create one DCS static cargo object and return its name and handle.
-- Shared by spawnCrate (new crate) and _spawnStatic (crate returning to ground).
-- @param weight      number   cargo mass in kg
-- @param position    vec3     world position {x, y, z}
-- @param coalitionId number   coalition.side.*
-- @param countryId   number|nil  DCS country id; derived from coalitionId if nil
-- @param modelKey    string|nil  key in spawnableCratesModels; auto if nil
-- @param label       string|nil  human-readable content name (e.g. "FOB Crate")
--                               shown in the DCS cargo interface and F10 list.
--                               Sanitised: spaces→_, special chars stripped.
-- @return string name, StaticObject|nil  (nil if dynAddStatic failed)
function CTLDCrateManager:_spawnStatic(weight, position, coalitionId, countryId, modelKey, label)
    local models = ctld.gs("spawnableCratesModels") or {}
    local key    = modelKey or (ctld.gs("slingLoad") and "sling" or "load")
    local model  = models[key] or models["load"] or {}

    local cId = countryId
    if not cId then
        cId = (coalitionId == coalition.side.RED) and country.id.RUSSIA or country.id.USA
    end

    local uid  = ctld.utils.getNextUniqId()
    local name
    if label and label ~= "" then
        -- Sanitise: keep alphanumeric, dash, underscore; replace spaces with _
        local safe = label:gsub("%s+", "_"):gsub("[^%w%-%_]", "")
        name = string.format("CTLD_%s_%d", safe, uid)
    else
        name = string.format("CTLD_Crate_%d", uid)
    end
    local data = {
        name     = name,
        x        = position.x,
        y        = position.z,   -- dynAddStatic maps y → DCS world-Z axis
        heading  = 0,
        type     = model.type     or "ammo_cargo",
        canCargo = model.canCargo or false,
        mass     = weight,
        country  = cId,
        dead     = false,
    }
    if model.shape_name then data.shape_name = model.shape_name end

    local ok, err = pcall(function() ctld.utils.dynAddStatic("CTLDCrateManager:_spawnStatic", data) end)
    if not ok then
        _log("CTLDCrateManager:_spawnStatic - dynAddStatic failed: " .. tostring(err), "WARNING")
        return name, nil
    end
    return name, StaticObject.getByName(name)
end

function CTLDCrateManager:spawnCrate(descriptor, position, coalitionId, spawnedBy, spawnMethod, countryId, modelKey)
    if not (descriptor and position) then
        _log("CTLDCrateManager:spawnCrate - missing descriptor or position", "WARNING")
        return nil
    end

    local crateName, dcsStatic = self:_spawnStatic(
        descriptor.weight, position, coalitionId, countryId, modelKey, descriptor.desc)
    if not dcsStatic then return nil end

    local models  = ctld.gs("spawnableCratesModels") or {}
    local usedKey = modelKey or (ctld.gs("slingLoad") and "sling" or "load")
    local crate = CTLDCrate:new({
        crateName   = crateName,
        descriptor  = descriptor,
        spawnMethod = spawnMethod or CTLDCrate.SPAWN_METHOD.CRATE_SPAWN,
        position    = position,
        heading     = 0,
        coalition   = coalitionId,
        spawnedBy   = spawnedBy,
        dcsStatic   = dcsStatic,
        modelKey    = (models[usedKey] and usedKey) or "load",
    })
    self:_register(crate)

    self:_publish("OnCrateSpawned", {
        crate       = crate,
        crateName   = crateName,
        descriptor  = descriptor,
        position    = position,
        coalition   = coalitionId,
        spawnedBy   = spawnedBy,
        spawnMethod = crate.spawnMethod,
        timestamp   = timer.getAbsTime(),
    })

    timer.scheduleFunction(function()
        self:_refreshNearbyPlayers(position)
    end, {}, timer.getTime() + 0.001)

    return crate
end

--- Recreate the DCS static for a crate returning to ground (static was destroyed on load).
-- Generates a new unique name, re-indexes self.crates, updates crate.crateName/dcsStatic.
-- @param crate    CTLDCrate
-- @param position vec3
-- @return bool
function CTLDCrateManager:_respawnStatic(crate, position)
    local label = crate.descriptor and crate.descriptor.desc or nil
    local newName, dcsStatic = self:_spawnStatic(
        crate.descriptor.weight, position, crate.coalition, nil, crate.modelKey, label)
    if not dcsStatic then return false end

    self.crates[crate.crateName] = nil
    crate.crateName = newName
    crate.dcsStatic = dcsStatic
    self.crates[newName] = crate
    return true
end

--- Spawn N crates in a straight line from a transport unit.
-- The axis direction is chosen randomly within the front sector for standard
-- units, or within the rear sector for native-cargo-capable units, so that
-- successive multi-crate spawns land at different angles and do not overlap.
--   Front sector : [-45°, +45°]  relative to unit heading (axisOffsetDeg 315..45)
--   Rear  sector : [135°, 225°]  relative to unit heading (axisOffsetDeg 135..225)
--
-- @param descriptors  table   ordered list of descriptor tables (one per crate)
-- @param transport    Unit    the requesting/packing transport unit
-- @param coalitionId  number  coalition.side.*
-- @param spawnedBy    string  unit name for attribution
-- @param spawnMethod  string  CTLDCrate.SPAWN_METHOD.*
-- @return number spawned count, table spawnInfo {positions, clock, distance}
function CTLDCrateManager:spawnCratesAligned(descriptors, transport, coalitionId, spawnedBy, spawnMethod)
    -- Detect native-cargo-capable transport (UH-1H, CH-47, Mi-8, etc.)
    local isDynamic = self:_isDynamicCapable(transport)
    local modelKey  = self:_crateModelKey(transport)

    -- Random axis within the appropriate sector (degrees relative to unit forward)
    local axisOffsetDeg
    if isDynamic then
        axisOffsetDeg = ctld.utils.RandomReal("spawnCratesAligned", 135, 225)  -- rear sector
    else
        -- Front sector wraps: pick randomly in [-45, +45], then normalise to [0, 360)
        local raw = ctld.utils.RandomReal("spawnCratesAligned", -45, 45)
        axisOffsetDeg = (raw + 360) % 360
    end

    local safeDist  = (ctld.utils.getSecureDistanceFromUnit(transport:getName()) or 10) + 5
    local spacing   = (ctld.gs and ctld.gs("crateSpacing")) or 5
    local n         = #descriptors
    -- Build avoid list: all DynamicCargo-capable transports near the spawning unit.
    -- Prevents freshly spawned crates from landing inside another aircraft's bbox,
    -- which would immediately trigger a false DCS-native load detection.
    local avoidBBoxes = self:_getDynamicBBoxes(transport)
    local spawnInfo = ctld.utils.getSpawnObjectPositions(transport, n, safeDist, spacing, axisOffsetDeg, avoidBBoxes)
    local spawned   = 0
    for i, descriptor in ipairs(descriptors) do
        local pos = spawnInfo.positions[i]
        if descriptor and pos then
            if self:spawnCrate(descriptor, pos, coalitionId, spawnedBy, spawnMethod, nil, modelKey) then
                spawned = spawned + 1
            end
        end
    end
    return spawned, spawnInfo
end

--- Register a crate pre-placed by the mission maker (called from INIT-B).
-- @param obj  StaticObject  DCS cargo static (already filtered: isExist + Category==6 + Cargos==true)
-- @param desc table         result of obj:getDesc()
function CTLDCrateManager:registerMMCrate(obj, desc)
    local crateName = obj:getName()

    if self.crates[crateName] then
        _log("CTLDCrateManager:registerMMCrate - already registered: " .. crateName, "WARNING")
        return
    end

    local typeName   = desc.typeName
    local descriptor = self:findDescriptorByTypeName(typeName)

    if descriptor == nil then
        _log("CTLDCrateManager:registerMMCrate - unknown cargo type '"
            .. tostring(typeName) .. "' (" .. crateName .. ") — skipped", "WARNING")
        return
    end

    local crate = CTLDCrate:new({
        crateName   = crateName,
        descriptor  = descriptor,
        spawnMethod = CTLDCrate.SPAWN_METHOD.MISSION_MAKER,
        spawnedBy   = nil,
        position    = obj:getPoint(),
        heading     = 0,
        coalition   = obj:getCoalition(),
        dcsStatic   = obj,
    })

    self:_register(crate)
    _log("CTLDCrateManager:registerMMCrate - registered '" .. crateName
        .. "' type='" .. tostring(typeName) .. "'", "INFO")

    self:_publish("OnMMCrateDetected", {
        crate       = crate,
        crateName   = crateName,
        descriptor  = descriptor,
        position    = crate.position,
        coalition   = crate.coalition,
        timestamp   = timer.getAbsTime(),
    })
end

--- Get a crate by its DCS unit name.
-- @param crateName string
-- @return CTLDCrate or nil
function CTLDCrateManager:getCrateByName(crateName)
    return self.crates[crateName]
end

--- Get all crates on the ground within a radius of a position.
-- @param position vec3
-- @param radius   number  metres
-- @return table of CTLDCrate
function CTLDCrateManager:getCratesInRange(position, radius)
    local result = {}
    for _, crate in pairs(self.crates) do
        if crate:isOnGround() then
            -- Prefer live DCS static position: covers crates moved by native DCS
            -- cargo system (dropped at a different location than original spawn).
            local cratePos = crate.position
            if crate.dcsStatic and crate.dcsStatic:isExist() then
                cratePos = crate.dcsStatic:getPoint()
            end
            if ctld.utils.getDistance("CTLDCrateManager:getCratesInRange", position, cratePos) <= radius then
                table.insert(result, crate)
            end
        end
    end
    return result
end

--- Load a crate into a transport unit.
-- Transitions crate: spawned|landed → loaded.
-- Publishes OnCrateLoaded.
-- @param crateName string
-- @param transport Unit
function CTLDCrateManager:loadCrate(crateName, transport)
    local crate = self.crates[crateName]
    if not crate then
        _log("CTLDCrateManager:loadCrate - crate not found: " .. tostring(crateName), "WARNING")
        return
    end
    if not crate:isOnGround() then
        _log("CTLDCrateManager:loadCrate - crate not on ground: " .. crateName, "WARNING")
        return
    end
    local pos = crate.position   -- capture before state change
    crate:load(transport)
    crate:destroy()              -- remove DCS static from ground
    ctld.utils.updateTransportWeight(transport:getName())
    self:_publish("OnCrateLoaded", {
        crate           = crate,
        crateName       = crateName,
        carrierUnitName = transport:getName(),
        coalition       = crate.coalition,
        descriptor      = crate.descriptor,
        timestamp       = timer.getAbsTime(),
    })
    self:_publish("OnCrateCleared", {
        crateName  = crateName,
        position   = pos,
        coalition  = crate.coalition,
        descriptor = crate.descriptor,
        reason     = "loaded",
        timestamp  = timer.getAbsTime(),
    })
end

--- Unload a crate to the ground (transport has landed).
-- Transitions crate: loaded → landed.
-- Publishes OnCrateUnloaded.
-- @param crateName string
-- @param position  vec3
-- @param method    string  "menu_ctld" | "dcs_native_unload"
function CTLDCrateManager:unloadCrate(crateName, position, method)
    local crate = self.crates[crateName]
    if not crate then return end
    -- Capture transport name before unload clears loadedBy
    local transportName = crate.loadedBy and crate.loadedBy:getName()
    crate:unload(position)
    if transportName then ctld.utils.updateTransportWeight(transportName) end
    -- Recreate DCS static on the ground (was destroyed when loaded)
    self:_respawnStatic(crate, position)
    -- Use the updated crateName (may have changed in _respawnStatic)
    local newName = crate.crateName
    self:_publish("OnCrateUnloaded", {
        crate           = crate,
        crateName       = newName,
        position        = position,
        coalition       = crate.coalition,
        method          = method or "menu_ctld",
        timestamp       = timer.getAbsTime(),
    })
    -- Crate returned to ground: notify nearby players it is loadable again.
    self:_publish("OnCrateSpawned", {
        crate      = crate,
        crateName  = newName,
        position   = position,
        coalition  = crate.coalition,
        descriptor = crate.descriptor,
        spawnedBy  = nil,
        spawnMethod = "unload",
        timestamp  = timer.getAbsTime(),
    })
end

--- Unpack a crate (contents deployed).
-- Transitions crate: spawned|landed → unpacked.
-- Publishes OnCrateUnpacked.
-- Spawn logic is delegated to the relevant manager based on descriptor type.
-- @param crateName string
-- @param unpacker  Unit  player unit requesting unpack
function CTLDCrateManager:unpackCrate(crateName, unpacker)
    local crate = self.crates[crateName]
    if not crate then return end
    if not crate:isOnGround() then
        _log("CTLDCrateManager:unpackCrate - crate not on ground: " .. crateName, "WARNING")
        return
    end
    local pos = crate.position   -- capture before state change
    crate:unpack()
    self:_publish("OnCrateUnpacked", {
        crate           = crate,
        crateName       = crateName,
        descriptor      = crate.descriptor,
        position        = pos,
        coalition       = crate.coalition,
        carrierUnitName = unpacker and unpacker:getName() or nil,
        timestamp       = timer.getAbsTime(),
    })
    self:_publish("OnCrateCleared", {
        crateName  = crateName,
        position   = pos,
        coalition  = crate.coalition,
        descriptor = crate.descriptor,
        reason     = "unpacked",
        timestamp  = timer.getAbsTime(),
    })
    crate:destroy()
    self:_unregister(crateName)
end

--- Destroy and remove a crate from the registry.
-- @param crateName string
function CTLDCrateManager:destroyCrate(crateName)
    local crate = self.crates[crateName]
    if not crate then return end
    local pos  = crate.position
    local coal = crate.coalition
    local desc = crate.descriptor
    crate:destroy()
    self:_unregister(crateName)
    self:_publish("OnCrateCleared", {
        crateName  = crateName,
        position   = pos,
        coalition  = coal,
        descriptor = desc,
        reason     = "destroyed",
        timestamp  = timer.getAbsTime(),
    })
end

--- Find a CTLD descriptor by the DCS unit field (vehicle typeName for pack lookup).
--- Returns all single-crate descriptors with isJTAC=true available to a coalition.
-- Used by CTLDJTACManager to populate the "Request JTAC Equipment" F10 menu.
-- Includes descriptors for all sides (side=nil), the given coalition, and ignores cratesRequired.
-- @param coalitionId number  coalition.side.RED (1) or coalition.side.BLUE (2)
-- @return table  list of descriptor tables (may be empty)
function CTLDCrateManager:getJTACDescriptors(coalitionId)
    local result = {}
    if not self._processedCrates then return result end
    for _, catData in pairs(self._processedCrates) do
        for _, entry in ipairs(catData.singleCrates or {}) do
            local sc = entry.singleCrate
            if sc and sc.isJTAC and (sc.side == nil or sc.side == coalitionId) then
                table.insert(result, sc)
            end
        end
    end
    return result
end

-- Uses self._weightIndex (singleCrates only) built by _processSpawnableCrates.
-- @param typeName string  DCS typeName (e.g. "M-1 Abrams")
-- @return descriptor table or nil
function CTLDCrateManager:findDescriptorByUnitType(typeName)
    if not typeName then return nil end
    if self._weightIndex then
        for _, descriptor in pairs(self._weightIndex) do
            if descriptor.unit == typeName then return descriptor end
        end
        return nil
    end
    -- Fallback: raw config scan (before _processSpawnableCrates ran)
    local spawnableCrates = ctld.gs("spawnableCrates")
    if not spawnableCrates then return nil end
    for _, category in pairs(spawnableCrates) do
        for _, descriptor in ipairs(category) do
            if descriptor.unit == typeName then return descriptor end
        end
    end
    return nil
end

--- Find a CTLD descriptor matching a DCS typeName (unit or type field).
-- Uses self._weightIndex (singleCrates only) built by _processSpawnableCrates.
-- @param typeName string  DCS typeName (e.g. "M92_Ammo_Pallet")
-- @return descriptor table or nil
function CTLDCrateManager:findDescriptorByTypeName(typeName)
    if not typeName then return nil end
    if self._weightIndex then
        for _, descriptor in pairs(self._weightIndex) do
            if descriptor.unit == typeName then
                return descriptor
            end
        end
        return nil
    end
    -- Fallback: raw config scan (before _processSpawnableCrates ran)
    local spawnableCrates = ctld.gs("spawnableCrates")
    if not spawnableCrates then return nil end
    for _, category in pairs(spawnableCrates) do
        for _, descriptor in ipairs(category) do
            if descriptor.unit == typeName then
                return descriptor
            end
        end
    end
    return nil
end

--- Check if enough crates of the same type are assembled nearby to unpack.
-- Searches for crates with the same descriptor.unit within radius, including crate itself.
-- @param crate   CTLDCrate  reference crate
-- @param radius  number     search radius in metres (default 100)
-- @return boolean, table    ready flag + list of assembled crates (length == cratesRequired)
function CTLDCrateManager:checkAssemblyReady(crate, radius)
    radius = radius or 100
    local required = (crate.descriptor and crate.descriptor.cratesRequired) or 1
    if required <= 1 then
        return true, { crate }
    end

    local function _livePos(c)
        if c.dcsStatic and c.dcsStatic:isExist() then return c.dcsStatic:getPoint() end
        return c.position
    end
    local refPos = _livePos(crate)

    local assembled = {}
    for _, c in pairs(self.crates) do
        if c:isOnGround()
            and c.descriptor
            and c.descriptor.unit == crate.descriptor.unit
            and ctld.utils.getDistance("CTLDCrateManager:checkAssemblyReady", refPos, _livePos(c)) <= radius
        then
            table.insert(assembled, c)
            if #assembled == required then
                return true, assembled
            end
        end
    end
    return false, assembled
end

--- Drop a crate from a transport in flight.
-- Below maxDropHeight → crate lands safely.
-- Above maxDropHeight → crate is destroyed (impact damage).
-- Publishes OnCrateUnloaded (method="drop") on safe landing,
-- or OnCrateDestroyed (reason="drop_impact") on destruction.
-- @param crateName     string
-- @param altitudeAGL   number  metres above ground level at drop time
function CTLDCrateManager:dropCrate(crateName, altitudeAGL)
    local crate = self.crates[crateName]
    if not crate then return end
    if not crate:isLoaded() then
        _log("CTLDCrateManager:dropCrate - crate not loaded: " .. tostring(crateName), "WARNING")
        return
    end

    local maxDropHeight    = ctld.gs("maxDropHeight") or 7.5
    -- Capture transport name before state transition clears loadedBy (via land/drop)
    local transportName    = crate.loadedBy and crate.loadedBy:getName()

    if altitudeAGL <= maxDropHeight then
        -- Safe drop: crate lands at current position
        local pos = crate.position
        crate:land(pos)
        if transportName then ctld.utils.updateTransportWeight(transportName) end
        self:_publish("OnCrateUnloaded", {
            crate           = crate,
            crateName       = crateName,
            position        = pos,
            coalition       = crate.coalition,
            method          = "drop",
            timestamp       = timer.getAbsTime(),
        })
    else
        -- Too high: crate destroyed on impact
        _log("CTLDCrateManager:dropCrate - destroyed on impact (alt=" .. tostring(altitudeAGL) .. "m): " .. crateName, "INFO")
        crate:destroy()
        self:_unregister(crateName)
        if transportName then ctld.utils.updateTransportWeight(transportName) end
        self:_publish("OnCrateDestroyed", {
            crate     = crate,
            crateName = crateName,
            coalition = crate.coalition,
            reason    = "drop_impact",
            timestamp = timer.getAbsTime(),
        })
    end
end

--- S_EVENT_BIRTH handler: register cargo statics that spawn via late activation.
-- Registered in CTLDDCSEventBridge by CTLDCoreManager.
function CTLDCrateManager:onBirth(event)
    local obj = event.initiator
    if not (obj and obj.isExist and obj:isExist()) then return end
    if Object.getCategory(obj) ~= 6 then return end
    local desc = obj:getDesc()
    if not (desc and desc.attributes and desc.attributes.Cargos == true) then return end
    local unitName = obj:getName()
    -- Skip CTLD-managed crates: S_EVENT_BIRTH may fire before _register() is called
    -- (synchronous dispatch in some DCS versions), so the prefix check is more reliable
    -- than getCrateByName() alone.
    if string.sub(unitName, 1, 5) == "CTLD_" then return end
    if self:getCrateByName(unitName) then return end   -- already registered
    self:registerMMCrate(obj, desc)
end

--- Spawn the DCS object described by a crate descriptor and activate its post-spawn role.
-- Uniform path for all standard (non-AA, non-FOB) unpack outcomes:
--   build unitDef (ctld.utils.buildGroupUnitDef)
--   → spawn       (ctld.utils.spawnFromDescriptor)
--   → post-spawn  (_dispatchPostSpawn)
--   → refresh     (refreshLoadSectionForUnit on playerName)
-- JTAC_dropEnabled is checked here for air JTAC descriptors.
-- @param desc       table    crate descriptor { unit, spawnAs, isJTAC, … }
-- @param pos        vec3     world spawn position
-- @param coa        number   coalition.side.*
-- @param cId        number   country.id.*
-- @param playerName string   unit name of the player who unpacked (optional — triggers menu refresh)
function CTLDCrateManager:_spawnUnpacked(desc, pos, coa, cId, playerName)
    if not (desc and desc.unit and pos) then return end

    local spawnAs = desc.spawnAs or "GROUND"
    local isAir   = spawnAs ~= "GROUND" and spawnAs ~= "STATIC"

    if isAir and ctld.gs("JTAC_dropEnabled") == false then
        ctld.utils.log("INFO", "CTLDCrateManager:_spawnUnpacked — JTAC_dropEnabled=false, skipped")
        return
    end

    -- Consume one JTAC slot before spawning (quota is definitive — legacy behaviour).
    if desc.isJTAC then
        local ok, reason = CTLDJTACManager.getInstance():_consumeJTACSlot(coa)
        if not ok then
            ctld.utils.log("WARN", "CTLDCrateManager:_spawnUnpacked — JTAC slot limit: %s", tostring(reason))
            if playerName then
                local pObj = CTLDPlayerManager.getInstance()._players[playerName]
                if pObj then trigger.action.outTextForGroup(pObj.groupId, reason, 10) end
            end
            return
        end
    end

    local gid   = ctld.utils.getNextUniqId()
    local uid   = ctld.utils.getNextUniqId()
    local gname = isAir
        and string.format("CTLD_AIR_%d", gid)
        or  string.format("CTLD_UNP_%d", uid)

    local unitDef = ctld.utils.buildGroupUnitDef(desc, pos, gname, gid, uid)
    local ok, err = ctld.utils.spawnFromDescriptor(desc, cId, unitDef)
    if not ok then
        local errStr = type(err) == "table" and ctld.utils.p(err) or tostring(err)
        ctld.utils.log("WARNING", "CTLDCrateManager:_spawnUnpacked — spawn failed: " .. errStr)
        return
    end

    if not isAir then
        EventDispatcher.getInstance():publish("OnGroundUnitSpawned", {
            vehicleType = desc.unit,
            position    = pos,
            coalitionId = coa,
            timestamp   = timer.getAbsTime(),
        })
    end

    self:_dispatchPostSpawn(desc, gname)

    if playerName then
        CTLDVehicleSpawner.getInstance():refreshLoadSectionForUnit(playerName)
        CTLDVehicleSpawner.getInstance():refreshPackSectionForUnit(playerName)
    end
end

--- Activate post-spawn role behaviors for an unpacked crate.
-- Called after successful spawn regardless of unit type.
-- Add new role activations here as new crate types are introduced.
-- @param desc   table  crate descriptor
-- @param gname  string spawned DCS group name
function CTLDCrateManager:_dispatchPostSpawn(desc, gname)
    if desc.isJTAC then
        CTLDJTACManager.getInstance():startLase(gname, nil, nil, nil, nil, nil, desc.specificParams)
        -- Register in CTLDVehicleSpawner so load/unload can suspend/resume JTAC lasing.
        CTLDVehicleSpawner.getInstance():registerJTACVehicle(gname, desc.unit, nil, nil)
    elseif (desc.spawnAs == nil or desc.spawnAs == "GROUND") and desc.unit then
        -- Register ground vehicles in CTLDVehicleSpawner so Load/Unload menu can track them.
        CTLDVehicleSpawner.getInstance():registerJTACVehicle(gname, desc.unit, nil, nil)
    end
end

--- Cleanup: destroy all tracked crates.
-- Called on mission end or full reset.
function CTLDCrateManager:cleanup()
    for crateName, _ in pairs(self.crates) do
        self:destroyCrate(crateName)
    end
    self.crates = {}
end

-- ============================================================
-- F10 Menu sections
-- ============================================================

--- Parachute all crates loaded by a transport.
-- Altitude AGL is checked at call time. If below parachuteMinAltitudeCrates, a message
-- is sent to the player's group and nothing else happens.
-- For each loaded crate: computes an independent landing position, schedules a timer
-- to land it after descent, fires events.
-- Publishes OnCrateParachuting immediately (per crate) and OnCrateParachuteLanded
-- after descentTime (per crate).
-- @param transport    Unit    DCS transport unit
-- @param playerObj    table   CTLDPlayer-like {groupId, unitName}
function CTLDCrateManager:parachuteCrates(transport, playerObj)
    local dropPos     = transport:getPoint()
    local groundUnder = land.getHeight({ x = dropPos.x, y = dropPos.z })
    local altAGL      = dropPos.y - groundUnder
    local minAlt      = ctld.gs("parachuteMinAltitudeCrates") or 30

    if altAGL < minAlt then
        trigger.action.outTextForGroup(playerObj.groupId,
            ctld.tr("Altitude too low for parachute drop. Minimum: %1m AGL (current: %2m AGL)",
                math.floor(minAlt), math.floor(altAGL)), 10)
        return
    end

    local descentRate = ctld.gs("parachuteDescentRateCrates") or 5
    local loaded      = {}
    for _, crate in pairs(self.crates) do
        if crate:isLoadedByCTLD() and crate.loadedBy == transport then
            table.insert(loaded, crate)
        end
    end

    if #loaded == 0 then
        trigger.action.outTextForGroup(playerObj.groupId, ctld.tr("No crates loaded."), 8)
        return
    end

    -- Announce drop to the player group (estimate descent time from current altitude)
    local _, estDescentTime = ctld.utils.calcDropPosition(transport, descentRate)
    trigger.action.outTextForGroup(playerObj.groupId,
        ctld.tr("Parachuting %1 crate(s) — landing in ~%2s",
            #loaded, math.floor(estDescentTime)), 10)

    for _, crate in ipairs(loaded) do
        -- DCS-native crates (convertNativeLoadToCTLD=false, e.g. C-130) keep
        -- loadedByDCSNative=true and dcsStatic alive.  We must destroy the original
        -- static before the virtual parachute descent so _respawnStatic can create a
        -- fresh one at the landing position without leaving a DCS-side duplicate.
        if crate.loadedByDCSNative and crate.dcsStatic and crate.dcsStatic:isExist() then
            crate.dcsStatic:destroy()
            crate.dcsStatic = nil
        end
        local landPos, descentTime = ctld.utils.calcDropPosition(transport, descentRate)
        crate:startParachute(altAGL)

        local dropData = {
            type          = "crate",
            unitName      = crate.crateName,
            dropPosition  = dropPos,
            landPositions = { landPos },
            altitude      = altAGL,
            descentTime   = descentTime,
            transport     = transport,
            player        = playerObj.unitName,
        }
        self._parachuteEffect:onStart(dropData)

        self:_publish("OnCrateParachuting", {
            crate           = crate,
            crateName       = crate.crateName,
            descriptor      = crate.descriptor,
            dropPosition    = dropPos,
            landingPosition = landPos,
            altitude        = altAGL,
            descentTime     = descentTime,
            carrierUnitName = transport:getName(),
            player          = playerObj.unitName,
            timestamp       = timer.getAbsTime(),
        })

        -- Capture loop variables for the timer closure
        local _crate         = crate
        local _landPos       = landPos
        local _dropData      = dropData
        local _transportName = transport:getName()
        timer.scheduleFunction(function()
            _crate.fromParachute = true
            _crate:land(_landPos)
            ctld.utils.updateTransportWeight(_transportName)
            -- Recreate DCS static so the crate is visible on the ground.
            -- _respawnStatic re-registers the crate under a new name — capture it.
            self:_respawnStatic(_crate, _landPos)
            local newName = _crate.crateName
            -- Notify nearby players that a new ground crate appeared.
            self:_publish("OnCrateSpawned", {
                crate       = _crate,
                crateName   = newName,
                position    = _landPos,
                coalition   = _crate.coalition,
                descriptor  = _crate.descriptor,
                spawnedBy   = nil,
                spawnMethod = "parachute",
                timestamp   = timer.getAbsTime(),
            })
            self._parachuteEffect:onLanded(_dropData)
            self:_publish("OnCrateParachuteLanded", {
                crate           = _crate,
                crateName       = newName,
                descriptor      = _crate.descriptor,
                position        = _landPos,
                coalition       = _crate.coalition,
                startAltitude   = altAGL,
                carrierUnitName = _transportName,
                player          = playerObj.unitName,
                timestamp       = timer.getAbsTime(),
            })
            self:_checkAutoUnpack(_crate)
        end, {}, timer.getTime() + descentTime)
    end
    -- All crates are now FALLING: update transport weight immediately so the
    -- flight model reflects the drop at once (not delayed until each crate lands).
    ctld.utils.updateTransportWeight(transport:getName())
    -- Update flight-state menu (disable Parachute Crates).
    -- playerObj may be a raw arg table from the menu callback — fetch the real CTLDPlayer.
    local _pObj = CTLDPlayerManager.getInstance():getPlayer(playerObj.unitName)
    if _pObj then self:refreshCrateFlightSection(_pObj) end
end

--- Poll the DCS-simulated altitude of a natively parachuted crate until it lands.
-- Called when a C-130 (or any dynamic-cargo aircraft) releases a crate in flight via the
-- DCS Dynamic Cargo UI. DCS physically animates the descent; CTLD must NOT auto-unpack
-- before the static actually touches the ground.
--
-- Polls every 1 s. Declares the crate landed when AGL ≤ 3 m, then calls _checkAutoUnpack.
-- Falls back to a 120-second timeout in case of degenerate AGL (unlikely terrain artefacts).
--
-- @param crate CTLDCrate   crate in STATE.FALLING with a live dcsStatic
function CTLDCrateManager:_scheduleParachuteLandingPoll(crate)
    local POLL_INTERVAL = 1.0   -- seconds between altitude checks
    local MAX_WAIT      = 120   -- safety timeout (seconds)
    local AGL_THRESHOLD = 3.0   -- metres AGL to declare landed
    local startTime     = timer.getTime()

    local function poll(_, t)
        -- Crate already transitioned out of FALLING (unpacked, reloaded, destroyed…)
        if crate.state ~= CTLDCrate.STATE.FALLING then return nil end

        -- Safety timeout — declare landed at last known position
        if (timer.getTime() - startTime) > MAX_WAIT then
            ctld.utils.log("WARN",
                "CTLDCrateManager:_scheduleParachuteLandingPoll: timeout — declaring %s landed",
                crate.crateName)
            crate.state = CTLDCrate.STATE.LANDED
            CTLDCrateManager.getInstance():_checkAutoUnpack(crate)
            return nil
        end

        -- DCS static destroyed mid-fall (e.g. enemy fire) — silently abandon
        if not (crate.dcsStatic and crate.dcsStatic:isExist()) then
            ctld.utils.log("INFO",
                "CTLDCrateManager:_scheduleParachuteLandingPoll: dcsStatic gone for %s — landing cancelled",
                crate.crateName)
            crate.state = CTLDCrate.STATE.LANDED
            return nil
        end

        local p   = crate.dcsStatic:getPoint()
        local agl = p.y - land.getHeight({ x = p.x, y = p.z })

        if agl <= AGL_THRESHOLD then
            crate.state    = CTLDCrate.STATE.LANDED
            crate.position = { x = p.x, y = p.y, z = p.z }
            ctld.utils.log("INFO",
                "CTLDCrateManager:_scheduleParachuteLandingPoll: %s landed at (%.0f,%.0f) AGL=%.1f m",
                crate.crateName, p.x, p.z, agl)
            CTLDCrateManager.getInstance():_checkAutoUnpack(crate)
            return nil
        end

        return t + POLL_INTERVAL
    end

    ctld.utils.log("INFO",
        "CTLDCrateManager:_scheduleParachuteLandingPoll: tracking %s (DCS native parachute)",
        crate.crateName)
    timer.scheduleFunction(poll, {}, timer.getTime() + POLL_INTERVAL)
end

--- Auto-unpack a set of parachuted crates when all required crates have landed.
-- Called after each parachuted crate lands (CTLD virtual or DCS-native airborne release).
-- Scans self.crates for LANDED + fromParachute=true crates of the same descriptor.unit
-- within autoUnpackRadiusParachute. If count >= cratesRequired the vehicle is spawned at
-- the centroid of the collected crates. No player is required.
-- @param landedCrate CTLDCrate  the crate that just landed
function CTLDCrateManager:_checkAutoUnpack(landedCrate)
    local desc = landedCrate.descriptor
    if not desc or not desc.unit then return end

    -- Explicit opt-out: equipment descriptors with autoUnpack=false are skipped.
    if desc.autoUnpack == false then return end
    -- Scene opt-out: check model.crate.autoUnpack=false (e.g. FOB requires live player).
    local _sm = CTLDSceneManager.getInstance()
    local _m  = _sm:getModel(desc.unit)
    if _m and _m.crate and _m.crate.autoUnpack == false then return end

    local required = desc.cratesRequired or 1
    local radius   = ctld.gs("autoUnpackRadiusParachute") or 1000
    local refPos   = landedCrate.position
    if not refPos then return end

    -- Collect eligible crates: LANDED + fromParachute=true + same unit type + in radius
    local candidates = {}
    for _, crate in pairs(self.crates) do
        if crate.fromParachute
            and crate:isOnGround()
            and crate.canBeUnpacked
            and crate.descriptor
            and crate.descriptor.unit == desc.unit
        then
            local cp = crate.position
            if cp then
                local dx = cp.x - refPos.x
                local dz = cp.z - refPos.z
                if math.sqrt(dx*dx + dz*dz) <= radius then
                    table.insert(candidates, crate)
                end
            end
        end
    end

    if #candidates < required then return end

    -- Take the first N crates (required count)
    local toUnpack = {}
    for i = 1, required do
        toUnpack[i] = candidates[i]
    end

    -- Compute centroid of selected crates
    local sumX, sumY, sumZ = 0, 0, 0
    for _, c in ipairs(toUnpack) do
        sumX = sumX + c.position.x
        sumY = sumY + c.position.y
        sumZ = sumZ + c.position.z
    end
    local centroid = {
        x = sumX / required,
        y = sumY / required,
        z = sumZ / required,
    }

    -- Determine country from coalition (mirrors standard unpack logic)
    local coa = landedCrate.coalition
    local cId = (coa == coalition.side.RED) and country.id.RUSSIA or country.id.USA

    -- Dispatch: scene crates → CTLDSceneManager:playSceneAtPos;
    --           equipment crates (vehicle, static, JTAC) → _spawnUnpacked.
    -- desc.unit is a registered scene name for scene crates, or a DCS type for equipment crates.
    local sm    = CTLDSceneManager.getInstance()
    local model = sm:getModel(desc.unit)
    if model then
        if model.crate and model.crate.fobCompatible then
            -- FOB scene: run spatial guards BEFORE consuming crates.
            local guardOk, guardReason = CTLDFOBManager.getInstance():checkSpatialGuards(centroid, coa)
            if not guardOk then
                ctld.utils.log("WARN",
                    "CTLDCrateManager: auto-unpack (parachute) FOB blocked — %s centroid=(%.0f,%.0f)",
                    tostring(guardReason), centroid.x, centroid.z)
                return
            end
            -- Guards passed: collect cratesUsed, destroy crates, start scene with full params.
            local cratesUsed = {}
            for _, c in ipairs(toUnpack) do
                cratesUsed[#cratesUsed + 1] = { crateName = c.crateName, descriptor = c.descriptor }
            end
            for _, c in ipairs(toUnpack) do
                self:unpackCrate(c.crateName, nil)
            end
            sm:playSceneAtPos(desc.unit, centroid, coa, cId, {
                centroid    = centroid,
                player      = "auto-unpack",
                coalitionId = coa,
                countryId   = cId,
                cratesUsed  = cratesUsed,
            })
            ctld.utils.log("INFO",
                "CTLDCrateManager: auto-unpack (parachute) FOB — name=%s required=%d centroid=(%.0f,%.0f,%.0f)",
                desc.unit, required, centroid.x, centroid.y, centroid.z)
        else
            -- Generic scene (FARP, etc.): extract repackData, destroy crates, play at centroid.
            local repackData = nil
            for _, c in ipairs(toUnpack) do
                if c.metadata and c.metadata.warehouseSnapshot and not repackData then
                    repackData = { warehouseSnapshot = c.metadata.warehouseSnapshot }
                end
            end
            for _, c in ipairs(toUnpack) do
                self:unpackCrate(c.crateName, nil)
            end
            sm:playSceneAtPos(desc.unit, centroid, coa, cId,
                repackData and { repackData = repackData } or nil)
            ctld.utils.log("INFO",
                "CTLDCrateManager: auto-unpack (parachute) SCENE — name=%s required=%d centroid=(%.0f,%.0f,%.0f)",
                desc.unit, required, centroid.x, centroid.y, centroid.z)
        end
    else
        -- Equipment crate (vehicle, static, JTAC): destroy crates then spawn.
        for _, c in ipairs(toUnpack) do
            self:unpackCrate(c.crateName, nil)
        end
        self:_spawnUnpacked(desc, centroid, coa, cId, nil)
        ctld.utils.log("INFO",
            "CTLDCrateManager: auto-unpack (parachute) EQUIPMENT — type=%s required=%d centroid=(%.0f,%.0f,%.0f)",
            desc.unit, required, centroid.x, centroid.y, centroid.z)
    end
end

--- Returns true if a crate descriptor entry has the JTAC role.
-- For single crates: checks desc.isJTAC == true.
-- For multi-crates:  resolves each weight to its descriptor; true if any has isJTAC == true.
-- @param desc  table  entry from spawnableCrates (may have .unit or .multiple)
local function _crateIsJTAC(desc)
    if desc.isJTAC then return true end
    if desc.multiple then
        local mgr = CTLDCrateManager.getInstance()
        for _, w in ipairs(desc.multiple) do
            local d = mgr:findDescriptorByWeight(w)
            if d and d.isJTAC then return true end
        end
    end
    return false
end

--- Build "Request Equipment" + "Crate Commands" F10 submenus for a player.
-- Requires enableCrates = true (configKey gate) AND unitActions.crates = true.
-- Sub-entries:
--   Request Equipment → per LGZ → per category → per crate (filtered by coalition + JTAC flag)
--   Crate Commands → Load/Drop/Unpack/List
--                  → List FOBs         if enabledFOBBuilding
--                  → Pack Vehicle (container, populated dynamically) if enablePackingVehicles
-- @param playerObj CTLDPlayer
-- @param menu      ctld.Menu
--- Rebuild the "Request Equipment" submenu branch for playerObj.
-- Shows only logistic zones where the player is currently located (cratesPickup).
-- Called on build, land, and takeoff.
-- @param playerObj CTLDPlayer
function CTLDCrateManager:refreshRequestEquipmentSection(playerObj)
    local caps = (ctld.gs("capabilitiesByType") or {})[playerObj.typeName]
    if not (playerObj.isTransport and caps and caps.cratesEnabled) then return end

    local mm   = ctld.MenuManager:getInstance()
    local menu = mm:getMenuByGroupId(playerObj.groupId)
    if not menu then return end

    local root     = ctld.tr("CTLD")
    local spawnSub = ctld.tr("Request Equipment")
    menu:clearBranch({ root, spawnSub })

    local transport = Unit.getByName(playerObj.unitName)
    if not (transport and transport:isExist()) or ctld.utils.inAir(transport) then
        menu:addCommand({ root, spawnSub }, ctld.tr("Land near logistics to request equipment"),
            function() end, {})
        menu:refresh()
        return
    end

    local zm      = CTLDZoneManager.getInstance()
    local lgZones = zm:getLogisticZonesAtPoint(transport:getPoint(), playerObj.coalition, "cratesPickup")

    if not next(lgZones) then
        menu:addCommand({ root, spawnSub }, ctld.tr("No logistics in range"),
            function() end, {})
        menu:refresh()
        return
    end

    local jtacOk      = ctld.gs("JTAC_dropEnabled") == true
    local showSets    = ctld.gs("enableAllCrates") ~= false
    local processed   = self._processedCrates or {}

    -- Shared spawn callback: handles both single crate (arg.unit) and set (arg.multiple).
    local function spawnFn(arg)
        local t = Unit.getByName(arg.unitName)
        if not (t and t:isExist()) then return end
        if ctld.utils.inAir(t) then
            trigger.action.outTextForGroup(ctld.utils.getGroupId(t),
                ctld.tr("You must be landed to request a crate."), 10)
            return
        end
        local selZone = CTLDZoneManager.getInstance():getLogisticZone(arg.zoneName)
        if not (selZone and selZone.active and selZone:isAlive()
                and selZone:isInZone(t:getPoint())) then
            trigger.action.outTextForGroup(ctld.utils.getGroupId(t),
                ctld.tr("You are not close enough to friendly logistics to get a crate!"), 10)
            return
        end
        local safeDist = (ctld.utils.getSecureDistanceFromUnit(arg.unitName) or 10) + 5
        local mgr      = CTLDCrateManager.getInstance()
        local gid      = ctld.utils.getGroupId(t)
        if arg.multiple then
            local descriptors = {}
            for _, weight in ipairs(arg.multiple) do
                local d = mgr:findDescriptorByWeight(weight)
                if d then table.insert(descriptors, d) end
            end
            local spawned, spawnInfo = mgr:spawnCratesAligned(
                descriptors, t, arg.coalition, arg.unitName, CTLDCrate.SPAWN_METHOD.MENU_CTLD)
            if spawned > 0 then
                trigger.action.outTextForGroup(gid,
                    ctld.tr("%1 crates have been brought out at your %2 o'clock",
                        spawned, spawnInfo.clock), 20)
            end
        elseif arg.spawnAsVehicle then
            -- Feature Q: spawn a whole vehicle WAITING (no crate)
            local vs = CTLDVehicleSpawner.getInstance()
            vs:spawnVehicleForTransport(arg.unit, t, selZone)
            trigger.action.outTextForGroup(gid,
                ctld.tr("Vehicle ready for loading", arg.desc), 20)
        else
            local mKey      = mgr:_crateModelKey(t)
            local spawnInfo = ctld.utils.getSpawnObjectPositions(t, 1, safeDist)
            local pos       = spawnInfo.positions[1]
            local descriptor = mgr:findDescriptorByTypeName(arg.unit)
            if descriptor then
                local spawned = mgr:spawnCrate(descriptor, pos, arg.coalition, arg.unitName,
                    CTLDCrate.SPAWN_METHOD.MENU_CTLD, nil, mKey)
                if spawned then
                    trigger.action.outTextForGroup(gid,
                        ctld.tr("A %1 crate weighing %2 kg has been brought out and is at your %3 o'clock ",
                            descriptor.desc, descriptor.weight, spawnInfo.clock), 20)
                end
            end
        end
    end

    for _, lgz in ipairs(lgZones) do
        local lgzName = lgz.name
        menu:addSubMenu({ root, spawnSub }, lgzName)
        for category, data in pairs(processed) do
            menu:addSubMenu({ root, spawnSub, lgzName }, category)
            local crateOrder = 0

            -- singleCrates, each immediately followed by its singleTypeSet (if visible)
            for _, entry in ipairs(data.singleCrates) do
                local sc     = entry.singleCrate
                local sideOk = (sc.side == nil) or (sc.side == playerObj.coalition)
                if sideOk and (not _crateIsJTAC(sc) or jtacOk) then
                    -- Request Equipment always spawns crates, never a whole vehicle.
                    -- Feature Q whole-vehicle spawn is handled by the dedicated "Load Vehicle" menu.
                    local spawnAsVehicle = false
                    crateOrder = crateOrder + 1
                    menu:addCommand({ root, spawnSub, lgzName, category }, sc.desc,
                        spawnFn,
                        { unit = sc.unit, desc = sc.desc, zoneName = lgzName,
                          unitName = playerObj.unitName, coalition = playerObj.coalition,
                          spawnAsVehicle = spawnAsVehicle },
                        { order = crateOrder })

                    local sts = entry.singleTypeSet
                    if sts and (not _crateIsJTAC(sts) or jtacOk) then
                        crateOrder = crateOrder + 1
                        menu:addCommand({ root, spawnSub, lgzName, category }, sts.desc,
                            spawnFn,
                            { multiple = sts.multiple, zoneName = lgzName, unitName = playerObj.unitName,
                              coalition = playerObj.coalition },
                            { order = crateOrder })
                    end
                end
            end

            -- mixedSets at the end (shown only when enableAllCrates is true)
            if showSets then
                for _, ms in ipairs(data.mixedSets) do
                    local sideOk = (ms.side == nil) or (ms.side == playerObj.coalition)
                    if sideOk and (not _crateIsJTAC(ms) or jtacOk) then
                        crateOrder = crateOrder + 1
                        menu:addCommand({ root, spawnSub, lgzName, category }, ms.desc,
                            spawnFn,
                            { multiple = ms.multiple, zoneName = lgzName, unitName = playerObj.unitName,
                              coalition = playerObj.coalition },
                            { order = crateOrder })
                    end
                end
            end
        end
    end
    menu:refresh()
end

--- Refresh Crate Commands visibility based on flight state (ground vs in-air).
-- Ground-only: Load Crate, Drop Crate(s), Unpack Crate, List Nearby Crates, Pack Vehicle.
-- Air-only:    Parachute Crates (caps.canParachuteDrop + CTLD crates onboard),
--              Release Slingload, Cut Slingload (caps.canSlingload + slingloaded crate active).
-- Called from buildMenuSection, onTakeoff, and onLand.
-- @param playerObj CTLDPlayer
function CTLDCrateManager:refreshCrateFlightSection(playerObj, overrideInAir)
    local caps = (ctld.gs("capabilitiesByType") or {})[playerObj.typeName]
    if not (playerObj.isTransport and caps and caps.cratesEnabled) then return end

    local mm   = ctld.MenuManager:getInstance()
    local menu = mm:getMenuByGroupId(playerObj.groupId)
    if not menu then return end

    local root      = ctld.tr("CTLD")
    local cratesSub = ctld.tr("Crate Commands")

    local transport = Unit.getByName(playerObj.unitName)
    -- overrideInAir: true = force flight, false = force ground, nil = use _isFlying flag / inAir().
    -- _isFlying is set by onTakeoff / onLand to bridge the gap before inAir() threshold settles.
    local inAir
    if overrideInAir ~= nil then
        inAir = overrideInAir
    elseif playerObj._isFlying ~= nil then
        inAir = playerObj._isFlying
    else
        inAir = transport and transport:isExist() and ctld.utils.inAir(transport) or false
    end

    -- Ground-only: visible only when landed
    if ctld.gs("loadCrateFromMenu") then
        menu:setBranchEnabled({ root, cratesSub, ctld.tr("Load Crate") }, not inAir)
    end
    menu:setBranchEnabled({ root, cratesSub, ctld.tr("Drop Crate(s)") },      not inAir)
    menu:setBranchEnabled({ root, cratesSub, ctld.tr("Unpack Crate") },       not inAir)
    menu:setBranchEnabled({ root, cratesSub, ctld.tr("List Nearby Crates") }, not inAir)
    self:refreshPackEquiptSection(playerObj, inAir, true)  -- _noRefresh: final refresh() below covers it

    -- Parachute Crates: enabled only in air + CTLD crates loaded
    if caps.canParachuteDrop then
        local onboard = 0
        if transport and transport:isExist() then
            for _, c in pairs(self.crates) do
                if c:isLoadedByCTLD()
                        and not c.inTransitOnSlingload
                        and c.loadedBy
                        and c.loadedBy:isExist() and c.loadedBy:getName() == playerObj.unitName then
                    onboard = onboard + 1
                end
            end
        end
        menu:setBranchEnabled({ root, cratesSub, ctld.tr("Parachute Crates") },
            inAir and onboard > 0)
    end

    -- Release / Cut Slingload: enabled only in air + slingloaded crate active
    if caps.canSlingload then
        local hasSlingload = false
        if inAir and transport and transport:isExist() then
            hasSlingload = self:_getSlingloadedCrate(transport) ~= nil
        end
        menu:setBranchEnabled({ root, cratesSub, ctld.tr("Release Slingload") }, hasSlingload)
        menu:setBranchEnabled({ root, cratesSub, ctld.tr("Cut Slingload") },     hasSlingload)
    end

    menu:refresh()
end

--- Refresh Crate Commands flight visibility for a player by unit name.
-- @param unitName string
function CTLDCrateManager:refreshCrateFlightSectionForUnit(unitName)
    local playerObj = CTLDPlayerManager.getInstance()._players[unitName]
    if playerObj then self:refreshCrateFlightSection(playerObj) end
end

function CTLDCrateManager:buildMenuSection(playerObj, menu)
    local caps = (ctld.gs("capabilitiesByType") or {})[playerObj.typeName]
    if not (playerObj.isTransport and caps and caps.cratesEnabled) then return end

    local root     = ctld.tr("CTLD")
    local spawnSub = ctld.tr("Request Equipment")
    -- order=25: after Troop Commands (20), before Vehicle Commands (30)
    menu:addSubMenu({ root }, spawnSub, { order = 25 })
    self:refreshRequestEquipmentSection(playerObj)

    -- Crate Commands
    local cratesSub = ctld.tr("Crate Commands")
    menu:addSubMenu({ root }, cratesSub, { order = 40 })

    if ctld.gs("loadCrateFromMenu") then
        local loadSub = ctld.tr("Load Crate")
        menu:addSubMenu({ root, cratesSub }, loadSub, { order = 10 })
        self:refreshLoadCrateSection(playerObj)
    end

    menu:addCommand({ root, cratesSub }, ctld.tr("Drop Crate(s)"),
        function(arg)
            local t = Unit.getByName(arg.unitName)
            if not (t and t:isExist()) then return end
            local gid = ctld.utils.getGroupId(t)
            if ctld.utils.inAir(t) then
                trigger.action.outTextForGroup(gid,
                    ctld.tr("You must land before dropping crates!"), 10)
                return
            end
            -- Collect all CTLD-managed crates loaded on this transport
            -- (DCS-native loads keep dcsStatic alive → excluded, must unload via DCS)
            local mgr     = CTLDCrateManager.getInstance()
            local loaded  = {}
            for _, c in pairs(mgr.crates) do
                if c:isLoadedByCTLD() and c.loadedBy and c.loadedBy:isExist() and c.loadedBy:getName() == t:getName() then
                    table.insert(loaded, c)
                end
            end
            if #loaded == 0 then
                trigger.action.outTextForGroup(gid,
                    ctld.tr("No crates on board to drop."), 10)
                return
            end
            -- Compute aligned drop positions (one per crate)
            local safeDist  = (ctld.utils.getSecureDistanceFromUnit(arg.unitName) or 10) + 5
            local spacing   = (ctld.gs and ctld.gs("crateSpacing")) or 5
            local caps_t    = (ctld.gs("capabilitiesByType") or {})[t:getTypeName()]
            local isDynamic = caps_t ~= nil and caps_t.canTransportWholeVehicle == true
            local axis
            if isDynamic then
                axis = ctld.utils.RandomReal("dropCrates", 135, 225)
            else
                axis = (ctld.utils.RandomReal("dropCrates", -45, 45) + 360) % 360
            end
            local spawnInfo = ctld.utils.getSpawnObjectPositions(t, #loaded, safeDist, spacing, axis)
            for i, c in ipairs(loaded) do
                local pos = spawnInfo.positions[i]
                if pos then
                    local groundY = land.getHeight({ x = pos.x, y = pos.z })
                    mgr:unloadCrate(c.crateName, { x = pos.x, y = groundY, z = pos.z }, "drop")
                end
            end
            trigger.action.outTextForGroup(gid,
                ctld.tr("%1 crate(s) dropped at your %2 o'clock", #loaded, spawnInfo.clock), 10)
        end,
        { unitName = playerObj.unitName }, { order = 15 })

    local unpackSub = ctld.tr("Unpack Crate")
    menu:addSubMenu({ root, cratesSub }, unpackSub, { order = 20 })
    self:refreshUnpackSection(playerObj, true)  -- _noRefresh: buildMenu calls refresh() at end

    menu:addCommand({ root, cratesSub }, ctld.tr("List Nearby Crates"),
        function(arg)
            local t = Unit.getByName(arg.unitName)
            if not (t and t:isExist()) then return end
            local gid  = ctld.utils.getGroupId(t)
            local mgr  = CTLDCrateManager.getInstance()
            local nearby = mgr:getCratesInRange(t:getPoint(), 300)

            -- Group by descriptor.unit (or desc for crates with no vehicle)
            local byUnit    = {}   -- [key] = { desc, count, required }
            local unitOrder = {}
            for _, c in ipairs(nearby) do
                if c.descriptor then
                    local key      = c.descriptor.unit or c.descriptor.desc or "?"
                    local desc     = c.descriptor.desc or key
                    local required = c.descriptor.cratesRequired or 1
                    if not byUnit[key] then
                        byUnit[key] = { desc = desc, count = 0, required = required }
                        table.insert(unitOrder, key)
                    end
                    byUnit[key].count = byUnit[key].count + 1
                end
            end

            if #unitOrder == 0 then
                trigger.action.outTextForGroup(gid,
                    ctld.tr("No crates within 300m."), 10)
                return
            end

            local lines = { ctld.tr("Crates within 300m:") }
            for _, key in ipairs(unitOrder) do
                local info = byUnit[key]
                if info.count >= info.required then
                    table.insert(lines, ctld.tr("  %1: %2/%3 — READY", info.desc, info.count, info.required))
                else
                    table.insert(lines, ctld.tr("  %1: %2/%3 — incomplete", info.desc, info.count, info.required))
                end
            end
            trigger.action.outTextForGroup(gid, table.concat(lines, "\n"), 15)
        end,
        { unitName = playerObj.unitName })

    self:refreshPackEquiptSection(playerObj, nil, true)  -- _noRefresh: buildMenu calls refresh() at end

    -- Parachute Crates: added when cap allows; visibility managed by refreshCrateFlightSection.
    if caps.canParachuteDrop then
        menu:addCommand({ root, cratesSub }, ctld.tr("Parachute Crates"),
            function(arg)
                local transport = Unit.getByName(arg.unitName)
                if not transport then return end
                CTLDCrateManager.getInstance():parachuteCrates(transport, arg)
            end,
            { unitName = playerObj.unitName, groupId = playerObj.groupId })
    end

    -- Release / Cut Slingload: added when cap allows; visibility managed by refreshCrateFlightSection.
    if caps.canSlingload then
        menu:addCommand({ root, cratesSub }, ctld.tr("Release Slingload"),
            function(arg)
                local t = Unit.getByName(arg.unitName)
                if not t then return end
                CTLDCrateManager.getInstance():releaseSlingload(t, arg)
            end,
            { unitName = playerObj.unitName, groupId = playerObj.groupId })

        menu:addCommand({ root, cratesSub }, ctld.tr("Cut Slingload"),
            function(arg)
                local t = Unit.getByName(arg.unitName)
                if not t then return end
                CTLDCrateManager.getInstance():cutSlingload(t, arg)
            end,
            { unitName = playerObj.unitName, groupId = playerObj.groupId })
    end

    self:refreshCrateFlightSection(playerObj)
end

--- Build "Smoke" F10 submenu for a player.
-- Requires enableSmokeDrop = true (configKey gate) AND isTransport.
-- @param playerObj CTLDPlayer
-- @param menu      ctld.Menu
function CTLDCrateManager:buildSmokeSection(playerObj, menu)
    if not playerObj.isTransport then return end

    local root     = ctld.tr("CTLD")
    local smokeSub = ctld.tr("Smoke")
    menu:addSubMenu({ root }, smokeSub, { order = 80 })

    local smMgr = CTLDSmokeManager.getInstance()

    local uName = playerObj.unitName

    local function doSmoke(arg)
        local unit = Unit.getByName(arg.unitName)
        if not (unit and unit:isExist()) then return end
        local pt  = unit:getPoint()
        local pos = { x = pt.x, y = land.getHeight({ x = pt.x, y = pt.z }), z = pt.z }
        trigger.action.smoke(pos, arg.color)
        trigger.action.outTextForCoalition(unit:getCoalition(),
            arg.unitName .. " dropped " .. arg.colorName .. " smoke.", 10)
        ctld.utils.log("INFO", "CTLDCrateManager:dropSmoke — %s %s", arg.unitName, arg.colorName)
        -- Feature H: always track the smoke so auto-resume can fire it
        -- even if the player activates the toggle after the drop.
        smMgr:registerSmoke(arg.unitName, pos, arg.color)
    end

    local function doToggleAutoResume(arg)
        local newState = smMgr:toggle(arg.unitName)
        local interval = ctld.gs("smokeAutoResumeInterval") or 270
        local msgKey   = newState
            and "Smoke auto-resume ON (%1s interval)"
            or  "Smoke auto-resume OFF"
        local msg = ctld.tr(msgKey):gsub("%%1", tostring(interval))
        local u = Unit.getByName(arg.unitName)
        local gid = ctld.utils.getGroupId(u)
        trigger.action.outTextForGroup(gid, msg, 10)
        ctld.utils.log("INFO", "CTLDSmokeManager: toggle for '%s' active=%s", arg.unitName, tostring(newState))
        -- Rebuild the full menu model (not just DCS layer) so the toggle label updates.
        -- refreshForUnit only replays the frozen memory model — buildMenu reconstructs it.
        local pm = CTLDPlayerManager.getInstance()
        if pm then
            local pObj = pm:getPlayer(arg.unitName)
            if pObj then pm:buildMenu(pObj) end
        end
    end

    menu:addCommand({ root, smokeSub }, ctld.tr("Drop Red Smoke"),    doSmoke,
        { unitName = uName, color = trigger.smokeColor.Red,    colorName = "RED" })
    menu:addCommand({ root, smokeSub }, ctld.tr("Drop Blue Smoke"),   doSmoke,
        { unitName = uName, color = trigger.smokeColor.Blue,   colorName = "BLUE" })
    menu:addCommand({ root, smokeSub }, ctld.tr("Drop Orange Smoke"), doSmoke,
        { unitName = uName, color = trigger.smokeColor.Orange, colorName = "ORANGE" })
    menu:addCommand({ root, smokeSub }, ctld.tr("Drop Green Smoke"),  doSmoke,
        { unitName = uName, color = trigger.smokeColor.Green,  colorName = "GREEN" })

    -- Feature H: toggle auto-resume (label reflects current state per unit)
    local toggleLabel = smMgr:isActive(uName)
        and ctld.tr("Smoke Auto-Resume [deactivate]")
        or  ctld.tr("Smoke Auto-Resume [activate]")
    menu:addCommand({ root, smokeSub }, toggleLabel, doToggleAutoResume, { unitName = uName })
end

-- ============================================================
-- Legacy-compatible public API (called by compat/legacy_api.lua)
-- ============================================================

--- Find a crate descriptor by weight number.
-- Uses self._weightIndex (O(1)) built by _processSpawnableCrates (singleCrates only).
-- @param weight number
-- @return table|nil  descriptor
function CTLDCrateManager:findDescriptorByWeight(weight)
    if not weight then return nil end
    if self._weightIndex then
        return self._weightIndex[weight]
    end
    -- Fallback: raw config scan (before _processSpawnableCrates ran)
    local spawnableCrates = ctld.gs("spawnableCrates")
    if not spawnableCrates then return nil end
    for _, category in pairs(spawnableCrates) do
        for _, descriptor in ipairs(category) do
            if descriptor.weight == weight then return descriptor end
        end
    end
    return nil
end

--- Spawn a crate at a DCS trigger zone (MM DO SCRIPT).
-- @param side   string   "red" | "blue"
-- @param weight number   crate weight (lookup key in spawnableCrates)
-- @param zone   string   DCS trigger zone name
-- @return CTLDCrate|nil
function CTLDCrateManager:spawnCrateAtZone(side, weight, zone)
    local trig = trigger.misc.getZone(zone)
    if not trig then
        ctld.utils.log("ERROR", "CTLDCrateManager:spawnCrateAtZone — zone not found: %s", tostring(zone))
        return nil
    end
    local descriptor = self:findDescriptorByWeight(weight)
    if not descriptor then
        ctld.utils.log("ERROR", "CTLDCrateManager:spawnCrateAtZone — no descriptor for weight=%s", tostring(weight))
        return nil
    end
    local p2  = { x = trig.point.x, y = trig.point.z }
    local pt  = { x = p2.x, y = land.getHeight(p2), z = p2.y }
    local cId = (side == "red") and coalition.side.RED or coalition.side.BLUE
    return self:spawnCrate(descriptor, pt, cId, nil, CTLDCrate.SPAWN_METHOD.MISSION_MAKER)
end

--- Spawn a crate at a Vec3 point (MM DO SCRIPT).
-- @param side   string   "red" | "blue"
-- @param weight number   crate weight
-- @param point  table    vec3 {x, y, z}
-- @param hdg    number   heading in degrees
-- @return CTLDCrate|nil
function CTLDCrateManager:spawnCrateAtPoint(side, weight, point, hdg)
    local descriptor = self:findDescriptorByWeight(weight)
    if not descriptor then
        ctld.utils.log("ERROR", "CTLDCrateManager:spawnCrateAtPoint — no descriptor for weight=%s", tostring(weight))
        return nil
    end
    local cId = (side == "red") and coalition.side.RED or coalition.side.BLUE
    return self:spawnCrate(descriptor, point, cId, nil, CTLDCrate.SPAWN_METHOD.MISSION_MAKER)
end

--- Start a recurring watcher that counts crates in a DCS zone and sets a DCS flag.
-- Reschedules every 5 seconds. Call once from a DO SCRIPT trigger.
-- @param zoneName   string          DCS trigger zone name
-- @param flagNumber number|string   DCS user flag to set to crate count
function CTLDCrateManager:startCrateCountWatcher(zoneName, flagNumber)
    local trig = trigger.misc.getZone(zoneName)
    if not trig then
        ctld.utils.log("ERROR", "CTLDCrateManager:startCrateCountWatcher — zone not found: %s", tostring(zoneName))
        return
    end
    local center = { x = trig.point.x, y = trig.point.y, z = trig.point.z }
    local radius = trig.radius
    local self_ref = self
    local function _tick()
        local count = 0
        for _, crate in pairs(self_ref.crates) do
            if crate:isOnGround() then
                if ctld.utils.getDistance("crateWatcher", crate.position, center) <= radius then
                    count = count + 1
                end
            end
        end
        trigger.action.setUserFlag(flagNumber, count)
        timer.scheduleFunction(function()
            self_ref:startCrateCountWatcher(zoneName, flagNumber)
        end, nil, timer.getTime() + 5)
    end
    _tick()
end
