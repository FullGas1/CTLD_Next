# CTLD v2 — API Reference

Quick-reference for mission makers and external scripts. Only the **public** surface is listed — internal helpers (prefixed `_`) are not stable API.

All managers are singletons. Always call `Manager.getInstance()` before any instance method.

---

## Table of Contents

- [EventDispatcher](#eventdispatcher)
- [CTLDTroopManager](#ctldtroopmanager)
- [CTLDZoneManager](#ctldzonemanager)
- [CTLDCrateManager](#ctldcratemanager)
- [CTLDVehicleSpawner](#ctldvehiclespawner)
- [CTLDFOBManager](#ctldfobmanager)
- [CTLDBeaconManager](#ctldbeaconmanager)
- [CTLDJTACManager](#ctldjtacmanager)
- [CTLDReconManager](#ctldreconmanager)
- [CTLDSceneManager](#ctldscenemanager)
- [CTLDCrateAssemblyManager](#ctldcrateassemblymanager)
- [mineFieldScene](#minefieldsceene)
- [Legacy wrappers (ctld.*)](#legacy-wrappers-ctld)

---

## EventDispatcher

*Internal publish/subscribe bus used by all managers. External scripts may subscribe to any CTLD event.*

| Method | Signature | Description |
|--------|-----------|-------------|
| `getInstance` | `() → EventDispatcher` | Returns singleton |
| `subscribe` | `(eventName, callback)` | Register a handler for the named event. Multiple handlers per event are supported. |
| `unsubscribe` | `(eventName, callback)` | Remove a specific handler. |
| `unsubscribeAll` | `(eventName)` | Remove all handlers for one event. |
| `publish` | `(eventName, payload)` | Fire all handlers for `eventName` with `payload`. Errors in handlers are logged and swallowed. *(Used internally by managers — external callers should not publish CTLD events.)* |

**Usage:**

```lua
EventDispatcher.getInstance():subscribe("OnTroopsDeployed", function(evt)
    -- evt.groupName, evt.deployedBy, evt.position, evt.trigger
    trigger.action.outText("Troops at " .. tostring(evt.position), 10)
end)
```

Full event catalogue: [`docs/specs/CTLD_Events.md`](specs/CTLD_Events.md)

---

## CTLDTroopManager

*Manages infantry boarding, deployment, field extraction, and AI troop scripting.*

| Method | Signature | Description |
|--------|-----------|-------------|
| `getInstance` | `() → CTLDTroopManager` | Returns singleton |
| `spawnGroupAtTrigger` | `(side, count, triggerName, radius)` | Spawn an extractable infantry group at a trigger zone. `side`: `"blue"` / `"red"`. Returns group name. |
| `spawnGroupAtPoint` | `(side, count, point, radius)` | Spawn an extractable group at an arbitrary DCS point `{x,y,z}`. |
| `preLoadTransport` | `(unitName, count)` | Pre-fill an AI transport with troops (call before mission start or at runtime). |
| `loadTransport` | `(unitName)` | Force-load an AI transport with troops from its nearest pickup zone. |
| `unloadTransport` | `(unitName)` | Force-unload troops from an AI transport at its current position. |
| `unloadInProximityToEnemy` | `(unitName, distance)` | Continuous trigger: auto-unload AI troops if an enemy is within `distance` metres. |
| `createLoadableGroup` | `(config)` | Add a new troop template at runtime. `config` has same fields as `loadableGroups` entries. Returns template name. |
| `editLoadableGroup` | `(name, config)` | Replace fields in an existing template (merge). |
| `removeLoadableGroup` | `(name)` | Remove a template entirely. |
| `disableLoadableGroup` | `(name)` | Hide a template from F10 menus (still registered). |
| `enableLoadableGroup` | `(name)` | Re-show a disabled template. |
| `startGroupCountWatcher` | `(zoneName, blueFlag, redFlag)` | Continuous trigger: write the count of deployed groups inside `zoneName` into `blueFlag`/`redFlag`. |
| `startUnitCountWatcher` | `(zoneName, blueFlag, redFlag)` | Same, counting individual soldiers. |

---

## CTLDZoneManager

*Manages all zone types: TRZ pickup/extract, AIZ, WPZ, LGZ logistic zones.*

| Method | Signature | Description |
|--------|-----------|-------------|
| `getInstance` | `() → CTLDZoneManager` | Returns singleton |
| `setTroopZoneActive` | `(zoneName, active)` | Activate (`true`) or deactivate (`false`) a TRZ pickup zone. Fires `OnLogisticZoneUpdated`. |
| `changeRemainingGroups` | `(zoneName, amount)` | Add or subtract from a TRZ zone's remaining group count. `amount` may be negative. |
| `activateWaypointZone` | `(zoneName)` | Enable a WPZ so newly deployed troops march toward it. |
| `deactivateWaypointZone` | `(zoneName)` | Disable a WPZ. |
| `createExtractZone` | `(zoneName, flagNumber, smoke)` | Register a DCS trigger zone as an extract zone. `smoke`: `0`=Green … `4`=Blue, `-1`=none. |
| `removeExtractZone` | `(zoneName, flagNumber)` | Unregister an extract zone. |
| `activateLogisticZone` | `(name)` | Re-enable a suspended LGZ. Fires `OnLogisticZoneUpdated`. |
| `deactivateLogisticZone` | `(name)` | Suspend a LGZ — players inside can no longer spawn crates. Fires `OnLogisticZoneUpdated`. |
| `registerFOBAsLogistic` | `(fobName, point, radius, coalitionId)` | Register a FOB as a logistic zone (called automatically by FOBManager on FOB build). |
| `unregisterLogistic` | `(name)` | Remove a logistic zone by name (called automatically on FOB destruction). |

**Shortcuts (legacy wrappers — prefer the methods above):**

```lua
ctld.activatePickupZone("pickzone1")           -- → setTroopZoneActive("pickzone1", true)
ctld.deactivatePickupZone("pickzone1")         -- → setTroopZoneActive("pickzone1", false)
ctld.changeRemainingGroupsForPickupZone(z, n)  -- → changeRemainingGroups(z, n)
ctld.activateWaypointZone("wp1")               -- → activateWaypointZone("wp1")
ctld.createExtractZone(z, flag, smoke)         -- → createExtractZone(z, flag, smoke)
```

---

## CTLDCrateManager

*Manages the full crate lifecycle: spawn, hover-load, drop, unpack, assembly, pack-equipt.*

| Method | Signature | Description |
|--------|-----------|-------------|
| `getInstance` | `() → CTLDCrateManager` | Returns singleton |
| `spawnCrateAtZone` | `(side, weight, zoneName)` | Spawn a crate at a named trigger zone. `side`: `"blue"` / `"red"`. `weight` must match a `spawnableCrates` entry. |
| `spawnCrateAtPoint` | `(side, weight, point, hdg)` | Spawn a crate at an arbitrary DCS point. `hdg` (optional): heading in radians. |
| `getCrateByName` | `(crateName)` | Return the `CTLDCrate` instance for a DCS static name, or `nil`. |
| `getCratesInRange` | `(position, radius)` | Return all `CTLDCrate` instances within `radius` metres of `position`. |
| `startCrateCountWatcher` | `(zoneName, flagNumber)` | Continuous trigger: update `flagNumber` with the count of CTLD crates inside `zoneName` every 5 s. |
| `findDescriptorByWeight` | `(weight)` | Return the crate descriptor for a given weight key, or `nil`. |
| `findDescriptorByUnitType` | `(typeName)` | Return the first descriptor whose `unit` field matches `typeName`. |
| `getJTACDescriptors` | `(coalitionId)` | Return all singleCrate descriptors with `isJTAC=true` for the given coalition. |

---

## CTLDVehicleSpawner

*Manages whole-vehicle transport: request, load, unload, parachute, pack.*

| Method | Signature | Description |
|--------|-----------|-------------|
| `getInstance` | `() → CTLDVehicleSpawner` | Returns singleton |
| `findPackableVehicles` | `(transport)` | Return list of `CTLDVehicle` objects in WAITING state near `transport`. |
| `packVehicle` | `(transportUnitName, packableUnitName, playerObj)` | Destroy a waiting vehicle and spawn its crates near the transport. Fires `OnVehiclePacked`. |
| `findLoadableVehicles` | `(transport)` | Return vehicle types eligible for boarding onto `transport` at its current position. |
| `findLoadedVehicles` | `(transport)` | Return `CTLDVehicle` objects currently loaded on `transport`. |
| `getLoadedVehicleWeight` | `(transportUnitName)` | Return total weight (kg) of vehicles loaded on the transport. |
| `scanMMVehicles` | `()` | Re-scan coalition ground groups for mission-editor-placed vehicles (called at init; safe to re-call). |

---

## CTLDFOBManager

*Manages FOB construction and lifecycle (creation, logistic zone, destruction threshold).*

| Method | Signature | Description |
|--------|-----------|-------------|
| `getInstance` | `() → CTLDFOBManager` | Returns singleton |
| `getFOBsForCoalition` | `(coalitionId)` | Return array of active FOB data tables for the given coalition. |
| `isInFOBTroopZone` | `(point, coalitionId)` | Return `true` if `point` falls inside any active FOB troop-pickup radius. |
| `checkSpatialGuards` | `(position, coalitionId)` | Return `true` if `position` passes all distance guards for a new FOB (min distance from existing zones). |

---

## CTLDBeaconManager

*Manages radio beacons: VHF/UHF/FM broadcast, battery timer, F10 map layer.*

| Method | Signature | Description |
|--------|-----------|-------------|
| `getInstance` | `() → CTLDBeaconManager` | Returns singleton |
| `createAtZone` | `(zoneName, coalitionStr, batteryLife, name)` | Spawn a beacon at a named trigger zone. `coalitionStr`: `"blue"` / `"red"`. `batteryLife`: minutes. `name` (optional): label shown in F10 list. |
| `getBeaconsForCoalition` | `(coalitionId)` | Return array of active beacon data tables for a coalition. |
| `getBeacon` | `(beaconName)` | Return beacon data table by internal name, or `nil`. |

---

## CTLDJTACManager

*Manages JTAC auto-lase, spot corrections, orbit, smoke, 9-line, multi-JTAC deconfliction.*

| Method | Signature | Description |
|--------|-----------|-------------|
| `getInstance` | `() → CTLDJTACManager` | Returns singleton |
| `autoLase` | `(groupName, laserCode, smoke, lock, colour, radio, orbitParams)` | Activate auto-lase for a pre-placed ME JTAC group. All params after `groupName` are optional. `laserCode`: 1111–1788. `smoke`: `true`/`false`. `lock`: `"vehicle"` / `"troop"` / `"all"`. `colour`: 0–4. `radio`: `{freq, mod, name}` SRS table. |
| `startLase` | `(groupName, laserCode, smoke, lock, colour, radio, orbitParams)` | Same as `autoLase` (v2 preferred name). |
| `stopAutoLase` | `(groupName)` | Stop auto-lase and deregister the JTAC. |
| `getJTACByName` | `(groupName)` | Return the `CTLDJTAC` instance for a group name, or `nil`. |
| `killJTAC` | `(groupName, killer)` | Force-destroy a JTAC unit and clean up all state. |
| `resumeJTAC` | `(groupName)` | Resume a JTAC that was paused (standby mode). |
| `requestSmoke` | `(groupName)` | Fire a smoke on the JTAC's current target (if lasing). |
| `registerMMJTAC` | `(group)` | Manually register an ME group as a JTAC (called automatically at init). |

---

## CTLDReconManager

*Manages the RECON scan layer: LOS detection, F10 map markers, auto-refresh.*

| Method | Signature | Description |
|--------|-----------|-------------|
| `getInstance` | `() → CTLDReconManager` | Returns singleton |
| `scan` | `(playerUnit, player)` | Trigger an immediate scan for `playerUnit`. Adds detected enemies to the player's RECON layer. |
| `stopScan` | `(playerUnit, player)` | Stop auto-refresh for `player` and clear their RECON markers. |
| `enableAutoRefresh` | `(playerUnit, player)` | Start periodic re-scan for `player` (interval: `reconRefreshInterval`). |
| `disableAutoRefresh` | `(playerUnit, player)` | Stop periodic re-scan. |
| `toggleLayer` | `(player, playerUnit, layerId)` | Show or hide a named RECON layer on the F10 map. |
| `getActiveScan` | `(player)` | Return the current scan state table for `player`, or `nil`. |
| `getPlayerLayers` | `(player)` | Return the map layer table for `player`. |

---

## CTLDSceneManager

*Executes time-sequenced deployments of DCS statics and groups (FARPs, FOB, minefield…)*

| Method | Signature | Description |
|--------|-----------|-------------|
| `getInstance` | `() → CTLDSceneManager` | Returns singleton |
| `registerSceneModel` | `(model)` | Register a scene model table. `model.name` must be unique. Call this from your mission script after CTLD loads. |
| `playScene` | `(unit, modelName, params, onComplete)` | Execute a scene relative to `unit`'s current position and heading. `params` (optional): extra data passed to step `func` callbacks via `ctx.scene._params`. `onComplete` (optional): callback `function()` fired after the last step. |
| `playSceneAtPos` | `(modelName, pos, coalitionId, countryId, params)` | Execute a scene at an arbitrary DCS point. |
| `getModel` | `(name)` | Return the registered model table for `name`, or `nil`. |
| `getScene` | `(name)` | Return the active `CTLDScene` instance for `name`, or `nil`. |
| `findNearbyRepackableScenes` | `(pos, radius)` | Return array of active `CTLDScene` objects within `radius` metres of `pos` that have an `onRepack` hook. |
| `packScene` | `(scene)` | Execute the repack sequence: call `onRepack`, destroy all spawned objects, spawn crates. |

**Scene model fields:**

```lua
local myScene = {
    name          = "My FARP",         -- unique name, also used as crate `unit` field
    fobCompatible = false,             -- set true to allow as a FOB scene
    onRepack      = function(scene, repackData) ... end,  -- optional: enables Pack Equipt
    steps = {
        -- Polar step: fixed offset from helicopter
        { objectsDescDbKey = "FARP_Tent",
          polar = { distance = 80, angle = 10 },
          relativeHeadingInDegrees = 90,
          relativeAltitudeInMeters = 0,
          delayAfterPreviousStep   = 2 },

        -- Func-only step: no spawn, just callback
        { delayAfterPreviousStep = 0,
          func = function(ctx) trigger.action.outText("Done", 5) end },
    }
}
CTLDSceneManager.getInstance():registerSceneModel(myScene)
```

---

## CTLDCrateAssemblyManager

*Manages multi-part AA system assembly from crate descriptors.*

| Method / Field | Signature | Description |
|----------------|-----------|-------------|
| `TEMPLATES` | static table | Declare all AA system templates here **before** CTLD init. Each entry: `{ name, side, sectionName, parts=[{DCSTypename, desc, weight, launcher?, amount?, NoCrate?}], repair={desc,weight} }`. |
| `getInstance` | `() → CTLDCrateAssemblyManager` | Returns singleton |
| `injectAACrates` | `(spawnableCrates)` | Static method. Populate `spawnableCrates` from `TEMPLATES`. Called automatically at init — only call manually if you add templates after init. |
| `getTemplateByName` | `(name)` | Return the template table for `name`, or `nil`. |
| `getTemplateForUnit` | `(unitName, repairFor)` | Return the template that contains `unitName` as a component, or `nil`. |
| `spawnSystemAt` | `(templateName, point, coa, countryId)` | Spawn a complete AA system at an arbitrary point (bypasses the crate requirement — useful for scripted pre-placed systems). |
| `countComplete` | `(coalitionId)` | Return the number of complete AA systems currently active for a coalition. |
| `getAllowedCount` | `(coalitionId)` | Return the configured AA system limit for a coalition (`AASystemLimitBLUE/RED`). |

---

## mineFieldScene

*Module (not a singleton) — call functions directly. Lays and clears landmine grids.*

| Function | Signature | Description |
|----------|-----------|-------------|
| `setLandMine` | `(unitObj, distFromUnit, nbCols, nbPerCol, colSpacing, rowSpacing) → bool, result` | Deploy a quinconce landmine grid in front of `unitObj`. All distances in metres. Returns `true, {mines}` on success, `false, errorString` on failure. |
| `setLandMineAuto` | `(unitObj, distFromUnit, widthM, lengthM, nbMines) → bool, result` | Parametric variant: compute grid layout automatically from area dimensions and mine count, then delegate to `setLandMine`. |
| `clearSet` | `(idx)` | Destroy all mines in set `idx` (index into `mineFieldScene._sets`) and erase its F10 marker. |

**Usage:**

```lua
-- Deploy ~40 mines in a 50 m wide × 80 m long field starting 30 m ahead
local ok, result = mineFieldScene.setLandMineAuto(
    Unit.getByName("my_helo"), 30, 50, 80, 40)
if not ok then env.error("Minefield error: " .. result) end

-- Clear the first set later
mineFieldScene.clearSet(1)
```

---

## Legacy wrappers (ctld.*)

All 22 v1 global functions are preserved in `src/legacy/legacy_api.lua` as thin wrappers. Existing missions continue to work unchanged. Each wrapper logs a deprecation warning.

| v1 call | v2 equivalent |
|---------|--------------|
| `ctld.spawnGroupAtTrigger(side, n, zone, r)` | `CTLDTroopManager.getInstance():spawnGroupAtTrigger(side, n, zone, r)` |
| `ctld.spawnGroupAtPoint(side, n, pt, r)` | `CTLDTroopManager.getInstance():spawnGroupAtPoint(side, n, pt, r)` |
| `ctld.preLoadTransport(unit, n)` | `CTLDTroopManager.getInstance():preLoadTransport(unit, n)` |
| `ctld.loadTransport(unit)` | `CTLDTroopManager.getInstance():loadTransport(unit)` |
| `ctld.unloadTransport(unit)` | `CTLDTroopManager.getInstance():unloadTransport(unit)` |
| `ctld.unloadInProximityToEnemy(unit, dist)` | `CTLDTroopManager.getInstance():unloadInProximityToEnemy(unit, dist)` |
| `ctld.activatePickupZone(zone)` | `CTLDZoneManager.getInstance():setTroopZoneActive(zone, true)` |
| `ctld.deactivatePickupZone(zone)` | `CTLDZoneManager.getInstance():setTroopZoneActive(zone, false)` |
| `ctld.changeRemainingGroupsForPickupZone(z, n)` | `CTLDZoneManager.getInstance():changeRemainingGroups(z, n)` |
| `ctld.activateWaypointZone(zone)` | `CTLDZoneManager.getInstance():activateWaypointZone(zone)` |
| `ctld.deactivateWaypointZone(zone)` | `CTLDZoneManager.getInstance():deactivateWaypointZone(zone)` |
| `ctld.createExtractZone(zone, flag, smoke)` | `CTLDZoneManager.getInstance():createExtractZone(zone, flag, smoke)` |
| `ctld.removeExtractZone(zone, flag)` | `CTLDZoneManager.getInstance():removeExtractZone(zone, flag)` |
| `ctld.countDroppedGroupsInZone(zone, bf, rf)` | `CTLDTroopManager.getInstance():startGroupCountWatcher(zone, bf, rf)` |
| `ctld.countDroppedUnitsInZone(zone, bf, rf)` | `CTLDTroopManager.getInstance():startUnitCountWatcher(zone, bf, rf)` |
| `ctld.cratesInZone(zone, flag)` | `CTLDCrateManager.getInstance():startCrateCountWatcher(zone, flag)` |
| `ctld.spawnCrateAtZone(side, w, zone)` | `CTLDCrateManager.getInstance():spawnCrateAtZone(side, w, zone)` |
| `ctld.spawnCrateAtPoint(side, w, pt)` | `CTLDCrateManager.getInstance():spawnCrateAtPoint(side, w, pt)` |
| `ctld.createRadioBeaconAtZone(zone, side, life, name)` | `CTLDBeaconManager.getInstance():createAtZone(zone, side, life, name)` |
| `ctld.JTACAutoLase(group, code, smoke, lock, col, radio)` | `CTLDJTACManager.getInstance():autoLase(group, code, smoke, lock, col, radio)` |
| `ctld.JTACStart(unit, code, smoke)` | `CTLDJTACManager.getInstance():startLase(unit, code, smoke)` |
| `ctld.JTACAutoLaseStop(group)` | `CTLDJTACManager.getInstance():stopAutoLase(group)` |
| `ctld.addCallback(fn)` | `EventDispatcher.getInstance():subscribe("OnEventName", fn)` |
