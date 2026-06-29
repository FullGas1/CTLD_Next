# CTLD v2 — Developer Guide

## 1. Repository structure

```
src/              Source modules (OOP, one class per file)
  lib/            Shared micro-libraries (class.lua, objectRegistry, parachute)
  scenes/         Scene data files (auto-registered at load time)
  compat/         Legacy v1 API wrappers (thin delegates, deprecated)
source/           Reference — original monolithic v1 CTLD.lua (read-only)
tools/
  merger/      Build tooling: merge src/ → CTLD_Next.lua
  CTLD_loader.lua Dev loader for Witchcraft (live DCS injection)
tests/            busted unit tests (no DCS required)
  helpers/        DCS stubs + module loader
  specs/          *_spec.lua test files
live_tests/          Witchcraft integration tests (requires live DCS mission)
docs/             This guide + missionmaker_guide.md + specs/
assets/           Audio files (beacon.ogg)
missions/         Demo and test .miz files
```

---

## 2. Architecture overview

CTLD v2 uses a **singleton manager** pattern: one manager per domain, each
accessed via `Manager.getInstance()`. Managers communicate exclusively through
the internal event bus `EventDispatcher`.

```
CTLDCoreManager          ← orchestrator, owns init sequence
CTLDPlayerManager        ← tracks connected players, owns F10 menu
CTLDZoneManager          ← pickup / extract / waypoint zones
CTLDTroopManager         ← troops boarding / deploying / extracting
CTLDCrateManager         ← crate spawn / load / unload / assembly
CTLDVehicleSpawner       ← vehicle request / pack
CTLDFOBManager           ← FOB construction pipeline
CTLDBeaconManager        ← radio beacons
CTLDJTACManager          ← JTAC auto-lase / orbit
CTLDReconManager         ← recon layer + F10 map marks
CTLDCrateAssemblyManager ← AA system assembly
CTLDSceneManager         ← scene engine (FARP, FOB, minefield…)
CTLDDCSEventBridge       ← single DCS event handler, routes to managers
CTLDPlayerTracker        ← player connect/disconnect tracking (no MIST)
```

Configuration is read-only via `ctld.gs("paramName")` — never call
`config:getSetting()` directly.

**Public API quick-reference** for all managers: [`docs/api-reference.md`](api-reference.md)

> **Troop + JTAC lifecycle state machine** — complete diagram with all states, transitions, and JTAC instance management:
> [docs/assets/troops_jtac_lifecycle.svg](assets/troops_jtac_lifecycle.svg)

### CTLDCoreManager init sequence

`CTLDCoreManager:init()` runs once at mission start and executes these phases in order:

| Phase | Method | Description |
| --- | --- | --- |
| INIT-B | `_initMMCrates()` | Scan coalition statics for MM-placed cargo objects |
| INIT-C | `_initMMJTACs()` | Scan coalition groups for MM-placed JTAC groups |
| INIT-D | `CTLDVehicleSpawner:scanMMVehicles()` | Scan coalition ground groups for MM-placed vehicles |
| INIT-E | `_initExtractableGroups()` | Register `extractableGroups` names into `CTLDTroopManager._droppedGroups` |
| INIT-A | `_initAITransports()` | Build AI team lists and start the auto-pickup/dropoff loop |

**INIT-E detail:** reads `ctld.gs("extractableGroups")`, calls `Group.getByName()` for each entry, inserts the group name into `CTLDTroopManager._droppedGroups[coalition]`. Groups not found are logged as WARN and skipped. No late-activation (iso-legacy). No `_droppedTemplates` entry — `embarkFromField` uses 130 kg/unit fallback.

---

## 3. Adding a new module

1. Create `src/CTLD_mymodule.lua` using the class pattern:

```lua
local CTLDMyManager = createClass("CTLDMyManager")
CTLDMyManager._instance = nil

function CTLDMyManager.getInstance()
    if not CTLDMyManager._instance then
        CTLDMyManager._instance = CTLDMyManager:new()
        CTLDMyManager._instance:init()
    end
    return CTLDMyManager._instance
end

function CTLDMyManager:init()
    -- setup
end
```

2. Add the filename to `tools/build/listToMerge.txt` in dependency order.
3. Add a `dofile(SRC .. "CTLD_mymodule.lua")` line in `tools/CTLD_loader.lua`
   at the same position.
4. Update `tests/helpers/loader.lua` with the same `dofile` line.
5. Write busted specs in `tests/specs/mymodule_spec.lua`.

---

## 4. Events

Publish:
```lua
EventDispatcher.getInstance():publish("OnMySomethingHappened", {
    unitName = "...",
    coalition = coalition.side.BLUE,
})
```

Subscribe (from another manager or external script):
```lua
EventDispatcher.getInstance():subscribe("OnMySomethingHappened", function(evt)
    -- evt.unitName, evt.coalition
end)
```

Full event catalogue: `docs/specs/CTLD_Events.md`

---

## 5. Scene engine

`CTLDSceneManager` executes time-sequenced deployments of DCS statics and ground groups. It is the backend for all FARP, FOB, and minefield operations.

### 5.1 Internal data model

```
CTLDScene (one per active deployment)
  ├── _model    : scene model table (steps, name, fobCompatible, onRepack…)
  ├── _params   : runtime context { unit, coalition, farpName, repackData, … }
  ├── _spawnedObjects : [{ obj=DCSStatic, category=… }, …]  (all objects spawned so far)
  └── _stepIndex : current step pointer

CTLDSceneManager (singleton)
  ├── _active[sceneName] : CTLDScene instances currently deployed
  └── _models[sceneName] : registered model tables
```

`CTLDSceneManager._active` is reset on every CTLD re-injection (Witchcraft dev cycle). Scene instances only survive a full mission restart.

### 5.2 Step execution

The step machine runs via `timer.scheduleFunction`. Each step:

1. Resolves position from `polar` or `axis` fields relative to the **snapshot** heading/position captured at unpack time.
2. Spawns the DCS object via `coalition.addStaticObject` (for statics) or `coalition.addGroup`.
3. Stores the spawned reference in `_spawnedObjects`.
4. Calls the optional `func(ctx)` callback where `ctx = { unit, scene, step, spawnedObj }`.
5. Schedules the next step after `step.delayAfterPreviousStep` seconds.

### 5.3 FARP Repack flow

```
Player selects "Pack Equipt → Pack [FARP]"
  └── CTLDCrateManager:refreshPackEquiptSection()
        └── CTLDSceneManager:findNearbyRepackableScenes(pos, 300)
              └── returns scenes where _model.onRepack ~= nil
        └── per scene: CTLDSceneManager:packScene(scene, transport, playerObj)
              1. scene._model.onRepack(scene, repackData)    ← snapshot warehouse
              2. scene:destroy()                              ← remove all spawnedObjects
              3. CTLDCrateManager:spawnCratesForScene(desc, pos)
                    └── crate.metadata.repackData = repackData
              4. CTLDSceneManager._active[name] = nil

On crate unpack at new site:
  └── CTLDCrateManager:_spawnUnpacked()
        └── desc.unit matches a scene name → CTLDSceneManager:executeScene(model, unit, params)
              └── params.repackData = crate.metadata.repackData  (carried from crate)
              └── warehouse step reads ctx.scene._params.repackData to restore fuel
```

### 5.4 Adding a new scene (dev checklist)

1. Create `src/scenes/CTLD_myScene.lua` — model table + `CTLDSceneManager.getInstance():registerSceneModel(myScene)` at the bottom.
2. Add the file to `tools/build/listToMerge.txt` and `tools/CTLD_loader.lua`.
3. Declare a crate in `CTLD_userConfig.lua` with `unit = "My Scene Name"`.
4. If the scene deploys a DCS Invisible FARP: add a func-only step at the end to call `w:setLiquidAmount(type, qty)` using `getLiquidAmount` (not `getLiquid`).
5. If repack support is needed: implement `myScene.onRepack(scene, repackData)` reading `w:getLiquidAmount(type)`.
6. Add `fobCompatible = true` if the scene should also be spawnable as a FOB.

See `src/scenes/CTLD_countrysideFarpScene.lua` for a complete reference implementation.

---

## 6. Crate spawn pipeline

All crate unpack outcomes (ground vehicle, air JTAC, future static) go through a single three-step pipeline in `CTLDCrateManager`:

```
_spawnUnpacked(desc, pos, coa, cId, playerName)
  ├── desc.isJTAC → CTLDJTACManager:_consumeJTACSlot(coa)   ← quota gate (definitive)
  │     └── limit reached → notify player + return (no spawn)
  ├── ctld.utils.buildGroupUnitDef(desc, pos, gname, gid, uid)
  │     ├── spawnAs == "GROUND"   → minimal {name, task, units[{x,y,heading}]}
  │     └── spawnAs == "AIRPLANE" → full {groupId, units[{alt,speed}], route[orbit+EPLRS]}
  │           (orbit + EPLRS embedded only when isJTAC = true)
  ├── ctld.utils.spawnFromDescriptor(desc, countryId, unitDef)
  │     ├── spawnAs == "STATIC"   → coalition.addStaticObject
  │     └── otherwise             → coalition.addGroup(Group.Category[spawnAs])
  └── _dispatchPostSpawn(desc, gname)
        └── isJTAC = true → CTLDJTACManager:startLase(gname)
```

**Key rules:**
- `coalition.addGroup` and `coalition.addStaticObject` must only be called via `ctld.utils.spawnFromDescriptor` — never directly.
- `ctld.utils.buildGroupUnitDef` is the single builder for GROUND and AIR unitDefs. STATIC objects have a separate schema and go directly to `addStaticObject`.
- Post-spawn role activation belongs exclusively in `_dispatchPostSpawn`. Do not add role logic elsewhere in the unpack path.
- `CTLDJTACManager:deployAirJTAC` (legacy/script entry point) also routes through `buildGroupUnitDef` + `spawnFromDescriptor`.
- JTAC quota (`JTAC_LIMIT_RED/BLUE`) is consumed **before** spawn in `_spawnUnpacked` (crate path) and in `spawnJTACFromDescriptor` (Request Equipment path). The quota is definitive — it is never refilled when a JTAC is killed. MM JTACs and infantry JTAC soldiers do not consume the quota.

**Crate descriptor fields driving the pipeline:**

| Field | Effect on pipeline |
|---|---|
| `spawnAs` (string, default `"GROUND"`) | Selects `addGroup` category or `addStaticObject` |
| `isJTAC` (boolean) | **Source of truth for JTAC role.** Adds orbit route to air unitDef; triggers `startLase` post-spawn. The unit type name (`unit`) is NOT used for JTAC detection anywhere in the OOP stack. |
| `specificParams` (table, air only) | Orbit tuning passed to `startLase` / `deployAirJTAC`: `speed`, `alti`, `orbitRadiusNoLase`, `orbitRadiusOnLase` |
| `cratesRequired` (number) | Guards unpack — must be met before pipeline runs |
| `showSets` (boolean, default `true`) | When `false`, suppresses the auto-generated "All crates" singleTypeSet menu entry for this crate even if `enableAllCrates = true` |

**JTAC detection rules (summary — do not invert):**

| Context | Rule |
|---|---|
| Request Equipment menu population | `CTLDCrateManager:getJTACDescriptors(coalition)` — iterates `_processedCrates`, returns all singleCrate entries with `isJTAC=true` for the player's coalition (or side=nil). No separate type list. |
| Request Equipment spawn | `CTLDVehicleSpawner:spawnJTACFromDescriptor(desc, spawner, zone)` — quota check → ground: `spawnVehicleForTransport`+`startLase`; air: `deployAirJTAC` |
| Post-unpack activation | `_dispatchPostSpawn`: `if desc.isJTAC → CTLDJTACManager:startLase()` |
| Pre-placed MM group detection | Group name contains `"jtac"` (case-insensitive) — unit type not used |
| Troop deploy with JTAC soldier | `tmpl.hasJtac == true` (computed from `jtac > 0` in template) → `startLase` after deploy |

> **Do not add new JTAC detection paths.** If a new unit type needs JTAC behaviour, add `isJTAC=true` to its crate descriptor — never add it to a type-name list.
> **Do not add a separate type list.** `JTAC_unitTypeNames` has been removed — the crate catalogue is the single source of truth for both the crate menu and the Request Equipment menu.

---

### spawnableCrates internal processing

`CTLDCrateManager:_processSpawnableCrates()` runs once at `getInstance()` time and transforms the raw `spawnableCrates` config into an internal structure used by the menu builder and all descriptor lookups.

**Three-pass algorithm:**

1. **Pass 1 — separation:** iterates `ipairs(category)` and routes each entry into `singleCrates` (has `weight` field) or `mixedSets` (has `mixedSet` field). Entries with neither are logged and skipped.
2. **Pass 2 — singleTypeSet generation:** for each singleCrate with `cratesRequired > 1`, when `enableAllCrates = true` and `sc.showSets ~= false`, creates a virtual `singleTypeSet = { multiple={w,w,...}, desc=sc.desc.." - "..ctld.tr("All crates"), ... }` stored adjacent to its parent. The suffix is i18n-aware.
3. **Pass 3 — mixedSet validation:** for each mixedSet, checks every weight against `catWeightIdx` (per-category index). Any unresolved weight marks the entire mixedSet as invalid (excluded from menu) and queues a startup MM warning via `trigger.action.outText`.

**Stored results:**

- `self._processedCrates[category] = { singleCrates=[{singleCrate, singleTypeSet?},...], mixedSets=[...] }`
- `self._weightIndex[weight] = descriptor` — O(1) lookup for all `findDescriptorBy*` methods (singleCrates only; mixedSets have no `weight` field).

**Menu rendering order** (`refreshRequestEquipmentSection`): for each category, iterates `data.singleCrates` (each followed immediately by its `singleTypeSet` if visible), then `data.mixedSets`. Coalition/JTAC filtering applied per player at render time. `crateOrder` counter ensures `_sortByOrder` produces a stable, deterministic sequence.

---

## 7. Build

**Local (Windows):**
```
powershell -ExecutionPolicy Bypass -File tools/build/merge_CTLD.ps1
```
Output: `CTLD_Next.lua` at repo root (gitignored). UTF-8 without BOM (required by DCS).

**CI (GitHub Actions):** automatic on push — see `.github/workflows/ci.yml`.

---

## 7.1 Dynamic loading in DCS mission (dev workflow)

By default, `CTLD_Next.lua` must be embedded inside the `.miz` archive (as a DO SCRIPT FILE action). Re-embedding after each build is tedious during active development. The **dynamic loading pattern** avoids this: DCS reads `CTLD_Next.lua` directly from a local path on disk at mission start via `dofile()`, so only a rebuild is needed — no .miz re-packaging.

> This is a **developer-only** setup. Do not ship `.miz` files to players with dynamic loading enabled — they would need the file at the same local path on their machine.

### Trigger setup

Add three MISSION START triggers in the DCS Mission Editor, in this order:

#### Trigger 1 — "Define loading mode"

- Type: `MISSION START`
- Condition: `FLAG IS FALSE (setToFlagIsFalseToEnable)` — fires when the flag is in its default false state
- Action: `DO SCRIPT`

```lua
if ctld == nil then ctld = {}; end
ctld.path = "F:\\Temp\\CTLD\\"  -- replace with your local repo/build folder
```

This sets `ctld.path`. The flag `setToFlagIsFalseToEnable` acts as a toggle: leave it false for dynamic load; set it to true in mission triggers to disable dynamic loading and fall back to static.

#### Trigger 2 — "Load CTLD - static"

- Type: `MISSION START`
- Condition: `LUA PREDICATE (return ctld == nil or ctld.path == nil)`
- Action: `DO SCRIPT FILE` → embedded `CTLD_Next.lua`

This fires only when `ctld.path` is **not** set — i.e., when dynamic loading is disabled. It loads the version baked into the .miz.

#### Trigger 3 — "Load CTLD - dynamic"

- Type: `MISSION START`
- Condition: `LUA PREDICATE (return ctld.path ~= nil)`
- Actions:
  1. `MESSAGE TO ALL` — `"Loading CTLD from disk..."` (optional, 10 s)
  2. `DO SCRIPT`

```lua
assert(dofile(ctld.path.."source\\CTLD_loader.lua"))
```

This fires only when `ctld.path` is defined. `CTLD_loader.lua` is the entry-point file generated by the build (equivalent to `CTLD_Next.lua`).

### Screenshots

![Trigger 1 — Define loading mode](assets/trigger-dynamic-loading.png)

> Trigger 1: sets `ctld.path`. Trigger 3 (dynamic) is visible in the left panel.

![Trigger 3 — Load CTLD dynamic](assets/trigger-dynamic-loading2.png)

> Trigger 3: LUA PREDICATE on `ctld.path ~= nil` → `dofile(ctld.path.."source\\CTLD_loader.lua")`.

### Dev cycle

```
1. Edit src/
2. Run build  →  CTLD_Next.lua updated on disk
3. Restart mission in DCS  →  dofile() picks up new version automatically
4. No .miz re-packaging needed
```

---

## 8. Testing

**busted (unit, no DCS):**
```
busted tests/specs/
```
Requires `luarocks install busted`.

**Witchcraft (integration, requires live DCS mission):**
```
node "%USERPROFILE%/.vscode-dcs-tools/bridge.js" "C:/path/to/live_tests/F-xx/test.lua"
```
Results in `live_tests/CTLD.log`.

---

## 9. Migration v1 → v2

### 7.1 Wrapper principle

All 22 v1 global functions (`ctld.spawnGroupAtTrigger`, `ctld.JTACAutoLase`,
etc.) are preserved as thin wrappers in `src/compat/legacy_api.lua`. Each
wrapper:
- Calls the equivalent v2 manager method
- Logs a deprecation warning to `ctld.log`

No behaviour change — existing missions continue to work unchanged.

### 7.2 Migration table

| v1 call | v2 equivalent |
|---|---|
| `ctld.spawnGroupAtTrigger(name, zone, side)` | `CTLDTroopManager.getInstance():spawnGroupAtTrigger(name, zone, side)` |
| `ctld.spawnGroupAtPoint(name, point, side)` | `CTLDTroopManager.getInstance():spawnGroupAtPoint(name, point, side)` |
| `ctld.preLoadTransport(unit, group)` | `CTLDTroopManager.getInstance():preLoadTransport(unit, group)` |
| `ctld.unloadTransport(unit)` | `CTLDTroopManager.getInstance():unloadTransport(unit)` |
| `ctld.loadTransport(unit, group)` | `CTLDTroopManager.getInstance():loadTransport(unit, group)` |
| `ctld.unloadInProximityToEnemy(unit)` | `CTLDTroopManager.getInstance():unloadInProximityToEnemy(unit)` |
| `ctld.activatePickupZone(zone)` | `CTLDZoneManager.getInstance():activatePickupZone(zone)` |
| `ctld.deactivatePickupZone(zone)` | `CTLDZoneManager.getInstance():deactivatePickupZone(zone)` |
| `ctld.changeRemainingGroupsForPickupZone(zone, n)` | `CTLDZoneManager.getInstance():changeRemainingGroups(zone, n)` |
| `ctld.activateWaypointZone(zone)` | `CTLDZoneManager.getInstance():activateWaypointZone(zone)` |
| `ctld.deactivateWaypointZone(zone)` | `CTLDZoneManager.getInstance():deactivateWaypointZone(zone)` |
| `ctld.createExtractZone(name, pt, r, side)` | `CTLDZoneManager.getInstance():createExtractZone(name, pt, r, side)` |
| `ctld.removeExtractZone(zone)` | `CTLDZoneManager.getInstance():removeExtractZone(zone)` |
| `ctld.countDroppedGroupsInZone(zone)` | `CTLDZoneManager.getInstance():countDroppedGroupsInZone(zone)` |
| `ctld.countDroppedUnitsInZone(zone)` | `CTLDZoneManager.getInstance():countDroppedUnitsInZone(zone)` |
| *(new)* | `CTLDZoneManager.getInstance():deactivateLogisticZone(name)` |
| *(new)* | `CTLDZoneManager.getInstance():activateLogisticZone(name)` |
| `ctld.cratesInZone(zone)` | `CTLDCrateManager.getInstance():startCrateCountWatcher(zone)` |
| `ctld.spawnCrateAtZone(type, zone, side)` | `CTLDCrateManager.getInstance():spawnCrateAtZone(type, zone, side)` |
| `ctld.spawnCrateAtPoint(type, pt, side)` | `CTLDCrateManager.getInstance():spawnCrateAtPoint(type, pt, side)` |
| `ctld.createRadioBeaconAtZone(zone, side, freq, mod)` | `CTLDBeaconManager.getInstance():createAtZone(zone, side, freq, mod)` |
| `ctld.JTACAutoLase(group, code, smoke)` | `CTLDJTACManager.getInstance():autoLase(group, code, smoke)` |
| `ctld.JTACStart(unit, code, smoke)` | `CTLDJTACManager.getInstance():startLase(unit, code, smoke)` |
| `ctld.JTACAutoLaseStop(group)` | `CTLDJTACManager.getInstance():stopAutoLase(group)` |

### 7.3 Replacing ctld.addCallback

v1 used a single catch-all callback:
```lua
-- v1
ctld.addCallback(function(event)
    if event.id == ctld.events.S_EVENT_CRATE_SPAWNED then
        -- handle
    end
end)
```

v2 uses targeted subscriptions:
```lua
-- v2
EventDispatcher.getInstance():subscribe("OnCrateSpawned", function(evt)
    -- evt.crateName, evt.coalition, evt.spawnedBy, evt.position
end)
```

Benefits: no `if/elseif` chain, only the relevant handler fires, multiple
subscribers supported per event.

### 7.4 Complete migration example

**v1 DO SCRIPT:**
```lua
ctld.spawnGroupAtTrigger("Alpha Squad", "LZ_NORTH", coalition.side.BLUE)
ctld.JTACAutoLase("ENEMY_ARMOUR", 1688, true)
ctld.addCallback(function(e)
    if e.id == ctld.events.S_EVENT_TROOPS_DEPLOYED then
        trigger.action.outText("Troops landed!", 10)
    end
end)
```

**v2 equivalent:**
```lua
local tm  = CTLDTroopManager.getInstance()
local jtac = CTLDJTACManager.getInstance()
local ed  = EventDispatcher.getInstance()

tm:spawnGroupAtTrigger("Alpha Squad", "LZ_NORTH", coalition.side.BLUE)
jtac:autoLase("ENEMY_ARMOUR", 1688, true)
ed:subscribe("OnTroopsDeployed", function(evt)
    trigger.action.outText("Troops landed!", 10)
end)
```

### 7.5 Pack vehicle (new in v2)

v1 had no functional pack vehicle. v2 implements:

```lua
-- Find packable vehicles near a transport
local vehicles = CTLDVehicleSpawner.getInstance():findPackableVehicles(transportUnit)

-- Pack one (destroys the vehicle, spawns crates)
CTLDVehicleSpawner.getInstance():packVehicle(transportName, vehicleName, playerObj)
```

The F10 "Pack Vehicle" submenu is populated automatically when the transport
lands near a packable vehicle.

---

## 10. Internationalisation (i18n)

### 8.1 How it works

- All user-facing strings are declared via `ctld.tr("English key")`.
- The active language is set in `src/CTLD_i18n.lua` (`ctld.i18n_lang`).
- Dictionaries live in separate files: `CTLD_i18n_en.lua`, `CTLD_i18n_fr.lua`,
  `CTLD_i18n_es.lua`, `CTLD_i18n_ko.lua`.
- Fallback chain: **active lang → EN → key itself** (never returns nil/empty).

### 8.2 Adding a new key

1. Add `ctld.tr("My new text")` in the source file.
2. Add the entry to `src/CTLD_i18n_en.lua` (key = value for EN).
3. Bump `translation_version` in `CTLD_i18n_en.lua`.
4. Run `tools/build/generate_i18n_dicts.ps1` — it propagates the new key
   (with EN value as placeholder) to all other language files and regenerates
   the merged loader.
5. Translators fill in the placeholder values in their language file.

### 8.3 Adding a new language

1. Copy `src/CTLD_i18n_en.lua` to `src/CTLD_i18n_XX.lua`.
2. Translate all values (keep keys identical to EN).
3. Add `CTLD_i18n_XX.lua` to `tools/build/listToMerge.txt`.
4. Add `ctld.i18n_lang = "XX"` as an option in `src/CTLD_i18n.lua`.
5. Regenerate: run `generate_i18n_dicts.ps1`.

### 8.4 Translator audit API

These functions let scripts and tests detect gaps between EN and a target language
without writing to `env.*`.

**`ctld.i18n_audit(language)`**

```lua
---@param  language string  Language code, e.g. "fr"
---@return table|nil result  { version_match=bool, en_version=str,
--                             lang_version=str, missing={}, untranslated={} }
---@return string|nil err    Non-nil when the language is unknown
local result, err = ctld.i18n_audit("fr")
if err then
    -- language not loaded
else
    if not result.version_match then
        -- EN bumped; FR needs update
    end
    -- result.missing      : keys present in EN but absent in FR
    -- result.untranslated : keys where FR value == EN value (not translated)
end
```

**`ctld.i18n_auditAll()`**

Runs `ctld.i18n_audit()` on every loaded non-EN language.

```lua
local results = ctld.i18n_auditAll()
-- results["fr"], results["es"], results["ko"] — each is an audit result table
for lang, r in pairs(results) do
    print(lang, "#missing=" .. #r.missing, "#untranslated=" .. #r.untranslated)
end
```

**`ctld.i18n_check(language, verbose)`** *(legacy — DCS only)*

Logs errors and warnings directly to `env.*`. Not suitable for assertions.
Use `ctld.i18n_audit()` in tests and scripts.

### 8.5 Mission-maker overrides (`ctld.i18n_overrides`)

`ctld.i18n_overrides` is **never set inside `src/`**. It is a mission-maker configuration variable, declared in `CTLD_userConfig.lua` (the `.miz`-side config file):

```lua
-- In CTLD_userConfig.lua (inside the .miz, not in src/)
ctld.i18n_overrides = {
    fr = {
        ["Troops loaded"] = "Soldats embarqués",
    },
    en = {
        ["Troops loaded"] = "Troops on board",
    },
}
```

**Runtime sequence:**

```
1. CTLD_Next.lua loads → dictionaries populated:
     ctld.i18n["en"]["Troops loaded"] = "Troops loaded"
     ctld.i18n["fr"]["Troops loaded"] = "Troupes chargées"

2. CTLD_userConfig.lua runs → sets ctld.i18n_overrides

3. CTLDi18n.getInstance() called → _init() iterates ctld.i18n_overrides
   and overwrites matching dict entries in memory

4. ctld.tr("Troops loaded") returns the overridden value
```

The distinction from `generate_i18n_dicts.ps1` (build-time): that script
synchronises the `CTLD_i18n_XX.lua` dictionary files in `src/`. Overrides
are a **runtime** mechanism — they never touch the source files.

Overrides are applied **once** at startup by `CTLDi18n:_init()` and are
not reset between calls to `ctld.tr()`.

---

## 11. Troop + JTAC lifecycle

### 9.1 Troop group state machine

A `CTLDTroopGroup` instance tracks troops from load to final disposal. It is not a DCS object — it lives entirely in Lua memory.

```
TRZ_LOADED ──embarkFromTroopZone()───────────────────────────────→ DEPLOYED
    │                                                               │
    │  (DCS group: never spawned)                                   │  (DCS group: spawned)
    │  _aliveUnits + _jtacUnits memorised                           │  _aliveUnits = live DCS units
    │                                                               │  _jtacUnits map populated on 1st disembark
    │                                                               │
    │                                                               ↓
    │                                                  embarkFromField()
    │                                                               │
    │                                                               ↓
    │  returnToTroopZone()                                          │ FIELD_LOADED
    │      │                                                        │
    │      ↓                                                        ↓
    │  RETURNED_TO_TRZ                                       DEPLOYED
    │  (instance discarded)                                  (respawn from _aliveUnits)
    │  deregisterJTAC() × N
    │
    └──dispatchToEXZ()───────────────────────────────────────────→ DEPLOYED_EXZ
        (DCS group: never spawned, flag counter only)                (silent, group discarded)
```

### 9.2 JTAC instance model

**One `CTLDJTAC` instance per alive JTAC unit in the group** — not one per group. The `_jtacUnits` map holds the truth:

```lua
-- CTLDTroopGroup fields (new)
self._aliveUnits = {}  -- [unitName] = dcsUnit (DCS Unit reference, not index)
self._jtacUnits  = {}  -- [unitName] = true (subset of _aliveUnits flagged as JTAC)
```

JTAC soldiers within a composite troop group are **unit-keyed**: `CTLDJTACManager.jtacs[unitName]`
with `CTLDJTAC.unitName` set. This distinguishes them from standalone JTAC groups (vehicle/drone),
which are group-keyed (`jtacs[groupName]`, `unitName == nil`).

Two separate entry points drive these two paths:

| JTAC type | Entry point | Key in `jtacs` | `unitName` field |
| --- | --- | --- | --- |
| Drone / vehicle JTAC | `CTLDJTACManager:startLase(groupName)` | `groupName` | `nil` |
| Infantry JTAC in troop group | `CTLDJTACManager:startLaseTroopUnit(unitName)` | `unitName` | set |

The `_autoLaseLoop` resolves the DCS unit via `Unit.getByName(unitName)` (unit-keyed path) or
`Group.getByName(groupName):getUnits()[1]` (group-keyed path). On unit death, unit-keyed JTACs
are cleaned up by `S_EVENT_DEAD → onUnitDead → deregisterJTAC(unitName)` — they must NOT call
`killJTAC` (which would destroy the composite group, killing surviving infantry).

### 9.3 Transition rules per exit path

| Exit path | JTAC action required |
|---|---|
| `embarkFromTroopZone()` → `TRZ_LOADED` | None — no JTAC instances yet |
| `disembark()` (1st deploy) | `startLaseTroopUnit(unitName)` for every `unitName` in `_jtacUnits` |
| `embarkFromField()` → `FIELD_LOADED` | **`deregisterJTAC(unitName)` for every key in `_jtacUnits` BEFORE `group:destroy()`** |
| `disembark()` (after field) | `startLaseTroopUnit(unitName)` for every key in `_jtacUnits` |
| `returnToTroopZone()` → `RETURNED_TO_TRZ` | `deregisterJTAC(unitName)` for every key in `_jtacUnits` |
| `dispatchToEXZ()` → `DEPLOYED_EXZ` | None — group never spawned, no JTAC ever instantiated |
| Transport destroyed (FIELD_LOADED) | All `_jtacUnits` orphans → `deregisterJTAC()` in `cleanupDeadTransports()` |

### 9.4 S_EVENT_DEAD sync

Every death of a unit in a deployed group triggers `CTLDTroopManager:onUnitDead(unitName)` which removes the dead unit from `_aliveUnits`. If it was a JTAC unit it also removes from `_jtacUnits` and calls `deregisterJTAC()`. The DCS group re-indexes surviving units automatically; using `unitName` keys (not indices) avoids any re-indexing bug.

### 9.5 Legacy terminology (→ v2 rename)

| Old method | New method |
|---|---|
| `loadFromZone()` | `embarkFromTroopZone()` |
| `deploy()` / `unload()` | `disembark()` |
| `extract()` | `embarkFromField()` |
| `returnToBase()` | `returnToTroopZone()` |
| `LOADED` state | `TRZ_LOADED` |
| `EXTRACTED` state | `FIELD_LOADED` |
| `hasJtac` (boolean) | `_jtacUnits` (map) |
| Group index-based tracking | `unitName`-based map tracking |

### 9.6 Transport kill with FIELD_LOADED troops

When a transport carrying `FIELD_LOADED` troops is shot down:
1. `CTLDPlayerManager:onPlayerLeaveUnit()` detects transport death
2. `_inTransit[unitName]` is niled by `cleanupDeadTransports()`
3. Any `_jtacUnits` still referenced in `CTLDJTACManager.jtacs` become **orphan zombies**
4. Fix: `cleanupDeadTransports()` must iterate the group's `_jtacUnits` and call `deregisterJTAC()` before clearing `_inTransit`

Full state machine diagram: [docs/assets/troops_jtac_lifecycle.svg](assets/troops_jtac_lifecycle.svg)

### 9.7 Multi-JTAC target deconfliction

When multiple JTACs are active simultaneously (infantry, vehicle, drone — any mix), `CTLDJTACManager` prevents them from lasing the same target via a shared claim table.

```lua
-- CTLDJTACManager field (singleton)
self._claimedTargets = {}  -- { [enemyUnitName] = jtacKey }
-- jtacKey = unitName (infantry/unit-keyed) or groupName (vehicle/drone/group-keyed)
```

**Claim lifecycle:**

| Event | Action |
| --- | --- |
| JTAC locks a new target | `_claimTarget(jtacKey, enemyUnitName)` |
| Lasing stops (any reason) | `_releaseTarget(enemyUnitName)` — called from `_stopLaseAndPublish` |
| JTAC deregistered | `_releaseTarget` + `_releaseAllTargetsFor(jtacKey)` — belt-and-suspenders |
| `cleanup()` | `_claimedTargets = {}` |

**Target selection flow** (`_autoLaseLoop` search phase):

1. `CTLDJTACDetector.findAllVisibleEnemies()` returns all LOS-visible enemy units sorted by priority then distance
2. Iterate the list — skip any `candidate.unitName` already in `_claimedTargets`
3. First unclaimed candidate → `_claimTarget` → create DCS spots → start lasing

**Target renewal** (critical case — when target is destroyed or LOS is lost):

- `_stopLaseAndPublish` releases the claim on the lost target
- Execution falls through to the search phase in the same `_autoLaseLoop` tick
- The JTAC immediately picks the next unclaimed candidate from a fresh `findAllVisibleEnemies` call

This means several JTACs losing their target simultaneously (e.g. explosion) each acquire a different next target rather than all converging on the same one.

**`CTLDJTACDetector.findAllVisibleEnemies` vs `findNearestVisibleEnemy`:**

`findNearestVisibleEnemy` is now a thin wrapper returning `findAllVisibleEnemies()[1]`. It is kept for any callsite that only needs the single best candidate (no deconfliction needed).
