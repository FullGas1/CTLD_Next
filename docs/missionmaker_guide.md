# CTLD — Mission Maker Guide

> This document is a living reference, updated progressively as features are developed.
> It covers what mission makers need to know to configure and extend CTLD in their missions.

---

## Table of Contents

1. [Configuration](#1-configuration)
2. [Translations & Localisation](#2-translations--localisation)
3. [Scene Deployment](#3-scene-deployment)
4. [Zone Setup](#4-zone-setup)
5. [Troop Transport](#5-troop-transport)
6. [Virtual Parachute Drop](#6-virtual-parachute-drop)
7. [Virtual Slingload](#7-virtual-slingload)
8. [Minefield](#8-minefield)
9. [Legacy API compatibility](#9-legacy-api-compatibility)
10. [Crates](#10-crates)
11. [Vehicles](#11-vehicles)
12. [FOB — Forward Operating Base](#12-fob--forward-operating-base)
13. [Radio Beacons](#13-radio-beacons)
14. [JTAC](#14-jtac)
15. [Recon](#15-recon)
16. [AA Systems](#16-aa-systems)
17. [Smoke Drop](#17-smoke-drop)
18. [Pack Equipt — Vehicle Repack & FARP Repack](#18-pack-equipt--vehicle-repack--farp-repack)
19. [Beacon Layer](#19-beacon-layer)

---

## 1. Configuration

### Overview

CTLD comes with sensible defaults for all parameters. As a mission maker, you never need to touch the internal source files. All customisation is done in a single file: **`CTLD_userConfig.lua`**, loaded by your mission via a `DO SCRIPT FILE` trigger at mission start, **after** CTLD itself is loaded.

`CTLD_userConfig.lua` is free-form Lua: you only override what you want to change. Anything not declared keeps its default value.

### How configuration works internally

On startup, `CTLDConfig` loads all default values. It then reads `ctld.yamlConfigDatas` (the content of your `CTLD_userConfig.lua`) and applies your overrides on top of the defaults. Throughout the CTLD codebase, every parameter is accessed via:

```lua
ctld.gs("parameterName")   -- the only authorised access form
```

### Load order in the mission editor

Your triggers must fire in this order:

| Order | Action | File |
|---|---|---|
| 1 | DO SCRIPT FILE | `CTLD_userConfig.lua` |
| 2 | DO SCRIPT FILE | `CTLD_Next.lua` |

### Customising parameters — `CTLD_userConfig.lua`

Only declare the parameters you want to override. Example:

```lua
-- CTLD_userConfig.lua
-- Only override what differs from the defaults.

ctld = ctld or {}
ctld.yamlConfigDatas = [[

ctld.enablePackingVehicles: true
ctld.maximumDistancePackableUnitsSearch: 350
ctld.cratesRequiredForFOB: 2
ctld.numberOfTroops: 8
ctld.maximumDistanceLogistic: 300
ctld.slingLoad: true

]]
```

Each line follows the pattern `ctld.parameterName: value`.

### Key configuration parameters

#### General behaviour

| Parameter | Default | Description |
|---|---|---|
| `enableCrates` | `true` | Enable crate spawning and unpacking |
| `enableAllCrates` | `true` | Global toggle: show "All crates" shortcut entries in Request Equipment menus (both auto-generated single-type sets and manually defined mixed sets). Set to `false` to hide all set shortcuts and keep only individual crate entries. |
| `slingLoad` | `false` | Use DCS sling-load physics instead of hover simulation |
| `enableHoverSlingload` | `true` | Allow crate loading by hovering above it (simulated slingload). If `false`, crates can only be loaded via F10 menu (`loadCrateFromMenu`) |
| `loadCrateFromMenu` | `true` | Allow crate loading via F10 menu |
| `disableAllSmoke` | `false` | Globally disable all smoke signals |

#### Distances (metres)

| Parameter | Default | Description |
|---|---|---|
| `maximumDistanceLogistic` | `200` | Max distance from logistics unit to load/spawn a crate |
| `maxExtractDistance` | `125` | Max distance from vehicle to troops for extraction |
| `maximumSearchDistance` | `4000` | Max distance for AI troops to search for enemies |
| `maximumMoveDistance` | `2000` | Max distance for AI troops to move from drop point |
| `maximumDistancePackableUnitsSearch` | `200` | Max distance to search for packable vehicles |

#### Troops

| Parameter | Default | Description |
|---|---|---|
| `numberOfTroops` | `10` | Default / max troop group size per transport |
| `enableFastRopeInsertion` | `true` | Allow fast-rope deployment |
| `fastRopeMaximumHeight` | `18.28` | Max height (m) for fast-rope insertion |
| `allowRandomAiTeamPickups` | `false` | Allow AI transports to randomly pick up infantry teams at pickup zones. When `false`, the AI always picks the first available template for its coalition. |
| `nbLimitSpawnedTroops` | `{0,0}` | Cumulative troop cap per coalition `{RED, BLUE}` — `0` = unlimited (Lua table) |

#### Infantry weight simulation

CTLD calculates group weight to check whether a troop group fits inside a transport (see `capabilitiesByType[type].unitLoadLimits`). Each soldier's weight is randomised ±10–20 % around `SOLDIER_WEIGHT`, then role-specific kit is added.

| Parameter | Default | Description |
|---|---|---|
| `SOLDIER_WEIGHT` | `80` | Base body weight per soldier (kg) |
| `KIT_WEIGHT` | `20` | Helmet + backpack per soldier (kg) |
| `RIFLE_WEIGHT` | `5` | Standard infantryman rifle kit (kg) |
| `MANPAD_WEIGHT` | `18` | AA soldier MANPAD tube (kg) |
| `RPG_WEIGHT` | `7.6` | AT soldier RPG + rocket (kg) |
| `MG_WEIGHT` | `10` | Machine-gunner weapon + 200-round belt (kg) |
| `MORTAR_WEIGHT` | `26` | Mortar crew tube + shells (kg) |
| `JTAC_WEIGHT` | `15` | JTAC laser + radio + binoculars (kg) |

#### FOB

| Parameter | Default | Description |
|---|---|---|
| `enabledFOBBuilding` | `true` | Allow FOB construction from crates |
| `cratesRequiredForFOB` | `3` | Number of large crates to build a FOB (small crates count as ⅓ each) |
| `troopPickupAtFOB` | `true` | Allow troop pickup at built FOBs |
| `fobMinDistanceFromZones` | `500` | Minimum distance (m) from any logistic zone at which a FOB may be deployed |
| `fobLogisticZoneRadius` | `150` | Radius (m) of the logistic zone created around a deployed FOB |
| `fobDestructionThreshold` | `0.5` | Fraction of scene objects destroyed before FOB is considered lost (0.0–1.0) |
| `fobTroopPickupRadius` | `150` | Radius (m) within which troops can board at a FOB |

#### Vehicles & packing

| Parameter | Default | Description |
|---|---|---|
| `enablePackingVehicles` | `true` | Allow vehicles to be packed back into crates |
| `capabilitiesByType` | `{...}` | Unified per-aircraft capabilities table — see [capabilitiesByType](#capabilitiesbytype) below |
| `vehiclesWeight` | `{...}` | Weight (kg) per vehicle DCS type, used for transport capacity checks (Lua table) |

### capabilitiesByType

The single table that defines every per-aircraft capability. Only aircraft listed here get CTLD F10 menus. Each key is the **exact DCS type name** of the aircraft.

```lua
_cfg.settings["capabilitiesByType"] = {
    ["UH-1H"] = {
        cratesEnabled            = true,   -- can load/unpack crates
        troopsEnabled            = true,   -- can load/deploy infantry
        canParachuteDrop         = true,   -- enables Parachute F10 entries
        canSlingload             = true,   -- enables hover-pickup + Slingload menus
        canTransportWholeVehicle = false,  -- whole-vehicle transport (Feature Q)
        useNativeDcsCargoSystem  = true,   -- uses DCS native cargo system for crates
        maxTroopsOnboard         = 8,      -- max soldiers (overrides ctld.numberOfTroops)
        maxCratesOnboard         = 1,      -- max crates carried simultaneously
        maxWholeVehiclesOnboard  = 0,      -- max whole vehicles carried simultaneously
    },
    ["C-130J-30"] = {
        cratesEnabled=true, troopsEnabled=true, canParachuteDrop=true, canSlingload=false,
        canTransportWholeVehicle=true, useNativeDcsCargoSystem=true, convertNativeLoadToCTLD=false,
        maxTroopsOnboard=80, maxCratesOnboard=20, maxWholeVehiclesOnboard=2,
        loadableVehiclesRED  = { "BRDM-2", "BTR_D" },
        loadableVehiclesBLUE = { "M1045 HMMWV TOW", "M1043 HMMWV Armament" },
    },
    -- ... one entry per aircraft type
}
```

**Field reference:**

| Field | Type | Description |
| --- | --- | --- |
| `cratesEnabled` | bool | Can load/spawn/unpack crates |
| `troopsEnabled` | bool | Can load/deploy infantry groups |
| `canParachuteDrop` | bool | Enables "Parachute" F10 entries |
| `canSlingload` | bool | Enables hover-pickup and "Release/Cut Slingload" menus |
| `canTransportWholeVehicle` | bool | Can load and re-deploy whole vehicles (Feature Q) |
| `useNativeDcsCargoSystem` | bool | When `true`, CTLD spawns crates as DCS cargo objects (required for C-130, CH-47, UH-1H native cargo integration). When `false`, crates are spawned directly as static objects. |
| `convertNativeLoadToCTLD` | bool | When `true`, any crate loaded via the DCS cargo UI is immediately converted to a CTLD-managed crate (destroys the DCS slot, prevents ghost crates). Set `true` for helicopters where the DCS cargo UI is accessible but CTLD parachute is needed (UH-1H, CH-47Fbl1). Leave `false` for aircraft that rely on DCS native cargo for ground ops or use DCS native parachute (C-130J-30, Il-76, Hercules). |
| `maxTroopsOnboard` | number | Max soldiers this aircraft can carry (overrides `numberOfTroops`) |
| `maxCratesOnboard` | number | Max crates loaded simultaneously (default: 1 for unlisted types) |
| `maxWholeVehiclesOnboard` | number | Max whole vehicles carried simultaneously (0 = disabled) |
| `maxVehicleWeight` | number | Max vehicle weight (kg) this aircraft can load whole; vehicles heavier than this are skipped by AI auto-pickup (WARN logged). Omit or set `nil` for unlimited. |
| `loadableVehiclesRED` | string[] | DCS type names of RED-coalition vehicles this aircraft can transport whole |
| `loadableVehiclesBLUE` | string[] | DCS type names of BLUE-coalition vehicles this aircraft can transport whole |

> When `canTransportWholeVehicle = true` and `loadableVehiclesRED/BLUE` list a vehicle type, that type appears in the **Request Equipment** F10 menu. Selecting it spawns the vehicle as a WAITING unit near the transport (instead of spawning a crate). The pilot then uses **Vehicle Commands > Load Vehicle** to embark it.
>
> Aircraft not listed in `capabilitiesByType` do not receive CTLD menus. Mod aircraft use their exact DCS type name as the key (e.g. `"Hercules"`, `"76MD"`, `"UH-60L"`).

#### Access control — addPlayerAircraftByType

| Parameter | Default | Description |
|---|---|---|
| `addPlayerAircraftByType` | `true` | Controls how CTLD decides which player units receive F10 menus |
| `transportPilotNames` | `{...}` | Whitelist of DCS unit names — active when `addPlayerAircraftByType = false`, and always used for AI transports |

**`addPlayerAircraftByType = true` (default)**
Any player whose aircraft type is listed in `capabilitiesByType` automatically receives CTLD F10 menus when they enter a slot. This is the recommended setting for open multiplayer servers.

**`addPlayerAircraftByType = false`**
Only unit names explicitly listed in `transportPilotNames` receive CTLD menus. Use this to restrict CTLD access to a fixed set of named slots — for example, a dedicated transport squadron in a controlled campaign. Players in CTLD-capable aircraft that are **not** in `transportPilotNames` join the mission normally but have no CTLD access.

> **AI transports** always use `transportPilotNames` regardless of `addPlayerAircraftByType`. Add AI unit names there to enable auto-pickup/drop-off behavior (see §5 — AI Transport).

```lua
-- Restrict CTLD to named slots only
_cfg.settings["addPlayerAircraftByType"] = false
_cfg.settings["transportPilotNames"] = {
    "transport_slot_1",
    "transport_slot_2",
    "transport_slot_3",
}
```

#### AA systems

| Parameter | Default | Description |
|---|---|---|
| `AASystemLimitBLUE` | `20` | Max active AA systems for BLUE |
| `AASystemLimitRED` | `20` | Max active AA systems for RED |
| `AASystemCrateStacking` | `false` | Allow multiple crate sets to add extra launchers (N×crates → N×launchers) |
| `aaLaunchers` | `3` | Default number of launchers per AA system when not specified in the template |

#### Beacons

| Parameter | Default | Description |
|---|---|---|
| `enabledRadioBeaconDrop` | `true` | Allow beacon deployment |
| `deployedBeaconBattery` | `30` | Beacon battery life (minutes) |
| `radioSound` | `"beacon.ogg"` | Sound file for beacon (must be added to the mission .miz) |
| `radioSoundFC3` | `"beaconsilent.ogg"` | Silent beacon file for FC3 aircraft |

#### JTAC

| Parameter | Default | Description |
|---|---|---|
| `JTAC_LIMIT_BLUE` | `10` | Max JTAC objects BLUE may spawn (definitive quota — not refilled when a JTAC is killed) |
| `JTAC_LIMIT_RED` | `10` | Max JTAC objects RED may spawn (same) |
| `JTAC_dropEnabled` | `true` | Allow JTAC crate spawn from F10 |
| `JTAC_maxDistance` | `10000` | JTAC line-of-sight range (metres) |
| `JTAC_lock` | `"all"` | Target filter: `"vehicle"` \| `"troop"` \| `"all"` |
| `JTAC_allowStandbyMode` | `true` | Allow toggling lasing on/off |
| `JTAC_laseSpotCorrections` | `true` | Lead moving targets — accounts for wind and target speed |
| `JTAC_allow9Line` | `true` | Allow 9-line requests |
| `JTAC_allowSmokeRequest` | `true` | Allow smoke-on-target requests |
| `JTAC_smokeOn_RED` | `false` | Enable smoke marking for RED JTACs |
| `JTAC_smokeOn_BLUE` | `false` | Enable smoke marking for BLUE JTACs |
| `JTAC_smokeColour_RED` | `4` | RED JTAC smoke colour — 0=Green 1=Red 2=White 3=Orange 4=Blue |
| `JTAC_smokeColour_BLUE` | `1` | BLUE JTAC smoke colour — 0=Green 1=Red 2=White 3=Orange 4=Blue |
| `JTAC_smokeMarginOfError` | `50` | Max random placement error radius (metres) for smoke |
| `JTAC_smokeOffset_x` | `0` | Fixed East/West offset (m) added to smoke position before the random error |
| `JTAC_smokeOffset_y` | `2` | Fixed vertical offset (m) — keeps smoke visible above terrain |
| `JTAC_smokeOffset_z` | `0` | Fixed North/South offset (m) added to smoke position before the random error |
| `jtacDroneRadius` | `1000` | Orbit radius (m) for drone JTAC units |
| `jtacDroneAltitude` | `7000` | Orbit altitude (m) for drone JTAC units |

##### Pre-placed JTAC groups (auto-detection)

CTLD automatically detects JTAC groups placed in the mission editor at startup. A group is recognised as a JTAC if its **group name contains `jtac`** (case-insensitive).

Examples: `jtac_blue_1`, `JTAC_Red_Forward`, `blue_jtac_drone`

> **Naming rule (mandatory):** any JTAC group placed in the mission editor **must** include `jtac` in its group name. CTLD uses the group name — not the unit type — to identify pre-placed JTACs. A group containing a Hummer or SKP-11 will NOT be detected unless its name contains `jtac`.

Late-activation JTAC groups are supported: CTLD registers them automatically when they activate during the mission.

#### RECON

| Parameter | Default | Description |
|---|---|---|
| `reconF10Menu` | `true` | Enable the RECON F10 menu |
| `reconEnabled` | `false` | Master switch — must be `true` for scan commands to work |
| `reconSearchRadius` | `5000` | LOS scan radius (metres) |
| `reconMinAltitude` | `50` | Minimum AGL altitude (m) required to perform a scan |
| `reconRefreshInterval` | `10` | Auto-refresh interval (seconds) |
| `reconIconScale` | `1.0` | Icon size multiplier (1.0 = default, 2.0 = double) |

### Customising spawnable crates

You can add new crate categories or entries without touching the defaults:

```lua
ctld = ctld or {}
ctld.yamlConfigDatas = [[...]]   -- your param overrides above

-- Add a new crate category (runs after CTLD loads)
ctld.spawnableCrates["My Vehicles"] = {
    -- singleCrate: 1 crate needed, no set shortcut generated
    { weight = 2000.01, desc = "My Custom Truck",  unit = "Ural-375",             side = 1 },
    -- singleCrate: cratesRequired=2 → auto-generates "My Custom Humvee - All crates" shortcut
    { weight = 2000.02, desc = "My Custom Humvee", unit = "M1043 HMMWV Armament", side = 2, cratesRequired = 2 },
    -- singleCrate: JTAC flag, hidden when JTAC_dropEnabled=false
    { weight = 2000.03, desc = "My Reaper JTAC",   unit = "MQ-9 Reaper",          side = 2, isJTAC = true, spawnAs = "AIRPLANE" },
    -- mixedSet: spawns multiple different crates in one click (components must be defined above)
    { mixedSet = { 2000.01, 2000.02 }, desc = "My Bundle", side = 2 },
}
```

> **Weight uniqueness:** each crate `weight` value must be globally unique across all categories — CTLD uses it as the crate identifier. Use values outside the `1000–1006` range to avoid conflicts with built-in crates.

### Crate descriptor fields

There are two entry types in `spawnableCrates`:

**singleCrate** — one deliverable unit assembled from N identical crates:

| Field | Type | Default | Description |
|---|---|---|---|
| `weight` | number | — | **Required.** Unique crate identifier (also displayed as weight in kg) |
| `desc` | string | — | **Required.** Human-readable name shown in F10 menu |
| `unit` | string | — | **Required.** DCS unit type name, or `"FOB"` sentinel for FOB crates |
| `side` | number | `nil` | `1` = RED only, `2` = BLUE only, `nil` = both coalitions |
| `cratesRequired` | number | `1` | Number of identical crates needed to unpack. When `> 1` and `enableAllCrates = true`, a shortcut entry `"<desc> - All crates"` is **automatically generated** immediately below in the menu — no manual entry needed. |
| `showSets` | boolean | `true` | Set to `false` to suppress the auto-generated "All crates" shortcut for this specific crate (useful for FOB Crate, sentinels, etc.). Only meaningful when `cratesRequired > 1`. |
| `spawnAs` | string | `"GROUND"` | DCS spawn category: `"GROUND"`, `"AIRPLANE"`, `"HELICOPTER"`, `"SHIP"`, `"TRAIN"`, `"STATIC"` |
| `isJTAC` | boolean | `false` | **JTAC role flag.** If `true`, the spawned unit starts auto-lasing immediately after unpack. For air units, an orbit route is embedded at spawn. **Only this flag activates JTAC behaviour** — unit type name is not used. All built-in JTAC entries (Hummer, SKP-11, MQ-9, RQ-1A) already carry it. |
| `specificParams` | table | `nil` | Air JTAC orbit tuning: `{ speed=kmh, alti=m_AGL, orbitRadiusNoLase=m, orbitRadiusOnLase=m }`. Only meaningful with `isJTAC=true` and `spawnAs = "AIRPLANE"/"HELICOPTER"`. |

**mixedSet** — one shortcut that spawns multiple **different** crates in a single click:

| Field | Type | Default | Description |
|---|---|---|---|
| `mixedSet` | number[] | — | **Required.** Array of singleCrate weights to spawn (all must be defined in the same category). |
| `desc` | string | — | **Required.** Name shown in F10 menu. |
| `side` | number | `nil` | Coalition filter (same as singleCrate). |

`mixedSet` entries always appear **after** all singleCrate entries in their category. They are only shown when `enableAllCrates = true`. If a weight in `mixedSet` does not match any singleCrate in the category, the entry is **excluded** and a warning is displayed in-game at mission start.

> **Menu order guarantee:** within each category, singleCrates appear first (each immediately followed by its auto-generated "All crates" shortcut if applicable), then all mixedSet entries. This order is enforced by the engine — config order within each group is preserved.
> **Menu visibility and `JTAC_dropEnabled`:** entries with `isJTAC=true` are hidden from the Request Equipment menu when `JTAC_dropEnabled = false`. A mixedSet is considered JTAC if any of its component weights resolves to a descriptor with `isJTAC=true`.

---

## 2. Translations & Localisation

### Available languages

CTLD ships with four built-in dictionaries:

| Code | Language |
|---|---|
| `en` | English (reference) |
| `fr` | French |
| `es` | Spanish |
| `ko` | Korean |

### Selecting a language

Open `src/CTLD_i18n.lua` and uncomment the desired language line:

```lua
ctld.i18n_lang = "en"
--ctld.i18n_lang = "fr"
--ctld.i18n_lang = "es"
--ctld.i18n_lang = "ko"
```

Only one line should be active at a time. This file is intentionally separate from the main scripts so that non-developer translators can edit it without touching any logic.

### Fallback chain

If a translation key is missing or empty in the active language, CTLD falls back automatically:

1. Active language dictionary
2. English dictionary
3. The key itself (= the English text)

A message is **never** empty or nil.

### Overriding specific translations from your mission

You can override any translation string directly in `CTLD_userConfig.lua`, without modifying any CTLD source file:

```lua
-- CTLD_userConfig.lua
ctld = ctld or {}

-- Override specific translations for the active language
ctld.i18n_overrides = {
    fr = {
        ["Pack Vehicles"]   = "Empaqueter vehicules",
        ["Drop Beacon"]     = "Poser balise radio",
    },
    en = {
        ["CTLD Commands"]   = "Helicopter Commands",
    },
}
```

Overrides are applied at startup on top of the built-in dictionaries. You can override any language independently of the active language selector.

### Adding a new language

1. Create `src/CTLD_i18n_XX.lua` following the English file as a template.
2. Add `CTLD_i18n_XX.lua` to `tools/build/listToMerge.txt` (after the other dict files).
3. Activate the new language in `CTLD_i18n.lua`.
4. Run `tools/build/generate_i18n_dicts.ps1` to check for missing keys.

---

## 3. Scene Deployment

### What it is
A **Scene** is a sequenced, time-delayed deployment of multiple DCS objects (statics and/or ground groups) triggered automatically when a player unpacks a designated crate. It allows mission makers to simulate realistic deployments — a FARP materializing piece by piece, a minefield being laid out — without any scripting beyond declaring the scene model.

### How it works
A scene is defined as an ordered list of **steps**.  Each step is one of three types:

#### Polar step — deterministic position
Object is spawned at a fixed distance and angle relative to the helicopter's position and heading (snapshot taken at unpack time).

| Field | Type | Description |
|---|---|---|
| `objectsDescDbKey` | string | Key of the object to spawn (see table below) |
| `polar` | table | `{ distance=N, angle=N }` — distance in metres, angle in degrees relative to aircraft heading |
| `relativeHeadingInDegrees` | number | Heading of the spawned object relative to aircraft heading |
| `relativeAltitudeInMeters` | number | Altitude offset from helicopter altitude |
| `delayAfterPreviousStep` | number | Seconds to wait after this step before triggering the next |
| `func` | function *(optional)* | Callback `function(unit, spawnedObj, step)` executed after spawn |

#### Axis step — random-axis position
Object(s) are spawned along a randomly chosen axis radiating from the helicopter.  Useful when the mission maker wants placement that looks natural without hard-coding a bearing.

| Field | Type | Description |
|---|---|---|
| `objectsDescDbKey` | string | Key of the object to spawn |
| `axis` | table | `{ count=N, safeDistance=N, spacing=N }` — number of objects, distance to first object (m), spacing between objects (m) |
| `delayAfterPreviousStep` | number | Seconds to wait before next step |
| `func` | function *(optional)* | Callback `function(unit, spawnedObj, step)` — `spawnedObj` is the last object spawned |

#### Func-only step — no spawn
No object is spawned; only the callback runs.  Use for completion messages, warehouse stocking, zone registration, etc.

| Field | Type | Description |
|---|---|---|
| `delayAfterPreviousStep` | number | Seconds to wait before next step |
| `func` | function | Callback `function(unit, spawnedObj, step)` — `spawnedObj` is always `nil` |

All positioning is computed automatically relative to the helicopter's position and heading at the moment of unpacking. Coalition (BLUE/RED) is resolved automatically for coalition-aware objects (vehicles, infantry).

### What you need to do as a mission maker

**Step 1** — Declare your scene model in a mission script loaded after CTLD:
```lua
local myScene = {
    name  = "My FARP",
    steps = {
        -- polar step: helipad 100 m ahead, facing south relative to helicopter
        { objectsDescDbKey = "SINGLE_HELIPAD", polar = { distance=100, angle=0   },
          relativeHeadingInDegrees=180, relativeAltitudeInMeters=0, delayAfterPreviousStep=0 },
        -- polar step: tent 130 m ahead-right, 3 s after helipad
        { objectsDescDbKey = "FARP_Tent",      polar = { distance=130, angle=5   },
          relativeHeadingInDegrees=90,  relativeAltitudeInMeters=0, delayAfterPreviousStep=3 },
        -- axis step: scatter 3 ammo crates randomly around the helicopter
        { objectsDescDbKey = "ammo_cargo", axis = { count=3, safeDistance=30, spacing=8 },
          delayAfterPreviousStep=5 },
        -- func-only step: print completion message
        { delayAfterPreviousStep=0,
          func = function(unit, spawnedObj, step)
              trigger.action.outText("FARP ready at " .. unit:getName(), 10)
              return true
          end },
    },
}
CTLDSceneManager.getInstance():registerSceneModel(myScene)
```

**Step 2** — Add a crate entry in `CTLD_userConfig.lua` using the exact scene name as the `unit` field:
```lua
ctld.spawnableCrates["My Deployments"] = {
    { weight = 1008.01, desc = "My FARP", unit = "My FARP", cratesRequired = 1 },
}
```

**Step 3** — In the mission, make sure the crate is available at a logistics zone. Players load the crate, fly to the desired location, unpack it — the scene plays automatically.

### Available objects (`objectsDescDbKey`)
`FARP`, `SINGLE_HELIPAD`, `FARP_Tent`, `FARP_Ammo_Storage`, `Fuel_Truck`, `repare_Truck`, `FARP_Security_Guard`, `barrels_cargo`, `ammo_cargo`, `Cargo06`, `NF-2_LightOn`, `Windsock`, `Tower Crane`, `us carrier shooter`
> `Farp_FG_Petit_Helipad` requires a specific external mod — only use if the mod is installed on all clients.

### Built-in scenes (ready to use)
| Scene name | Description |
|---|---|
| `FARP Alpha` | Full FARP deployment: helipad, tent, ammo dump, fuel truck, repair truck, security squad, decor |
| `Countryside FARP` | Invisible-FARP heliport + tent + trucks + guards + lights. Warehouse is zeroed (visual FARP, no fuel service by default). Supports repack. |
| `Metal FARP` | Metallic helipad (requires `Farp_FG_Petit_Helipad` mod) + tent + trucks + lights. Warehouse stocked with 10 000 L × 4 fuel types. Supports repack. |
| `mineField` | Lays a configurable grid of landmines in front of the helicopter, marked on the F10 map |
| `FOB` | Forward Operating Base: outpost structure + watchtower, deployed from FOB crates |

### FARP Repack (`enableFARPRepack`)

When `enableFARPRepack = true` (default), a **Pack Equipt** submenu appears under **Crate Commands** whenever the player is on the ground within 300 m of a deployed FARP scene that supports repack. Selecting it:

1. Captures the current fuel levels from the FARP warehouse (snapshot).
2. Destroys all spawned scene objects.
3. Spawns the required crates near the helicopter, carrying the warehouse snapshot in their metadata.

When those crates are later unpacked at a new location, the warehouse is restored to the captured levels instead of using the defaults.

**Configuration:**
```lua
cfg.settings["enableFARPRepack"] = false  -- default: true (set to false to disable)
```

**Supported scenes:** `Countryside FARP`, `Metal FARP`.

**Custom scenes:** Add an `onRepack` function to your scene model to enable repack support:
```lua
myScene.onRepack = function(scene, repackData)
    -- Read current state before objects are destroyed.
    -- Store anything you want restored on next deploy in repackData.
    local farpName = scene._params and scene._params.farpName
    if not farpName then return end
    local ab = Airbase.getByName(farpName)
    if not ab then return end
    local w = ab:getWarehouse()
    repackData.warehouseSnapshot = {
        liquid = { [0]=w:getLiquidAmount(0), [1]=w:getLiquidAmount(1), [2]=w:getLiquidAmount(2), [3]=w:getLiquidAmount(3) }
    }
end
```

In your warehouse step, check `ctx.scene._params.repackData` to decide whether to restore or use defaults:
```lua
local snap = ctx.scene._params.repackData and ctx.scene._params.repackData.warehouseSnapshot
if snap and snap.liquid then
    for fuelType = 0, 3 do
        w:setLiquidAmount(fuelType, snap.liquid[fuelType] or 0)
    end
else
    -- first deployment: apply defaults
    w:addLiquid(0, 10000)
end
```

---

## 4. Zone Setup

CTLD zones are declared directly in the **DCS Mission Editor** by naming your trigger zones with a structured convention. No scripting is required.

### 4.1 Naming convention

The zone name encodes its type and all parameters, separated by `_`.

> **Rule:** The `_` character is the field separator. It is **forbidden** inside any field value (zone name, flag name, etc.).

```
TYPE_name_param1_param2_..._paramN
```

CTLD reads all trigger zone names at mission start, parses those that match a known prefix, and registers them automatically.

### 4.2 Zone types and schemas

Four zone prefixes are recognised by CTLD and auto-discovered from DCS trigger zone names:

| Prefix | Zone type | Schema |
|---|---|---|
| `TRZ` | Troop zone — pickup and/or extract objective | `TRZ_name_A/R/B/N_stock_flag_target` — **all 5 fields required** |
| `IAZ` | AI drop-off zone — AI transport auto-deploys troops here | `AIZ_name_[R/B/N]` |
| `WPZ` | Waypoint zone — troops deployed inside march to zone centre | `WPZ_name_[R/B/N]` |
| `LGZ` | Logistic zone — crate and vehicle services | `LGZ_name_[R/B/N]` |

**Coalition parameter:**

| Value | Coalition |
|---|---|
| `A` | All coalitions (TRZ only) |
| `R` | RED only |
| `B` | BLUE only |
| `N` | Neutral |
| *(omit)* | All coalitions (IAZ/WPZ/LGZ only — TRZ requires explicit `A`) |

> **Uniqueness:** two zones of the same prefix cannot share the same `name`.

---

### 4.3 TRZ — Troop zone

A troop zone provides **player pickup** and/or **extract-objective** functions.

**All 5 fields are required.** The parser rejects any TRZ name that has missing or invalid fields — a warning is written to `CTLD.log` and the zone is ignored.

**Schema:** `TRZ_<name>_<A|R|B|N>_<stock>_<flag>_<target>`

| Field | Position | Type | Values | Meaning |
|---|---|---|---|---|
| `name` | 2 | string | any (no underscores, not a reserved word) | Zone identifier used in logs and F10 menus |
| `coalition` | 3 | letter | `A` `R` `B` `N` | Who can interact: **A**=all, **R**=RED, **B**=BLUE, **N**=NEUTRAL |
| `stock` | 4 | integer 0–999 | `0`=no pickup · `1–998`=limited · `999`=unlimited | Troop boarding capacity |
| `flag` | 5 | string | DCS flag name or `nil` | Flag incremented by soldier count on extract; `nil` = no objective |
| `target` | 6 | integer ≥0 | `0`=no threshold · `N≥1`=soldier count goal | Win condition threshold (checked by DCS triggers, not CTLD) |

> **Reserved words** — forbidden as `name` or `flag`: `nil`, `A`, `R`, `B`, `N`.

---

#### Stock values explained

| Name value | Pickup capability | What the player sees |
|---|---|---|
| `0` | **None** — no pickup | No "Load from" entry in the F10 menu |
| `1–998` | Limited — decrements on each load | "Load from `<name>` (N remaining)" |
| `999` | **Unlimited** — never exhausted | "Load from `<name>`" |

> Use `999` for unlimited pickup — **not** `0`. `0` means no pickup capability.

#### Flag / target values explained

| Flag value | Target value | Behaviour |
|---|---|---|
| `nil` | any | Zone has no objective. Troops deployed here spawn as a DCS ground group. |
| a flag name | `0` | Objective is active, no defined threshold. Flag is incremented by soldier count. No win condition checked by CTLD. |
| a flag name | `N≥1` | Objective with threshold. CTLD increments the flag; the mission maker defines the DCS victory trigger `if flag >= N`. |

---

#### Examples

| Zone name | Coalition | Stock | Flag | Target | Zone type |
|---|---|---|---|---|---|
| `TRZ_base_B_50_nil_0` | BLUE | 50 (limited) | — | — | **Pickup** — 50 soldiers, restock on RTB |
| `TRZ_depot_A_999_nil_0` | All | unlimited | — | — | **Pickup** — unlimited, all coalitions |
| `TRZ_exfil_B_0_rescue_0` | BLUE | no pickup | `rescue` | no threshold | **Extract-only** — troops deployed here increment flag `rescue` |
| `TRZ_lz_R_0_secure_100` | RED | no pickup | `secure` | 100 soldiers | **Extract with win condition** — RED objective at 100 soldiers |
| `TRZ_fob_N_20_defend_50` | NEUTRAL | 20 (limited) | `defend` | 50 soldiers | **Mixed** — pickup (20) + extract objective |
| `TRZ_marker_B_0_nil_0` | BLUE | no pickup | — | — | **Inert** — BLUE named marker, no function |

---

#### Annotated example: `TRZ_fob_N_20_defend_50`

```
TRZ  _  fob  _  N   _  20     _  defend  _  50
 │      │       │      │          │          │
 │      │       │      │          │          └─ target : 50 soldiers complete the objective
 │      │       │      │          └──────────── flag   : "defend" (DCS flag name)
 │      │       │      └─────────────────────── stock  : 20 troops max (limited pickup)
 │      │       └────────────────────────────── coalition: NEUTRAL
 │      └────────────────────────────────────── name   : "fob"
 └───────────────────────────────────────────── prefix TRZ
```

#### Annotated example: `TRZ_depot_A_999_nil_0`

```
TRZ  _  depot  _  A   _  999      _  nil     _  0
                           │           │          │
                           │           │          └─ target : 0 → no win condition
                           │           └──────────── flag   : "nil" → no objective
                           └──────────────────────── stock  : 999 → unlimited pickup
```

#### Annotated example: `TRZ_lz_R_0_secure_100`

```
TRZ  _  lz  _  R    _  0         _  secure  _  100
                        │                        │
                        │                        └─ target : 100 soldiers needed
                        └──────────────────────── stock  : 0 → extract-only (no pickup)
```

---

> **Extract-only zone** (`stock=0`): `hasPickup() = false`. No "Load from" entry in the F10 menu. Only serves as an objective trigger when troops are deployed inside.
>
> **Mixed zone** (stock>0 + flag≠nil): supports both boarding and objective scoring. When a player lands inside with troops, **the objective takes priority**: the flag is incremented and **no** DCS group is spawned. RTB (stock restore) is triggered only in pickup-only zones.
>
> **Smoke signals:** troop zone smoke is configured globally via `troopZoneSmokeColor` config, not per zone name.

---

### 4.4 AIZ — AI transport zones (pickup + drop-off)

AIZ zones control the automatic behaviour of AI transports (units listed in `transportPilotNames`). Human players are never affected by AIZ zones.

> **All AIZ zones are declared by config** — there is no naming convention. Any DCS trigger zone can be used as an AIZ zone; just reference its name in `cfg.settings["aiZones"]`.

#### Zone roles

| Role | Trigger | Behaviour |
|---|---|---|
| **Pickup** | AI transport lands inside zone | Loads troops and/or a whole vehicle onto the AI transport |
| **Drop-off** | AI transport lands inside zone | Deploys troops and/or unloads a whole vehicle |

A zone may be declared as pickup only, drop-off only, or both simultaneously.

#### Config declaration

Zones are declared in `cfg.settings["aiZones"]`, an array of entries:

```lua
_cfg.settings["aiZones"] = {
    -- Troops-only pickup, max 5 sorties
    { dcsZoneName = "my_base",     coalition = "BLUE",
      isPickup = true, cargoType = "T", troopStock = 5 },

    -- Vehicle-only pickup (vehicles must be physically in zone)
    { dcsZoneName = "depot_alpha", coalition = "BLUE",
      isPickup = true, cargoType = "V" },

    -- Troops + vehicle pickup (T stock=5, vehicles unlimited)
    { dcsZoneName = "hub_tv",      coalition = "BLUE",
      isPickup = true, cargoType = "TV", troopStock = 5 },

    -- Ground drop-off only
    { dcsZoneName = "lz_front",    coalition = "BLUE",
      isDropoff = true, aiDropMode = "G" },

    -- Ground + parachute drop-off (default)
    { dcsZoneName = "lz_rear",     coalition = "BLUE",
      isDropoff = true },
}
```

#### All pickup parameters

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `dcsZoneName` | string | ✅ | Exact name of the DCS trigger zone in the ME |
| `coalition` | `"RED"` / `"BLUE"` / `"NEUTRAL"` | ✅ | Controls which AI transports use this zone |
| `isPickup` | `true` | at least one | Designates zone as a pickup zone |
| `isDropoff` | `true` | at least one | Designates zone as a drop-off zone |
| `cargoType` | `"T"` / `"V"` / `"TV"` | pickup only | What the AI loads: troops, whole vehicle, or both. Default: `"T"` |
| `troopStock` | integer | pickup+T | `N` = max N sorties; `-1` = unlimited; `0` or absent = no stock check (unlimited) |
| `vehicleStock` | integer | pickup+V | Max vehicle pickups; absent = unlimited |
| `aiDropMode` | `"G"` / `"P"` / `"GP"` | drop-off | How troops are deployed. `G` = ground; `P` = parachute; `GP` = either. Default: `"GP"` |
| `troopTemplates` | `{"Name1", ...}` | optional | Whitelist of troop template names. Only listed templates are eligible at this zone. If absent, any compatible template may be picked. |
| `vehicleTypes` | `{"TypeName", ...}` | optional | Whitelist of DCS vehicle type names present in the zone. Only listed types are eligible for loading. If absent, any loadable vehicle qualifies. |

#### Controlling which troop template is loaded

By default, the AI transport selects the first compatible template (or a random one if `allowRandomAiTeamPickups = true`). Use `troopTemplates` to restrict which templates are eligible at a given zone:

```lua
{ dcsZoneName = "spec_ops_base", coalition = "BLUE",
  isPickup = true, cargoType = "T", troopStock = 5,
  troopTemplates = { "Spec Ops Group", "Anti Tank" } },
```

If the whitelist does not match any template currently in `_aiTeams`, the pickup is skipped and a `WARN` is logged.

#### Controlling which vehicle is loaded

Use `vehicleTypes` to restrict which vehicle types the AI may pick up at a given zone:

```lua
{ dcsZoneName = "armor_depot", coalition = "BLUE",
  isPickup = true, cargoType = "V",
  vehicleTypes = { "Hummer", "M1025 HMMWV Armament" } },
```

Only vehicles of the listed DCS type names (physically present in the zone and registered with CTLD) are eligible for loading.

#### Weight compatibility

A whole vehicle is only loaded if its weight (from `groundVehicleWeights`) does not exceed `maxVehicleWeight` for the transport aircraft. If no vehicle passes the weight check, a `WARN` is written to `CTLD.log` — the AI transport is **not blocked**.

#### AI transport setup

1. Create trigger zones in the DCS ME (any name, any radius suitable for landing).

2. Declare zones in `cfg.settings["aiZones"]` (see above).

3. Add the AI unit's **exact DCS unit name** to `transportPilotNames`:

```lua
_cfg.settings["transportPilotNames"] = {
    ["heliai_supply"] = true,
    ["heliai_medevac"] = true,
}
```

1. Route the AI unit so it lands inside the zones (waypoints with "Landing" task).

> Both pickup and drop-off use `S_EVENT_LAND` — the trigger fires at the **exact moment of touchdown**. The AI unit must physically land inside the zone radius.

#### Validation report

At mission start, CTLD validates all entries in `cfg.settings["aiZones"]` and displays a report on screen and in `CTLD.log`. The report is shown in the mission language (EN/FR/ES/KO).

| Code | Severity | Trigger | Action |
| --- | --- | --- | --- |
| G1 | ERROR | Entry has no `dcsZoneName` | Entry ignored |
| G2 | ERROR | `dcsZoneName` is a duplicate | Entry ignored |
| G3 | ERROR | Entry has no `coalition` | Entry ignored |
| G4 | ERROR | `coalition` is not `"BLUE"` or `"RED"` | Entry ignored |
| G5 | ERROR | Neither `isPickup` nor `isDropoff` is set | Entry ignored |
| Fix5 | WARN | `isPickup=true` but `cargoType` missing or invalid | Default `"T"` applied |
| Fix6 | WARN | `isDropoff=true` but `aiDropMode` missing or invalid | Default `"GP"` applied |
| Overlap | WARN | A zone is both pickup and drop-off for the same coalition | Risk of instant pickup+drop-off loop |

If there are no errors and no warnings, a single `INFO` line is written to `CTLD.log` (no screen popup).

---

### 4.5 WPZ — Waypoint zone

When troops are deployed (fast-rope or ground drop) at a point that falls **inside** an active WPZ zone, they automatically march toward the **centre** of the zone instead of searching for the nearest enemy.

**Schema:** `WPZ_name_[R/B/N]`

| Example name | Meaning |
|---|---|
| `WPZ_hill47_B` | BLUE waypoint zone "hill47" |
| `WPZ_bridge` | All-coalition waypoint zone |

> WPZ zones do **not** appear in the F10 load menu — they act silently at deploy time.

---

### 4.6 LGZ — Logistic zone

Defines a logistics base. Players must be inside a logistic zone to spawn crates from the F10 menu. Resources are unlimited (rate-limited to one crate per 40 seconds per player). Zone radius is set in the DCS trigger zone editor.

**Schema:** `LGZ_name_[R/B/N]`

| Example name | Meaning |
|---|---|
| `LGZ_depot1_B` | Logistic zone "depot1", BLUE only |
| `LGZ_farmmain_R` | Logistic zone "farmmain", RED only |
| `LGZ_shared` | Logistic zone open to all coalitions |

> **Rule:** `_` is forbidden inside `name`. Use `farmmain` not `farp_main`.

> **Creating a logistic zone at runtime:** the only way to add a new LGZ during a live mission is to deploy a FOB. When the FOB build sequence completes, CTLD automatically registers a circular logistic zone centered on the FOB site (radius = `fobLogisticZoneRadius`, default 150 m, under the FOB's name). No `LGZ_` trigger zone or config entry is required.
>
> **FOB LGZ destruction:** when enemy forces destroy more than `fobDestructionThreshold` (default 50 %) of the FOB scene objects, the FOB is considered lost — its logistic zone is immediately removed and the `OnFOBDestroyed` event fires. The threshold is a fraction (0.0–1.0): at 0.5, losing 3 of 5 structures removes the zone; the FOB does not need to be fully wiped out. See §12 for full details.

#### Deactivating / reactivating a logistic zone at runtime

Use the `CTLDZoneManager` API from a DO SCRIPT trigger to simulate zone capture or temporary loss:

```lua
-- Deactivate — zone ignored by all players until reactivated
CTLDZoneManager.getInstance():deactivateLogisticZone("depot1")

-- Reactivate — zone becomes available again
CTLDZoneManager.getInstance():activateLogisticZone("depot1")
```

This works for both `LGZ_` trigger zones and `logisticUnits`-based zones. The zone remains registered and can be toggled any number of times. An `OnLogisticZoneUpdated` event is fired on each call.

---

### 4.7 Legacy zone configuration (backward compatibility)

Missions using the classic CTLD v1 approach (zone names in config tables, not DCS trigger name parsing) are still supported. Declare zones in `CTLD_userConfig.lua` using the config tables below. The `_` character is allowed in zone names here — these are plain DCS trigger zone names, not parsed schemas.

**Pickup zones** (`pickupZones`):

```lua
-- { "DCS zone name", "smoke color", limit, "active", side }
-- smoke color: "none"|"green"|"red"|"white"|"orange"|"blue"
-- limit: -1 = unlimited, or any integer >= 1
-- active: "yes" | "no"
-- side: 0 = both, 1 = RED, 2 = BLUE
ctld.pickupZones = {
    { "pickzone1",  "blue",  -1, "yes", 0 },
    { "pickzone2",  "red",   -1, "yes", 2 },
    { "USS Tarawa", "blue",  10, "yes", 2 },  -- ship unit name also accepted
}
```

**Drop-off zones** (`dropOffZones`) — AI auto-deploy points:

```lua
-- { "DCS zone name", "smoke color", side }
ctld.dropOffZones = {
    { "dropzone1", "green", 2 },
    { "dropzone2", "none",  0 },
}
```

**Waypoint zones** (`wpZones`) — deployed troops march toward the zone centre:

```lua
-- { "DCS zone name", "smoke color", "active", side }
ctld.wpZones = {
    { "wpzone1", "green", "yes", 2 },
}
```

**Logistic units** (`logisticUnits`) — crate services tied to a DCS unit or static object:

```lua
-- List of unit or static names placed in the mission editor.
-- If the named object is destroyed, its logistic zone is automatically removed.
ctld.logisticUnits = { "logistic1", "logistic2" }
```

> Legacy zones and auto-discovered zones (TRZ/IAZ/WPZ/LGZ) coexist without conflict. A zone already registered from trigger name discovery is never overwritten by legacy config.

---

### 4.8 Debug log (developers / mission testers)

Enable the dedicated CTLD log file to isolate CTLD messages from the DCS standard log:

```lua
-- CTLD_userConfig.lua
ctld.yamlConfigDatas = [[
  ctld.debug: true
  ctld.ctldLogPath: "C:\\Users\\<you>\\path\\to\\CTLD_Next\\tests\\dcs\\"
]]
```

CTLD writes all its log output to `<ctldLogPath>CTLD.log`. The DCS standard log is unaffected.

> **Requirement: desanitized DCS.** File I/O (`io.open`) is blocked on standard sanitized DCS installations. Keep `ctld.debug: false` (the default) on those machines — CTLD will log to the standard DCS log only and will not crash.

---

## 5. Troop Transport

### Overview

CTLD transports infantry teams between TroopZones (TRZ_) and combat areas. The full operational cycle is:

```
1. embarkFromTroopZone  — board troops from a TRZ pickup zone        → TRZ_LOADED
2. disembark            — fast-rope or ground-drop at any location     → DEPLOYED
                          (if inside EXZ_ zone: dispatchToEXZ → DEPLOYED_EXZ)
3. embarkFromField      — land near a dropped group and pick it up    → FIELD_LOADED
4. disembark            — drop the extracted group at a new location  → DEPLOYED
                          (repeatable steps 3–4 as needed)
5. returnToTroopZone    — unload inside a TRZ to return troops        → RETURNED_TO_TRZ
                          (zone stock restored)
```

Troops are **never** physically on board the aircraft as DCS units — they are held in
memory until deployed. JTAC soldiers are tracked individually: one `CTLDJTAC` instance
per alive JTAC unit, managed through the `_jtacUnits` map in `CTLDTroopGroup`.

> **Troop transport flows diagram** — all boarding, deploy, extract, and parachute flows with
> context-sensitive disembark logic, JTAC actions, and AI transport:
> [docs/assets/troops_transport_flows.svg](assets/troops_transport_flows.svg)
>
> **Troop + JTAC lifecycle reference diagram** — complete state machine with all
> transitions, per-unit JTAC tracking, and `_aliveUnits` / `_jtacUnits` details:
> [docs/assets/troops_jtac_lifecycle.svg](assets/troops_jtac_lifecycle.svg)

---

### F10 menu — "Troop Commands"

The menu appears automatically for all transport-capable aircraft (types listed in `capabilitiesByType` config).

```
CTLD
  └── Troop Commands                         ← rebuilt on landing/takeoff
        ├── Disembark Troops                 ← single group: direct action
        │   or Disembark Troops (submenu)    ← if 2+ groups onboard:
        │       ├── Disembark All            ←   deploy all groups in sequence
        │       ├── [1] Standard Group       ←   deploy group at index 1
        │       └── [2] Anti Air             ←   deploy group at index 2
        ├── Embark / Extract Troops          ← always present on ground
        │     ├── Load from <zone1>          ←   one sub-menu per TRZ pickup zone the player is inside
        │     │     ├── Load Standard Group  ←     templates filtered by remaining capacity
        │     │     └── ...
        │     ├── Extract: <group name>      ←   single nearby group: direct button
        │     │   or Extract from field      ←   if 2+ groups nearby: submenu with distances
        │     │       ├── GroupA (25m)
        │     │       └── GroupB (87m)
        │     └── (disabled if nothing to load or extract)
        ├── Check Cargo                      ← count + weight of all onboard groups
        └── Parachute Troops                 ← single group: direct
            or Parachute Troops (submenu)    ← if 2+ groups: submenu + "Parachute All"
```

> The menu is rebuilt automatically on every landing and takeoff, and immediately after each embark/disembark operation.
> "Embark / Extract Troops" is greyed out if the aircraft is at capacity, if no TRZ pickup zone is within range, and if no friendly group is within `maxExtractDistance` metres.

**"Disembark Troops" context logic (priority order):**

| Aircraft state | Action |
|---|---|
| In flight | Button not shown |
| On ground + inside a TRZ with `flag` (objective zone) | Silent drop → objective counter incremented, no DCS group spawned |
| On ground + inside a TRZ pickup-only (no flag) | Return troops to TroopZone — zone stock restored |
| On ground + not in any TRZ | Fast-rope (if conditions met) or ground drop into combat |

**Multi-group transport:** players may load multiple groups sequentially as long as the cumulative troop count stays within the aircraft's capacity (`numberOfTroops` or per-type override). Each group is tracked independently. The disembark and parachute menus automatically switch to per-group submenus when two or more groups are onboard.

---

### Configuring loadable groups

Define the infantry templates available to players in `CTLD_userConfig.lua`:

```lua
ctld.loadableGroups = {
    { name = "Standard Group",  inf = 6, mg = 2, at = 2 },
    { name = "Anti Air",        inf = 2, aa = 3 },
    { name = "Anti Tank",       inf = 2, at = 6 },
    { name = "Mortar Squad",    mortar = 6 },
    { name = "JTAC Group",      inf = 4, jtac = 1 },
    { name = "Single JTAC",     jtac = 1 },
    -- side = 1 → RED only, side = 2 → BLUE only, omit for both
    { name = "BLUE Stingers",   inf = 2, aa = 4, side = 2 },
}
```

**Role keys:**

| Key | Unit type (BLUE / RED) | Equipment weight |
|---|---|---|
| `inf` | Soldier M4 GRG / Infantry AK | +5 kg |
| `mg` | Soldier M249 / Paratrooper AKS-74 | +10 kg |
| `at` | Paratrooper RPG-16 (both sides) | +7.6 kg |
| `aa` | Soldier stinger / SA-18 Igla manpad | +18 kg |
| `mortar` | 2B11 mortar (both sides) + 1 servant soldier per tube | +26 kg |
| `jtac` | Same model as `inf`, name tagged "JTAC" | +15+5 kg |

> A template with `jtac > 0` automatically triggers JTAC lasing upon deployment (laser code attributed by CTLDJtacManager).
>
> **Mortar servants:** each `mortar` unit spawns one additional infantry "crew member" (servant) positioned within 1 m of the tube. Servants are cosmetic — they do not count toward the troop capacity limit, zone stock, or the `unitTotal` displayed in Check Cargo.

#### Post-deploy task (`specificParams.task`)

Adding `specificParams = { task = "..." }` to a template makes the spawned group automatically receive a route or behaviour 2 seconds after landing.

| Value | Behaviour |
|---|---|
| `"gotoNearestWPZ"` | Group marches toward the center of the nearest active `WPZ_` zone for its coalition. No movement if no WPZ exists. |
| `"AttackNearestEnemyOnLos"` | Group advances toward the nearest enemy unit within 10 km with line-of-sight. No movement if no visible enemy is found. |
| *(absent / nil)* | No task assigned after spawn (default). |

In both cases the group is set to ROE `OPEN_FIRE` and alarm state `AUTO`.

```lua
ctld.loadableGroups = {
    -- Standard groups (no post-spawn task)
    { name = "Standard Group", inf = 6, mg = 2, at = 2 },
    -- Assault team: automatically advance toward nearest visible enemy
    { name = "Assault Team",   inf = 6, mg = 2, at = 2,
      specificParams = { task = "AttackNearestEnemyOnLos" } },
    -- Advance guard: march to the nearest waypoint zone
    { name = "Advance Guard",  inf = 4, at = 2,
      specificParams = { task = "gotoNearestWPZ" } },
}
```

> The task is also re-applied after a field extraction and re-deployment: `specificParams` is preserved through the `_droppedTemplates` mechanism.

---

### Key configuration parameters

| Parameter | Default | Description |
|---|---|---|
| `numberOfTroops` | `10` | Max troops per transport (applies to all aircraft unless overridden per type) |
| `enableFastRopeInsertion` | `true` | Allow fast-rope deployment (altitude + speed conditions required) |
| `fastRopeMaximumHeight` | `18.28` | Max AGL height (m) for fast-rope (≈ 60 ft) |
| `spawnDistanceInCircle` | `10` | Extra distance (m) added to aircraft safe-distance for the troop formation circle radius |
| `maxExtractDistance` | `125` | Max radius (m) to search for extractable friendly groups |
| `nbLimitSpawnedTroops` | `{0, 0}` | `{red, blue}` — max simultaneous troops in the field per coalition. `0` = unlimited |

All per-aircraft capacities (troop limit, crate limit, vehicle transport, parachute, slingload) are now configured through the unified `capabilitiesByType` table — see [§1 capabilitiesByType](#capabilitiesbytype) for the full reference.

---

### Troop formation at drop point

When troops are deployed, CTLD spawns the DCS group in a **circle** centred on the drop point. The radius is:

```
circleRadius = aircraft bounding-box half-length + ctld.gs("spawnDistanceInCircle")
```

This ensures infantry never spawns inside or under the aircraft. Larger aircraft (CH-47, C-130) automatically produce a larger circle. Units are evenly distributed around the circumference and all face the same heading as the deploying aircraft.

---

### Fast-rope conditions

Fast-rope deploys troops while the aircraft is still airborne. Conditions:

- `enableFastRopeInsertion = true`
- AGL altitude ≤ `fastRopeMaximumHeight + 3 m`
- Ground speed < 2.2 m/s (≈ 8 km/h)

If conditions are not met while airborne, CTLD refuses deployment and shows an error message. Land the aircraft to drop troops unconditionally.

---

### Extract objective zones

When troops are deployed inside a TRZ that has a `flag` defined, **no DCS group is spawned**. Instead, the troop count is added to the zone's DCS flag. Use this to score evacuations or trigger mission phases.

See [§4.3 TRZ](#43-trz--troop-zone) for zone naming and flag conventions.

---

### Pre-placed extractable groups (`extractableGroups`)

CTLD can make **existing DCS mission editor groups** available for field extraction, without using a TRZ pickup zone.

**Use case:** a squad of troops is placed directly on the map in a hostile area. Players must fly in, land, and extract them via the F10 "Embark / Extract Troops" menu — exactly as if those troops had been deployed by CTLD.

**Configuration** — in `CTLD_userConfig.lua`, list the DCS group names to register:

```lua
_cfg.settings["extractableGroups"] = {
    "rescue_team_alpha",
    "rescue_team_bravo",
    "downed_pilot_1",
}
```

At mission start, CTLD scans each name via `Group.getByName()`. Groups that exist are immediately added to the extractable pool for the matching coalition. Groups that cannot be found are skipped with a warning in `CTLD.log`.

**Behaviour:**

- No TRZ zone required — extraction works anywhere within `maxExtractDistance` of the transport
- Weight defaults to 130 kg per alive unit (no template on record)
- No late-activation: groups that are not yet active at CTLD init are not registered

**Default value:** 25 preset names `extract1` … `extract25` (matching the legacy convention).

---

## 6. Virtual Parachute Drop

CTLD can simulate parachute drops for crates, troops, and vehicles without relying on DCS physics. When a player activates a parachute drop from the F10 menu, each unit or crate is immediately removed from the transport and scheduled to land at a computed ground position after a simulated descent time.

### 6.1 Enabling parachute drops per aircraft

Parachute menus are **hidden by default**. Enable them individually for each aircraft type via `canParachuteDrop = true` in `capabilitiesByType`:

```lua
_cfg.settings["capabilitiesByType"] = {
    ["UH-1H"]     = { ..., canParachuteDrop = true  },
    ["CH-47Fbl1"] = { ..., canParachuteDrop = true  },
    ["Mi-8MT"]    = { ..., canParachuteDrop = false },
    -- ...
}
```

When `canParachuteDrop = true`, up to three F10 menu entries become available. Each appears **only in flight** and only when the relevant cargo is onboard:

- **Parachute Crates** — drops all CTLD-loaded crates (excludes crates in active virtual slingload)
- **Parachute Troops** — drops all embarked troops
- **Parachute Vehicle** — drops the loaded whole vehicle

> **Restriction — DCS native cargo:** crates loaded via the **DCS standard cargo UI** (not the CTLD F10 menu) are **excluded from the Parachute Crates menu**, even if CTLD has detected and claimed them in-flight. This is a hard DCS limitation: no API exists to free an aircraft cargo slot in-flight, so calling `destroy()` on a native cargo would permanently block the slot for the session. Players must use the CTLD F10 "Load Crate" menu to load crates that they intend to parachute.

#### Per-aircraft crate parachute behavior

The way crates are parachuted differs fundamentally between aircraft types, controlled by the `convertNativeLoadToCTLD` flag:

| Aircraft type | `convertNativeLoadToCTLD` | Crate parachute method | 3D animation |
| --- | --- | --- | --- |
| C-130J-30, Il-76, Hercules | `false` | **DCS native parachute action** — use the aircraft built-in DCS parachute function. DCS handles the descent and renders a 3D parachute attached to each crate. CTLD claims the crates on landing. | Yes (DCS engine) |
| UH-1H, CH-47Fbl1 | `true` | **CTLD F10 "Parachute Crates" menu** — crates loaded via the DCS cargo UI are immediately converted to CTLD-managed at load time. Use the CTLD F10 menu to drop; DCS native parachute has no effect on CTLD-managed crates. | No (virtual drop) |
| Mi-8MT, Mi-24P | n/a | **None** (`canParachuteDrop = false`) — no parachute option for crates; ground deploy only. | No |

> **C-130 workflow:** load crates via the DCS cargo station or CTLD F10 "Load Crate" menu, climb to drop altitude, then use the **C-130 DCS native parachute function** (not the CTLD F10 "Parachute Crates" entry). The crates descend with full 3D parachute animation and are automatically registered by CTLD when they land.
>
> **UH-1H / CH-47 workflow:** load crates via the CTLD F10 "Load Crate" menu (or DCS cargo UI — CTLD auto-converts), climb to drop altitude, then use **F10 > Helicopter Commands > Parachute Crates**. No 3D animation; crates are placed at the computed landing position after a simulated descent delay.

All three share the same altitude gate: the action is refused (with an on-screen message) if the aircraft is below the configured minimum AGL for that payload type.

### 6.2 Landing position algorithm

Each dropped unit lands at a position computed from:

1. **Inertia** — forward drift inherited from transport velocity, scaled by `parachuteInertiaFactor × descentTime`
2. **Lateral drift** — random direction, random magnitude in `[parachuteLateralDriftMin, parachuteLateralDriftMax]` metres

Units of the same drop (e.g. an 8-man squad) each receive an independent random drift, so they scatter realistically around the drop zone.

### 6.3 Configuration parameters

All parameters are set in `CTLD_userConfig.lua`.

#### Minimum altitude gates

| Parameter | Default | Description |
| --- | --- | --- |
| `parachuteMinAltitudeCrates` | `152` | Minimum AGL (m) to drop crates (≈ 500 ft) |
| `parachuteMinAltitudeTroops` | `152` | Minimum AGL (m) to drop troops (≈ 500 ft) |
| `parachuteMinAltitudeVehicles` | `152` | Minimum AGL (m) to drop a vehicle (≈ 500 ft) |

Below these thresholds the menu action is rejected and the payload remains loaded.

#### Descent rates

| Parameter | Default | Description |
| --- | --- | --- |
| `parachuteDescentRateCrates` | `5` | Simulated descent speed (m/s) for crates |
| `parachuteDescentRateTroops` | `5` | Simulated descent speed (m/s) for troops |
| `parachuteDescentRateVehicles` | `8` | Simulated descent speed (m/s) for vehicles (heavier load) |

The descent rate determines how long the payload takes to reach the ground, which directly controls how far inertia carries it forward.

#### Drift parameters

| Parameter | Default | Description |
| --- | --- | --- |
| `parachuteInertiaFactor` | `0.3` | Fraction of transport velocity applied as forward drift (0.0 = no inertia, 1.0 = full velocity) |
| `parachuteLateralDriftMin` | `10` | Minimum random lateral drift per unit (m) |
| `parachuteLateralDriftMax` | `80` | Maximum random lateral drift per unit (m) |

### 6.4 Events

| Event | Fired | Payload |
| --- | --- | --- |
| `OnCrateParachuting` | Immediately at drop, per crate | `{ crate, transport, estimatedLandingTime }` |
| `OnCrateParachuteLanded` | After descent time, per crate | `{ crate, landPos }` |
| `OnTroopsDeployed` | Immediately at drop | `{ troops, transport, trigger="parachute" }` |
| `OnTroopsParachuteLanded` | After descent time, per unit | `{ unit, landPos }` |
| `OnVehicleParachuting` | Immediately at drop | `{ vehicle, transport, estimatedLandingTime }` |
| `OnVehicleParachuteLanded` | After descent time | `{ vehicle, landPos }` |

Use `OnTroopsDeployed` with `trigger == "parachute"` to distinguish parachute drops from normal ground deployments.

---

## 7. Virtual Slingload

Virtual slingload is an alternative to DCS native sling-load physics (`slingLoad=true`). It simulates the hook-and-carry mechanic by polling the helicopter's position relative to nearby crates. No DCS cargo sling event is used.

### 7.1 Enabling slingload per aircraft

Set `canSlingload = true` in the `capabilitiesByType` entry for each aircraft that supports hover pickup:

```lua
_cfg.settings["capabilitiesByType"] = {
    ["UH-1H"]     = { ..., canSlingload = true  },
    ["Mi-8MT"]    = { ..., canSlingload = true  },
    ["CH-47Fbl1"] = { ..., canSlingload = true  },
    ["C-130J-30"] = { ..., canSlingload = false },  -- fixed-wing cannot hover
}
```

Default is `false` for all types. FOB crates are never slingloadable.

### 7.2 Hooking a crate (hover pickup)

Hover pickup is enabled by `enableHoverSlingload = true` (default). To hook a crate:

1. Fly directly above the crate at a height between `minimumHoverHeight` and `maximumHoverHeight` (7.5–12 m by default).
2. Stay within `maxDistanceFromCrate` (5.5 m) horizontally.
3. Hold the hover for `hoverTime` seconds (10 s by default). A countdown is displayed on screen.

If the helicopter drifts out of range the countdown resets. Once the timer reaches zero, the crate is automatically attached and the on-screen message confirms the hook.

`enableHoverSlingload = false` disables the hover countdown entirely. Crates can still be loaded via the F10 "Load Crate" menu entry if `loadCrateFromMenu = true`.

### 7.3 Carrying and dropping

Once a crate is slingloaded, two F10 menu entries appear under **Crate Commands** — **visible only while airborne and a virtual slingload is active**:

**Release Slingload** — controlled release:

- Only available when AGL ≤ `maximumHoverHeight` (≈ at or near the ground).
- Crate is placed safely below the helicopter.
- Use this for precision delivery.

**Cut Slingload** — emergency drop, available at any altitude:

- AGL > 40 m → crate is **destroyed** on impact (too much speed at landing).
- AGL ≤ 40 m → crate lands at a position offset by the helicopter's current inertia. Faster flight = more drift from the drop point.

### 7.4 Speed limit

If the helicopter exceeds `maxSlingloadSpeed` (default 50 m/s ≈ 180 km/h) while carrying a slingloaded crate, the crate is **automatically lost** and destroyed. A warning message is sent to the group. This forces realistic low-speed transport.

### 7.5 Configuration parameters

| Parameter | Default | Description |
| --- | --- | --- |
| `enableHoverSlingload` | `true` | Enable hover-based pickup countdown |
| `minimumHoverHeight` | `7.5` | Min height (m) between helicopter and crate for pickup |
| `maximumHoverHeight` | `12.0` | Max height (m) between helicopter and crate for pickup |
| `maxDistanceFromCrate` | `5.5` | Max horizontal distance (m) from crate for pickup |
| `hoverTime` | `10` | Seconds of sustained hover required to hook a crate |
| `maxSlingloadSpeed` | `50` | Max speed (m/s) while carrying a slingloaded crate — exceed it and the crate is lost |

### 7.6 Events

| Event | Fired | Payload |
| --- | --- | --- |
| `OnCrateLoaded` | Crate successfully hooked | `{ crate, transport, trigger="slingload" }` |
| `OnCrateUnloaded` | Release Slingload | `{ crate, transport, trigger="slingload_release", position }` |
| `OnCrateUnloaded` | Cut Slingload (AGL ≤ 40m) | `{ crate, transport, trigger="slingload_cut", position }` |
| `OnCrateLost` | Cut too high (AGL > 40m) or overspeed | `{ crate, transport, trigger="slingload_cut_impact"\|"slingload_overspeed" }` |

Use the `trigger` field to distinguish slingload events from normal load/unload operations.

---

---

## 8. Minefield

### 8.1 Overview

The minefield system spawns real DCS landmine statics in a **quinconce (staggered) pattern** in front of a transport unit. Odd rows contain N mines, even rows contain N−1 mines offset laterally by half a column spacing:

```text
x    x    x    x        ← row 1 (odd,  N mines)
   x    x    x          ← row 2 (even, N-1 mines, shifted right by spacing/2)
x    x    x    x        ← row 3 (odd)
   x    x    x          ← row 4 (even)
```

A bounding quadrilateral is drawn on the F10 map to mark the extent of the field.

### 8.2 Parametric API — `setLandMineAuto`

The simplest way to deploy a minefield. Provide the desired area dimensions and mine count; the system computes the best column/row layout automatically.

```lua
local ok, result = mineFieldScene.setLandMineAuto(
    transport,   -- DCS Unit object (defines origin and heading)
    30,          -- distance (m) from unit to first mine row
    50,          -- width  (m) — lateral extent of the field
    80,          -- length (m) — forward extent of the field
    40           -- desired number of mines
)
-- result is the array of spawned DCS static objects.
-- Actual count may differ slightly from the requested value due to quinconce rounding.
-- Use #result to get the exact count.
```

### 8.3 Explicit API — `setLandMine`

For full control over column count, row count, and spacings:

```lua
local ok, result = mineFieldScene.setLandMine(
    transport,   -- DCS Unit object
    20,          -- distance (m) from unit to first mine row
    5,           -- mines per odd row (N columns)
    15,          -- number of rows
    6,           -- lateral spacing between adjacent mines (m)
    12           -- forward spacing between rows (m)
)
-- quinconce: 8 odd rows × 5 + 7 even rows × 4 = 68 mines
```

### 8.4 Configuration parameters

| Parameter                  | Default | Description                                              |
|----------------------------|---------|----------------------------------------------------------|
| `showMinefieldOnF10Map`    | `true`  | Draw bounding quad on F10 map when a minefield is placed |

### 8.5 Special cases

| Condition              | Behaviour                                    |
|------------------------|----------------------------------------------|
| `nbMines == 1`         | Single mine, small square F10 marker         |
| `nbMinesColumns == 1`  | Straight forward column, no stagger          |
| `nbMinesColumns >= 2`  | Full quinconce layout                        |

---

## 9. Legacy API compatibility

> **Deprecation notice:** The functions below are compatibility wrappers from CTLD v1.
> They remain functional in v2 but will be removed in v3.
> For new missions, use the v2 event-driven API via `EventDispatcher:subscribe()` instead.

### 9.1 Overview

CTLD v2 provides 22 thin wrapper functions that replicate the v1 global API.
Each wrapper delegates to the appropriate v2 manager internally.
A deprecation warning is logged to `ctld.log` on every call.

### 9.2 Troops

| v1 function | Description |
|---|---|
| `ctld.spawnGroupAtTrigger(groupName, triggerName, side)` | Spawn a troop group at a trigger zone |
| `ctld.spawnGroupAtPoint(groupName, point, side)` | Spawn a troop group at a world point |
| `ctld.preLoadTransport(unitName, groupName)` | Pre-load troops into a transport |
| `ctld.unloadTransport(unitName)` | Unload all troops from a transport |
| `ctld.loadTransport(unitName, groupName)` | Load a specific group into a transport |
| `ctld.unloadInProximityToEnemy(unitName)` | Force-unload troops near an enemy unit |

**Example — spawn troops from a DO SCRIPT:**
```lua
ctld.spawnGroupAtTrigger("Infantry Squad Alpha", "LZ_NORTH", coalition.side.BLUE)
```

### 9.3 Pickup and extract zones

| v1 function | Description |
|---|---|
| `ctld.activatePickupZone(zoneName)` | Activate a troop pickup zone |
| `ctld.deactivatePickupZone(zoneName)` | Deactivate a troop pickup zone |
| `ctld.changeRemainingGroupsForPickupZone(zoneName, n)` | Set remaining group count for a zone |
| `ctld.activateWaypointZone(zoneName)` | Activate a waypoint (extract) zone |
| `ctld.deactivateWaypointZone(zoneName)` | Deactivate a waypoint zone |
| `ctld.createExtractZone(name, point, radius, side)` | Create an extract zone at runtime |
| `ctld.removeExtractZone(zoneName)` | Remove a runtime extract zone |
| `ctld.countDroppedGroupsInZone(zoneName)` | Return number of deployed groups in zone |
| `ctld.countDroppedUnitsInZone(zoneName)` | Return number of deployed units in zone |
| `ctld.cratesInZone(zoneName)` | Return number of crates in zone |

**Example — dynamic extract zone:**
```lua
ctld.createExtractZone("EXZ_ALPHA", { x = 12000, y = 0, z = -5000 }, 300, coalition.side.BLUE)
-- ... later, when objective is complete:
ctld.removeExtractZone("EXZ_ALPHA")
```

### 9.4 Crates

| v1 function | Description |
|---|---|
| `ctld.spawnCrateAtZone(unitType, triggerZoneName, side)` | Spawn a vehicle crate at a trigger zone |
| `ctld.spawnCrateAtPoint(unitType, point, side)` | Spawn a vehicle crate at a world point |

> **Note:** `ctld.spawnCrateAtZone` and `ctld.spawnCrateAtPoint` are fully functional in v2.
> They use `CTLDCrateManager:spawnCrate()` which calls `ctld.utils.dynAddStatic` internally.

**Example — spawn a Humvee crate near a FARP:**
```lua
ctld.spawnCrateAtZone("M1043 HMMWV Armament", "FARP_BRAVO", coalition.side.BLUE)
```

### 9.5 Radio beacon

| v1 function | Description |
|---|---|
| `ctld.createRadioBeaconAtZone(zoneName, side, freq, modulation)` | Place a radio beacon at a trigger zone |

**Example:**
```lua
ctld.createRadioBeaconAtZone("LZ_NORTH", coalition.side.BLUE, 270000, radio.modulation.AM)
```

### 9.6 JTAC

| v1 function | Description |
|---|---|
| `ctld.JTACAutoLase(groupName, code, smoke)` | Start auto-lasing a group |
| `ctld.JTACStart(unitName, code, smoke)` | Start lasing a specific unit |
| `ctld.JTACAutoLaseStop(groupName)` | Stop auto-lasing |

**Example — auto-lase an enemy armour group:**
```lua
ctld.JTACAutoLase("ENEMY_ARMOUR_1", 1688, true)
-- ... when strike complete:
ctld.JTACAutoLaseStop("ENEMY_ARMOUR_1")
```

### 9.7 Callbacks (replaced by EventDispatcher)

In v1, external scripts used `ctld.addCallback(fn)` to react to CTLD events.
In v2, use `EventDispatcher:subscribe(eventName, fn)` instead.

| v1 pattern | v2 equivalent |
|---|---|
| `ctld.addCallback(function(event) ... end)` | `EventDispatcher.getInstance():subscribe("OnCrateSpawned", fn)` |

Available v2 events: `OnCrateSpawned`, `OnCrateLoaded`, `OnCrateUnloaded`, `OnCrateUnpacked`,
`OnVehiclePacked`, `OnTroopsBoarded`, `OnTroopsDeployed`, `OnTroopsExtracted`,
`OnJTACSpawned`, `OnLaseStart`, `OnLaseStop`, `OnBeaconDropped`, `OnFOBDeployed`, and more.

---

## 10. Crates

### 10.1 Overview

Crates are the core CTLD mechanic. A transport helicopter flies to a logistics zone, spawns a crate from the F10 menu (or loads one already on the ground), carries it to a destination, and unpacks it to deploy a vehicle, AA system, or FOB component.

```
LGZ (spawn) → load (hover or menu) → fly → unload → unpack → vehicle / FOB / AA
```

> **Transport flows reference diagram** — for a complete visual overview of all equipment transport modes (crates, whole vehicles, JTAC lifecycle) with per-method status indicators:
> [docs/assets/equiptTransportFlows.svg](assets/equiptTransportFlows.svg)

### 10.2 Actions

> **F10 menu visibility — ground vs in-flight**
> The **Crate Commands** submenu is context-sensitive. Items are shown or hidden automatically based on whether the aircraft is on the ground or airborne:
>
> | State | Visible entries |
> | --- | --- |
> | **Ground** | Load Crate · Drop Crate(s) · Unpack Crate · List Nearby Crates · Pack Vehicle |
> | **In flight** | Parachute Crates (if CTLD crates loaded, non-slingloaded) · Release Slingload · Cut Slingload (if virtual slingload active) |

#### Spawn crate
**Utility:** Creates a DCS static cargo object near the logistics zone. The crate represents a specific vehicle or kit.
**How it works:** Player selects "Get Crate" from the F10 menu while inside a LGZ. A crate static is spawned at a fixed offset from the helicopter (forward sector). One crate per 40 s cooldown per player.
**Activation:** F10 → Crate Commands → Get [vehicle name]
**Script:**
```lua
-- v2 direct API
CTLDCrateManager.getInstance():spawnCrate(descriptor, position, coalition.side.BLUE, "pilotName", "crate_spawn")
-- legacy wrapper
ctld.spawnCrateAtZone("M1043 HMMWV Armament", "LGZ_depot1", coalition.side.BLUE)
```

#### Load crate
**Utility:** Attaches a nearby crate to the transport so it can be carried.
**How it works:** Two methods available depending on config:
- **Hover pickup** (`enableHoverSlingload=true`): hover 7.5–12 m above the crate for `hoverTime` seconds. Countdown shown on screen.
- **Menu pickup** (`loadCrateFromMenu=true`): F10 → Crate Commands → Load Crate.
**Activation:** Hover above crate OR F10 → Crate Commands → Load Crate

#### Unload crate
**Utility:** Places the carried crate on the ground at the current position.
**How it works:** Crate is spawned as a static at the helicopter's position. The transport is freed.
**Activation:** F10 → Crate Commands → Unload Crate(s)
**Script:**
```lua
CTLDCrateManager.getInstance():unloadCrate(crateName, position, "menu")
```

#### Unpack crate
**Utility:** Consumes the crate(s) and deploys the vehicle, AA system, or triggers FOB construction.
**How it works:** CTLD checks that the required number of matching crates (`cratesRequired`) are within 300 m. If met, crates are destroyed and the object is spawned via the unified spawn pipeline (`ctld.utils.buildGroupUnitDef` + `ctld.utils.spawnFromDescriptor`). The DCS API used depends on `spawnAs`: ground vehicles use `coalition.addGroup(GROUND)`, air units use `coalition.addGroup(AIRPLANE/HELICOPTER)`, static objects use `coalition.addStaticObject`.
**Activation:** F10 → Crate Commands → Unpack Crate(s)
**Conditions:** Must be on the ground, not inside a LGZ, crates within 300 m.

### 10.3 Key configuration parameters

| Parameter | Default | Description |
|---|---|---|
| `enableCrates` | `true` | Enable the crate system |
| `enableAllCrates` | `true` | Add "Get All Crates" shortcut entries |
| `maximumDistanceLogistic` | `200` | Max distance (m) from logistics unit to interact |

### 10.4 Events

| Event | Fired when |
|---|---|
| `OnCrateSpawned` | Crate spawned from logistics zone |
| `OnCrateLoaded` | Crate loaded onto transport |
| `OnCrateUnloaded` | Crate placed on ground |
| `OnCrateUnpacked` | Crate assembled into vehicle/AA/FOB |
| `OnCrateLost` | Crate destroyed (overspeed, cut slingload high) |

---

## 11. Vehicles

### 11.1 Overview

CTLD supports two vehicle operations: **requesting** a vehicle at a logistics zone (spawns it from a crate remotely) and **packing** an existing ground vehicle back into crates for transport.

> See also: [Transport flows diagram](assets/equiptTransportFlows.svg) — all load/unload methods for whole-vehicle transport (Flow 2) including GAP-1/GAP-2 status.

### 11.2 Actions

#### Request vehicle (spawn from logistics zone)
**Utility:** Allows a player to call for a specific vehicle to be delivered to their position from a logistics zone without needing to fly there and back.
**How it works:** Player selects a vehicle type from the F10 menu while inside a LGZ. CTLD spawns the vehicle group near the logistics zone, ready for the player to load or drive.
**Activation:** F10 → Vehicle Transport → Request [vehicle name]

#### Load vehicle (dynamic cargo)
**Utility:** Loads a nearby ground vehicle into a dynamic-cargo-capable transport (C-130, Il-76) using DCS native cargo loading.
**How it works:** CTLD detects vehicles in `vehiclesForTransport` within the aircraft's cargo bay bounding box. The vehicle group is destroyed and held in memory. On unload, it is re-spawned.
**Activation:** Automatic when vehicle enters aircraft cargo bay, or F10 → Vehicle Commands → Load / Extract Vehicles (requires landing).

> **Virtual slingload not supported for whole vehicles.** Only aircraft listed in `vehicleTransportEnabled` can transport whole vehicles (via DCS native cargo bay or F10 menu). All other aircraft (e.g. UH-1H) must use crates: pack the vehicle into crates, transport by slingload or menu load, then unpack at destination (see §7 and Flow 1 in the transport diagram).

> **Cargo capacity limits (menu load).** When loading via the F10 menu (`menu_ctld` method), CTLD enforces two limits. **Count:** the number of vehicles loaded simultaneously is capped by `internalCargoLimits[transportType]` (default: 1). If the limit is reached the player receives a message and the load is refused. **Weight:** after each load or unload, CTLD calls `trigger.action.setUnitInternalCargo` with the sum of `vehiclesWeight[vehicleType]` (default: 2500 kg per vehicle), preventing take-off when overloaded. These limits do **not** apply to DCS-native loading (C-130, Il-76 cargo bay): DCS manages weight and capacity natively in that case.

#### Unload vehicle
**Utility:** Re-spawns the carried vehicle at the current position.
**How it works:** Vehicle group is spawned behind the transport (dynamic cargo aircraft) or at a fixed offset.
**Activation:** F10 → Vehicle Transport → Unload Vehicle

#### Pack vehicle
**Utility:** Converts a ground vehicle back into crates so a helicopter can transport it. This is the reverse of unpack.
**How it works:** Player lands near a packable ground vehicle (within `maximumDistancePackableUnitsSearch`). The vehicle is destroyed and `cratesRequired` crates are spawned around the helicopter:
- **Helicopter** (non dynamic cargo): crates spawned in the **front** sector (±45°)
- **C-130 / Il-76** (dynamic cargo capable): crates spawned in the **rear** sector (±45°)
**Activation:** F10 → Crate Commands → Pack Vehicle → [vehicle name] (appears only when a packable vehicle is nearby and the aircraft is on the ground)
**Script:**
```lua
CTLDVehicleSpawner.getInstance():packVehicle(transportUnitName, vehicleUnitName, playerObj)
```

### 11.3 Key configuration parameters

| Parameter | Default | Description |
|---|---|---|
| `enablePackingVehicles` | `true` | Enable pack vehicle menu |
| `maximumDistancePackableUnitsSearch` | `200` | Max distance (m) from transport to search for packable vehicles |
| `vehicleTransportCapabilities` | `{...}` | Per-aircraft whole-unit vehicle transport: `maxVehicles`, `vehiclesRED`, `vehiclesBLUE` (Feature Q) |
| `internalCargoLimits` | `{ ["Mi-8MT"]=2, ["CH-47Fbl1"]=8, ... }` | Max number of vehicles (menu load) per transport DCS type name. Default: 1 for unlisted types. Also caps slingload crates count. |
| `vehiclesWeight` | `{ ["M1045 HMMWV TOW"]=3220, ... }` | Weight (kg) per vehicle type used for `setUnitInternalCargo` after menu load/unload. Default: 2500 kg for unlisted types. |

### 11.4 Events

| Event | Fired when |
|---|---|
| `OnVehiclePacked` | Vehicle packed into crates |
| `OnVehicleDead` | Spawned CTLD vehicle destroyed |

---

## 12. FOB — Forward Operating Base

### 12.1 Overview

A FOB is a deployable forward base built from crates. Once built, it automatically registers as a logistic zone (players can spawn crates and vehicles from it) and optionally as a troop pickup zone.

The FOB logistic zone is a standard circular LGZ centered on the FOB site. It is identified by the FOB name (not an `LGZ_` trigger zone). Its radius is controlled by `fobLogisticZoneRadius` (default 150 m). It can be deactivated / reactivated at runtime like any other LGZ via `CTLDZoneManager.getInstance():deactivateLogisticZone(fobName)`.

> **FOBs are the only way to create a new logistic zone at runtime.** If your mission design requires logistics at a position determined during play, deploy a FOB rather than pre-placing an `LGZ_` trigger zone.

### 12.2 Build action

**Utility:** Assembles FOB crates into a functioning forward base with structures, beacon, and logistics capability.
**How it works:**
1. Player loads `cratesRequiredForFOB` FOB crates (weight 1001–1003 by default) and flies to the desired location.
2. Unpack is triggered from the F10 menu. CTLD checks that all required crates are within 750 m of each other and that the position is ≥ `fobMinDistanceFromZones` from existing zones.
3. The FOB scene plays (structures spawn sequentially; timing is managed internally by the FOB scene engine).
4. When complete: a radio beacon is automatically placed at the FOB centroid, the area registers as a LGZ, and (if `troopPickupAtFOB=true`) as a troop pickup zone.
**Activation:** F10 → Crate Commands → Unpack Crate(s) (when FOB crates are nearby)

### 12.3 FOB destruction

If enemy forces destroy enough FOB structures to drop the integrity below `(1 - fobDestructionThreshold)`, the FOB is considered destroyed: its logistic zone is immediately unregistered, its beacon is removed, and the `OnFOBDestroyed` event is fired.

With the default `fobDestructionThreshold = 0.5`, the FOB is lost as soon as **more than 50 % of its scene objects are destroyed** — the FOB does not need to be completely wiped out.

| `fobDestructionThreshold` | Structures that must survive | FOB lost when |
| --- | --- | --- |
| `0.5` (default) | > 50 % | ≥ 50 % destroyed |
| `0.75` | > 25 % | ≥ 75 % destroyed |
| `1.0` | > 0 % (any survivor) | all structures destroyed |

> Once destroyed, the FOB logistic zone is permanently removed for the mission. There is no automatic rebuild — players must deploy new FOB crates at a different location to restore logistics in that area.

### 12.4 Key configuration parameters

| Parameter | Default | Description |
|---|---|---|
| `enabledFOBBuilding` | `true` | Enable FOB construction |
| `cratesRequiredForFOB` | `3` | Number of FOB crates required |
| `troopPickupAtFOB` | `true` | Register FOB as a troop pickup zone after build |
| `fobMinDistanceFromZones` | `500` | Min distance (m) from existing zones |
| `fobDestructionThreshold` | `0.5` | Fraction of structures destroyed to trigger FOB loss |
| `fobLogisticZoneRadius` | `150` | Logistics zone radius (m) around FOB centroid |

### 12.5 Events

| Event | Fired when |
|---|---|
| `OnFOBDeployed` | FOB construction completed |
| `OnFOBDestroyed` | FOB destroyed by enemy action |

---

## 13. Radio Beacons

### 13.1 Overview

Radio beacons are deployable navigation aids. A player drops a beacon from their aircraft; it transmits on automatically-assigned VHF, UHF and FM frequencies for a configurable battery life. All coalition members see the beacon on the F10 map.

> ⚠️ **Required: sound files must be embedded in the mission.**
> CTLD does not bundle audio files — you must add them manually via the mission editor:
> **Mission → Sounds → Add** → select `assets/beacon.ogg` and `assets/beaconsilent.ogg` from the CTLD repo.
> **If these files are missing, all radio transmissions are silent and FM homing will not work.**
> The VHF ADF needle may still respond (it reacts to the TACAN_beacon unit itself, not to the sound), but no audio will be heard on any frequency.

### 13.2 Actions

#### Drop beacon
**Utility:** Places a radio beacon at the current position for navigation or coordination.
**How it works:** A static unit is spawned at the helicopter's position. CTLD auto-assigns unique VHF, UHF and FM frequencies from the configured pools (no two active beacons share a frequency). Transmission starts immediately. An F10 map marker is drawn.
**Activation:** F10 → Beacon Commands → Drop Beacon
**Script:**
```lua
-- Drop at helicopter position
CTLDBeaconManager.getInstance():dropBeacon(transportUnit, playerObj)
-- Drop at a trigger zone (legacy wrapper)
ctld.createRadioBeaconAtZone("LZ_NORTH", coalition.side.BLUE, 270000, radio.modulation.AM)
```

#### Remove beacon
**Utility:** Removes the nearest friendly beacon.
**How it works:** CTLD finds the closest beacon to the transport within detection range, removes the static, stops transmission, and removes the F10 marker.
**Activation:** F10 → Beacon Commands → Remove Beacon

#### List beacons
**Utility:** Displays all active beacons for the player's coalition with their frequencies and position.
**Activation:** F10 → Beacon Commands → List Beacons

#### Toggle F10 map layer
**Utility:** Show or hide all beacon markers on the F10 map for this player.
**Activation:** F10 → Beacon Commands → Toggle Beacon Layer

### 13.3 Frequency assignment

CTLD auto-assigns frequencies from three pools defined in config:

| Pool | Config key | Default range |
|---|---|---|
| VHF | `beaconVHFFrequencies` | 118–136 MHz |
| UHF | `beaconUHFFrequencies` | 225–400 MHz |
| FM | `beaconFMFrequencies` | 30–88 MHz |

### 13.4 Key configuration parameters

| Parameter | Default | Description |
|---|---|---|
| `enabledRadioBeaconDrop` | `true` | Enable beacon deployment |
| `deployedBeaconBattery` | `30` | Battery life (minutes) |
| `radioSound` | `"beacon.ogg"` | Sound file (must be added to mission sound library) |

### 13.5 Events

| Event | Fired when |
|---|---|
| `OnBeaconDropped` | Beacon placed |
| `OnBeaconRemoved` | Beacon manually removed |
| `OnBeaconDestroyed` | Beacon static destroyed by enemy |
| `OnBeaconRefreshed` | Beacon frequencies/mark refreshed |

---

## 14. JTAC

### 14.1 Overview

CTLD provides two JTAC modes: **crate-deployed JTACs** (spawned by players from the F10 menu) and **pre-placed JTACs** (groups placed in the Mission Editor and auto-detected at startup). All JTACs auto-lase the nearest enemy target within LOS.

### 14.2 Actions

#### Request JTAC Equipment
**Utility:** Spawns a JTAC vehicle or drone directly at the logistics zone, ready for the player to load.
**How it works:** Player selects a JTAC type from the F10 menu while landed inside a logistics zone. CTLD spawns the unit near the zone; the player can then load and transport it. The JTAC starts auto-lasing once unloaded and deployed.
**Activation:** F10 → JTAC → Request JTAC Equipment → [type]

> **Menu constraint:** The "Request JTAC Equipment" submenu is **dynamic**. It shows available types only when the player is landed inside an active logistics zone. Outside a LGZ the submenu displays "No logistics in range" (no-op). The submenu refreshes automatically on landing, takeoff, and FOB deployment.
>
> **Visibility gate:** The submenu only appears if `JTAC_dropEnabled ≠ false`, the player's aircraft is a transport (`isTransport=true`), and at least one `spawnableCrates` descriptor with `isJTAC=true` is available for the player's coalition. No separate type list is required — JTAC types are derived directly from the crate catalogue.

#### Spawn JTAC (from crate)
**Utility:** Deploys a JTAC unit from a crate near the current position. The JTAC starts lasing immediately.
**How it works:** Player selects "Get JTAC Crate" from the F10 menu inside a LGZ. A JTAC crate is spawned, then unpacked at the destination. The JTAC unit appears and begins scanning for targets.
**Activation:** F10 → Crate Commands → Get JTAC Crate → Unpack Crate(s)

#### Auto-lase (script)
**Utility:** Starts a JTAC auto-lasing loop on a named group. The JTAC continuously re-acquires the nearest LOS enemy.
**How it works:** CTLD runs a `timer.scheduleFunction` loop. Each cycle it calls `world.searchObjects` in the JTAC's LOS cone, selects the nearest valid target, and fires the DCS laser spot. If the target is destroyed the JTAC re-acquires.
**Activation:** F10 (automatic for spawned JTACs) or script:
```lua
CTLDJTACManager.get():autoLase("JTAC_BLUE_1", 1688, true)
-- params: groupName, laserCode, enableSmoke
-- legacy wrapper
ctld.JTACAutoLase("JTAC_BLUE_1", 1688, true)
```

#### Start lase / Stop lase (script)
**Utility:** Force-start or stop lasing on a specific JTAC group from a mission script.
```lua
CTLDJTACManager.get():startLase("JTAC_BLUE_1", 1688, true)
CTLDJTACManager.get():stopAutoLase("JTAC_BLUE_1")
-- legacy wrappers
ctld.JTACStart("JTAC_BLUE_1", 1688, true)
ctld.JTACAutoLaseStop("JTAC_BLUE_1")
```

#### JTAC soldiers in troop templates

When a troop template includes `jtac` slots (e.g. `composition = { inf = 4, jtac = 2 }`), the JTAC soldiers within the group are tracked and managed **at unit level**, not at group level.

**Lifecycle:**

- On `disembark()` (deploy): each JTAC unit is individually registered in `CTLDJTACManager` and starts auto-lasing via `startLaseTroopUnit(unitName)`. Lasing begins automatically — no additional script call needed.
- On `embarkFromField()` (pick up from field): each JTAC unit is deregistered **before** the DCS group is destroyed, stopping the lasing loop cleanly.
- On unit death (`S_EVENT_DEAD`): the dead JTAC unit is deregistered automatically; surviving JTAC units in the same group continue lasing unaffected.
- On `returnToTroopZone()`: all remaining JTAC units are deregistered.

**Important:** The `startLaseTroopUnit` / `deregisterJTAC` calls target individual DCS unit names (not the group name). This means a composite group (e.g. 4 infantry + 2 JTAC) can lose one JTAC soldier without affecting the other JTAC or the infantry.

**Distinction from standalone JTACs:** Vehicle and drone JTACs spawned via crates or `Request JTAC Equipment` are group-keyed. Infantry JTACs in troop groups are unit-keyed. The two registries coexist in `CTLDJTACManager.jtacs`.

#### Smoke target
**Utility:** Marks the lased target with smoke for pilot identification.
**Activation:** F10 → JTAC Commands → Smoke Target (appears when JTAC is active in range)

### 14.3 Key configuration parameters

| Parameter | Default | Description |
|---|---|---|
| `JTAC_LIMIT_BLUE` | `10` | Max JTAC objects BLUE may spawn (definitive — not refilled on JTAC death) |
| `JTAC_LIMIT_RED` | `10` | Max JTAC objects RED may spawn (same) |
| `JTAC_dropEnabled` | `true` | Enable JTAC crate spawn from F10 |
| `JTAC_maxDistance` | `10000` | JTAC LOS scan range (m) |
| `JTAC_lock` | `"all"` | Target filter: `"vehicle"`, `"troop"`, `"all"` |
| `JTAC_allowStandbyMode` | `true` | Allow toggling laser on/off |
| `JTAC_allow9Line` | `true` | Enable 9-line CAS request display |
| `JTAC_targetDeconfliction` | `true` | Prevent multiple JTACs from lasing the same target simultaneously. When enabled, each JTAC picks the nearest available target not already being lased by another JTAC. Disable only for single-JTAC missions where the overhead is unwanted. |

### 14.4 Events

| Event | Fired when |
|---|---|
| `OnJTACSpawned` | JTAC unit created |
| `OnLaseStart` | Laser activated on a target |
| `OnLaseStop` | Laser deactivated |
| `OnTargetLased` | Lased target confirmed LOS |
| `OnSmokeTarget` | Smoke marker placed on target |
| `OnJTACDead` | JTAC unit destroyed |

---

## 15. Recon

### 15.1 Overview

The recon system allows players to perform LOS-based **enemy** scanning from their aircraft. Detected enemy units are marked on the F10 map with layer-specific icons. Players can enable auto-refresh to keep the picture current.

> **Scope:** RECON is exclusively reserved for displaying information about **enemy units** detected via Line-of-Sight (LOS) from an allied unit. It must not be used to display friendly assets (FOBs, logistic zones, beacons, etc.) — those are managed by their respective submenus.
> **Note:** RECON is disabled by default. Set `reconEnabled: true` in your mission config to activate it.

### 15.2 Actions

#### RECON [Start]
**Utility:** Performs an immediate LOS scan around the player's aircraft and marks detected enemy units on the F10 map. Enables auto-refresh at `reconRefreshInterval` seconds.
**Requirements:** `reconEnabled=true`, player altitude ≥ `reconMinAltitude` AGL, at least one layer active.
**Activation:** F10 → Recon → RECON [Start]

#### RECON [Stop]
**Utility:** Stops auto-refresh and removes all RECON marks from the F10 map for this player immediately.
**Activation:** F10 → Recon → RECON [Stop]

#### Toggle layer
**Utility:** Show or hide a specific detection category (infantry, ground vehicles, air defense, aircraft, helicopters, ships). Toggling a layer off while RECON is active immediately removes its marks from the map.
**Activation:** F10 → Recon → [layer name] → [activate] / [deactivate]

### 15.3 Layers and icons

| Layer | Icon shape | Color (RED enemy) |
|---|---|---|
| Infantry | Circle with cross (⊕) | Red |
| Ground Vehicles | Rectangle with diagonal | Red |
| Air Defense | Filled circle + apex lines (△) | Red |
| Aircraft | Perpendicular cross with center dot | Red |
| Helicopters | Circle with H bars | Red |
| Ships | Elongated rectangle with bow arrow | Red |

Icon colors match the enemy coalition (RED = red, BLUE = blue). Size is controlled by `reconIconScale`.

> **DCS limitation:** RECON icons are drawn in world-space (metres), so they scale with F10 map zoom. There is no screen-space alternative in the DCS API.

### 15.4 Key configuration parameters

| Parameter | Default | Description |
|---|---|---|
| `reconF10Menu` | `true` | Enable the RECON F10 menu |
| `reconEnabled` | `false` | Master switch — must be `true` for scan commands to work |
| `reconSearchRadius` | `5000` | LOS scan radius (m) |
| `reconMinAltitude` | `50` | Minimum AGL altitude (m) to perform a scan |
| `reconRefreshInterval` | `10` | Auto-refresh interval (s) |
| `reconIconScale` | `1.0` | Icon size multiplier (1.0 = default, 2.0 = double) |

### 15.4 Events

| Event | Fired when |
|---|---|
| `OnReconScan` | Manual scan performed |
| `OnReconScanRefresh` | Auto-refresh scan performed |
| `OnReconHideTargets` | Marks hidden |
| `OnReconAutoRefreshEnabled` | Auto-refresh started |
| `OnReconAutoRefreshDisabled` | Auto-refresh stopped |
| `OnReconLayerToggled` | A layer toggled on/off |

---

## 16. AA Systems

### 16.1 Overview

AA systems (Hawk, Patriot, NASAM, BUK, KUB, S-300) are multi-crate kits. Each system requires a specific number of part crates (radar, launcher, command post…) to be assembled together. CTLD handles assembly, repair, and rearm.

### 16.2 Actions

#### Deploy AA system
**Utility:** Assembles all required part crates into a functional AA ground group.
**How it works:** When a player unpacks a crate that belongs to an AA template, CTLD checks that all required part types (defined in `CTLDCrateAssemblyManager.TEMPLATES`) are within 300 m. If the count is met and the coalition AA limit (`AASystemLimitBLUE/RED`) has not been reached, all part crates are destroyed and the AA group is spawned via `coalition.addGroup`.
**Activation:** F10 → Crate Commands → Unpack Crate(s) (when all required parts are present nearby)

#### Repair AA system
**Utility:** Restores a damaged AA group to full strength.
**How it works:** Player brings a repair crate (specific weight for the system) and unpacks it within 300 m of the damaged AA group. The group is destroyed and re-spawned at full health.
**Activation:** F10 → Crate Commands → Unpack Crate(s) (with repair crate nearby and damaged AA system in range)

#### Rearm AA system
**Utility:** Restores ammunition to a depleted AA launcher.
**How it works:** Player unpacks a full part-set of crates for the same system near the existing group. The group is destroyed and re-spawned with full ammunition loadout.
**Activation:** F10 → Crate Commands → Unpack Crate(s) (with full crate set nearby and existing AA system in range)

### 16.3 Key configuration parameters

| Parameter | Default | Description |
|---|---|---|
| `AASystemLimitBLUE` | `20` | Max simultaneous active AA systems for BLUE |
| `AASystemLimitRED` | `20` | Max simultaneous active AA systems for RED |
| `AASystemCrateStacking` | `false` | Allow additional crate sets to add extra launchers to existing system |

### 16.4 Built-in AA templates

| Template | Crates required | Parts |
|---|---|---|
| Hawk | 3 | Search radar, Track radar, Launcher |
| Patriot | 3 | Search radar, ECS/ICC, Launcher |
| NASAM | 3 | Search radar, C2, Launcher |
| BUK | 3 | Search radar, TELAR, Loader |
| KUB | 2 | Search radar, TELAR |
| S-300 | 4 | Big Bird radar, Clam Shell, Command post, Launcher |

### 16.5 Events

| Event | Fired when |
|---|---|
| `OnCrateUnpacked` | AA system assembled (same event as vehicle unpack, check `descriptor.isAASystem`) |
| `OnCrateLost` | AA crate destroyed before assembly |

## 17. Smoke Drop

### 17.1 Overview

Transport aircraft with `enableSmokeDrop = true` get a **Smoke** submenu in F10. Players can drop coloured smoke grenades at their current position and optionally enable **auto-resume** to simulate a perpetual smoke signal.

### 17.2 Actions

#### Drop Smoke

**Utility:** Places a coloured smoke grenade at the aircraft's ground position.

**Activation:** F10 → Smoke → Drop Red / Blue / Orange / Green Smoke

**Notes:** DCS smoke lasts approximately 5 minutes and cannot be extended natively. Every drop is tracked internally for auto-resume (see below).

#### Smoke Auto-Resume toggle

**Utility:** Automatically re-triggers all smokes dropped by this player before they expire, creating a perpetual smoke signal.

**Activation:** F10 → Smoke → Smoke Auto-Resume [activate] / [deactivate]

**Behaviour:**

- **[activate]** → label switches to **[deactivate]**; any smoke dropped from this point is re-triggered every `smokeAutoResumeInterval` seconds.
- **[deactivate]** → label switches back to **[activate]**; all stored smoke positions are cleared; smokes currently burning expire naturally.
- The toggle is **per player** (each pilot manages their own smokes independently).
- Smokes dropped **before** activating the toggle are also tracked and will be resumed when the interval elapses.

### 17.3 Key configuration parameters

| Parameter | Default | Description |
| --- | --- | --- |
| `enableSmokeDrop` | `true` | Show the Smoke submenu for transport aircraft |
| `disableAllSmoke` | `false` | Globally disable all CTLD smoke actions |
| `smokeAutoResume` | `false` | Default auto-resume state at mission start (per-player toggle overrides this) |
| `smokeAutoResumeInterval` | `270` | Seconds between smoke re-triggers (default 270 s ≈ 4 min 30 s, matching DCS smoke lifetime) |

---

## 18. Pack Equipt — Vehicle Repack & FARP Repack

**Pack Equipt** is a unified F10 submenu under **Crate Commands** that lets players pack deployed equipment back into crates for relocation. It only appears when the helicopter is **on the ground** and at least one packable item is within range. The submenu is absent in flight.

### 18.1 Pack Vehicle

Packs a deployed ground vehicle back into crates so it can be air-transported to a new location.

**Requirements:**
- `enablePackingVehicles = true` (config)
- Vehicle registered with CTLD (spawned from a crate unpack or from Request Equipment)
- Player on the ground within `maximumDistancePackableUnitsSearch` metres of the vehicle

**Workflow:**
1. Land within range of the vehicle.
2. Select **Crate Commands → Pack Equipt → [vehicle name]**.
3. The vehicle is destroyed and its crates spawn around the helicopter.
4. Load and fly the crates to the new destination, then unpack.

**Event fired:** `OnVehiclePacked` — fields: `vehicleName`, `vehicleType`, `packedBy`

**Config:**

| Parameter | Default | Description |
|---|---|---|
| `enablePackingVehicles` | `true` | Enable vehicle repack |
| `maximumDistancePackableUnitsSearch` | `200` | Max distance (m) to search for packable vehicles |

### 18.2 Pack FARP

Packs a deployed FARP scene back into crates, snapshotting its warehouse fuel levels. When the crates are unpacked at a new site, the FARP respawns with the captured fuel quantities restored.

**Requirements:**
- `enableFARPRepack = true` (default)
- A repackable FARP scene (Countryside FARP, Metal FARP, or custom scene with `onRepack` hook) deployed within 300 m

**Workflow:**
1. Land within 300 m of the deployed FARP.
2. Select **Crate Commands → Pack Equipt → Pack [FARP name]**.
3. Fuel levels are snapshotted, the scene is destroyed, and crates spawn around the helicopter.
4. Fly the crates to the new site, unpack — the FARP redeploys with fuel restored.

**Config:**

| Parameter | Default | Description |
|---|---|---|
| `enableFARPRepack` | `true` | Enable FARP repack |

**Custom scene support:** add `onRepack(scene, repackData)` to your scene model. Read the warehouse and store in `repackData`. On re-deploy, check `ctx.scene._params.repackData` — see §3 FARP Repack for the full code example.

---

## 19. Beacon Layer

When enabled, each deployed beacon is drawn as a coloured circle icon on the F10 map, independently of the text list shown by **List Beacons**.

### 19.1 Enabling

```lua
-- CTLD_userConfig.lua (YAML block)
ctld.yamlConfigDatas = [[
  ctld.beaconLayerEnabled: true
  ctld.beaconAutoRefreshLayer: true    -- auto-add new beacons to the active layer
  ctld.beaconRefreshInterval: 60       -- seconds between layer refreshes
  ctld.beaconIconRadius: 25            -- radius (m) of each circle icon
  ctld.beaconTextSize: 12              -- font size of beacon label
]]
```

Beacon icon colour (RGBA, Lua table — not a YAML line):

```lua
local _cfg = CTLDConfig.get()
_cfg.settings["beaconIconColor"] = { 1.0, 0.5, 0.0, 1.0 }  -- orange (default)
```

### 19.2 Behaviour

- Each beacon icon is drawn at the beacon's spawn position.
- The label shows the beacon name (or its frequency if no name was set).
- When a beacon expires (battery dead) or is manually removed, its icon is erased automatically.
- **Auto-refresh:** if `beaconAutoRefreshLayer = true`, the layer is rebuilt every `beaconRefreshInterval` seconds to reflect battery expirations and new drops without requiring a manual F10 action.

### 19.3 Layer toggle (F10)

Players can show or hide the beacon layer via **Radio Beacons → Toggle Beacon Layer** in the F10 menu (available when `beaconLayerEnabled = true`).

---

*— End of missionmaker_guide.md —*
