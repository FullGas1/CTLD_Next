-- ============================================================
-- src/legacy/legacy_api.lua
-- Legacy API compatibility wrappers — CTLD v1 → v2
--
-- Provides the original ctld.* function signatures used in
-- mission DO SCRIPT triggers, forwarding each call to the
-- corresponding v2 manager with a deprecation warning.
--
-- Deprecation warnings are logged at WARNING level so they
-- appear in both DCS.log and ctld.log (if enabled).
--
-- NOTE: ctld.spawnCrateAtZone / ctld.spawnCrateAtPoint delegate
-- to CTLDCrateManager:spawnCrate() (implemented, uses ctld.utils.dynAddStatic).
--
-- NOTE: ctld.addCallback() is not wrapped — use
-- EventDispatcher:subscribe(eventName, handler) instead.
-- See documentation/migration-v2.md for the full migration guide.
--
-- Load order: after all managers (last in listToMerge.txt,
-- before CTLD_userConfig.lua).
-- ============================================================

---@diagnostic disable
ctld = ctld or {}

-- ============================================================
-- Troops / Transport
-- ============================================================

--- @deprecated Use CTLDTroopManager:spawnGroupAtTrigger()
function ctld.spawnGroupAtTrigger(_groupSide, _number, _triggerName, _searchRadius)
    ctld.logWarning("DEPRECATED: ctld.spawnGroupAtTrigger — use CTLDTroopManager:spawnGroupAtTrigger()")
    CTLDTroopManager.getInstance():spawnGroupAtTrigger(_groupSide, _number, _triggerName, _searchRadius)
end

--- @deprecated Use CTLDTroopManager:spawnGroupAtPoint()
function ctld.spawnGroupAtPoint(_groupSide, _number, _point, _searchRadius)
    ctld.logWarning("DEPRECATED: ctld.spawnGroupAtPoint — use CTLDTroopManager:spawnGroupAtPoint()")
    CTLDTroopManager.getInstance():spawnGroupAtPoint(_groupSide, _number, _point, _searchRadius)
end

--- @deprecated Use CTLDTroopManager:preLoadTransport()
function ctld.preLoadTransport(_unitName, _number, _troops)
    ctld.logWarning("DEPRECATED: ctld.preLoadTransport — use CTLDTroopManager:preLoadTransport()")
    CTLDTroopManager.getInstance():preLoadTransport(_unitName, _number, _troops)
end

--- @deprecated Use CTLDTroopManager:unloadTransport()
function ctld.unloadTransport(_unitName)
    ctld.logWarning("DEPRECATED: ctld.unloadTransport — use CTLDTroopManager:unloadTransport()")
    CTLDTroopManager.getInstance():unloadTransport(_unitName)
end

--- @deprecated Use CTLDTroopManager:loadTransport()
function ctld.loadTransport(_unitName)
    ctld.logWarning("DEPRECATED: ctld.loadTransport — use CTLDTroopManager:loadTransport()")
    CTLDTroopManager.getInstance():loadTransport(_unitName)
end

--- @deprecated Use CTLDTroopManager:unloadInProximityToEnemy()
function ctld.unloadInProximityToEnemy(_unitName, _distance)
    ctld.logWarning("DEPRECATED: ctld.unloadInProximityToEnemy — use CTLDTroopManager:unloadInProximityToEnemy()")
    return CTLDTroopManager.getInstance():unloadInProximityToEnemy(_unitName, _distance)
end

-- ============================================================
-- Zones
-- ============================================================

--- @deprecated Use CTLDZoneManager:setTroopZoneActive()
function ctld.activatePickupZone(_zoneName)
    ctld.logWarning("DEPRECATED: ctld.activatePickupZone — use CTLDZoneManager:setTroopZoneActive(name, true)")
    CTLDZoneManager.getInstance():setTroopZoneActive(_zoneName, true)
end

--- @deprecated Use CTLDZoneManager:setTroopZoneActive()
function ctld.deactivatePickupZone(_zoneName)
    ctld.logWarning("DEPRECATED: ctld.deactivatePickupZone — use CTLDZoneManager:setTroopZoneActive(name, false)")
    CTLDZoneManager.getInstance():setTroopZoneActive(_zoneName, false)
end

--- @deprecated Use CTLDZoneManager:changeRemainingGroups()
function ctld.changeRemainingGroupsForPickupZone(_zoneName, _amount)
    ctld.logWarning("DEPRECATED: ctld.changeRemainingGroupsForPickupZone — use CTLDZoneManager:changeRemainingGroups()")
    CTLDZoneManager.getInstance():changeRemainingGroups(_zoneName, _amount)
end

--- @deprecated Use CTLDZoneManager:activateWaypointZone()
function ctld.activateWaypointZone(_zoneName)
    ctld.logWarning("DEPRECATED: ctld.activateWaypointZone — use CTLDZoneManager:activateWaypointZone()")
    CTLDZoneManager.getInstance():activateWaypointZone(_zoneName)
end

--- @deprecated Use CTLDZoneManager:deactivateWaypointZone()
function ctld.deactivateWaypointZone(_zoneName)
    ctld.logWarning("DEPRECATED: ctld.deactivateWaypointZone — use CTLDZoneManager:deactivateWaypointZone()")
    CTLDZoneManager.getInstance():deactivateWaypointZone(_zoneName)
end

--- @deprecated Use CTLDZoneManager:createExtractZone()
function ctld.createExtractZone(_zone, _flagNumber, _smoke)
    ctld.logWarning("DEPRECATED: ctld.createExtractZone — use CTLDZoneManager:createExtractZone()")
    CTLDZoneManager.getInstance():createExtractZone(_zone, _flagNumber, _smoke)
end

--- @deprecated Use CTLDZoneManager:removeExtractZone()
function ctld.removeExtractZone(_zone, _flagNumber)
    ctld.logWarning("DEPRECATED: ctld.removeExtractZone — use CTLDZoneManager:removeExtractZone()")
    CTLDZoneManager.getInstance():removeExtractZone(_zone, _flagNumber)
end

--- @deprecated Use CTLDTroopManager:startGroupCountWatcher()
function ctld.countDroppedGroupsInZone(_zone, _blueFlag, _redFlag)
    ctld.logWarning("DEPRECATED: ctld.countDroppedGroupsInZone — use CTLDTroopManager:startGroupCountWatcher()")
    CTLDTroopManager.getInstance():startGroupCountWatcher(_zone, _blueFlag, _redFlag)
end

--- @deprecated Use CTLDTroopManager:startUnitCountWatcher()
function ctld.countDroppedUnitsInZone(_zone, _blueFlag, _redFlag)
    ctld.logWarning("DEPRECATED: ctld.countDroppedUnitsInZone — use CTLDTroopManager:startUnitCountWatcher()")
    CTLDTroopManager.getInstance():startUnitCountWatcher(_zone, _blueFlag, _redFlag)
end

-- ============================================================
-- Crates
-- ============================================================

--- @deprecated Use CTLDCrateManager:spawnCrateAtZone()
-- NOTE: non-functional until CTLDCrateManager:spawnCrate() is implemented.
function ctld.spawnCrateAtZone(_side, _weight, _zone)
    ctld.logWarning("DEPRECATED: ctld.spawnCrateAtZone — use CTLDCrateManager:spawnCrateAtZone()")
    return CTLDCrateManager.getInstance():spawnCrateAtZone(_side, _weight, _zone)
end

--- @deprecated Use CTLDCrateManager:spawnCrateAtPoint()
-- NOTE: non-functional until CTLDCrateManager:spawnCrate() is implemented.
function ctld.spawnCrateAtPoint(_side, _weight, _point, _hdg)
    ctld.logWarning("DEPRECATED: ctld.spawnCrateAtPoint — use CTLDCrateManager:spawnCrateAtPoint()")
    return CTLDCrateManager.getInstance():spawnCrateAtPoint(_side, _weight, _point, _hdg)
end

--- @deprecated Use CTLDCrateManager:startCrateCountWatcher()
function ctld.cratesInZone(_zone, _flagNumber)
    ctld.logWarning("DEPRECATED: ctld.cratesInZone — use CTLDCrateManager:startCrateCountWatcher()")
    CTLDCrateManager.getInstance():startCrateCountWatcher(_zone, _flagNumber)
end

-- ============================================================
-- Beacons
-- ============================================================

--- @deprecated Use CTLDBeaconManager:createAtZone()
function ctld.createRadioBeaconAtZone(_zone, _coalition, _batteryLife, _name)
    ctld.logWarning("DEPRECATED: ctld.createRadioBeaconAtZone — use CTLDBeaconManager:createAtZone()")
    CTLDBeaconManager.getInstance():createAtZone(_zone, _coalition, _batteryLife, _name)
end

-- ============================================================
-- JTAC
-- ============================================================

--- @deprecated Use CTLDJTACManager:autoLase()
function ctld.JTACAutoLase(_jtacGroupName, _laserCode, _smoke, _lock, _colour, _radio)
    ctld.logWarning("DEPRECATED: ctld.JTACAutoLase — use CTLDJTACManager:autoLase()")
    CTLDJTACManager.getInstance():autoLase(_jtacGroupName, _laserCode, _smoke, _lock, _colour, _radio)
end

--- @deprecated Use CTLDJTACManager:startLase()
function ctld.JTACStart(_jtacGroupName, _laserCode, _smoke, _lock, _colour, _radio)
    ctld.logWarning("DEPRECATED: ctld.JTACStart — use CTLDJTACManager:startLase()")
    CTLDJTACManager.getInstance():startLase(_jtacGroupName, _laserCode, _smoke, _lock, _colour, _radio)
end

--- @deprecated Use CTLDJTACManager:stopAutoLase()
function ctld.JTACAutoLaseStop(_jtacGroupName)
    ctld.logWarning("DEPRECATED: ctld.JTACAutoLaseStop — use CTLDJTACManager:stopAutoLase()")
    CTLDJTACManager.getInstance():stopAutoLase(_jtacGroupName)
end
