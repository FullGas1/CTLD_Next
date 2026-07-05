-- ============================================================
-- CTLD_beacon.lua
-- CTLDBeacon entity + CTLDBeaconManager singleton
--
-- Dependencies : class (lib/class.lua), CTLDUtils (ctld.utils),
--                CTLDConfig (ctld.gs), EventDispatcher
-- DCS API      : coalition.addGroup, Group.getByName, trigger.action,
--                coord.LOtoLL, coord.LLtoMGRS, timer, land.getHeight
--
-- Beacon lifecycle:
--   dropped  : 3 TACAN_beacon units spawned, radio transmissions started
--   active   : refresh every beaconRefreshInterval seconds
--   destroyed: battery depleted OR < 3 units alive → cleanup + free freqs
--   removed  : manual removal by player within 500m
--
-- Frequency pools (recycled when < 3 free):
--   VHF : 200–1250 kHz  (10 kHz steps below 850, 50 kHz above)
--   UHF : 220–399 MHz   (0.5 MHz steps)
--   FM  : 30–76 MHz     (formula: (100*f + 10*s + t) * 100 kHz)
--
-- Radio transmission modes:
--   VHF : mode 0 (AM), sound = radioSound
--   UHF : mode 0 (AM), sound = radioSoundFC3 (silent — FC3 aircraft)
--   FM  : mode 1 (FM), sound = radioSound
--
-- Draw layer:
--   Per-player toggle. Each beacon draws 2 circles + 1 text label.
--   Mark IDs: beaconId*10+1 (outer), *10+2 (inner), *10+3 (text).
-- ============================================================

---@diagnostic disable
ctld = ctld or {}

-- ============================================================
-- CTLDBeacon  (entity)
-- ============================================================

CTLDBeacon = class()

--- Constructor.
-- @param data table
--   Required : beaconName, name, coalition, position
--              vhfGroupName, uhfGroupName, fmGroupName
--              vhf (Hz), uhf (Hz), fm (Hz)
--              batteryEndTime (-1 = infinite), spawnTime
-- @param data.isFOB bool  (default false)
function CTLDBeacon:init(data)
    self.beaconName    = data.beaconName     -- unique key (vhfGroupName)
    self.name          = data.name           -- display name ("Beacon #3")
    self.coalitionId   = data.coalitionId
    self.position      = data.position

    self.vhfGroupName  = data.vhfGroupName
    self.uhfGroupName  = data.uhfGroupName
    self.fmGroupName   = data.fmGroupName

    self.vhf           = data.vhf
    self.uhf           = data.uhf
    self.fm            = data.fm

    self.batteryEndTime= data.batteryEndTime  -- timer.getTime() + duration, or -1
    self.spawnTime     = data.spawnTime       -- timer.getAbsTime() at drop
    self.isFOB         = data.isFOB or false
end

--- True if the beacon battery is still alive (or infinite).
function CTLDBeacon:isBatteryAlive()
    return self.batteryEndTime == -1 or timer.getTime() < self.batteryEndTime
end

--- Number of still-alive DCS units for this beacon (0–3).
function CTLDBeacon:countAliveUnits()
    local n = 0
    for _, gname in ipairs({ self.vhfGroupName, self.uhfGroupName, self.fmGroupName }) do
        local g = Group.getByName(gname)
        if g and g:getUnits() and #g:getUnits() == 1 then n = n + 1 end
    end
    return n
end

--- Battery remaining in seconds. Returns math.huge for infinite beacons.
function CTLDBeacon:batteryRemaining()
    if self.batteryEndTime == -1 then return math.huge end
    return math.max(0, self.batteryEndTime - timer.getTime())
end

--- Formatted frequency string for display.
-- "245.00 kHz - 350.50 / 45.20 MHz"
function CTLDBeacon:freqText()
    return string.format("%.2f kHz - %.2f / %.2f MHz",
        self.vhf / 1000, self.uhf / 1000000, self.fm / 1000000)
end

--- Formatted MGRS string for the beacon position.
function CTLDBeacon:mgrsCoords()
    local lat, lon = coord.LOtoLL(self.position)
    local mgrs     = coord.LLtoMGRS(lat, lon)
    return string.format("%s %s %s",
        mgrs.UTMZone .. mgrs.MGRSDigraph,
        string.sub(mgrs.Easting,  1, 5),
        string.sub(mgrs.Northing, 1, 5))
end


-- ============================================================
local BEACON_REMOVAL_RADIUS = 500  -- Max distance (m) to search for the closest beacon to remove

-- CTLDBeaconManager  (singleton)
-- ============================================================

CTLDBeaconManager = class()
CTLDBeaconManager._instance = nil

function CTLDBeaconManager.getInstance()
    if not CTLDBeaconManager._instance then
        local o = setmetatable({}, CTLDBeaconManager)
        o:init()
        CTLDBeaconManager._instance = o
    end
    return CTLDBeaconManager._instance
end

function CTLDBeaconManager:init()
    self._beacons         = {}   -- beaconName -> CTLDBeacon
    self._beaconCount     = 0    -- monotonic counter for display names
    self._layerState      = {}   -- playerName -> { enabled=bool, marks={} }
    -- Mark IDs are allocated from ctld.utils.getNextMarkId() (app-wide monotonic counter)

    -- Frequency pools
    self._freeVHF  = {}
    self._usedVHF  = {}
    self._freeUHF  = {}
    self._usedUHF  = {}
    self._freeFM   = {}
    self._usedFM   = {}
    self:_buildFreqPools()

    if ctld.gs("enabledRadioBeaconDrop") then
        self:_scheduleRefresh()
    end

    CTLDPlayerManager.getInstance():registerMenuSection({
        key       = "beacons",
        manager   = self,
        method    = "buildMenuSection",
        configKey = "enabledRadioBeaconDrop",
        order     = 60,
    })
    ctld.utils.log("INFO", "CTLDBeaconManager: init complete")
end

-- ============================================================
-- Frequency pools
-- ============================================================

-- Known NDB frequencies to skip in VHF pool (kHz → × 1000 = Hz).
-- These match existing NDB beacons on DCS maps (Caucasus, Nevada, etc.)
-- and would interfere if used for CTLD radio beacons.
CTLDBeaconManager._ndbSkip = {
    745, 381, 384, 300.50, 312.5, 1175, 342, 735, 353.00, 440,
    795, 525, 520, 690, 625, 291.5, 435, 309.50, 920, 1065,
    274, 312.50, 580, 602, 297.50, 750, 485, 950, 214,
    1025, 730, 995, 455, 307, 670, 329, 395, 770,
    380, 705, 300.5, 507, 740, 1030, 515,
    330, 309.5, 348, 462, 905, 352, 1210, 942, 435, 324,
    320, 420, 311, 389, 396, 862, 680, 297.5, 920, 662,
    866, 907, 309.5, 822, 515, 470, 342, 1182, 309.5, 720, 528,
    337, 312.5, 830, 740, 309.5, 641, 312, 722, 682, 1050,
    1116, 935, 1000, 430, 577, 326,
}

function CTLDBeaconManager:_buildFreqPools()
    -- Build NDB skip set for fast lookup (Hz values)
    local skipSet = {}
    for _, kHz in ipairs(CTLDBeaconManager._ndbSkip) do
        skipSet[kHz * 1000] = true
    end

    -- VHF: 200–840 kHz by 10 kHz (skipping NDB), then 850–1250 kHz by 50 kHz (skipping NDB)
    for f = 200000, 840000, 10000 do
        if not skipSet[f] then self._freeVHF[#self._freeVHF + 1] = f end
    end
    for f = 850000, 1250000, 50000 do
        if not skipSet[f] then self._freeVHF[#self._freeVHF + 1] = f end
    end

    -- UHF: 220–398.5 MHz by 0.5 MHz (stops before 399 MHz, matching source)
    local f = 220000000
    while f < 399000000 do
        self._freeUHF[#self._freeUHF + 1] = f
        f = f + 500000
    end

    -- FM: (100*f + 10*s + t) * 100000 Hz, f=3..7, s=0..5, t=0..9
    for f = 3, 7 do
        for s = 0, 5 do
            for t = 0, 9 do
                self._freeFM[#self._freeFM + 1] = (100 * f + 10 * s + t) * 100000
            end
        end
    end
end

--- Draw one frequency from a pool, recycling used if < 3 free.
-- @param free  table (pool of free freqs)
-- @param used  table (pool of used freqs)
-- @return number frequency (Hz)
function CTLDBeaconManager:_pickFreq(free, used)
    if #free <= 3 then
        for _, f in ipairs(used) do free[#free + 1] = f end
        for k in pairs(used) do used[k] = nil end
    end
    local idx  = math.random(#free)
    local freq = table.remove(free, idx)
    used[#used + 1] = freq
    return freq
end

--- Return all three frequencies for a new beacon.
function CTLDBeaconManager:_assignFrequencies()
    return {
        vhf = self:_pickFreq(self._freeVHF, self._usedVHF),
        uhf = self:_pickFreq(self._freeUHF, self._usedUHF),
        fm  = self:_pickFreq(self._freeFM,  self._usedFM),
    }
end

--- Return frequencies to their free pools.
function CTLDBeaconManager:_freeFrequencies(beacon)
    self._freeVHF[#self._freeVHF + 1] = beacon.vhf
    self._freeUHF[#self._freeUHF + 1] = beacon.uhf
    self._freeFM[#self._freeFM + 1]   = beacon.fm
    -- Remove from used tables
    for _, pool in ipairs({ {self._usedVHF, beacon.vhf},
                             {self._usedUHF, beacon.uhf},
                             {self._usedFM,  beacon.fm} }) do
        for i = #pool[1], 1, -1 do
            if pool[1][i] == pool[2] then table.remove(pool[1], i); break end
        end
    end
end

-- ============================================================
-- Spawn helpers
-- ============================================================

--- Spawn one TACAN_beacon DCS group at position for a given country.
-- Returns the spawned Group, or nil on failure.
function CTLDBeaconManager:_spawnBeaconUnit(point, countryId, displayName)
    local uid = ctld.utils.getNextUniqId()
    local groupData = {
        visible  = false,
        hidden   = false,
        category = Group.Category.GROUND,
        country  = countryId,
        name     = "CTLDBeacon-" .. uid,
        task     = {},
        units    = {
            {
                type           = "TACAN_beacon",
                name           = "CTLDBeaconUnit-" .. uid .. " [" .. displayName .. "]",
                x              = point.x,
                y              = point.z,   -- DCS ground unit: y = world Z
                heading        = 0,
                playerCanDrive = true,
                skill          = "Excellent",
            }
        },
    }
    local result = ctld.utils.dynAdd("CTLDBeaconManager:_spawnBeaconUnit", groupData)
    if not result then
        ctld.utils.log("ERROR", "CTLDBeaconManager: dynAdd failed for beacon unit")
        return nil
    end
    return Group.getByName(result.name)
end

--- Start (or restart) radio transmissions for a beacon's three groups.
function CTLDBeaconManager:_startTransmissions(beacon)
    local soundNormal = "l10n/DEFAULT/" .. (ctld.gs("radioSound")    or "beacon.ogg")
    local soundSilent = "l10n/DEFAULT/" .. (ctld.gs("radioSoundFC3") or "beaconsilent.ogg")

    local entries = {
        { groupName = beacon.vhfGroupName, freq = beacon.vhf, mode = 0, sound = soundNormal },
        { groupName = beacon.uhfGroupName, freq = beacon.uhf, mode = 0, sound = soundSilent },
        { groupName = beacon.fmGroupName,  freq = beacon.fm,  mode = 1, sound = soundNormal },
    }

    for _, e in ipairs(entries) do
        local g = Group.getByName(e.groupName)
        if g and g:getUnits() and #g:getUnits() == 1 then
            local unit = g:getUnit(1)
            -- Set ROE: weapon hold
            g:getController():setOption(
                AI.Option.Ground.id.ROE,
                AI.Option.Ground.val.ROE.WEAPON_HOLD)
            trigger.action.stopRadioTransmission(e.groupName)
            trigger.action.radioTransmission(
                e.sound, unit:getPoint(), e.mode, true, e.freq, 1000, e.groupName)
        end
    end
end

--- Stop transmissions and destroy all three DCS groups for a beacon.
function CTLDBeaconManager:_destroyBeaconUnits(beacon)
    for _, gname in ipairs({ beacon.vhfGroupName, beacon.uhfGroupName, beacon.fmGroupName }) do
        local g = Group.getByName(gname)
        if g then
            trigger.action.stopRadioTransmission(gname)
            g:destroy()
        end
    end
end

-- ============================================================
-- Public actions
-- ============================================================

--- Drop a radio beacon at position, spawned by transport.
-- @param transport  Unit   DCS transport unit
-- @param player     string playerName
-- @param isFOB      bool   (default false)
-- @return CTLDBeacon or nil
function CTLDBeaconManager:dropBeacon(transport, player, isFOB, overridePosition)
    if not ctld.gs("enabledRadioBeaconDrop") then
        ctld.utils.log("WARN", "CTLDBeaconManager:dropBeacon — beacons disabled in config")
        return nil
    end

    local coalitionId= transport:getCoalition()
    local countryId  = transport:getCountry()

    -- When the transport is on the ground, offset the beacon behind the aircraft
    -- to avoid spawning the ground unit inside the aircraft's collision box.
    local point
    if overridePosition then
        point = overridePosition
    else
        local tPos = transport:getPoint()
        if not ctld.utils.inAir(transport) then
            -- Compute safe offset from bounding box (same method as crate spawn).
            local okBox, box = pcall(function() return transport:getDesc().box end)
            local offset = (okBox and box)
                and (math.max(math.abs(box.max.x), math.abs(box.min.x)) + 5)
                or 20
            local hdg = ctld.utils.getHeadingInRadians(
                "CTLDBeaconManager:dropBeacon", transport, true)
            -- Place beacon directly behind the aircraft (heading + π).
            local angle = hdg + math.pi
            local px = tPos.x + math.cos(angle) * offset
            local pz = tPos.z + math.sin(angle) * offset
            local py = land.getHeight({ x = px, y = pz })
            point = { x = px, y = py, z = pz }
        else
            point = tPos
        end
    end

    local freqs = self:_assignFrequencies()

    self._beaconCount = self._beaconCount + 1
    local displayName = "Beacon #" .. self._beaconCount
    local freqText    = string.format("%.2f kHz - %.2f / %.2f MHz",
        freqs.vhf / 1000, freqs.uhf / 1000000, freqs.fm / 1000000)

    local vhfGroup = self:_spawnBeaconUnit(point, countryId, displayName .. " VHF " .. freqText)
    local uhfGroup = self:_spawnBeaconUnit(point, countryId, displayName .. " UHF " .. freqText)
    local fmGroup  = self:_spawnBeaconUnit(point, countryId, displayName .. " FM "  .. freqText)

    if not (vhfGroup and uhfGroup and fmGroup) then
        ctld.utils.log("ERROR", "CTLDBeaconManager:dropBeacon — spawn failed for '%s'", displayName)
        return nil
    end

    local batteryMins = ctld.gs("deployedBeaconBattery") or 30
    local batteryEnd  = isFOB and -1 or (timer.getTime() + batteryMins * 60)

    local beacon = CTLDBeacon:new({
        beaconName    = vhfGroup:getName(),
        name          = displayName,
        coalitionId   = coalitionId,
        position      = point,
        vhfGroupName  = vhfGroup:getName(),
        uhfGroupName  = uhfGroup:getName(),
        fmGroupName   = fmGroup:getName(),
        vhf           = freqs.vhf,
        uhf           = freqs.uhf,
        fm            = freqs.fm,
        batteryEndTime= batteryEnd,
        spawnTime     = timer.getAbsTime(),
        isFOB         = isFOB or false,
    })

    self._beacons[beacon.beaconName] = beacon
    -- Delay transmissions by 1s: DCS coalition.addGroup leaves units uninitialized for ~1s;
    -- calling radioTransmission immediately yields an invalid position (0,0,0 or stale).
    local bname = beacon.beaconName
    timer.scheduleFunction(function()
        local b = CTLDBeaconManager.getInstance()._beacons[bname]
        if b then CTLDBeaconManager.getInstance():_startTransmissions(b) end
    end, nil, timer.getTime() + 1)

    -- Notify coalition
    trigger.action.outTextForCoalition(coalitionId,
        ctld.tr("Navigation beacon deployed - %1", freqText), 20)

    -- Update active layers
    self:_addBeaconToLayers(beacon)

    EventDispatcher.getInstance():publish("OnBeaconDropped", {
        player     = player,
        playerUnit = transport,
        coalition  = coalitionId,
        beacon     = self:_beaconPayload(beacon),
        timestamp  = timer.getAbsTime(),
    })

    return beacon
end

--- Remove the closest beacon to transport (manual removal).
-- @param transport Unit   DCS transport unit
-- @param player    string playerName
function CTLDBeaconManager:removeClosestBeacon(transport, player)
    local pos        = transport:getPoint()
    local coalitionId= transport:getCoalition()
    local maxDist    = BEACON_REMOVAL_RADIUS

    local closest, closestDist = nil, math.huge
    for _, beacon in pairs(self._beacons) do
        if beacon.coalitionId == coalitionId then
            local d = ctld.utils.getDistance("CTLDBeaconManager", pos, beacon.position)
            if d < closestDist and d <= maxDist then
                closest, closestDist = beacon, d
            end
        end
    end

    if not closest then
        trigger.action.outText(ctld.tr("No Radio Beacons within 500m."), 10)
        return
    end

    local remaining = closest:batteryRemaining()
    self:_destroyBeaconUnits(closest)
    self:_freeFrequencies(closest)
    self:_removeBeaconFromLayers(closest)
    self._beacons[closest.beaconName] = nil

    trigger.action.outTextForCoalition(coalitionId,
        ctld.tr("Radio beacon removed - %1", closest:freqText()), 20)

    EventDispatcher.getInstance():publish("OnBeaconRemoved", {
        player     = player,
        playerUnit = transport,
        coalition  = coalitionId,
        beacon     = {
            beaconName    = closest.beaconName,
            name          = closest.name,
            position      = closest.position,
            mgrsCoords    = closest:mgrsCoords(),
            frequencies   = { vhf = closest.vhf, uhf = closest.uhf, fm = closest.fm },
            battery       = { remainingTime = remaining, wasInfinite = closest.isFOB },
            distance      = closestDist,
        },
        reason           = "manual",
        frequenciesFreed = { vhf = closest.vhf, uhf = closest.uhf, fm = closest.fm },
        timestamp        = timer.getAbsTime(),
    })
end

--- List active beacons for the coalition of transport to player screen.
-- @param transport Unit
function CTLDBeaconManager:listBeacons(transport)
    local coalitionId = transport:getCoalition()
    local lines = {}
    for _, beacon in pairs(self._beacons) do
        if beacon.coalitionId == coalitionId then
            lines[#lines + 1] = beacon.name .. ": " .. beacon:freqText()
        end
    end
    local msg = #lines > 0
        and (ctld.tr("Radio Beacons:") .. "\n" .. table.concat(lines, "\n"))
        or   ctld.tr("No Active Radio Beacons")
    trigger.action.outTextForGroup(ctld.utils.getGroupId(transport), msg, 20)
end

--- Toggle the beacon map layer for a player.
-- @param player    string playerName
-- @param transport Unit
function CTLDBeaconManager:toggleLayer(player, transport)
    if not ctld.gs("beaconLayerEnabled") then return end

    local coalitionId = transport:getCoalition()
    if not self._layerState[player] then
        self._layerState[player] = { enabled = false, marks = {} }
    end

    local state    = self._layerState[player]
    local previous = state.enabled
    state.enabled  = not state.enabled

    local beaconsDisplayed = {}
    if state.enabled then
        for _, beacon in pairs(self._beacons) do
            if beacon.coalitionId == coalitionId then
                local mid = self:_nextMark()
                self:_drawBeaconIcon(beacon, mid)
                state.marks[#state.marks + 1] = { beaconName = beacon.beaconName, markId = mid }
                beaconsDisplayed[#beaconsDisplayed + 1] = {
                    beaconName = beacon.beaconName, name = beacon.name,
                    position   = beacon.position, mgrsCoords = beacon:mgrsCoords(),
                    frequencies= { vhf=beacon.vhf, uhf=beacon.uhf, fm=beacon.fm },
                    markId     = mid,
                }
            end
        end
        trigger.action.outTextForGroup(ctld.utils.getGroupId(transport),
            ctld.tr("Beacon layer enabled. %1 beacon(s).", #beaconsDisplayed), 10)
    else
        for _, mark in ipairs(state.marks) do self:_removeMarkId(mark.markId) end
        state.marks = {}
        trigger.action.outTextForGroup(ctld.utils.getGroupId(transport),
            ctld.tr("Beacon layer disabled."), 10)
    end

    EventDispatcher.getInstance():publish("OnBeaconLayerToggled", {
        player            = player,
        playerUnit        = transport,
        coalition         = coalitionId,
        previousState     = previous,
        newState          = state.enabled,
        action            = state.enabled and "enabled" or "disabled",
        beaconsDisplayed  = beaconsDisplayed,
        totalBeaconsDisplayed = #beaconsDisplayed,
        timestamp         = timer.getAbsTime(),
    })
end

-- ============================================================
-- Refresh schedule
-- ============================================================

function CTLDBeaconManager:_scheduleRefresh()
    local interval = ctld.gs("beaconRefreshInterval") or 60
    local self_ref = self
    local function refresh(_, t)
        -- Guard B: stop zombie loop if this instance is no longer the singleton.
        if CTLDBeaconManager._instance ~= self_ref then return nil end
        self_ref:_refreshAll()
        return t + interval
    end
    local fid = timer.scheduleFunction(refresh, nil, timer.getTime() + interval)
    ctld.scheduler.register("beacon_refresh", fid)
end

function CTLDBeaconManager:_refreshAll()
    local refreshed, destroyed = {}, {}

    for beaconName, beacon in pairs(self._beacons) do
        local alive     = beacon:countAliveUnits()
        local batOk     = beacon:isBatteryAlive()
        local keepBeacon= (alive == 3 and batOk)

        if keepBeacon then
            self:_startTransmissions(beacon)
            refreshed[#refreshed + 1] = {
                beaconName          = beacon.beaconName,
                name                = beacon.name,
                position            = beacon.position,
                frequencies         = { vhf=beacon.vhf, uhf=beacon.uhf, fm=beacon.fm },
                battery             = {
                    remainingTime    = beacon:batteryRemaining(),
                    percentRemaining = beacon.isFOB and 1.0 or
                        beacon:batteryRemaining() / ((ctld.gs("deployedBeaconBattery") or 30) * 60),
                    infinite         = beacon.isFOB,
                },
                transmissionsActive = true,
                unitsAlive          = alive,
            }
        else
            local reason = (not batOk) and "battery_depleted" or "unit_destroyed"
            self:_destroyBeaconUnits(beacon)
            self:_freeFrequencies(beacon)
            self:_removeBeaconFromLayers(beacon)
            self._beacons[beaconName] = nil

            destroyed[#destroyed + 1] = beacon

            EventDispatcher.getInstance():publish("OnBeaconDestroyed", {
                beacon = {
                    beaconName    = beacon.beaconName,
                    name          = beacon.name,
                    position      = beacon.position,
                    mgrsCoords    = beacon:mgrsCoords(),
                    frequencies   = { vhf=beacon.vhf, uhf=beacon.uhf, fm=beacon.fm },
                    battery       = {
                        remainingTime = beacon:batteryRemaining(),
                        duration      = (ctld.gs("deployedBeaconBattery") or 30) * 60,
                        infinite      = beacon.isFOB,
                    },
                    unitsAlive    = alive,
                    durationAlive = timer.getAbsTime() - beacon.spawnTime,
                },
                reason           = reason,
                frequenciesFreed = { vhf=beacon.vhf, uhf=beacon.uhf, fm=beacon.fm },
                coalition        = beacon.coalitionId,
                timestamp        = timer.getAbsTime(),
            })
        end
    end

    -- No-op: don't fire event if nothing happened
    if #refreshed == 0 and #destroyed == 0 then return end

    EventDispatcher.getInstance():publish("OnBeaconRefreshed", {
        beacons               = refreshed,
        totalBeaconsRefreshed = #refreshed,
        totalBeaconsDestroyed = #destroyed,
        timestamp             = timer.getAbsTime(),
    })
end

-- ============================================================
-- Draw layer helpers
-- ============================================================

function CTLDBeaconManager:_nextMark()
    return ctld.utils.getNextMarkId()
end

function CTLDBeaconManager:_drawBeaconIcon(beacon, markId)
    local pos    = beacon.position
    local radius = ctld.gs("beaconIconRadius") or 25
    local color  = ctld.gs("beaconIconColor")  or { 1.0, 0.5, 0.0, 1.0 }
    local fill   = { color[1], color[2], color[3], 0.2 }
    local p      = { x = pos.x, y = 0, z = pos.z }

    -- Outer circle
    trigger.action.circleToAll(-1, markId * 10 + 1, p, radius,
        color, fill, 1, true, "Radio Beacon")
    -- Inner circle (solid fill)
    trigger.action.circleToAll(-1, markId * 10 + 2, p, radius * 0.5,
        color, color, 1, true, "")
    -- Text label
    local pText = { x = pos.x, y = 0, z = pos.z + radius + 10 }
    trigger.action.textToAll(-1, markId * 10 + 3, pText,
        { 1.0, 1.0, 1.0, 1.0 }, { 0.0, 0.0, 0.0, 0.7 },
        ctld.gs("beaconTextSize") or 12, true,
        beacon.name .. "\n" .. beacon:mgrsCoords())
end

function CTLDBeaconManager:_removeMarkId(markId)
    for i = 1, 3 do
        trigger.action.removeMark(markId * 10 + i)
    end
end

--- Add a newly-dropped beacon to all active layers of the same coalition.
function CTLDBeaconManager:_addBeaconToLayers(beacon)
    if not ctld.gs("beaconAutoRefreshLayer") then return end
    for _, state in pairs(self._layerState) do
        if state.enabled then
            -- We cannot know the coalition of the layer owner here without extra state.
            -- Conservative: add to all active layers and let the draw API handle visibility (-1=all).
            local mid = self:_nextMark()
            self:_drawBeaconIcon(beacon, mid)
            state.marks[#state.marks + 1] = { beaconName = beacon.beaconName, markId = mid }
        end
    end
end

--- Remove a beacon's marks from all active layers.
function CTLDBeaconManager:_removeBeaconFromLayers(beacon)
    for _, state in pairs(self._layerState) do
        if state.enabled then
            for i = #state.marks, 1, -1 do
                if state.marks[i].beaconName == beacon.beaconName then
                    self:_removeMarkId(state.marks[i].markId)
                    table.remove(state.marks, i)
                end
            end
        end
    end
end

-- ============================================================
-- Internal payload builder
-- ============================================================

function CTLDBeaconManager:_beaconPayload(beacon)
    local battMins = (ctld.gs("deployedBeaconBattery") or 30) * 60
    return {
        beaconName  = beacon.beaconName,
        name        = beacon.name,
        position    = beacon.position,
        mgrsCoords  = beacon:mgrsCoords(),
        frequencies = {
            vhf = beacon.vhf, vhfGroup = beacon.vhfGroupName,
            uhf = beacon.uhf, uhfGroup = beacon.uhfGroupName,
            fm  = beacon.fm,  fmGroup  = beacon.fmGroupName,
        },
        battery = {
            startTime = beacon.spawnTime,
            endTime   = beacon.batteryEndTime == -1 and -1
                        or (beacon.spawnTime + battMins),
            duration  = battMins,
            infinite  = beacon.isFOB,
        },
        isFOB = beacon.isFOB,
    }
end

-- ============================================================
-- Query API
-- ============================================================

--- Return all active beacons for a coalition.
function CTLDBeaconManager:getBeaconsForCoalition(coalitionId)
    local result = {}
    for _, beacon in pairs(self._beacons) do
        if beacon.coalitionId == coalitionId then
            result[#result + 1] = beacon
        end
    end
    return result
end

--- Return CTLDBeacon by beaconName, or nil.
function CTLDBeaconManager:getBeacon(beaconName)
    return self._beacons[beaconName]
end

-- ============================================================
-- F10 Menu section
-- ============================================================

--- Build the "Radio Beacons" F10 submenu for a player.
-- Requires enabledRadioBeaconDrop = true (configKey gate) AND isTransport.
-- @param playerObj CTLDPlayer
-- @param menu      ctld.Menu
function CTLDBeaconManager:buildMenuSection(playerObj, menu)
    if not playerObj.isTransport then return end

    local root      = ctld.tr("CTLD")
    local beaconSub = ctld.tr("Radio Beacons")
    menu:addSubMenu({ root }, beaconSub, { order = 60 })

    menu:addCommand({ root, beaconSub }, ctld.tr("Drop Beacon"),
        function(arg)
            local transport = Unit.getByName(arg.unitName)
            if transport then CTLDBeaconManager.getInstance():dropBeacon(transport, nil, false) end
        end,
        { unitName = playerObj.unitName })

    menu:addCommand({ root, beaconSub }, ctld.tr("Remove Closest Beacon"),
        function(arg)
            local transport = Unit.getByName(arg.unitName)
            if transport then CTLDBeaconManager.getInstance():removeClosestBeacon(transport, nil) end
        end,
        { unitName = playerObj.unitName })

    menu:addCommand({ root, beaconSub }, ctld.tr("List Beacons"),
        function(arg)
            local transport = Unit.getByName(arg.unitName)
            if transport then CTLDBeaconManager.getInstance():listBeacons(transport) end
        end,
        { unitName = playerObj.unitName })
end

-- ============================================================
-- Legacy-compatible public API (called by compat/legacy_api.lua)
-- ============================================================

--- Create a radio beacon at a DCS trigger zone (MM DO SCRIPT, no transport required).
-- coalitionStr: "red" | "blue". batteryLife: minutes (nil = config default).
-- name: display name (nil = auto-generated "Beacon #N").
-- @param zoneName    string   DCS trigger zone name
-- @param coalitionStr string  "red" | "blue"
-- @param batteryLife number|nil  battery life in minutes
-- @param name        string|nil  display name
-- @return CTLDBeacon|nil
function CTLDBeaconManager:createAtZone(zoneName, coalitionStr, batteryLife, name)
    local trig = trigger.misc.getZone(zoneName)
    if not trig then
        ctld.utils.log("ERROR", "CTLDBeaconManager:createAtZone — zone not found: %s", tostring(zoneName))
        return nil
    end
    local p2 = { x = trig.point.x, y = trig.point.z }
    local pt = { x = p2.x, y = land.getHeight(p2), z = p2.y }
    local coalitionId = (coalitionStr == "red") and coalition.side.RED or coalition.side.BLUE
    local countryId   = (coalitionId == coalition.side.RED) and country.id.RUSSIA or country.id.USA

    local freqs = self:_assignFrequencies()
    self._beaconCount = self._beaconCount + 1

    if not name or name == "" then name = "Beacon #" .. self._beaconCount end

    local freqText = string.format("%.2f kHz - %.2f / %.2f MHz",
        freqs.vhf / 1000, freqs.uhf / 1000000, freqs.fm / 1000000)

    local vhfGroup = self:_spawnBeaconUnit(pt, countryId, name .. " VHF " .. freqText)
    local uhfGroup = self:_spawnBeaconUnit(pt, countryId, name .. " UHF " .. freqText)
    local fmGroup  = self:_spawnBeaconUnit(pt, countryId, name .. " FM "  .. freqText)

    if not (vhfGroup and uhfGroup and fmGroup) then
        ctld.utils.log("ERROR", "CTLDBeaconManager:createAtZone — spawn failed for '%s'", name)
        return nil
    end

    local batteryMins = batteryLife or ctld.gs("deployedBeaconBattery") or 30
    local batteryEnd  = timer.getTime() + batteryMins * 60

    local beacon = CTLDBeacon:new({
        beaconName     = vhfGroup:getName(),
        name           = name,
        coalitionId    = coalitionId,
        position       = pt,
        vhfGroupName   = vhfGroup:getName(),
        uhfGroupName   = uhfGroup:getName(),
        fmGroupName    = fmGroup:getName(),
        vhf            = freqs.vhf,
        uhf            = freqs.uhf,
        fm             = freqs.fm,
        batteryEndTime = batteryEnd,
        spawnTime      = timer.getAbsTime(),
        isFOB          = false,
    })

    self._beacons[beacon.beaconName] = beacon
    local bname2 = beacon.beaconName
    timer.scheduleFunction(function()
        local b = CTLDBeaconManager.getInstance()._beacons[bname2]
        if b then CTLDBeaconManager.getInstance():_startTransmissions(b) end
    end, nil, timer.getTime() + 1)
    self:_addBeaconToLayers(beacon)

    trigger.action.outTextForCoalition(coalitionId,
        name .. "\n" .. freqText, 20)

    EventDispatcher.getInstance():publish("OnBeaconDropped", {
        player     = "MissionMaker",
        playerUnit = nil,
        coalition  = coalitionId,
        beacon     = self:_beaconPayload(beacon),
        timestamp  = timer.getAbsTime(),
    })

    ctld.utils.log("INFO", "CTLDBeaconManager:createAtZone — '%s' at zone '%s'", name, zoneName)
    return beacon
end
