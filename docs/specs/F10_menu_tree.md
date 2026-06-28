# CTLD v2 — F10 Menu Tree

**Status**: Current — extracted from `src/` 2026-06-29
**Replaces**: previous version based on `old/CTLD_menus.lua` (v1, obsolete)

---

## Architecture Overview

### Two-layer model

| Layer | Class | Responsibility |
|---|---|---|
| Logical model | `ctld.Menu` | In-memory tree per group, unlimited depth, pagination-transparent |
| DCS renderer | `ctld.MenuManager` | Singleton, wipe + atomic rebuild on `refresh()`, sorts by `order`, paginates |

### Order convention

Every top-level submenu carries an explicit `order` value. Siblings render in ascending `order` order, independent of manager init sequence. Nodes without `order` go last (`math.huge`).

### Enabled convention

`node.enabled = false` → invisible in DCS, **position preserved** in memory. Use `menu:setBranchEnabled(path, bool)` + `menu:refresh()` to toggle features at runtime without losing order slots.

### Pagination rule

DCS F10 slots: F1–F10 per level (F11=Prev Page DCS, F12=Quit DCS).

| Visible children | Rendering |
|---|---|
| ≤ 10 | All on one page |
| > 10 | F1–F9 = content, F10 = "→ Next Page" submenu (DCS-only, not in memory model) |

---

## Top-Level Structure

```
CTLD (root, order=10)
├── Check Cargo                     (command)
├── Troop Commands                  (submenu, order=20)
├── Request Equipment               (submenu, order=25)
├── Vehicle Commands                (submenu, order=30)
├── Crate Commands                  (submenu, order=40)
├── FOB (List active FOBs)          (submenu, order=60)  ← conflicts with Radio Beacons
├── Radio Beacons                   (submenu, order=60)  ← conflicts with FOB
├── RECON                           (submenu, order=70)
├── Mine Field                      (submenu, order=75)  ← conditional, sol only
├── Smoke                           (submenu, order=80)
└── JTAC                            (submenu, order=90)
```

> **order=60 conflict**: Both FOB (`CTLD_fob.lua:521`) and Radio Beacons (`CTLD_beacon.lua`) use `order=60`. DCS render order between them depends on manager init sequence. This is a known gap — one should be renumbered (e.g. FOB → order=55).

DCS render order (F-key order, approximate):
```
F1 - Troop Commands
F2 - Request Equipment
F3 - Vehicle Commands
F4 - Crate Commands
F5 - FOB / Radio Beacons (order=60, sequence depends on init)
F6 - Radio Beacons / FOB
F7 - RECON
F8 - Mine Field (conditional — only shown when mine fields nearby on ground)
F9 - Smoke
F9 - JTAC
```

---

## Section Registration Table

| Section | Manager | Order | Config gate | Capability gate |
|---|---|---|---|---|
| Check Cargo | CTLDPlayerManager | — | — | — |
| Troop Commands | CTLDTroopManager | 20 | — | `troopsEnabled=true` |
| Request Equipment | CTLDCrateManager | 25 | — | `cratesEnabled=true` |
| Crate Commands | CTLDCrateManager | 40 | — | `cratesEnabled=true` |
| Vehicle Commands | CTLDVehicleSpawner | 30 | — | `canCarryVehicles=true` |
| FOB (List FOBs) | CTLDFOBManager | **60** ⚠️ | `enabledFOBBuilding` | — |
| Radio Beacons | CTLDBeaconManager | **60** ⚠️ | `enabledRadioBeaconDrop` | `isTransport=true` |
| RECON | CTLDReconManager | 70 | `reconF10Menu` | — |
| Mine Field | mineFieldScene | 75 | — | SOL + mine fields nearby |
| Smoke | CTLDCrateManager | 80 | `enableSmokeDrop` | `isTransport=true` |
| JTAC | CTLDJTACManager | 90 | `JTAC_jtacStatusF10` | — |

⚠️ Both FOB and Radio Beacons use order=60. Render order between them is init-sequence dependent.

All sections registered via `CTLDPlayerManager:registerMenuSection()`.

---

## Troop Commands (order=20)

**Manager**: `CTLDTroopManager`
**File**: `src/CTLD_troop.lua`

```
Troop Commands
├── Disembark Troops            [SOL ONLY — if hasTroops]
│   ├── (direct command if 1 group)
│   └── Disembark Troops (submenu if 2+ groups)
│       ├── Disembark All
│       ├── [1] TemplateNameA
│       └── [2] TemplateNameB
│
├── Embark / Extract Troops     [SOL ONLY — if TRZ zones or field groups nearby]
│   ├── Load from TRZ_ZoneName
│   │   ├── Load Template-Infantry
│   │   └── Load Template-Mixed
│   └── Extract from field      [if dropped troops nearby]
│       ├── GroupName1 (50m)
│       └── GroupName2 (120m)
│
├── Check Cargo                 [SOL ONLY]
│
└── Parachute Troops            [AIR ONLY — if canParachuteDrop + hasTroops]
    ├── (direct command if 1 group)
    └── Parachute Troops (submenu if 2+ groups)
        ├── Parachute All
        └── [1] TemplateNameA
```

**Pagination**: `Embark / Extract` paginated at 10 items/page.

**Per-template conditions**: visible if `tmpl.total <= transportLimit` AND stock available AND side compatible.

**Refresh trigger**: `S_EVENT_LAND`, `S_EVENT_TAKEOFF`, embark/disembark operations.

---

## Request Equipment (order=25)

**Manager**: `CTLDCrateManager`
**File**: `src/CTLD_crate.lua`
**Condition**: transport landed AND inside a logistics zone (LGZ)

```
Request Equipment
├── [Logistics Zone "Zone-Alpha"]
│   ├── Infantry
│   │   ├── Rifle Squad
│   │   └── Rifle Squad x3   (singleTypeSet if enableAllCrates)
│   ├── Support
│   │   └── Machine Gunner Team
│   └── [→ Next Page]        (if >10 categories, PAG: 10/p)
└── [Logistics Zone "Zone-Beta"]
    └── [...]
```

**Item conditions**:
- JTAC items: visible if `JTAC_dropEnabled=true`
- `descriptor.side` filter: coalition match required
- Whole-vehicle items (Feature Q): visible if `canTransportWholeVehicle=true` AND vehicle type in `loadableVehiclesRED/BLUE` → spawns WAITING vehicle instead of crate

**Spawn types**:
| Type | Behavior |
|---|---|
| Single crate | Spawn 1 crate |
| SingleTypeSet | Spawn N crates of same type |
| MixedSet | Spawn multi-type set (`enableAllCrates` required) |
| Vehicle (Feature Q) | Spawn WAITING vehicle directly |

---

## Crate Commands (order=40)

**Manager**: `CTLDCrateManager`
**File**: `src/CTLD_crate.lua`

```
Crate Commands
├── Load Crate          (submenu, order=10) [SOL ONLY — if loadCrateFromMenu=true]
│   └── [dynamic: nearby crates <300m with assembly status]
│
├── Drop Crate(s)       (command, order=15) [SOL ONLY]
│
├── Unpack Crate        (submenu, order=20) [SOL ONLY]
│   ├── [Crate 1 - M1045 HMMWV TOW, 2500kg]
│   ├── [Crate 2 - Soldier]
│   └── [...]
│
├── List Nearby Crates  (command)           [SOL ONLY]
│
├── Pack Equipt         (submenu, order=25) [SOL ONLY — dynamic, rebuilt on land]
│   ├── Pack FARP-AlphaModel               [if enableFARPRepack + nearby FARP scenes]
│   ├── Pack FARP-BetaModel
│   ├── M1A1 Abrams                        [if enablePackingVehicles + packable vehicles nearby]
│   └── M113 APC
│   (submenu hidden entirely if no packable content found)
│
├── Parachute Crates    (command)           [AIR ONLY — if canParachuteDrop + crates onboard]
│
├── Release Slingload   (command)           [AIR ONLY — if canSlingload + slingload active]
│
└── Cut Slingload       (command)           [AIR ONLY — if canSlingload + slingload active]
```

**Refresh patterns**:
- `refreshCrateFlightSection()`: toggles SOL/AIR visibility on land/takeoff
- `refreshPackEquiptSection()`: rebuilds "Pack Equipt" dynamically on land
- `refreshRequestEquipmentSection()`: rebuilds "Request Equipment" on zone enter/land

---

## Vehicle Commands (order=30)

**Manager**: `CTLDVehicleSpawner`
**File**: `src/CTLD_vehicle.lua`
**Condition**: `capabilitiesByType[typeName].canCarryVehicles=true`

```
Vehicle Commands
├── Load / Extract Vehicles  (submenu)  [SOL ONLY — dynamic]
│   ├── M1A1 Abrams
│   ├── M113 APC
│   └── [... vehicles within range, coalition match, loadable type]
│
├── Unload Vehicles          (submenu)  [SOL ONLY — hidden if 0 loaded]
│   ├── Vehicle 1 (descriptor label)
│   └── Vehicle 2
│
└── Parachute Vehicle        (command)  [AIR ONLY — if canParachuteDrop + vehicle loaded]
```

**Load filters**:
- Distance ≤ `maximumDistancePackableUnitsSearch` (~200m)
- Coalition: must match transport coalition
- Type: must be in `capabilitiesByType[typeName].loadableVehiclesRED` or `loadableVehiclesBLUE`
- State: `WAITING`

**Refresh triggers**: landing, takeoff, vehicle spawn/despawn events.

---

## Radio Beacons (order=60)

**Manager**: `CTLDBeaconManager`
**File**: `src/CTLD_beacon.lua`
**Config gate**: `enabledRadioBeaconDrop=true`

```
Radio Beacons
├── Drop Beacon
├── Remove Closest Beacon
└── List Beacons
```

- **Drop Beacon**: spawns TACAN/ADF beacon units + starts radio transmissions
- **Remove Closest Beacon**: removes beacon within 500m
- **List Beacons**: displays VHF/UHF/FM frequencies

---

## RECON (order=70)

**Manager**: `CTLDReconManager`
**File**: `src/CTLD_recon.lua`
**Config gate**: `reconF10Menu=true`

```
RECON
├── RECON [Start] / RECON [Stop]     (toggle command)
├── Infantry        [activate/deactivate (X)]
├── Air Defense (AA) [activate/deactivate (X)]
├── Ground Vehicles [activate/deactivate (X)]
├── Helicopters     [activate/deactivate (X)]
├── Aircraft        [activate/deactivate (X)]
├── Ships           [activate/deactivate (X)]
└── FARP / FOB      [activate/deactivate (X)]
```

**Label logic**:
- RECON active + layer enabled: `[deactivate]`
- RECON active + layer disabled: `[activate]`
- RECON inactive + layer disabled: `[activate] (X)` — `(X)` indicates scan not running

**Layers** (7): `infantry`, `air_defense`, `ground_vehicles`, `helicopters`, `aircraft`, `ships`, `farp_fob`

**Scan pipeline**:
1. Altitude check (AGL ≥ `reconMinAltitude`, default 50m)
2. LOS check per enemy unit → match against enabled layers (priority order)
3. Draw API mark per target (shape by layer, color by coalition)
4. Auto-refresh timer (`reconRefreshInterval`, default 10s) → detect new/moved/lost targets

**Icons**: infantry=⊕, vehicle=▭╱, AA=△, helicopter=circleH, aircraft=⊕small, ship=elongated rect, FARP/FOB=helipad T

---

## Mine Field (order=75)

**Manager**: `mineFieldScene` (scene plugin)
**File**: `src/scenes/CTLD_mineFieldScene.lua`
**Condition**: player on ground AND mine fields within `demineRadius` (default 150m)

```
Mine Field
├── Clear Mine Field (N mines, ~Xm)    [one entry per nearby mine set]
└── [...]
```

This section is registered via `CTLDPlayerManager.deferMenuSection()` and refreshed on land/takeoff and after each clearing operation. Hidden entirely if no mine fields are nearby.

---

## Smoke (order=80)

**Manager**: `CTLDCrateManager`
**File**: `src/CTLD_crate.lua`
**Config gate**: `enableSmokeDrop=true`

```
Smoke
├── Drop Red Smoke
├── Drop Blue Smoke
├── Drop Orange Smoke
├── Drop Green Smoke
└── Smoke Auto-Resume [activate] / [deactivate]   (toggle command)
```

`Smoke Auto-Resume`: if activated, smoke markers are automatically re-dropped after burning out.

---

## JTAC (order=90)

**Manager**: `CTLDJTACManager`
**File**: `src/CTLD_jtac.lua`
**Config gate**: `JTAC_jtacStatusF10=true`

```
JTAC
├── Request JTAC Equipment  (submenu)  [SOL ONLY — if JTAC_dropEnabled + in LGZ]
│   ├── Air JTAC Type1   (drone, spawnAs="AIRPLANE")
│   ├── Ground JTAC Type2 (vehicle)
│   └── [...]
│
├── JTAC Status  (command)
│
├── [JTAC Name 1]  (submenu — per active JTAC, same coalition)
│   ├── Lasing [activate] / [deactivate]      [if JTAC_allowStandbyMode]
│   ├── Spot Corrections [activate/deactivate] [if JTAC_laseSpotCorrections≠nil]
│   ├── Request Smoke on Target                [if JTAC_allowSmokeRequest]
│   └── Request 9-Line                         [if JTAC_allow9Line]
│
└── [JTAC Name 2]
    └── [...]
```

**JTAC menu visibility by state**:

| JTAC state | Menu visible | Submenu |
|---|---|---|
| SPAWNED | Yes | Created |
| IDLE | Yes | Present |
| LASING | Yes | Present |
| ORBITING | Yes | Present |
| IN_TRANSIT | Yes | Present |
| DEAD | **No** | Removed |

**Dynamic rebuild**: `toggleStandby()` / `toggleSpotCorrections()` → `_rebuildJTACCommandBranch()` → wipes and rebuilds per-JTAC submenu for all coalition players.

**JTAC config flags** (those affecting menu):

| Flag | Effect on menu |
|---|---|
| `JTAC_dropEnabled` | Shows/hides "Request JTAC Equipment" |
| `JTAC_allowStandbyMode` | Shows/hides "Lasing [toggle]" |
| `JTAC_laseSpotCorrections` | Shows/hides "Spot Corrections [toggle]" |
| `JTAC_allowSmokeRequest` | Shows/hides "Request Smoke on Target" |
| `JTAC_allow9Line` | Shows/hides "Request 9-Line" |

---

## Refresh Events Summary

| Event | Managers refreshed |
|---|---|
| `S_EVENT_LAND` | CTLDCrateManager, CTLDTroopManager, CTLDVehicleSpawner, CTLDJTACManager |
| `S_EVENT_TAKEOFF` | Same — toggles SOL/AIR branch visibility |
| Vehicle spawn/despawn | CTLDVehicleSpawner: `refreshLoadSection` + `refreshPackEquiptSection` |
| Crate load/unload | CTLDCrateManager: `refreshCrateFlightSection` |
| Troop embark/disembark | CTLDTroopManager: `refreshMenuSection` |
| JTAC spawn/dead | CTLDJTACManager: `_rebuildJTACCommandBranch` for all coalition players |

---

## Key Differences from v1

| v1 (old/CTLD_menus.lua) | v2 |
|---|---|
| Single monolithic `addTransportF10MenuOptions()` | Each manager registers its own section |
| `ctld.checkTroopStatus`, `ctld.loadTroopsFromZone`, etc. (global functions) | OOP methods on manager instances |
| Static menu built once on player enter | Dynamic sections rebuilt on land/takeoff events |
| No order control | Explicit `order` field per node |
| PKZ / EXZ zone naming | TRZ zone naming (see TroopZones_Architecture.md) |
| No whole-vehicle menu integration | Feature Q: whole vehicles in Request Equipment |
