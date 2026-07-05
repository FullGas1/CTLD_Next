-- ============================================================
-- CTLD_recon.lua
-- CTLDReconRenderer (static) + CTLDReconManager (singleton)
--
-- SCOPE: RECON is exclusively for displaying ENEMY unit information
-- detected via Line-of-Sight (LOS) from an allied unit.
-- It must NOT be used to display friendly assets (FOBs, zones, beacons…).
-- Those belong in their own manager menus.
--
-- Dependencies : class (lib/class.lua), CTLDUtils (ctld.utils),
--                CTLDConfig (ctld.gs), EventDispatcher
-- DCS API      : coalition.getGroups, Unit.getByName, land.getHeight,
--                land.isVisible (via ctld.utils.getUnitsLOS),
--                trigger.action, timer, missionCommands
--
-- Recon workflow:
--   1. Player enables one or more layers (Layers submenu)
--   2. Player scans → LOS check via ctld.utils.getUnitsLOS()
--      → Draw API icons per layer type on F10 map
--   3. Optional: Auto-Refresh every reconRefreshInterval seconds
--      → tracks moved/new/lost targets
--   4. Hide All Targets → remove marks, stop timer
--
-- Layers (per-player state):
--   infantry, ground_vehicles, air_defense, aircraft, helicopters, ships
--
-- Icons (CTLDReconRenderer):
--   Each target gets a markId; elements at markId*10+1..3
--   infantry   : circle + cross (2 lines)
--   vehicle    : rectangle + diagonal
--   aa         : triangle (3 lines)
--   aircraft   : cross (2 lines) + small circle
--   helicopter : circle + H shape (2 lines)
--   ship       : elongated rectangle + bow lines
-- ============================================================

---@diagnostic disable
ctld = ctld or {}

-- ============================================================
-- CTLDReconRenderer  (static table — no instance)
-- ============================================================

CTLDReconRenderer = {}

--- Remove all draw elements for a markId (3 sub-elements max).
function CTLDReconRenderer.removeIcon(markId)
    if not markId then return end
    for i = 1, 3 do
        trigger.action.removeMark(markId * 10 + i)
    end
end

--- Infantry icon: circle + horizontal + vertical cross (⊕).
-- @param coalition number  player coalition (1=RED, 2=BLUE) — marks visible to this coalition only
function CTLDReconRenderer.drawInfantryIcon(pos, markId, color, coalition)
    local r    = 150 * (ctld.gs("reconIconScale") or 1.0)
    local fill = { color[1], color[2], color[3], 0.3 }
    local p    = { x = pos.x, y = 0, z = pos.z }
    trigger.action.circleToAll(coalition, markId * 10 + 1, p, r, color, fill, 1, true, "Infantry")
    trigger.action.lineToAll(coalition, markId * 10 + 2,
        { x = pos.x - r, y = 0, z = pos.z }, { x = pos.x + r, y = 0, z = pos.z },
        color, 1, true, "")
    trigger.action.lineToAll(coalition, markId * 10 + 3,
        { x = pos.x, y = 0, z = pos.z - r }, { x = pos.x, y = 0, z = pos.z + r },
        color, 1, true, "")
end

--- Vehicle icon: rectangle + diagonal (▭╱).
function CTLDReconRenderer.drawVehicleIcon(pos, markId, color, coalition)
    local s    = 150 * (ctld.gs("reconIconScale") or 1.0)
    local hs   = s / 2
    local fill = { color[1], color[2], color[3], 0.3 }
    trigger.action.rectToAll(coalition, markId * 10 + 1,
        { x = pos.x - hs, y = 0, z = pos.z - hs },
        { x = pos.x + hs, y = 0, z = pos.z + hs },
        color, fill, 1, true, "Vehicle")
    trigger.action.lineToAll(coalition, markId * 10 + 2,
        { x = pos.x - hs, y = 0, z = pos.z - hs },
        { x = pos.x + hs, y = 0, z = pos.z + hs },
        color, 1, true, "")
end

--- AA icon: filled circle (background) + 2 lines forming an apex (△ without base).
-- 3-slot budget: slot1=filled circle, slot2=left side, slot3=right side.
-- The apex shape (^) makes it recognisable as a pointed/AA symbol on the fill background.
function CTLDReconRenderer.drawAAIcon(pos, markId, color, coalition)
    local s    = 150 * (ctld.gs("reconIconScale") or 1.0)
    local hs   = s / 2
    local fill = { color[1], color[2], color[3], 0.3 }
    local apex = { x = pos.x,      y = 0, z = pos.z + hs }
    local bl   = { x = pos.x - hs, y = 0, z = pos.z - hs }
    local br   = { x = pos.x + hs, y = 0, z = pos.z - hs }
    trigger.action.circleToAll(coalition, markId * 10 + 1,
        { x = pos.x, y = 0, z = pos.z }, hs * 0.9,
        color, fill, 1, true, "AA")
    trigger.action.lineToAll(coalition, markId * 10 + 2, bl, apex, color, 1, true, "")
    trigger.action.lineToAll(coalition, markId * 10 + 3, apex, br, color, 1, true, "")
end

--- Aircraft icon: perpendicular cross (2 lines) + small center circle.
function CTLDReconRenderer.drawAircraftIcon(pos, markId, color, coalition)
    local s  = 150 * (ctld.gs("reconIconScale") or 1.0)
    local hs = s / 2
    trigger.action.lineToAll(coalition, markId * 10 + 1,
        { x = pos.x,      y = 0, z = pos.z + hs },
        { x = pos.x,      y = 0, z = pos.z - hs },
        color, 1, true, "Aircraft")
    trigger.action.lineToAll(coalition, markId * 10 + 2,
        { x = pos.x - hs, y = 0, z = pos.z },
        { x = pos.x + hs, y = 0, z = pos.z },
        color, 1, true, "")
    trigger.action.circleToAll(coalition, markId * 10 + 3,
        { x = pos.x, y = 0, z = pos.z }, hs * 0.35,
        color, color, 1, true, "")
end

--- Helicopter icon: circle + H shape (2 vertical bars).
function CTLDReconRenderer.drawHelicopterIcon(pos, markId, color, coalition)
    local r    = 150 * (ctld.gs("reconIconScale") or 1.0)
    local fill = { color[1], color[2], color[3], 0.3 }
    trigger.action.circleToAll(coalition, markId * 10 + 1,
        { x = pos.x, y = 0, z = pos.z }, r, color, fill, 1, true, "Helicopter")
    trigger.action.lineToAll(coalition, markId * 10 + 2,
        { x = pos.x - r * 0.4, y = 0, z = pos.z - r * 0.5 },
        { x = pos.x - r * 0.4, y = 0, z = pos.z + r * 0.5 },
        color, 1, true, "")
    trigger.action.lineToAll(coalition, markId * 10 + 3,
        { x = pos.x + r * 0.4, y = 0, z = pos.z - r * 0.5 },
        { x = pos.x + r * 0.4, y = 0, z = pos.z + r * 0.5 },
        color, 1, true, "")
end

--- Ship icon: elongated rectangle + bow arrow (2 lines converging to point).
function CTLDReconRenderer.drawShipIcon(pos, markId, color, coalition)
    local sw   = 250 * (ctld.gs("reconIconScale") or 1.0)
    local sh   = 100 * (ctld.gs("reconIconScale") or 1.0)
    local fill = { color[1], color[2], color[3], 0.3 }
    trigger.action.rectToAll(coalition, markId * 10 + 1,
        { x = pos.x - sw / 2, y = 0, z = pos.z - sh / 2 },
        { x = pos.x + sw / 2, y = 0, z = pos.z + sh / 2 },
        color, fill, 1, true, "Ship")
    trigger.action.lineToAll(coalition, markId * 10 + 2,
        { x = pos.x + sw / 2,           y = 0, z = pos.z - sh / 2 },
        { x = pos.x + sw / 2 + sh / 2,  y = 0, z = pos.z },
        color, 1, true, "")
    trigger.action.lineToAll(coalition, markId * 10 + 3,
        { x = pos.x + sw / 2,           y = 0, z = pos.z + sh / 2 },
        { x = pos.x + sw / 2 + sh / 2,  y = 0, z = pos.z },
        color, 1, true, "")
end

--- FARP / FOB icon: T in a square (helipad marker).
-- DCS axes: x = North/South (x+ = North), z = East/West (z+ = East).
-- Slot 1: filled square (background).
-- Slot 2: horizontal bar at NORTH top of T  — constant x+0.25r, z varies E-W.
-- Slot 3: vertical stem going SOUTH           — constant z=center, x from +0.25r to -0.45r.
function CTLDReconRenderer.drawFarpIcon(pos, markId, color, coalition)
    local r    = 150 * (ctld.gs("reconIconScale") or 1.0)
    local fill = { color[1], color[2], color[3], 0.3 }
    -- Square background
    trigger.action.rectToAll(coalition, markId * 10 + 1,
        { x = pos.x - r * 0.7, y = 0, z = pos.z - r * 0.7 },
        { x = pos.x + r * 0.7, y = 0, z = pos.z + r * 0.7 },
        color, fill, 1, true, "FARP/FOB")
    -- Horizontal bar at NORTH (x + 0.25r), running west to east (z varies)
    trigger.action.lineToAll(coalition, markId * 10 + 2,
        { x = pos.x + r * 0.25, y = 0, z = pos.z - r * 0.45 },
        { x = pos.x + r * 0.25, y = 0, z = pos.z + r * 0.45 },
        color, 1, true, "")
    -- Vertical stem: from bar (x + 0.25r) south to (x - 0.45r), center z
    trigger.action.lineToAll(coalition, markId * 10 + 3,
        { x = pos.x + r * 0.25, y = 0, z = pos.z },
        { x = pos.x - r * 0.45, y = 0, z = pos.z },
        color, 1, true, "")
end

--- Dispatch icon creation to the correct draw function.
-- @param target table  { position, layer, playerCoalition, coalition }
-- @param markId number
function CTLDReconRenderer.createIcon(target, markId)
    local r          = target.layer.iconRenderer
    local pos        = target.position
    local playerCoa  = target.playerCoalition or -1
    -- Color follows detected unit's coalition (RED=1, BLUE=2, NEUTRAL=0).
    -- Shape already distinguishes layer type, so color conveys coalition.
    local COALITION_COLORS = {
        [0] = { 0.70, 0.70, 0.70, 1.0 },  -- neutral  → grey
        [1] = { 1.00, 0.15, 0.15, 1.0 },  -- RED      → red
        [2] = { 0.15, 0.40, 1.00, 1.0 },  -- BLUE     → blue
    }
    local col = COALITION_COLORS[target.coalition] or target.layer.color
    if     r == "infantry"   then CTLDReconRenderer.drawInfantryIcon(pos, markId, col, playerCoa)
    elseif r == "vehicle"    then CTLDReconRenderer.drawVehicleIcon(pos, markId, col, playerCoa)
    elseif r == "aa"         then CTLDReconRenderer.drawAAIcon(pos, markId, col, playerCoa)
    elseif r == "aircraft"   then CTLDReconRenderer.drawAircraftIcon(pos, markId, col, playerCoa)
    elseif r == "helicopter" then CTLDReconRenderer.drawHelicopterIcon(pos, markId, col, playerCoa)
    elseif r == "ship"       then CTLDReconRenderer.drawShipIcon(pos, markId, col, playerCoa)
    elseif r == "farp"       then CTLDReconRenderer.drawFarpIcon(pos, markId, col, playerCoa)
    else
        -- Fallback: plain circle
        local fill = { col[1], col[2], col[3], 0.3 }
        trigger.action.circleToAll(playerCoa, markId * 10 + 1,
            { x = pos.x, y = 0, z = pos.z }, 30, col, fill, 1, true, "")
    end
end


-- ============================================================
-- CTLDReconManager  (singleton)
-- ============================================================

CTLDReconManager = class()
CTLDReconManager._instance = nil

function CTLDReconManager.getInstance()
    if not CTLDReconManager._instance then
        local o = setmetatable({}, CTLDReconManager)
        o:init()
        CTLDReconManager._instance = o
    end
    return CTLDReconManager._instance
end

function CTLDReconManager:init()
    self._activeScans  = {}   -- player -> scan state
    self._playerLayers = {}   -- player -> array of layer copies
    self._farpMarks    = {}   -- player -> { [id] = markId }  (FARP/FOB persistent marks)
    -- Mark IDs are allocated from ctld.utils.getNextMarkId() (app-wide monotonic counter)

    CTLDPlayerManager.getInstance():registerMenuSection({
        key       = "recon",
        manager   = self,
        method    = "buildMenuSection",
        configKey = "reconF10Menu",
        order     = 70,
    })
    ctld.utils.log("INFO", "CTLDReconManager: init complete")
end

-- ============================================================
-- Default layer definitions
-- ============================================================

-- DCS attribute names (case-sensitive, from DCS unit type tables)
-- Layer order matters: _matchLayer returns the FIRST matching layer.
-- More specific attributes must come before broader ones to avoid misclassification:
--   "Air Defence" ⊂ "Vehicles"  → air_defense before ground_vehicles
--   "Helicopters" ⊂ "Planes"    → helicopters before aircraft
CTLDReconManager._defaultLayers = {
    {
        layerId      = "infantry",
        name         = "Infantry",
        enabled      = false,
        color        = { 0.29, 0.56, 0.89, 1.0 },
        filterAttrib = "Infantry",
        iconRenderer = "infantry",
    },
    {
        layerId      = "air_defense",
        name         = "Air Defense (AA)",
        enabled      = false,
        color        = { 0.91, 0.30, 0.24, 1.0 },
        filterAttrib = "Air Defence",  -- more specific than "Vehicles"
        iconRenderer = "aa",
    },
    {
        layerId      = "ground_vehicles",
        name         = "Ground Vehicles",
        enabled      = false,
        color        = { 0.31, 0.78, 0.47, 1.0 },
        filterAttrib = "Vehicles",
        iconRenderer = "vehicle",
    },
    {
        layerId      = "helicopters",
        name         = "Helicopters",
        enabled      = false,
        color        = { 0.90, 0.49, 0.13, 1.0 },
        filterAttrib = "Helicopters",  -- more specific than "Planes"
        iconRenderer = "helicopter",
    },
    {
        layerId      = "aircraft",
        name         = "Aircraft",
        enabled      = false,
        color        = { 0.95, 0.77, 0.06, 1.0 },
        filterAttrib = "Planes",
        iconRenderer = "aircraft",
    },
    {
        layerId      = "ships",
        name         = "Ships",
        enabled      = false,
        color        = { 0.20, 0.60, 0.86, 1.0 },
        filterAttrib = "Ships",
        iconRenderer = "ship",
    },
    {
        -- farp_fob uses a dedicated scan pipeline (_scanFarpLOS), not _matchLayer.
        -- filterAttrib = nil intentionally: _matchLayer skips layers without filterAttrib.
        layerId      = "farp_fob",
        name         = "FARP / FOB",
        enabled      = false,
        color        = { 0.95, 0.30, 0.60, 1.0 },
        filterAttrib = nil,
        iconRenderer = "farp",
    },
}

-- ============================================================
-- Layer management (per-player)
-- ============================================================

-- Returns or lazily initializes the per-player layer array.
function CTLDReconManager:_getPlayerLayers(player)
    if not self._playerLayers[player] then
        local layers = {}
        for _, def in ipairs(CTLDReconManager._defaultLayers) do
            layers[#layers + 1] = {
                layerId      = def.layerId,
                name         = def.name,
                enabled      = def.enabled,
                color        = def.color,
                filterAttrib = def.filterAttrib,
                iconRenderer = def.iconRenderer,
            }
        end
        self._playerLayers[player] = layers
    end
    return self._playerLayers[player]
end

-- Returns the layer object for layerId in player's list, or nil.
function CTLDReconManager:_findLayer(player, layerId)
    for _, layer in ipairs(self:_getPlayerLayers(player)) do
        if layer.layerId == layerId then return layer end
    end
    return nil
end

-- Returns list of enabled layers for player.
function CTLDReconManager:_enabledLayers(player)
    local result = {}
    for _, layer in ipairs(self:_getPlayerLayers(player)) do
        if layer.enabled then result[#result + 1] = layer end
    end
    return result
end

-- ============================================================
-- LOS scan helpers
-- ============================================================

-- Returns enemy unit name list for all relevant categories.
function CTLDReconManager:_getEnemyUnitNames(coalitionId)
    local enemySide = coalitionId == coalition.side.BLUE
                      and coalition.side.RED
                      or  coalition.side.BLUE
    return ctld.utils.getUnitsListNamesByCategory(
        "CTLDReconManager:_getEnemyUnitNames",
        enemySide,
        {
            Group.Category.GROUND,
            Group.Category.AIRPLANE,
            Group.Category.HELICOPTER,
            Group.Category.SHIP,
        })
end

--- Find the highest-priority layer matching a unit's attributes.
--- Uses the FULL ordered layer list so that priority (air_defense > ground_vehicles,
--- helicopters > aircraft) is always respected regardless of which layers are enabled.
--- Returns the layer only if it is currently enabled; returns nil otherwise.
--- This prevents a unit from "falling through" to a lower-priority layer when its
--- best-match layer is disabled (e.g. Mi-8MT must not show as Aircraft when
--- Helicopters layer is OFF; ZU-23 must not show as Vehicle when AA layer is OFF).
function CTLDReconManager:_matchLayer(unit, allLayers)
    for _, layer in ipairs(allLayers) do
        if layer.filterAttrib then   -- farp_fob has no filterAttrib: skip in unit matching
            local ok, has = pcall(function() return unit:hasAttribute(layer.filterAttrib) end)
            if ok and has then
                return layer.enabled and layer or nil
            end
        end
    end
    return nil
end

-- Allocate next unique mark ID (delegates to shared app-wide counter).
function CTLDReconManager:_nextMark()
    return ctld.utils.getNextMarkId()
end

-- Core LOS scan. Returns array of target records.
-- altoffset = 180 matches source/CTLD_recon.lua ctld.utils.getUnitsLOS call.
function CTLDReconManager:_scanLOS(playerUnit, enabledLayers, searchRadius)
    local enemyNames = self:_getEnemyUnitNames(playerUnit:getCoalition())
    if #enemyNames == 0 then return {} end

    local los = ctld.utils.getUnitsLOS(
        "CTLDReconManager:_scanLOS",
        { playerUnit:getName() },
        180,
        enemyNames,
        180,
        searchRadius)

    local targets   = {}
    local playerPos = playerUnit:getPoint()

    if los then
        for _, entry in ipairs(los) do
            if entry.vis then
                for _, unit in ipairs(entry.vis) do
                    local layer = self:_matchLayer(unit, enabledLayers)
                    if layer then
                        local uPos = unit:getPoint()
                        targets[#targets + 1] = {
                            unit            = unit,
                            unitName        = unit:getName(),
                            unitType        = unit:getTypeName(),
                            coalition       = unit:getCoalition(),
                            playerCoalition = playerUnit:getCoalition(),
                            position        = uPos,
                            distance        = ctld.utils.getDistance(
                                "CTLDReconManager:_scanLOS", playerPos, uPos),
                            layer           = layer,
                            los             = true,
                        }
                    end
                end
            end
        end
    end

    return targets
end

-- ============================================================
-- FARP/FOB scan (Source A: coalition.getAirbases  Source B: CTLDFOBManager)
-- ============================================================

--- Scan for enemy FARP/FOB objects in LOS and update _farpMarks[player].
-- New detections: create icon + register CTLDStaticWatcher.
-- Existing marks: skipped (persistent until destroyed or layer off).
-- @param playerUnit  DCS Unit
-- @param player      string
function CTLDReconManager:_syncFarpMarks(playerUnit, player)
    local layer = self:_findLayer(player, "farp_fob")
    if not layer or not layer.enabled then return end

    local playerPos = playerUnit:getPoint()
    local playerCoa = playerUnit:getCoalition()
    local enemySide = playerCoa == coalition.side.BLUE
                      and coalition.side.RED or coalition.side.BLUE
    local radius    = ctld.gs("reconSearchRadius") or 5000

    if not self._farpMarks[player] then
        self._farpMarks[player] = {}
    end
    local marks = self._farpMarks[player]

    local function _addMark(id, pos, checkFn)
        if marks[id] then return end   -- already marked
        local markId = self:_nextMark()
        local target = {
            position        = pos,
            coalition       = enemySide,
            playerCoalition = playerCoa,
            layer           = layer,
        }
        CTLDReconRenderer.createIcon(target, markId)
        marks[id] = markId

        -- Register watcher: fires when object dies
        local self_ref = self
        CTLDStaticWatcher.getInstance():watch(
            "recon_farp_" .. player .. "_" .. id,
            checkFn,
            function()
                local mid = self_ref._farpMarks[player] and self_ref._farpMarks[player][id]
                if mid then
                    CTLDReconRenderer.removeIcon(mid)
                    self_ref._farpMarks[player][id] = nil
                end
                EventDispatcher.getInstance():publish("ReconFarpLost", {
                    player = player, id = id,
                })
            end
        )

        EventDispatcher.getInstance():publish("ReconFarpDetected", {
            player          = player,
            playerUnit      = playerUnit,
            coalition       = enemySide,
            playerCoalition = playerCoa,
            position        = pos,
            id              = id,
        })
        ctld.utils.log("INFO", "CTLDReconManager: FARP/FOB '%s' marked for player '%s'",
            tostring(id), tostring(player))
    end

    -- Source A: coalition.getAirbases (FARPs, helipads)
    local bases = coalition.getAirbases(enemySide) or {}
    for _, ab in ipairs(bases) do
        local okE, exists = pcall(function() return ab:isExist() end)
        if okE and exists then
            local okD, desc = pcall(function() return ab:getDesc() end)
            if okD and desc and desc.attributes and desc.attributes.Helipad then
                local abPos = ab:getPoint()
                local dist  = ctld.utils.vec3Mag("RECON_farp",
                    ctld.utils.subVec3("RECON_farp", playerPos, abPos))
                if dist <= radius then
                    local p1 = { x = playerPos.x, y = playerPos.y + 180, z = playerPos.z }
                    local p2 = { x = abPos.x,     y = abPos.y + 180,     z = abPos.z     }
                    if land.isVisible(p1, p2) then
                        local id = ab:getName()
                        _addMark(id, abPos, function() return ab:isExist() end)
                    end
                end
            end
        end
    end

    -- Source B: CTLDFOBManager enemy FOBs
    local okFM, fobMgr = pcall(CTLDFOBManager.getInstance)
    if okFM and fobMgr and fobMgr._fobs then
        for fobId, fob in pairs(fobMgr._fobs) do
            if fob.coalitionId == enemySide and fob:isAlive() then
                local fobPos = fob.position
                local dist   = ctld.utils.vec3Mag("RECON_fob",
                    ctld.utils.subVec3("RECON_fob", playerPos, fobPos))
                if dist <= radius then
                    local p1 = { x = playerPos.x, y = playerPos.y + 180, z = playerPos.z }
                    local p2 = { x = fobPos.x,    y = fobPos.y + 180,    z = fobPos.z    }
                    if land.isVisible(p1, p2) then
                        _addMark(fobId, fobPos, function() return fob:isAlive() end)
                    end
                end
            end
        end
    end
end

--- Remove all FARP/FOB marks for a player and cancel their watchers.
function CTLDReconManager:_clearFarpMarks(player)
    local marks = self._farpMarks[player]
    if not marks then return end
    local watcher = CTLDStaticWatcher.getInstance()
    for id, markId in pairs(marks) do
        CTLDReconRenderer.removeIcon(markId)
        watcher:unwatch("recon_farp_" .. player .. "_" .. id)
    end
    self._farpMarks[player] = {}
end

-- Remove all Draw API icons from a scan's target list + FARP marks.
function CTLDReconManager:_removeAllMarks(scan)
    for _, tgt in ipairs(scan.targets) do
        CTLDReconRenderer.removeIcon(tgt.markId)
    end
    if scan.player then
        self:_clearFarpMarks(scan.player)
    end
end

-- ============================================================
-- Public actions
-- ============================================================

--- Scan and start RECON with auto-refresh (menu F10 "RECON [Start]").
-- Also called internally on layer toggle while RECON is active (re-scan with updated layers).
-- @param playerUnit DCS Unit
-- @param player     string  playerName
function CTLDReconManager:scan(playerUnit, player)
    -- Gate: same key as the menu section (reconF10Menu).
    -- If the RECON menu is visible, scan must work without additional config.
    if not ctld.gs("reconF10Menu") then
        trigger.action.outTextForGroup(ctld.utils.getGroupId(playerUnit),
            ctld.tr("RECON is disabled (set reconF10Menu=true in config)."), 10)
        return
    end

    -- Altitude check (AGL)
    local pos    = playerUnit:getPoint()
    local ground = land.getHeight({ x = pos.x, y = pos.z })
    local agl    = pos.y - ground
    local minAlt = ctld.gs("reconMinAltitude") or 50
    if agl < minAlt then
        trigger.action.outTextForGroup(ctld.utils.getGroupId(playerUnit),
            ctld.tr("Altitude too low for recon scan (min %1 m)", minAlt), 10)
        return
    end

    -- Cancel previous auto-refresh timer and remove marks before rebuilding.
    local prevScan  = self._activeScans[player]
    local isRescan  = prevScan ~= nil  -- re-scan from layer toggle vs fresh Start
    if prevScan then
        if prevScan.refreshTimer then timer.removeFunction(prevScan.refreshTimer) end
        self:_removeAllMarks(prevScan)
        self._activeScans[player] = nil
    end

    local enabledLayers = self:_enabledLayers(player)
    -- No early-return when no layers enabled: RECON starts regardless so the player can
    -- activate layers via menu after Start without needing to restart RECON.
    -- Info message only on fresh Start (not on layer toggle re-scan).
    if #enabledLayers == 0 and not isRescan then
        trigger.action.outTextForGroup(ctld.utils.getGroupId(playerUnit),
            ctld.tr("RECON started. Activate layers to see targets."), 10)
    end

    local radius  = ctld.gs("reconSearchRadius") or 5000
    -- Pass ALL layers (not just enabled) so _matchLayer can enforce priority correctly.
    local targets = self:_scanLOS(playerUnit, self:_getPlayerLayers(player), radius)

    -- Create icons + count per layer
    local targetsByLayer = {}
    for _, tgt in ipairs(targets) do
        local mid = self:_nextMark()
        tgt.markId = mid
        CTLDReconRenderer.createIcon(tgt, mid)
        local lid = tgt.layer.layerId
        targetsByLayer[lid] = (targetsByLayer[lid] or 0) + 1
    end

    self._activeScans[player] = {
        playerUnit   = playerUnit,
        coalition    = playerUnit:getCoalition(),
        player       = player,
        targets      = targets,
        layers       = enabledLayers,
        autoRefresh  = false,
        refreshTimer = nil,
    }

    -- FARP/FOB layer: initial sync (adds marks for newly detected objects)
    self:_syncFarpMarks(playerUnit, player)

    -- Build activeLayers payload
    local activeLayersPayload = {}
    for _, l in ipairs(enabledLayers) do
        activeLayersPayload[#activeLayersPayload + 1] = {
            layerId = l.layerId, name = l.name, enabled = true, color = l.color
        }
    end

    EventDispatcher.getInstance():publish("OnReconScan", {
        player               = player,
        playerUnit           = playerUnit,
        coalition            = playerUnit:getCoalition(),
        position             = pos,
        altitude             = agl,
        searchRadius         = radius,
        activeLayers         = activeLayersPayload,
        targets              = targets,
        targetsByLayer       = targetsByLayer,
        totalTargetsDetected = #targets,
        totalMarksCreated    = #targets,
        autoRefresh          = true,
        timestamp            = timer.getAbsTime(),
    })

    -- Auto-refresh always enabled when RECON starts.
    -- Pass _fromScan=true so enableAutoRefresh skips its own rebuild
    -- (scan() already calls _rebuildReconBranch below).
    self:enableAutoRefresh(playerUnit, player, true)

    -- Single menu rebuild after scan (covers both start and layer-toggle re-scan).
    self:_rebuildReconBranch(player, playerUnit)
end

--- Stop RECON for player (menu F10 "RECON [Stop]").
-- Stops auto-refresh timer, removes all marks, sets RECON to idle state.
-- Layer enabled/disabled states are preserved for the next Start.
-- @param playerUnit DCS Unit
-- @param player     string
function CTLDReconManager:stopScan(playerUnit, player)
    local scan = self._activeScans[player]
    if not scan then return end

    local refreshStopped = scan.autoRefresh
    if scan.refreshTimer then
        timer.removeFunction(scan.refreshTimer)
        scan.refreshTimer = nil
    end

    local marksRemoved = {}
    for _, tgt in ipairs(scan.targets) do
        CTLDReconRenderer.removeIcon(tgt.markId)
        marksRemoved[#marksRemoved + 1] = {
            markId    = tgt.markId,
            unitType  = tgt.unitType,
            layer     = { layerId = tgt.layer.layerId, name = tgt.layer.name },
            position  = tgt.position,
            wasActive = true,
        }
    end
    self:_clearFarpMarks(player)
    self._activeScans[player] = nil

    trigger.action.outTextForGroup(ctld.utils.getGroupId(playerUnit),
        ctld.tr("Recon stopped. %1 targets hidden.", #marksRemoved), 10)

    EventDispatcher.getInstance():publish("OnReconHideTargets", {
        player            = player,
        playerUnit        = playerUnit,
        coalition         = playerUnit:getCoalition(),
        marksRemoved      = marksRemoved,
        totalMarksRemoved = #marksRemoved,
        refreshStopped    = refreshStopped,
        timestamp         = timer.getAbsTime(),
    })

    -- Rebuild menu: RECON [Start] + all layer labels switch to (X) suffix.
    self:_rebuildReconBranch(player, playerUnit)
end

--- Enable auto-refresh (menu F10 "Auto-Refresh: [OFF]" → ON).
-- @param playerUnit DCS Unit
-- @param player     string
-- @param _fromScan  boolean  internal flag — skip menu rebuild when called from scan()
function CTLDReconManager:enableAutoRefresh(playerUnit, player, _fromScan)
    local scan = self._activeScans[player]
    if not scan then
        trigger.action.outTextForGroup(ctld.utils.getGroupId(playerUnit),
            ctld.tr("No active recon scan. Use 'Scan Area' first."), 10)
        return
    end
    if scan.autoRefresh then return end

    local interval = ctld.gs("reconRefreshInterval") or 10
    scan.autoRefresh = true

    local self_ref = self
    local pName    = player
    local uName    = playerUnit:getName()
    scan.refreshTimer = timer.scheduleFunction(function(_, t)
        self_ref:_doRefresh(pName, uName, t)
    end, nil, timer.getTime() + interval)

    if ctld.gs("debug") then
        ctld.utils.log("DEBUG", "CTLDReconManager:enableAutoRefresh — interval %d s, player %s",
            interval, tostring(player))
    end

    EventDispatcher.getInstance():publish("OnReconAutoRefreshEnabled", {
        player          = player,
        playerUnit      = playerUnit,
        coalition       = playerUnit:getCoalition(),
        previousState   = false,
        newState        = true,
        targetsCount    = #scan.targets,
        refreshInterval = interval,
        timestamp       = timer.getAbsTime(),
    })

    if not _fromScan then
        self:_rebuildReconBranch(player, playerUnit)
    end
end

--- Disable auto-refresh (menu F10 "Auto-Refresh: [ON]" → OFF).
-- @param playerUnit DCS Unit
-- @param player     string
function CTLDReconManager:disableAutoRefresh(playerUnit, player)
    local scan = self._activeScans[player]
    if not scan or not scan.autoRefresh then return end

    local interval = ctld.gs("reconRefreshInterval") or 10
    scan.autoRefresh = false
    if scan.refreshTimer then
        timer.removeFunction(scan.refreshTimer)
        scan.refreshTimer = nil
    end

    trigger.action.outTextForGroup(ctld.utils.getGroupId(playerUnit),
        ctld.tr("Auto-refresh disabled. Current targets frozen on map."), 10)

    EventDispatcher.getInstance():publish("OnReconAutoRefreshDisabled", {
        player          = player,
        playerUnit      = playerUnit,
        coalition       = playerUnit:getCoalition(),
        previousState   = true,
        newState        = false,
        targetsCount    = #scan.targets,
        refreshInterval = interval,
        timestamp       = timer.getAbsTime(),
    })

    self:_rebuildReconBranch(player, playerUnit)
end

--- Toggle a recon layer ON/OFF for a player.
-- If a scan is active, re-scans immediately with updated layer set.
-- @param player     string
-- @param playerUnit DCS Unit
-- @param layerId    string
function CTLDReconManager:toggleLayer(player, playerUnit, layerId)
    local layer = self:_findLayer(player, layerId)
    if not layer then
        ctld.utils.log("WARN", "CTLDReconManager:toggleLayer: unknown layerId '%s'", tostring(layerId))
        return
    end

    layer.enabled = not layer.enabled
    local state   = layer.enabled and "ON" or "OFF"

    trigger.action.outTextForGroup(ctld.utils.getGroupId(playerUnit),
        ctld.tr("Recon layer '%1': %2", layer.name, state), 10)

    -- Immediate re-scan if scan is active (applies new layer state).
    -- scan() handles its own menu rebuild so we skip the extra call below.
    local didScan = false
    if self._activeScans[player] then
        self:scan(playerUnit, player)
        didScan = true
    end

    EventDispatcher.getInstance():publish("OnReconLayerToggled", {
        layerId   = layer.layerId,
        layerName = layer.name,
        visible   = layer.enabled,
        coalition = playerUnit:getCoalition(),
        player    = player,
        timestamp = timer.getAbsTime(),
    })

    -- Only rebuild menu if scan() didn't already do it.
    if not didScan then
        self:_rebuildReconBranch(player, playerUnit)
    end
end

-- ============================================================
-- Auto-refresh timer callback
-- ============================================================

--- Called by timer.scheduleFunction every reconRefreshInterval seconds.
-- @param playerName string
-- @param unitName   string  (DCS unit name, for re-lookup after tick)
function CTLDReconManager:_doRefresh(playerName, unitName, _t)
    local scan = self._activeScans[playerName]
    if not scan or not scan.autoRefresh then return end

    local playerUnit = Unit.getByName(unitName)
    if not playerUnit or not playerUnit:isExist() then
        -- Player gone — cleanup silently
        self:_removeAllMarks(scan)
        self._activeScans[playerName] = nil
        return
    end

    local radius         = ctld.gs("reconSearchRadius") or 5000
    -- Use full layer list so _matchLayer enforces priority on disabled layers.
    local currentTargets = self:_scanLOS(playerUnit, self:_getPlayerLayers(playerName), radius)

    -- Index previous targets by unitName
    local prevIndex = {}
    for _, tgt in ipairs(scan.targets) do
        prevIndex[tgt.unitName] = tgt
    end

    local newTargets   = {}
    local movedTargets = {}
    local lostTargets  = {}

    for _, tgt in ipairs(currentTargets) do
        local prev = prevIndex[tgt.unitName]
        if not prev then
            -- New target
            local mid = self:_nextMark()
            tgt.markId = mid
            CTLDReconRenderer.createIcon(tgt, mid)
            tgt.status = "new"
            newTargets[#newTargets + 1] = tgt
        else
            local d = ctld.utils.getDistance(
                "CTLDReconManager:_doRefresh", prev.position, tgt.position)
            if d > 5 then
                -- Moved: remove old icon (invalidates its DCS ID permanently),
                -- allocate a fresh ID for the new icon (DCS IDs must never be reused).
                CTLDReconRenderer.removeIcon(prev.markId)
                local newMid = self:_nextMark()
                tgt.markId = newMid
                CTLDReconRenderer.createIcon(tgt, newMid)
                tgt.status        = "moved"
                tgt.hasMoved      = true
                tgt.distanceMoved = d
                movedTargets[#movedTargets + 1] = {
                    unit          = tgt.unit,
                    unitName      = tgt.unitName,
                    unitType      = tgt.unitType,
                    positionOld   = prev.position,
                    positionNew   = tgt.position,
                    distanceMoved = d,
                    markId        = newMid,
                }
            else
                -- Carry forward the existing markId so stopScan/removeAllMarks can remove it.
                tgt.markId = prev.markId
                tgt.status = "existing"
            end
            prevIndex[tgt.unitName] = nil
        end
    end

    -- Remaining in prevIndex = lost (out of LOS or dead)
    for uName, prevTgt in pairs(prevIndex) do
        local reason = "out_of_los"
        if not prevTgt.unit:isExist() then reason = "dead" end
        CTLDReconRenderer.removeIcon(prevTgt.markId)
        lostTargets[#lostTargets + 1] = {
            unit     = prevTgt.unit,
            unitName = uName,
            unitType = prevTgt.unitType,
            reason   = reason,
            markId   = prevTgt.markId,
        }
    end

    -- Update scan state
    scan.targets     = currentTargets
    scan.playerUnit  = playerUnit

    -- FARP/FOB: sync new detections (existing marks kept, dead ones removed by watcher)
    self:_syncFarpMarks(playerUnit, playerName)

    -- Re-schedule next refresh
    local interval = ctld.gs("reconRefreshInterval") or 10
    local self_ref = self
    local pName    = playerName
    local uNameRef = unitName
    scan.refreshTimer = timer.scheduleFunction(function(_, t)
        self_ref:_doRefresh(pName, uNameRef, t)
    end, nil, timer.getTime() + interval)

    EventDispatcher.getInstance():publish("OnReconScanRefresh", {
        player                = playerName,
        playerUnit            = playerUnit,
        coalition             = playerUnit:getCoalition(),
        position              = playerUnit:getPoint(),
        altitude              = playerUnit:getPoint().y,
        activeLayers          = scan.layers,
        targets               = currentTargets,
        newTargets            = newTargets,
        movedTargets          = movedTargets,
        lostTargets           = lostTargets,
        totalTargetsCurrent   = #currentTargets,
        totalTargetsNew       = #newTargets,
        totalTargetsMoved     = #movedTargets,
        totalTargetsLost      = #lostTargets,
        marksCreated          = #newTargets,
        marksUpdated          = #movedTargets,
        marksRemoved          = #lostTargets,
        timestamp             = timer.getAbsTime(),
    })
end

-- ============================================================
-- Query API
-- ============================================================

--- Return current scan state for player, or nil.
-- @param player string
-- @return table|nil  { playerUnit, coalition, targets, layers, autoRefresh, refreshTimer }
function CTLDReconManager:getActiveScan(player)
    return self._activeScans[player]
end

--- Return per-player layers array.
-- @param player string
-- @return table  array of layer objects
function CTLDReconManager:getPlayerLayers(player)
    return self:_getPlayerLayers(player)
end

-- ============================================================
-- F10 Menu section
-- ============================================================

--- Internal: add all RECON commands to an already-existing RECON submenu node.
-- "RECON [Start/Stop]": single toggle entry for RECON active state.
-- Layer labels: [activate/deactivate] when RECON active, [activate/deactivate (X)] when idle.
-- @param menu     ctld.Menu
-- @param unitName string  used as DCS unit key and player-state key
function CTLDReconManager:_addReconCommands(menu, unitName)
    local root      = ctld.tr("CTLD")
    local reconSub  = ctld.tr("RECON")
    local isActive  = self._activeScans[unitName] ~= nil

    -- RECON [Start] / RECON [Stop] — single start/stop toggle.
    local reconLabel = isActive and ctld.tr("RECON [Stop]") or ctld.tr("RECON [Start]")
    menu:addCommand({ root, reconSub }, reconLabel,
        function(arg)
            local unit = Unit.getByName(arg.unitName)
            if not unit then return end
            local rmgr = CTLDReconManager.getInstance()
            if rmgr._activeScans[arg.unitName] then
                rmgr:stopScan(unit, arg.unitName)
            else
                rmgr:scan(unit, arg.unitName)
            end
        end,
        { unitName = unitName })

    -- Per-layer toggles — label shows NEXT ACTION (what clicking will do).
    -- Layer enabled  : "Layer [deactivate]"
    -- Layer disabled : "Layer [activate]"
    -- (X) suffix when RECON is idle (no active scan).
    local layers = self:_getPlayerLayers(unitName)
    for _, layer in ipairs(layers) do
        local action = layer.enabled and ctld.tr("[deactivate]") or ctld.tr("[activate]")
        if not isActive then action = action .. " (X)" end
        local label = string.format("%s %s", layer.name, action)
        menu:addCommand({ root, reconSub }, label,
            function(arg)
                local unit = Unit.getByName(arg.unitName)
                if unit then
                    CTLDReconManager.getInstance():toggleLayer(arg.unitName, unit, arg.layerId)
                end
            end,
            { unitName = unitName, layerId = layer.layerId })
    end
end

--- Internal: clear the RECON branch commands and re-add them with current state labels.
-- Call after any state change: scan start/stop, layer toggle.
-- @param unitName  string  player/unit key
-- @param playerUnit DCS Unit object
function CTLDReconManager:_rebuildReconBranch(unitName, playerUnit)
    local menu = ctld.MenuManager:getInstance():getMenuByUnitName(unitName)
    if not menu then return end
    local root     = ctld.tr("CTLD")
    local reconSub = ctld.tr("RECON")
    menu:clearBranch({ root, reconSub })
    self:_addReconCommands(menu, unitName)
    menu:refresh()
end

--- Build the "RECON" F10 submenu for a player.
-- Requires reconF10Menu = true (configKey gate).
-- @param playerObj CTLDPlayer
-- @param menu      ctld.Menu
function CTLDReconManager:buildMenuSection(playerObj, menu)
    local root     = ctld.tr("CTLD")
    local reconSub = ctld.tr("RECON")
    menu:addSubMenu({ root }, reconSub, { order = 70 })
    self:_addReconCommands(menu, playerObj.unitName)
end
