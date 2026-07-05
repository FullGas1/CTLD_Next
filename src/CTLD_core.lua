-- ============================================================
-- CTLD_core.lua
-- Core infrastructure: EventDispatcher, CTLDDCSEventBridge,
-- CTLDPlayerTracker, CTLDCoreManager
--
-- Dependencies : class (lib/class.lua), CTLDUtils (ctld.utils),
--                CTLDCrateManager, CTLDJTACManager
-- DCS API      : world.addEventHandler, coalition.getPlayers,
--                coalition.getStaticObjects, coalition.getGroups,
--                Object.getCategory, timer.scheduleFunction
--
-- Initialisation order (called by CTLD_userConfig or entry point):
--   1. CTLDDCSEventBridge.getInstance()   -- registers world.addEventHandler
--   2. CTLDPlayerTracker.getInstance()    -- subscribes to player events + scan
--   3. CTLDCoreManager.getInstance()      -- INIT-B (crates) + INIT-C (JTACs)
--   4. other managers as needed
-- ============================================================

---@diagnostic disable
ctld = ctld or {}


-- ============================================================
-- EventDispatcher  (singleton — CTLD internal pub/sub only)
-- ============================================================
-- Routes CTLD business events (OnCrateLoaded, OnTroopsDeployed, …).
-- DCS engine events NEVER pass through here; they go through CTLDDCSEventBridge.

EventDispatcher = class()
EventDispatcher._instance = nil

--- Return (or create) the singleton instance.
function EventDispatcher.getInstance()
    if not EventDispatcher._instance then
        local o = setmetatable({}, EventDispatcher)
        o:init()
        EventDispatcher._instance = o
    end
    return EventDispatcher._instance
end

function EventDispatcher:init()
    self._listeners = {}
end

--- Subscribe callback to a named CTLD event.
-- The same callback may be registered multiple times; each registration
-- produces one additional call on publish.  Callers are responsible for
-- avoiding duplicate subscriptions.
-- @param eventName  string
-- @param callback   function  receives the payload table
function EventDispatcher:subscribe(eventName, callback)
    if type(callback) ~= "function" then return end
    if not self._listeners[eventName] then
        self._listeners[eventName] = {}
    end
    table.insert(self._listeners[eventName], callback)
end

--- Unsubscribe a specific callback (last-registered occurrence removed first).
-- @param eventName string
-- @param callback  function  exact reference used at subscribe time
function EventDispatcher:unsubscribe(eventName, callback)
    local subs = self._listeners[eventName]
    if not subs then return end
    for i = #subs, 1, -1 do
        if subs[i] == callback then
            table.remove(subs, i)
            return
        end
    end
end

--- Remove all subscribers for an event (e.g. on module teardown).
-- @param eventName string
function EventDispatcher:unsubscribeAll(eventName)
    self._listeners[eventName] = nil
end

--- Publish a CTLD event.  Dispatch list is copied before iteration so that
-- a callback may safely subscribe/unsubscribe during dispatch.
-- @param eventName string
-- @param payload   table
function EventDispatcher:publish(eventName, payload)
    local subs = self._listeners[eventName]
    if not subs or #subs == 0 then return end
    local dispatch = {}
    for i = 1, #subs do dispatch[i] = subs[i] end
    for i = 1, #dispatch do
        local ok, err = pcall(dispatch[i], payload)
        if not ok then
            ctld.utils.log("ERROR",
                "EventDispatcher:publish [%s] callback error: %s", eventName, tostring(err))
        end
    end
end


-- ============================================================
-- CTLDDCSEventBridge  (singleton — single world.addEventHandler)
-- ============================================================
-- Receives all DCS engine events and routes them to registered managers.
-- Each manager registers via bridge:register(target, eventId, "methodName").
-- The bridge does NO filtering beyond event id — filtering is each manager's job.

CTLDDCSEventBridge = class()
CTLDDCSEventBridge._instance = nil

--- Return (or create) the singleton instance.
-- world.addEventHandler is called exactly once, at first getInstance().
function CTLDDCSEventBridge.getInstance()
    if not CTLDDCSEventBridge._instance then
        local o = setmetatable({}, CTLDDCSEventBridge)
        o:init()
        CTLDDCSEventBridge._instance = o
    end
    return CTLDDCSEventBridge._instance
end

function CTLDDCSEventBridge:init()
    self._handlers = {}   -- eventId (number) -> list of { target, method }
    world.addEventHandler(self)
    ctld.utils.log("INFO", "CTLDDCSEventBridge: world.addEventHandler registered")
end

--- Register a manager method to be called for a DCS event id.
-- @param target   object   manager instance (self receiver)
-- @param eventId  number   world.event.S_EVENT_* constant
-- @param method   string   method name on target
function CTLDDCSEventBridge:register(target, eventId, method)
    if not self._handlers[eventId] then
        self._handlers[eventId] = {}
    end
    table.insert(self._handlers[eventId], { target = target, method = method })
end

--- DCS engine callback — do NOT rename.
function CTLDDCSEventBridge:onEvent(event)
    local list = self._handlers[event.id]
    if not list then return end
    for _, entry in ipairs(list) do
        local ok, err = pcall(entry.target[entry.method], entry.target, event)
        if not ok then
            ctld.utils.log("ERROR",
                "CTLDDCSEventBridge:onEvent handler error [%s / eventId=%s]: %s",
                tostring(entry.method), tostring(event.id), tostring(err))
        end
    end
end


-- ============================================================
-- CTLDStaticWatcher  (singleton)
-- ============================================================
-- Compensates for unreliable S_EVENT_DEAD on static/base objects.
-- Callers register an (id, checkFn, onDeadFn) triplet; a 1 s timer
-- polls checkFn() and calls onDeadFn() + dispatches "S_EVENT_STATIC_DEAD"
-- the first time checkFn returns false.
--
-- Usage:
--   CTLDStaticWatcher.getInstance():watch(id, checkFn, onDeadFn)
--   CTLDStaticWatcher.getInstance():unwatch(id)
--
-- S_EVENT_STATIC_DEAD payload: { id, meta }
--   meta = whatever the caller passed as 4th arg to watch() (optional).

CTLDStaticWatcher = class()
CTLDStaticWatcher._instance = nil

function CTLDStaticWatcher.getInstance()
    if not CTLDStaticWatcher._instance then
        local o = setmetatable({}, CTLDStaticWatcher)
        o:init()
        CTLDStaticWatcher._instance = o
    end
    return CTLDStaticWatcher._instance
end

function CTLDStaticWatcher:init()
    self._watched = {}   -- id -> { checkFn, onDeadFn, meta }
    self._timer   = nil
    ctld.utils.log("INFO", "CTLDStaticWatcher: init complete")
end

--- Register an object to watch.
-- @param id       string   unique key (e.g. airbase name or fobId)
-- @param checkFn  function returns true while alive
-- @param onDeadFn function called once when checkFn() → false
-- @param meta     any      passed to onDeadFn and S_EVENT_STATIC_DEAD payload (optional)
function CTLDStaticWatcher:watch(id, checkFn, onDeadFn, meta)
    self._watched[id] = { checkFn = checkFn, onDeadFn = onDeadFn, meta = meta }
    self:_ensureTimer()
    ctld.utils.log("INFO", "CTLDStaticWatcher: watching '%s'", tostring(id))
end

--- Deregister an object (e.g. on mark cleared by toggle/HideAll).
function CTLDStaticWatcher:unwatch(id)
    self._watched[id] = nil
    ctld.utils.log("INFO", "CTLDStaticWatcher: unwatched '%s'", tostring(id))
end

--- Start the poll timer if not already running.
function CTLDStaticWatcher:_ensureTimer()
    if self._timer then return end
    local self_ref = self
    self._timer = timer.scheduleFunction(function(_, t)
        return self_ref:_tick(t)
    end, nil, timer.getTime() + 1)
end

--- Poll all watched objects. Returns next schedule time or nil to stop.
function CTLDStaticWatcher:_tick(t)
    local dead = {}
    for id, entry in pairs(self._watched) do
        local ok, alive = pcall(entry.checkFn)
        if not ok or not alive then
            dead[#dead + 1] = id
        end
    end

    for _, id in ipairs(dead) do
        local entry = self._watched[id]
        self._watched[id] = nil
        ctld.utils.log("INFO", "CTLDStaticWatcher: '%s' dead — firing onDeadFn", tostring(id))
        local ok, err = pcall(entry.onDeadFn, entry.meta)
        if not ok then
            ctld.utils.log("ERROR", "CTLDStaticWatcher: onDeadFn error for '%s': %s",
                tostring(id), tostring(err))
        end
        local okD, ed = pcall(EventDispatcher.getInstance)
        if okD and ed then
            ed:publish("S_EVENT_STATIC_DEAD", { id = id, meta = entry.meta })
        end
    end

    if next(self._watched) then
        return t + 1   -- reschedule in 1 s
    else
        self._timer = nil
        return nil     -- no more watched objects — stop timer
    end
end

-- ============================================================
-- CTLDPlayerTracker  (singleton — human slot tracking, no MIST)
-- ============================================================
-- Maintains a double-index of connected human players:
--   _byUnit[unitName]     -> playerName
--   _byPlayer[playerName] -> { unitName, coalition }
--
-- Sources:
--   S_EVENT_PLAYER_ENTER_UNIT / LEAVE_UNIT  (primary, event-driven)
--   S_EVENT_BIRTH                           (backup for first joiner)
--   coalition.getPlayers() scan             (safety net during first 3 min)

CTLDPlayerTracker = class()
CTLDPlayerTracker._instance = nil

--- Return (or create) the singleton instance.
-- CTLDDCSEventBridge must be initialised before calling this.
function CTLDPlayerTracker.getInstance()
    if not CTLDPlayerTracker._instance then
        local o = setmetatable({}, CTLDPlayerTracker)
        o:init()
        CTLDPlayerTracker._instance = o
    end
    return CTLDPlayerTracker._instance
end

function CTLDPlayerTracker:init()
    self._byUnit   = {}   -- unitName   -> playerName
    self._byPlayer = {}   -- playerName -> { unitName, coalition }

    local bridge = CTLDDCSEventBridge.getInstance()
    bridge:register(self, world.event.S_EVENT_PLAYER_ENTER_UNIT, "onPlayerEnterUnit")
    bridge:register(self, world.event.S_EVENT_PLAYER_LEAVE_UNIT, "onPlayerLeaveUnit")
    bridge:register(self, world.event.S_EVENT_BIRTH,             "onBirth")

    -- Immediate scan: catch slots already occupied at init time
    self:_scanAllSlots()

    -- Repeated scans for 3 min to recover slots missed before bridge was ready
    -- (DCS may fire S_EVENT_BIRTH before world.addEventHandler is registered)
    local startTime = timer.getTime()
    local self_ref  = self
    local function securityScan()
        self_ref:_scanAllSlots()
        if timer.getTime() - startTime < 180 then
            return timer.getTime() + 30   -- reschedule every 30 s
        end
        -- After 3 min: event-driven tracking is sufficient
    end
    timer.scheduleFunction(securityScan, nil, timer.getTime() + 5)

    ctld.utils.log("INFO", "CTLDPlayerTracker: init complete")
end

-- DCS event handlers -------------------------------------------

function CTLDPlayerTracker:onPlayerEnterUnit(event)
    local unit = event.initiator
    if not unit then return end
    local playerName = unit:getPlayerName()
    if not playerName then return end
    local unitName = unit:getName()
    local coal     = unit:getCoalition()
    self._byUnit[unitName]     = playerName
    self._byPlayer[playerName] = { unitName = unitName, coalition = coal }
end

function CTLDPlayerTracker:onPlayerLeaveUnit(event)
    local unit = event.initiator
    if not unit then return end
    local unitName   = unit:getName()
    local playerName = self._byUnit[unitName]
    if playerName then
        self._byUnit[unitName]     = nil
        self._byPlayer[playerName] = nil
    end
end

--- Backup handler: catches first joiner if PLAYER_ENTER_UNIT was missed.
function CTLDPlayerTracker:onBirth(event)
    local unit = event.initiator
    if not (unit and unit.getPlayerName) then return end
    local playerName = unit:getPlayerName()
    if not playerName then return end
    local unitName = unit:getName()
    if self._byUnit[unitName] then return end   -- already tracked
    local coal = unit:getCoalition()
    self._byUnit[unitName]     = playerName
    self._byPlayer[playerName] = { unitName = unitName, coalition = coal }
end

-- Internal scan ----------------------------------------------------

--- Active scan via coalition.getPlayers() — idempotent, adds missing entries only.
function CTLDPlayerTracker:_scanAllSlots()
    for _, side in ipairs({ coalition.side.RED, coalition.side.BLUE }) do
        local units = coalition.getPlayers(side) or {}
        for _, unit in ipairs(units) do
            local playerName = unit:getPlayerName()
            if playerName then
                local unitName = unit:getName()
                if not self._byUnit[unitName] then
                    local coal = unit:getCoalition()
                    self._byUnit[unitName]     = playerName
                    self._byPlayer[playerName] = { unitName = unitName, coalition = coal }
                end
            end
        end
    end
end

-- Public API -------------------------------------------------------

--- Return the playerName occupying unitName, or nil if AI/unoccupied.
-- @param unitName string
-- @return string or nil
function CTLDPlayerTracker:getPlayerByUnit(unitName)
    return self._byUnit[unitName]
end

--- Return { unitName, coalition } for playerName, or nil if not connected.
-- @param playerName string
-- @return table or nil
function CTLDPlayerTracker:getUnitByPlayer(playerName)
    return self._byPlayer[playerName]
end

--- Return all connected players as a list of { playerName, unitName, coalition }.
-- @return table
function CTLDPlayerTracker:getAllPlayers()
    local result = {}
    for playerName, data in pairs(self._byPlayer) do
        result[#result + 1] = {
            playerName = playerName,
            unitName   = data.unitName,
            coalition  = data.coalition,
        }
    end
    return result
end

--- Return true if unitName is currently occupied by a human player.
-- @param unitName string
-- @return boolean
function CTLDPlayerTracker:isPlayerUnit(unitName)
    return self._byUnit[unitName] ~= nil
end


-- ============================================================
-- CTLDCoreManager  (singleton — startup orchestrator)
-- ============================================================
-- Runs INIT-B (MM crates), INIT-C (MM JTACs) and INIT-D (MM vehicles) at startup.
-- Registers late-activation handlers for crates, JTACs and vehicles in the bridge.
--
-- INIT-A (AI transports) is deferred to CTLDTransportManager (not yet implemented).

CTLDCoreManager = class()
CTLDCoreManager._instance = nil

--- Return (or create) the singleton instance.
-- CTLDDCSEventBridge, CTLDPlayerTracker, CTLDCrateManager and CTLDJTACManager
-- must all be available before calling this.
function CTLDCoreManager.getInstance()
    if not CTLDCoreManager._instance then
        local o = setmetatable({}, CTLDCoreManager)
        o:init()
        CTLDCoreManager._instance = o
    end
    return CTLDCoreManager._instance
end

function CTLDCoreManager:init()
    local bridge = CTLDDCSEventBridge.getInstance()

    -- Register late-activation handlers
    bridge:register(CTLDCrateManager.getInstance(),    world.event.S_EVENT_BIRTH, "onBirth")
    bridge:register(CTLDJTACManager.getInstance(),             world.event.S_EVENT_BIRTH, "onBirth")
    bridge:register(CTLDVehicleSpawner.getInstance(),  world.event.S_EVENT_BIRTH, "onBirth")

    -- Register land/takeoff for dynamic troop menu rebuild
    bridge:register(CTLDPlayerManager.getInstance(), world.event.S_EVENT_LAND,    "onLand")
    bridge:register(CTLDPlayerManager.getInstance(), world.event.S_EVENT_TAKEOFF, "onTakeoff")

    -- Register land event for AI troop pickup/dropoff (exact touchdown)
    bridge:register(self, world.event.S_EVENT_LAND, "onAILand")

    -- Troop unit death: keep _aliveUnits / _jtacUnits in sync with DCS reality
    -- Also triggers cleanupDeadTransports to remove orphaned transit entries
    local okTM, tm = pcall(CTLDTroopManager.getInstance)
    if okTM then
        bridge:register(tm, world.event.S_EVENT_DEAD, "onUnitDead")
        bridge:register(tm, world.event.S_EVENT_DEAD, "onTransportDead")
        ctld.utils.log("INFO", "CTLDCoreManager: CTLDTroopManager S_EVENT_DEAD bridge registered")
    end

    -- INIT-B: detect cargo statics placed by the mission maker
    self:_initMMCrates()

    -- INIT-C: detect JTAC groups pre-placed by the mission maker
    self:_initMMJTACs()

    -- INIT-D: detect ground vehicles placed by the mission maker
    CTLDVehicleSpawner.getInstance():scanMMVehicles()

    -- INIT-E: register MM pre-placed groups as extractable
    self:_initExtractableGroups()

    -- INIT-MOD: probe all DCS typeNames declared in config — detect missing mods
    CTLDModValidator.getInstance():run()
    -- INIT-SCENE-AUDIT: disable scenes with missing DCS types + purge from Request Equipment menu
    CTLDSceneManager.getInstance():_auditAfterModValidator()

    -- INIT-A: AI transport auto-pickup/dropoff loop
    self:_initAITransports()

    ctld.utils.log("INFO", "CTLDCoreManager: init complete (INIT-A + INIT-B + INIT-C + INIT-D + INIT-E + INIT-MOD + INIT-SCENE-AUDIT)")
end

-- INIT-B -----------------------------------------------------------

--- Scan all coalition statics for cargo objects placed by the mission maker.
-- Delegates to CTLDCrateManager:registerMMCrate() for each detected cargo.
-- API note: coalition.getStaticObjects() may return destroyed objects (DCS bug)
--           → filtered by isExist().  Object.getCategory() == 6 == CARGO.
function CTLDCoreManager:_initMMCrates()
    local sides = { coalition.side.RED, coalition.side.BLUE, coalition.side.NEUTRAL }
    local count = 0
    for _, side in ipairs(sides) do
        local statics = coalition.getStaticObjects(side) or {}
        for _, obj in ipairs(statics) do
            if obj:isExist() and Object.getCategory(obj) == 6 then
                local desc = obj:getDesc()
                if desc and desc.attributes and desc.attributes.Cargos == true then
                    CTLDCrateManager.getInstance():registerMMCrate(obj, desc)
                    count = count + 1
                end
            end
        end
    end
    ctld.utils.log("INFO", "CTLDCoreManager: INIT-B complete — %d MM crate(s) detected", count)
end

-- INIT-C -----------------------------------------------------------

--- Scan all coalition ground groups for JTAC groups pre-placed by the mission maker.
-- Delegates to CTLDJTACManager for active groups; marks late-activation groups pending.
-- API note: coalition.getGroups() may return destroyed groups (DCS bug)
--           → filtered by isExist().  Only RED and BLUE (no NEUTRAL support).
function CTLDCoreManager:_initMMJTACs()
    local sides = { coalition.side.RED, coalition.side.BLUE }
    local count = 0
    for _, side in ipairs(sides) do
        local groups = coalition.getGroups(side) or {}
        for _, group in ipairs(groups) do
            if group:isExist() and self:_isJTACGroup(group) then
                -- isActive() only exists on ME-placed groups; dynamically spawned groups (coalition.addGroup)
                -- do not have this method → guard with pcall, default to true (already active).
                local ok, isAct = pcall(function() return group:isActive() end)
                if not ok then isAct = true end
                if isAct then
                    CTLDJTACManager.getInstance():registerMMJTAC(group)
                else
                    -- Late activation: will be picked up by onBirth handler
                    CTLDJTACManager.getInstance():markPendingJTAC(group:getName())
                end
                count = count + 1
            end
        end
    end
    ctld.utils.log("INFO", "CTLDCoreManager: INIT-C complete — %d MM JTAC group(s) detected", count)
end

-- INIT-E -----------------------------------------------------------

--- Register pre-placed MM groups as extractable (embarkFromField-eligible).
-- Legacy parity: source/CTLD.lua:11276-11287 — reads extractableGroups at init and
-- inserts matching DCS groups into droppedTroopsRED/BLUE.
-- In v2: inserts groupName into CTLDTroopManager._droppedGroups[coalition].
-- No late-activation support (iso-legacy: groups that don't exist at init are skipped).
-- No _droppedTemplates entry — embarkFromField falls back to 130 kg per alive unit (iso-legacy).
function CTLDCoreManager:_initExtractableGroups()
    local names = ctld.gs("extractableGroups") or {}
    local count = 0
    local tm = CTLDTroopManager.getInstance()
    for _, groupName in ipairs(names) do
        local group = Group.getByName(groupName)
        if group == nil or not group:isExist() then
            ctld.utils.log("WARN", "CTLDCoreManager: INIT-E — extractableGroup '%s' not found, skipped", groupName)
        else
            local coa = group:getCoalition()
            if not tm._droppedGroups[coa] then tm._droppedGroups[coa] = {} end
            table.insert(tm._droppedGroups[coa], groupName)
            count = count + 1
            ctld.utils.log("INFO", "CTLDCoreManager: INIT-E — registered extractable group '%s' (coalition %d)",
                groupName, coa)
        end
    end
    ctld.utils.log("INFO", "CTLDCoreManager: INIT-E complete — %d extractable group(s) registered", count)
end

--- Return true if group should be managed as a JTAC by CTLD.
-- Detection rule (new OOP system — no separate jtacUnitTypes table):
--   Group name contains "jtac" (case-insensitive).
-- Convention: MM must name JTAC groups with "jtac" in the name
--   (e.g. "jtac_blue_1", "JTAC_Red_Drone").
-- @param group Group  DCS group object
-- @return boolean
function CTLDCoreManager:_isJTACGroup(group)
    return group:getName():lower():find("jtac") ~= nil
end

-- INIT-A -----------------------------------------------------------

--- Build per-coalition team lists and start the AI transport polling loop.
-- Legacy parity: ctld.checkAIStatus + redTeams/blueTeams init (source/CTLD.lua:11291-11334).
-- The loop always runs (AI auto-unload at dropoff zones works regardless of the flag).
-- allowRandomAiTeamPickups gates random template selection vs first-available.
function CTLDCoreManager:_initAITransports()
    -- Always build team lists — populated regardless of transportPilotNames.
    -- side == nil → both coalitions ; side == 1 → RED ; side == 2 → BLUE
    self._aiTeams = { [1] = {}, [2] = {} }
    self._aiTransportVehicle = {}  -- [unitName] = { type=string, isScene=bool } | nil
    local okTM, tm = pcall(CTLDTroopManager.getInstance)
    if okTM and tm then
        for _, tmpl in ipairs(tm._templates) do
            if not tmpl.disabled then
                if tmpl.side == nil or tmpl.side == 1 then
                    table.insert(self._aiTeams[1], tmpl)
                end
                if tmpl.side == nil or tmpl.side == 2 then
                    table.insert(self._aiTeams[2], tmpl)
                end
            end
        end
    end

    -- Build lookup set for fast O(1) check in onAILand.
    local pilotNames = ctld.gs("transportPilotNames")
    self._aiPilotNames = {}
    if pilotNames then
        for _, n in ipairs(pilotNames) do self._aiPilotNames[n] = true end
    end

    -- Skip timer if no AI pilots configured.
    if not pilotNames or #pilotNames == 0 then
        ctld.utils.log("INFO", "CTLDCoreManager: INIT-A teams built — timer skipped (transportPilotNames empty)")
        return
    end

    -- Post-init scan: trigger pickup for AI pilots already on the ground inside a pickup zone.
    -- Handles the case where the unit spawns at the AIZ_P location (S_EVENT_LAND never fires).
    local selfRef = self
    timer.scheduleFunction(function()
        for unitName in pairs(selfRef._aiPilotNames) do
            local u = Unit.getByName(unitName)
            if u and u:isExist() and not ctld.utils.inAir(u) then
                selfRef:onAILand({ id = world.event.S_EVENT_LAND, initiator = u })
            end
        end
    end, nil, timer.getTime() + 0.5)

    -- Start polling loop (2 s interval — same as legacy).
    local function loop(_, t)
        -- Guard B: stop zombie loop if this instance is no longer the singleton.
        if CTLDCoreManager._instance ~= selfRef then return nil end
        selfRef:_checkAIStatus()
        return t + 2
    end
    local fid = timer.scheduleFunction(loop, nil, timer.getTime() + 1)
    ctld.scheduler.register("ai_transport", fid)
    ctld.utils.log("INFO", "CTLDCoreManager: INIT-A complete — AI transport loop started (%d pilot name(s))",
        #pilotNames)
end

--- Periodic AI transport maintenance (every 2 s).
-- Primary pickup/dropoff via S_EVENT_LAND; this loop is a safety fallback for units
-- still on the ground after landing (handles cases where S_EVENT_LAND fires before
-- the unit has fully stopped inside the zone).
function CTLDCoreManager:_checkAIStatus()
    local ok, tm = pcall(CTLDTroopManager.getInstance)
    if not ok or not tm then return end
    -- Cleanup orphaned transport entries.
    local okClean, errClean = pcall(tm.cleanupDeadTransports, tm)
    if not okClean then
        ctld.utils.log("WARN", "CTLDCoreManager:_checkAIStatus cleanupDeadTransports error: %s", tostring(errClean))
    end
    -- Fallback pickup/dropoff: process any AI pilot currently on the ground.
    -- Guards inside onAILand (hasTroops checks, zone checks) prevent double actions.
    for unitName in pairs(self._aiPilotNames) do
        local u = Unit.getByName(unitName)
        if u and u:isExist() and not ctld.utils.inAir(u) then
            self:onAILand({ id = world.event.S_EVENT_LAND, initiator = u, _aiRetried = true })
        end
    end
end

--- Called on S_EVENT_LAND for AI transports.
-- Handles vehicle and troop pickup/dropoff at the exact moment of landing.
-- Dropoff zone is checked first; pickup is skipped on the same landing.
-- Parachute vehicle dropoff (in-flight) is not handled here.
function CTLDCoreManager:onAILand(event)
    local u = event and event.initiator
    if not u or not u:isExist() then return end

    local unitName = u:getName()
    local aiSet = self._aiPilotNames or {}
    if not aiSet[unitName] then return end
    if u:getPlayerName() ~= nil then return end  -- skip player-controlled

    local ok, tm = pcall(CTLDTroopManager.getInstance)
    if not ok or not tm then return end
    local okVS, vs = pcall(CTLDVehicleSpawner.getInstance)

    local coa       = u:getCoalition()
    local pt        = u:getPoint()
    local zm        = CTLDZoneManager.getInstance()
    local typeName  = u:getTypeName()
    local hasTr     = tm:hasTroops(unitName)
    local caps      = (ctld.gs("capabilitiesByType") or {})[typeName] or {}

    -- ---- Dropoff zone (vehicle + troops, ground only) -------------------
    local dropZone = zm:getAIDropoffZoneAt(pt, coa)
    if dropZone then
        local dm = dropZone.aiDropMode or "GP"

        -- Virtual vehicle dropoff (Feature T: stock-based AI vehicles)
        local vEntry = self._aiTransportVehicle[unitName]
        if vEntry and (dm == "G" or dm == "GP") then
            if vEntry.isScene then
                CTLDSceneManager.getInstance():playScene(u, vEntry.type, nil, nil)
            elseif vEntry.isAASystem then
                -- Feature U: spawn multi-part AA system directly (bypass crate assembly)
                CTLDCrateAssemblyManager.getInstance():spawnSystemAt(
                    vEntry.type, pt, coa, u:getCountry())
            else
                if okVS then
                    -- Spawn in the rear sector at safe distance from the transport
                    -- so the helicopter can take off without hitting the vehicle.
                    local safePos = vs:computeSafeDropPos(u, true)
                    vs:spawnVehicleAt({ vehicleType = vEntry.type,
                                        country     = u:getCountry(),
                                        coalitionId = coa }, safePos)
                end
            end
            ctld.utils.notifyCoalition(
                ctld.tr("AI %1 delivered: %2", unitName, vEntry.type), 10, coa)
            -- restore stock if dropzone is also a pickup zone
            if dropZone.isAIPickup then dropZone:aiRestoreVehicleStock(vEntry.type) end
            self._aiTransportVehicle[unitName] = nil
        end

        -- Physical vehicle dropoff (Feature S: DCS whole-unit in transit via loadVehicle)
        if okVS and (dm == "G" or dm == "GP") and not vEntry then
            local loaded = vs:findLoadedVehicles(u)
            if #loaded > 0 then
                local veh = loaded[1]
                -- Spawn behind the helicopter (rear sector) so the AI takeoff path
                -- (forward) does not intersect the newly placed vehicle.
                vs:unloadVehicle(veh, u, nil, "menu_ctld", true)
                ctld.utils.notifyCoalition(
                    ctld.tr("AI %1 unloaded: %2", unitName, veh.vehicleType or "vehicle"),
                    10, coa)
            end
        end

        -- Troop dropoff
        if hasTr and (dm == "G" or dm == "GP") then
            local transitList = tm:getInTransit(unitName) or {}
            local troopNames  = {}
            local troopTotal  = 0
            for _, grp in ipairs(transitList) do
                if grp.templateName then troopNames[#troopNames + 1] = grp.templateName end
                troopTotal = troopTotal + (grp.unitTotal or 0)
            end
            -- restore per-template stock if dropzone is also a pickup zone (Feature T)
            if dropZone.isAIPickup then
                for _, grp in ipairs(transitList) do
                    if grp.templateName then
                        dropZone:aiRestoreTroopStock(grp.templateName, grp.unitTotal or 1)
                    end
                end
            end
            tm:disembarkAll(u)
            ctld.utils.notifyCoalition(
                ctld.tr("AI %1 dropped troops: %2 (%3)", unitName, table.concat(troopNames, ", "), troopTotal),
                10, coa)
        end
        return  -- dropoff zone: no pickup on same landing
    end

    -- ---- Pickup zone (vehicle + troops, gated by aiCargoType) ----------
    local pickZone = zm:getAIPickupZoneAt(pt, coa)
    if not pickZone and not event._aiRetried then
        local selfRef = self
        timer.scheduleFunction(function()
            if u and u:isExist() and not ctld.utils.inAir(u) then
                selfRef:onAILand({ id = event.id, initiator = u, _aiRetried = true })
            end
        end, nil, timer.getTime() + 1.5)
    end
    if pickZone then
        local cargoType = pickZone.aiCargoType or "T"
        local doVeh     = (cargoType == "V" or cargoType == "TV")
        local doTroops  = (cargoType == "T" or cargoType == "TV")

        -- Vehicle pickup
        -- A: vehicleStock=nil → pickup disabled for this zone
        if doVeh and caps.canTransportWholeVehicle and pickZone._aiVehicleStock then
            local alreadyLoaded = (self._aiTransportVehicle[unitName] ~= nil)
                               or (okVS and #vs:findLoadedVehicles(u) > 0)
            if not alreadyLoaded then
                local physicalLoaded = false

                -- C1: physical DCS vehicles in zone take priority
                if okVS then
                    local loadables = vs:findLoadableVehicles(u)
                    if pickZone.vehicleTypes then
                        local typeSet = {}
                        for _, vt in ipairs(pickZone.vehicleTypes) do typeSet[vt] = true end
                        local filtered = {}
                        for _, v in ipairs(loadables) do
                            if typeSet[v.vehicleType] then filtered[#filtered + 1] = v end
                        end
                        loadables = filtered
                    end
                    local maxW    = caps.maxVehicleWeight
                    local weights = ctld.gs("groundVehicleWeights") or {}
                    local compatible = {}
                    for _, v in ipairs(loadables) do
                        local w = weights[v.vehicleType] or 0
                        if not maxW or w <= maxW then compatible[#compatible + 1] = v end
                    end
                    if #loadables > 0 and #compatible == 0 then
                        ctld.utils.log("WARN",
                            "CTLDCoreManager:onAILand [%s] no physical vehicle within weight limit (%s kg), %d found",
                            unitName, tostring(maxW), #loadables)
                    end
                    if #compatible > 0 then
                        local veh = compatible[1]
                        vs:loadVehicle(veh, u, nil, "menu_ctld")
                        ctld.utils.notifyCoalition(
                            ctld.tr("AI %1 loaded: %2", unitName, veh.vehicleType or "vehicle"),
                            10, coa)
                        physicalLoaded = true
                    end
                end

                -- C2: virtual stock pickup only when no physical vehicle found
                if not physicalLoaded then
                    local vEntry = pickZone:aiPickVehicleEntry()  -- nil if isAll
                    if vEntry then
                        pickZone:aiConsumeVehicleStock(vEntry.type)
                        self._aiTransportVehicle[unitName] = vEntry
                        ctld.utils.notifyCoalition(
                            ctld.tr("AI %1 loaded: %2", unitName, vEntry.type), 10, coa)
                    end
                end
            end
        end

        -- Troop pickup (re-check hasTroops after potential vehicle load)
        -- A: troopStock=nil → pickup disabled for this zone
        if doTroops and not tm:hasTroops(unitName) and pickZone._aiTroopStock then
            local teams = self._aiTeams[coa] or {}
            -- troopTemplates whitelist (Feature S) — applied before stock selection
            if pickZone.troopTemplates then
                local nameSet = {}
                for _, tn in ipairs(pickZone.troopTemplates) do nameSet[tn] = true end
                local filtered = {}
                for _, t in ipairs(teams) do
                    if nameSet[t.name] then filtered[#filtered + 1] = t end
                end
                if #filtered == 0 then
                    ctld.utils.log("WARN",
                        "CTLDCoreManager:onAILand [%s] troopTemplates whitelist matched no team — skipped",
                        unitName)
                end
                teams = filtered
            end
            -- B: equitable draw among eligible templates by highest current stock
            local tmpl = pickZone:aiPickTroopTemplate(teams, typeName, unitName, tm)
            if not tmpl then
                ctld.utils.log("WARN",
                    "CTLDCoreManager:onAILand [%s] troopStock exhausted or no eligible template",
                    unitName)
            else
                local loaded = tm:embarkFromTroopZone(u, pickZone, tmpl)
                if loaded then
                    pickZone:aiConsumeTroopStock(tmpl.name)
                    ctld.utils.notifyCoalition(
                        ctld.tr("AI %1 picked up troops: %2 (%3)", unitName, tmpl.name, tmpl.total),
                        10, coa)
                end
            end
        end
    end
end
