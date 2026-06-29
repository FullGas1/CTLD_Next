# CTLD Events Catalog

**Status**: Current — extracted from `src/` 2026-06-29
**Total events**: 51 CTLD application events + 13 DCS engine event types handled

---

## Overview

CTLD uses a pub/sub pattern via `EventDispatcher` (singleton, `src/CTLD_core.lua`).

```lua
-- Subscribe
EventDispatcher.getInstance():subscribe("OnCrateLoaded", function(payload)
    -- payload fields depend on event (see below)
end)

-- Unsubscribe
EventDispatcher.getInstance():unsubscribe("OnCrateLoaded", myCallback)
```

All events carry at minimum a `timestamp` field (`timer.getAbsTime()`).

---

## Events by Domain

### Beacon Events (5)

#### `OnBeaconDropped`
Fired when a radio beacon is deployed.

| Field | Type | Description |
|---|---|---|
| `player` | string | Player name, or `"MissionMaker"` if from zone |
| `playerUnit` | Unit or nil | DCS Unit object |
| `coalition` | number | Coalition ID |
| `beacon` | table | Full beacon payload (see below) |
| `timestamp` | number | `timer.getAbsTime()` |

`beacon` sub-table: `{ beaconName, name, position (vec3), mgrsCoords, frequencies { vhf, uhf, fm }, battery { remainingTime, wasInfinite, duration, infinite } }`

**Publisher**: `CTLDBeaconManager:dropBeacon()`, `CTLDBeaconManager:createAtZone()`

---

#### `OnBeaconRemoved`
Fired when a player manually removes the closest beacon.

| Field | Type | Description |
|---|---|---|
| `player` | string | |
| `playerUnit` | Unit | |
| `coalition` | number | |
| `beacon` | table | `{ beaconName, name, position, mgrsCoords, frequencies, battery, distance }` |
| `reason` | string | `"manual"` |
| `frequenciesFreed` | table | `{ vhf, uhf, fm }` |
| `timestamp` | number | |

**Publisher**: `CTLDBeaconManager:removeClosestBeacon()`

---

#### `OnBeaconDestroyed`
Fired when a beacon's battery runs out or its DCS units are all destroyed.

| Field | Type | Description |
|---|---|---|
| `beacon` | table | `{ beaconName, name, position, mgrsCoords, frequencies, battery, unitsAlive, durationAlive }` |
| `reason` | string | `"battery"` or `"units"` |
| `frequenciesFreed` | table | `{ vhf, uhf, fm }` |
| `timestamp` | number | |

**Publisher**: `CTLDBeaconManager:_tick()` (battery depleted or < 3 radio units alive)

---

#### `OnBeaconRefreshed`
Fired on each beacon manager tick with a summary of all active beacons.

| Field | Type | Description |
|---|---|---|
| `beacons` | table | Array of beacon payload tables |
| `totalBeaconsRefreshed` | number | |
| `totalBeaconsDestroyed` | number | Beacons destroyed this tick |
| `timestamp` | number | |

**Publisher**: `CTLDBeaconManager:_tick()` (periodic refresh)

---

#### `OnBeaconLayerToggled`
Fired when a player toggles the beacon F10 map layer.

| Field | Type | Description |
|---|---|---|
| `player` | string | |
| `playerUnit` | Unit | |
| `coalition` | number | |
| `previousState` | bool | |
| `newState` | bool | |
| `action` | string | `"enabled"` or `"disabled"` |
| `beaconsDisplayed` | table | Array of beacons now displayed |
| `totalBeaconsDisplayed` | number | |
| `timestamp` | number | |

**Publisher**: `CTLDBeaconManager:toggleBeaconLayer()`

---

### Crate Events (10)

#### `OnCrateSpawned`
Fired when any crate appears on the map.

| Field | Type | Description |
|---|---|---|
| `crate` | CTLDCrate | Internal crate object |
| `crateName` | string | Unique crate identifier |
| `descriptor` | table | Crate descriptor |
| `position` | vec3 | |
| `coalition` | number | |
| `spawnedBy` | string or nil | Player/mission-maker name |
| `spawnMethod` | string | `"request_crate"`, `"parachute_drop"`, `"slingload_cut"`, `"mm_late_activation"`, ... |
| `timestamp` | number | |

**Publisher**: `CTLDCrateManager:spawn()`, `:respawnFromMMCrate()`, `:dropCrate()`, `:parachuteDropCrate()`

---

#### `OnCrateLoaded`
Fired when a crate is picked up (slingload or DCS native cargo).

| Field | Type | Description |
|---|---|---|
| `crate` | CTLDCrate | |
| `crateName` | string | |
| `carrierUnitName` | string | Name of the transport unit |
| `coalition` | number | |
| `descriptor` | table | |
| `trigger` | string | `"slingload"` or `"dcs_native"` |
| `method` | string or nil | `"dcs_native"` (absent for slingload) |
| `timestamp` | number | |

**Publisher**: `CTLDCrateManager:loadCrate()`

---

#### `OnCrateUnloaded`
Fired when a crate is dropped or unloaded (not unpacked).

| Field | Type | Description |
|---|---|---|
| `crate` | CTLDCrate | |
| `crateName` | string | |
| `coalition` | number | |
| `descriptor` | table | |
| `method` | string or nil | `"dcs_native"` if native, absent for slingload |
| `timestamp` | number | |

**Publisher**: `CTLDCrateManager:unloadCrate()`, `:dropCrate()`

---

#### `OnCrateLost`
Fired when a crate is destroyed due to overspeed slingload or high-altitude drop impact.

| Field | Type | Description |
|---|---|---|
| `crate` | CTLDCrate | |
| `crateName` | string | |
| `coalition` | number | |
| `transport` | Unit | The carrying aircraft |
| `trigger` | string | `"slingload_overspeed"` or `"slingload_cut_impact"` |
| `timestamp` | number | |

**Publisher**: `CTLDCrateManager:checkSlingloadStatus()`, `:dropCrate()`

---

#### `OnCrateCleared`
Fired when a crate is removed from the world (unpacked, destroyed, or loaded natively).

| Field | Type | Description |
|---|---|---|
| `crateName` | string | |
| `position` | vec3 | Last known position |
| `coalition` | number | |
| `descriptor` | table | |
| `reason` | string | `"destroyed"`, `"unpacked"`, or `"loaded"` |
| `timestamp` | number | |

**Publisher**: `CTLDCrateManager:dropCrate()`, `:unpackCrate()`, `:destroyCrate()`, `:unloadCrate()` (native)

---

#### `OnCrateUnpacked`
Fired when a crate is successfully unpacked (assembled into equipment).

| Field | Type | Description |
|---|---|---|
| `crate` | CTLDCrate | |
| `crateName` | string | |
| `descriptor` | table | |
| `position` | vec3 | Unpack location |
| `coalition` | number | |
| `carrierUnitName` | string or nil | Unit performing the unpack |
| `timestamp` | number | |

**Publisher**: `CTLDCrateManager:unpackCrate()`

---

#### `OnCrateDestroyed`
Fired when a crate is destroyed on high-altitude drop impact (not slingload).

| Field | Type | Description |
|---|---|---|
| `crate` | CTLDCrate | |
| `crateName` | string | |
| `coalition` | number | |
| `reason` | string | `"drop_impact"` |
| `timestamp` | number | |

**Publisher**: `CTLDCrateManager:dropCrate()` (impact path)

---

#### `OnCrateParachuting`
Fired when a crate is released in parachute drop mode.

| Field | Type | Description |
|---|---|---|
| `crate` | CTLDCrate | |
| `crateName` | string | |
| `descriptor` | table | |
| `dropPosition` | vec3 | Position at release |
| `landingPosition` | vec3 | Estimated landing position |
| `altitude` | number | AGL in metres |
| `descentTime` | number | Estimated seconds to landing |
| `carrierUnitName` | string | |
| `player` | string | Player name |
| `timestamp` | number | |

**Publisher**: `CTLDCrateManager:parachuteDropCrate()`

---

#### `OnCrateParachuteLanded`
Fired when a parachuted crate lands (async, after descent timer).

| Field | Type | Description |
|---|---|---|
| `crate` | CTLDCrate | |
| `crateName` | string | |
| `descriptor` | table | |
| `position` | vec3 | Landing position |
| `coalition` | number | |
| `startAltitude` | number | AGL at release |
| `timestamp` | number | |

**Publisher**: `CTLDCrateManager:parachuteDropCrate()` (async timer callback)

---

#### `OnMMCrateDetected`
Fired when a mission-maker pre-placed crate is registered on late activation.

| Field | Type | Description |
|---|---|---|
| `crate` | CTLDCrate | |
| `crateName` | string | |
| `descriptor` | table | |
| `position` | vec3 | |
| `coalition` | number | |
| `timestamp` | number | |

**Publisher**: `CTLDCrateManager:registerMMCrate()`

---

### Vehicle Events (8)

#### `OnVehicleSpawnedForTransport`
Fired when a vehicle is spawned in WAITING state for transport (Feature Q / Request Equipment).

| Field | Type | Description |
|---|---|---|
| `vehicleId` | string | Internal CTLD vehicle ID |
| `vehicle` | Unit | DCS Unit object |
| `vehicleType` | string | DCS type name |
| `spawner` | string or nil | Player name |
| `logisticZone` | table or nil | Zone where spawned |
| `spawnMethod` | string | `"request_vehicle"` |
| `position` | vec3 | |
| `timestamp` | number | |

**Publisher**: `CTLDVehicleSpawner:requestVehicle()`

---

#### `OnVehicleLoaded`
Fired when a vehicle is loaded into a transport.

| Field | Type | Description |
|---|---|---|
| `vehicleId` | string | |
| `ctldVehicleObject` | CTLDVehicle | |
| `dcsUnitObject` | Unit or nil | Present if native load |
| `vehicleType` | string | |
| `transportUnitObject` | Unit | |
| `player` | string | |
| `method` | string | `"slingload"` or `"dcs_native"` |
| `spawnMethod` | string | |
| `position` | vec3 | |
| `transportPosition` | vec3 | |
| `timestamp` | number | |

**Publisher**: `CTLDVehicleSpawner:loadVehicle()`

---

#### `OnVehicleUnloaded`
Fired when a vehicle is unloaded from a transport.

Same fields as `OnVehicleLoaded`.

**Publisher**: `CTLDVehicleSpawner:unloadVehicle()`

---

#### `OnVehiclePacked`
Fired when a vehicle is packed into crates.

| Field | Type | Description |
|---|---|---|
| `vehicleType` | string | |
| `descriptor` | table | Crate descriptor used |
| `transport` | string | Transport unit name |
| `player` | string or nil | |
| `cratesSpawned` | number | Number of crates spawned |
| `timestamp` | number | |

**Publisher**: `CTLDVehicleSpawner:packVehicle()`

---

#### `OnVehicleParachuting`
Fired when a vehicle is released in parachute mode.

| Field | Type | Description |
|---|---|---|
| `vehicle` | CTLDVehicle | |
| `transport` | string | Transport unit name |
| `player` | string | |
| `altitude` | number | AGL in metres |
| `dropPosition` | vec3 | |
| `estimatedLandingPos` | vec3 | |
| `estimatedLandingTime` | number | `timer.getAbsTime() + descentTime` |
| `timestamp` | number | |

**Publisher**: `CTLDVehicleSpawner:parachuteDropVehicle()`

---

#### `OnVehicleParachuteLanded`
Fired when a parachuted vehicle lands.

| Field | Type | Description |
|---|---|---|
| `vehicle` | CTLDVehicle | |
| `position` | vec3 | |
| `transport` | string | |
| `player` | string | |
| `startAltitude` | number | AGL at release |
| `timestamp` | number | |

**Publisher**: `CTLDVehicleSpawner:parachuteDropVehicle()` (async timer callback)

---

#### `OnVehicleDead`
Fired when a tracked CTLD vehicle is destroyed.

| Field | Type | Description |
|---|---|---|
| `vehicleId` | string | |
| `vehicle` | Unit | S_EVENT_DEAD initiator |
| `vehicleType` | string | |
| `coalition` | number or nil | |
| `position` | vec3 | |
| `durationAlive` | number | Seconds since spawn |
| `timestamp` | number | |

**Publisher**: `CTLDVehicleSpawner:onDead()` (S_EVENT_DEAD handler)

---

#### `OnGroundUnitSpawned` / `OnGroundUnitRemoved`
Fired when any CTLD-tracked ground unit appears or disappears.

| Field | Type | Description |
|---|---|---|
| `vehicleType` | string | DCS type name |
| `position` | vec3 | |
| `coalitionId` | number | (Spawned only) |
| `reason` | string | Removed only: `"loaded"`, `"packed"`, `"dead"` |
| `timestamp` | number | |

**Publishers**:
- `OnGroundUnitSpawned`: `CTLDCrateManager:spawnFromDescriptor()`, `CTLDVehicleSpawner:_spawnGroundUnit()`
- `OnGroundUnitRemoved`: `CTLDVehicleSpawner:loadVehicle()`, `:onDead()`, `:packVehicle()`

---

### Troop Events (2)

#### `OnTroopsDeployed`
Fired when troops are deployed by parachute.

| Field | Type | Description |
|---|---|---|
| `troops` | CTLDTroopGroup | |
| `carrierUnitName` | string | |
| `player` | string | |
| `trigger` | string | `"parachute"` |
| `destination` | table | `{ type="combat", troopZone=nil }` |
| `timestamp` | number | |

**Publisher**: `CTLDTroopManager:parachuteDeployTroops()`

---

#### `OnTroopsParachuteLanded`
Fired when parachuted troops land (async, after descent timer).

| Field | Type | Description |
|---|---|---|
| `troops` | CTLDTroopGroup | |
| `spawnedGroup` | Group | DCS group spawned on ground |
| `positions` | table | Array of vec3, one per soldier |
| `transport` | string | |
| `player` | string | |
| `startAltitude` | number | |
| `timestamp` | number | |

**Publisher**: `CTLDTroopManager:parachuteDeployTroops()` (async timer callback)

---

### JTAC Events (9)

#### `OnJTACSpawned`
Fired when a JTAC is spawned (vehicle or static).

| Field | Type | Description |
|---|---|---|
| `jtac.groupName` | string | |
| `jtac.groupId` | number | |
| `jtac.unitName` | string | |
| `jtac.unitId` | number or nil | |
| `jtac.unitType` | string or nil | |
| `jtac.coalition` | number | |
| `jtac.position` | vec3 or nil | |
| `jtac.isFlying` | bool | `true` for drone JTACs |
| `jtac.isInfantry` | bool | |
| `jtac.route` | table or nil | Drone patrol route |
| `spawner` | string | Player unit name or `"MissionMaker"` |
| `laserCode` | number | Assigned laser code (0 if none) |
| `smokeEnabled` | bool | |
| `smokeColor` | string or nil | |
| `lockMode` | string | JTAC lock mode setting |
| `radio` | table or nil | Radio config `{ freq, modulation }` |
| `timestamp` | number | |

**Publisher**: `CTLDJTACManager:spawnJTAC()`, `:spawnJTACStatic()`

---

#### `OnJTACInTransit`
Fired when a vehicle JTAC is embarked into a transport.

| Field | Type | Description |
|---|---|---|
| `jtac.groupName` | string | |
| `jtac.coalition` | number | |
| `transport` | Unit | |
| `timestamp` | number | |

**Publisher**: `CTLDJTACManager:prepareDeploymentFromCrate()`

---

#### `OnJTACLaseStart`
Fired when a JTAC acquires a target and begins lasing.

| Field | Type | Description |
|---|---|---|
| `jtac.groupName` | string | |
| `jtac.unitName` | string | |
| `jtac.position` | vec3 | |
| `jtac.coalition` | number | |
| `target.unitName` | string | |
| `target.unitId` | number | |
| `target.unitType` | string | |
| `target.coalition` | number | |
| `target.position` | vec3 | |
| `target.priority` | number | Target priority score |
| `target.selectionMethod` | string | `"auto_nearest"` or `"manual"` |
| `target.wasManuallySelected` | bool | |
| `laserCode` | number | |
| `lockMode` | string | JTAC lock mode |
| `distance` | number | Metres from JTAC to target |
| `lineOfSight` | bool | LOS confirmed at time of lock |
| `radio` | table or nil | Radio config |
| `message` | string or nil | Status message shown to player |
| `timestamp` | number | |

**Publisher**: `CTLDJTACManager:_tick()` (lasing loop, on acquisition)

---

#### `OnJTACTargetLased`
Fired each lase cycle when a JTAC is actively lasing.

| Field | Type | Description |
|---|---|---|
| `jtac.groupName` | string | |
| `jtac.unitName` | string | |
| `jtac.coalition` | number | |
| `target.unitName` | string | |
| `target.position` | vec3 | Corrected position for drone |
| `laserCode` | number | |
| `timestamp` | number | |

**Publisher**: `CTLDJTACManager:_tick()` (lasing loop, each cycle)

---

#### `OnJTACLaseStop`
Fired when a JTAC stops lasing.

| Field | Type | Description |
|---|---|---|
| `jtac.groupName` | string | |
| `jtac.coalition` | number | |
| `jtac.laserCode` | number | |
| `target.unitName` | string or nil | |
| `target.unitType` | string | |
| `target.lastKnownPosition` | vec3 | |
| `reason` | string | `"target_dead"`, `"out_of_range"`, `"manual"` |
| `timestamp` | number | |

**Publisher**: `CTLDJTACManager:stopLasing()`

---

#### `OnJTACOrbitStart`
Fired when a drone JTAC starts its orbit over a target.

| Field | Type | Description |
|---|---|---|
| `jtac.groupName` | string | |
| `jtac.coalition` | number | |
| `target.unitName` | string | |
| `target.position` | vec3 | |
| `timestamp` | number | |

**Publisher**: `CTLDJTACManager:_tick()` (orbit loop)

---

#### `OnJTACSmokeTarget`
Fired when a JTAC smokes its current target on player request.

| Field | Type | Description |
|---|---|---|
| `jtac.groupName` | string | |
| `jtac.coalition` | number | |
| `target.unitName` | string | |
| `target.position` | vec3 | |
| `smokePosition` | vec3 | Actual smoke spawn point |
| `smokeColor` | number | `trigger.smokeColor.*` constant |
| `timestamp` | number | |

**Publisher**: `CTLDJTACManager:smokeTarget()`

---

#### `OnJTACDead`
Fired when a JTAC is destroyed in combat.

| Field | Type | Description |
|---|---|---|
| `jtac.groupName` | string | |
| `jtac.coalition` | number | |
| `jtac.laserCode` | number | |
| `killer` | table or nil | `{ unitName, playerName }` |
| `lastTarget` | table or nil | Last lased target |
| `timestamp` | number | |

**Publisher**: `CTLDJTACManager:killJTAC()` (S_EVENT_DEAD handler)

> Note: repack is NOT a death — `OnJTACDead` is not fired when a JTAC vehicle is re-embarked.

---

### RECON Events (9)

#### `ReconFarpDetected`

Fired when a player in RECON detects an enemy FARP or FOB.

> Note: uses non-standard naming (no `On` prefix) — matches source at `CTLD_recon.lua:493`.

| Field | Type | Description |
|---|---|---|
| `player` | string | Player name |
| `playerUnit` | Unit | DCS Unit object |
| `coalition` | number | Enemy coalition ID |
| `playerCoalition` | number | Player's coalition ID |
| `position` | vec3 | FARP/FOB position |
| `id` | string | Internal mark ID (used by `ReconFarpLost`) |

**Publisher**: `CTLDReconManager` (FARP/FOB layer detection logic)

---

#### `ReconFarpLost`

Fired when a previously detected enemy FARP/FOB leaves the RECON scan radius or is destroyed.

> Note: uses non-standard naming (no `On` prefix) — matches source at `CTLD_recon.lua:487`.

| Field | Type | Description |
|---|---|---|
| `player` | string | Player name |
| `id` | string | Internal mark ID matching the `ReconFarpDetected` event |

**Publisher**: `CTLDReconManager` (FARP/FOB layer cleanup callback)

---

#### `OnReconScan`
Fired when a player performs a RECON scan.

| Field | Type | Description |
|---|---|---|
| `player` | string | |
| `playerUnit` | Unit | |
| `coalition` | number | |
| `position` | vec3 | Scanner position |
| `altitude` | number | AGL in metres |
| `searchRadius` | number | Metres |
| `activeLayers` | table | Array of active layer descriptors |
| `targets` | table | Array of detected targets |
| `targetsByLayer` | table | Map `layerId → targets` |
| `totalTargetsDetected` | number | |
| `totalMarksCreated` | number | |
| `timestamp` | number | |

**Publisher**: `CTLDReconManager:scan()`

---

#### `OnReconScanRefresh`
Fired each auto-refresh cycle with delta information.

| Field | Type | Description |
|---|---|---|
| `player` | string | |
| `playerUnit` | Unit | |
| `coalition` | number | |
| `position` | vec3 | |
| `altitude` | number | |
| `activeLayers` | table | |
| `targets` | table | All current targets |
| `newTargets` | table | Newly detected this cycle |
| `movedTargets` | table | Targets that moved |
| `lostTargets` | table | Targets that disappeared |
| `totalTargetsCurrent` | number | |
| `totalTargetsNew` | number | |
| `totalTargetsMoved` | number | |
| `totalTargetsLost` | number | |
| `timestamp` | number | |

**Publisher**: `CTLDReconManager:_doRefresh()` (auto-refresh timer)

---

#### `OnReconHideTargets`
Fired when a player stops RECON and all marks are removed.

| Field | Type | Description |
|---|---|---|
| `player` | string | |
| `playerUnit` | Unit | |
| `coalition` | number | |
| `marksRemoved` | table | Array of removed mark records |
| `totalMarksRemoved` | number | |
| `refreshStopped` | bool | Whether auto-refresh was running |
| `timestamp` | number | |

**Publisher**: `CTLDReconManager:stopRecon()`

---

#### `OnReconLayerToggled`
Fired when a player enables/disables a RECON detection layer.

| Field | Type | Description |
|---|---|---|
| `layerId` | string | e.g. `"infantry"`, `"ground_vehicles"` |
| `layerName` | string | Human-readable layer name |
| `visible` | bool | New state |
| `coalition` | number | |
| `player` | string | |
| `timestamp` | number | |

**Publisher**: `CTLDReconManager:toggleReconLayer()`

---

#### `OnReconAutoRefreshEnabled` / `OnReconAutoRefreshDisabled`

| Field | Type | Description |
|---|---|---|
| `player` | string | |
| `playerUnit` | Unit | |
| `coalition` | number | |
| `previousState` | bool | |
| `newState` | bool | |
| `targetsCount` | number | Current target count |
| `refreshInterval` | number | Seconds between refreshes |
| `timestamp` | number | |

**Publishers**: `CTLDReconManager:enableAutoRefresh()`, `:disableAutoRefresh()`

---

### FOB Events (2)

#### `OnFOBDeployed`
Fired when a FOB is fully assembled and deployed.

| Field | Type | Description |
|---|---|---|
| `fob.fobId` | string | |
| `fob.name` | string | |
| `fob.coalitionId` | number | |
| `cratesUsed` | table | Array of crates consumed |
| `totalCratesUsed` | number | |
| `position` | vec3 | |
| `sceneObjects` | table | DCS StaticObjects spawned |
| `logisticZone` | table | Created LGZ `{ name, radius, type="static" }` |
| `player` | string | Player unit name who triggered deployment |
| `timestamp` | number | |

**Publisher**: `CTLDFOBManager:deployFOBCrates()` (after full build)

---

#### `OnFOBDestroyed`
Fired when a FOB's integrity drops below the destruction threshold.

| Field | Type | Description |
|---|---|---|
| `fob.fobId` | string | |
| `fob.name` | string | |
| `fob.coalitionId` | number | |
| `position` | vec3 | |
| `destruction.killerUnit` | Unit or nil | |
| `destruction.killerCoalition` | number or nil | |
| `destruction.objectsDestroyed` | number | |
| `destruction.objectsTotal` | number | |
| `destruction.destructionThreshold` | number | Config `fobDestructionThreshold` (default 0.5) |
| `destruction.integrityPercent` | number | 0.0–1.0 at time of event |
| `logisticZone` | table | `{ name, wasActive=true }` |
| `durationAlive` | number | Seconds from deployment to destruction |
| `timestamp` | number | |

**Publisher**: `CTLDFOBManager:onDead()` (S_EVENT_DEAD handler)

---

### AA System Events (3)

#### `OnAASystemDeployed`
Fired when an AA system is fully assembled.

| Field | Type | Description |
|---|---|---|
| `systemName` | string | `"HAWK"`, `"PATRIOT"`, etc. |
| `groupName` | string | DCS group name |
| `heli` | Unit or nil | `nil` if AI-deployed |
| `coalition` | number | |
| `position` | vec3 | |
| `timestamp` | number | |

**Publisher**: `CTLDCrateAssemblyManager:tryUnpackOrRepair()` (full assembly path)

---

#### `OnAASystemRearmed`
Fired when a launcher is added to an existing AA system.

| Field | Type | Description |
|---|---|---|
| `systemName` | string | |
| `groupName` | string | |
| `heli` | Unit | |
| `coalition` | number | |
| `timestamp` | number | |

**Publisher**: `CTLDCrateAssemblyManager:tryUnpackOrRepair()` (rearm path)

---

#### `OnAASystemRepaired`
Fired when a full AA system is repaired and re-spawned.

Same fields as `OnAASystemRearmed`.

**Publisher**: `CTLDCrateAssemblyManager:tryUnpackOrRepair()` (repair path)

---

### Zone Events (2)

#### `OnZoneSmokeRefreshed`
Fired on each smoke refresh timer cycle.

| Field | Type | Description |
|---|---|---|
| `troopZones` | table | Array of troop zone payload tables |
| `logisticZones` | table | Array of logistic zone payload tables |
| `timestamp` | number | |
| `refreshInterval` | number | Seconds |

**Publisher**: `CTLDZoneManager:_refreshSmoke()` (periodic timer)

---

#### `OnLogisticZoneUpdated`
Fired when dynamic zone units are added or removed.

| Field | Type | Description |
|---|---|---|
| `zones` | table | All zones after update |
| `unitsAdded` | table | Newly registered units |
| `unitsRemoved` | table | Units that left the zone |
| `timestamp` | number | |

**Publisher**: `CTLDZoneManager:updateDynamicZones()`

---

## DCS Engine Events Handled

| DCS Event | Manager | Method | Purpose |
|---|---|---|---|
| `S_EVENT_PLAYER_ENTER_UNIT` | CTLDPlayerTracker | `onPlayerEnterUnit()` | Player enters transport |
| `S_EVENT_PLAYER_LEAVE_UNIT` | CTLDPlayerTracker | `onPlayerLeaveUnit()` | Player leaves transport |
| `S_EVENT_BIRTH` | CTLDCoreManager | `onBirth()` | Late-activation detection |
| `S_EVENT_BIRTH` | CTLDCrateManager | `onBirth()` | Register MM crates |
| `S_EVENT_BIRTH` | CTLDJTACManager | `onBirth()` | Activate JTAC late-activation |
| `S_EVENT_BIRTH` | CTLDVehicleSpawner | `onBirth()` | Register MM vehicles |
| `S_EVENT_LAND` | CTLDPlayerManager | `onLand()` | Player lands → menu rebuild |
| `S_EVENT_TAKEOFF` | CTLDPlayerManager | `onTakeoff()` | Player takes off → menu rebuild |
| `S_EVENT_LAND` | CTLDCoreManager | `onAILand()` | AI transport lands → auto pickup/drop |
| `S_EVENT_DEAD` | CTLDTroopManager | `onUnitDead()` / `onTransportDead()` | Troop group or carrier destroyed |
| `S_EVENT_DEAD` | CTLDVehicleSpawner | `onDead()` | Tracked vehicle destroyed |
| `S_EVENT_DEAD` | CTLDCrateManager | `onCrateDead()` | Crate static destroyed in combat |
| `S_EVENT_DEAD` | CTLDFOBManager | `onDead()` | FOB scene object destroyed |
| `S_EVENT_DEAD` | CTLDZoneManager | `onDead()` | Mobile unit leaves logistic zone |

---

## Summary

| Domain | Count |
|---|---|
| Beacon | 5 |
| Crate | 10 |
| Vehicle | 8 |
| Troop | 2 |
| JTAC | 9 |
| RECON | 7 |
| FOB | 2 |
| AA System | 3 |
| Zone | 2 |
| **Total** | **48** |

Events with known subscribers (internal menu refresh): ~10.
Events with no subscribers (available for mission-maker external use): ~38.
