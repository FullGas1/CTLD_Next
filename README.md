# DCS-CTLD Next

Complete Troops and Logistics Deployment for DCS World — **v2 modular rewrite**

---

## License

Originally created by Ciribob, maintained by Zip and the [VEAF Team](https://www.veaf.org).

Open-source and free (use, modify, fork, even commercial profit). Credit is appreciated.
Reach out to [Zip on Discord](https://discordapp.com/users/421317390807203850) to participate.
[Buy me a coffee](https://coff.ee/veaf_zip) if you'd like to support the work.

---

## Contents

- [Features](#features)
- [Installation](#installation)
  - [Static load (production)](#static-load-production)
  - [Dynamic load (development)](#dynamic-load-development)
  - [Required sound files](#required-sound-files)
- [Configuration](#configuration)
  - [Configuration file structure](#configuration-file-structure)
  - [Language](#language)
  - [Zone Naming Conventions](#zone-naming-conventions)
  - [Troop Pickup Zones](#troop-pickup-zones)
  - [AI Zones (Feature S)](#ai-zones-feature-s)
  - [Waypoint Zones](#waypoint-zones)
  - [Transport Unit Setup](#transport-unit-setup)
  - [Logistic Units](#logistic-units)
  - [Spawnable Crates](#spawnable-crates)
  - [Custom Troop Templates](#custom-troop-templates)
  - [JTAC Configuration](#jtac-configuration)
  - [Parachute Configuration](#parachute-configuration)
  - [Slingload Configuration](#slingload-configuration)
  - [FOB Configuration](#fob-configuration)
  - [Beacon Layer Configuration](#beacon-layer-configuration)
  - [Smoke Drop Configuration](#smoke-drop-configuration)
  - [Minefield Configuration](#minefield-configuration)
  - [Miscellaneous Parameters](#miscellaneous-parameters)
- [Mission Editor Script Functions](#mission-editor-script-functions)
  - [Troops](#troops)
  - [Zones](#zones)
  - [Crates](#crates)
  - [JTAC](#jtac)
  - [Beacons](#beacons)
- [Subscribing to CTLD Events](#subscribing-to-ctld-events)
- [In-Game F10 Menu](#in-game-f10-menu)
- [Troop Operations](#troop-operations)
- [Crate Operations](#crate-operations)
- [Virtual Parachute Drop](#virtual-parachute-drop)
- [Virtual Slingload](#virtual-slingload)
- [Forward Operating Base (FOB)](#forward-operating-base-fob)
- [FARP Deployment](#farp-deployment)
- [Radio Beacons](#radio-beacons)
- [JTAC Auto-Lase](#jtac-auto-lase)
- [Smoke Drop](#smoke-drop)
- [Recon and Target Marking](#recon-and-target-marking)
- [Minefield Deployment](#minefield-deployment)
- [AA System Construction](#aa-system-construction)
- [Pack Equipt](#pack-equipt)
- [Migration from v1](#migration-from-v1)
- [Developer Guide](#developer-guide)

---

## Features

- **Troops** — load, transport and deploy infantry groups via F10 menu; configurable group compositions (inf / MG / AT / AA / mortar / JTAC / civilian)
- **Vehicles** — load whole light vehicles into C-130 / IL-76 class aircraft and deliver them to any LZ
- **Crates** — spawn, hover-load, drop, and unpack supply crates to build vehicles and AA systems
- **Vehicle Pack** — pack a ground vehicle into crates for air transport, then reassemble it on the other side
- **Virtual Parachute** — drop troops, crates or vehicles by parachute with inertia and lateral drift simulation
- **Virtual Slingload** — simulate cargo sling loading without DCS sling-load physics bugs (hover detection, overspeed loss)
- **FOB Construction** — assemble a Forward Operating Base from dropped crates; becomes a new spawn and logistics point
- **FARP Deployment** — deploy a Forward Arming and Refuelling Point using a helicopter-carried crate sequence
- **FARP Repack** — pack a deployed FARP scene back into crates and redeploy it elsewhere; warehouse fuel levels snapshot and restore
- **Radio Beacons** — deploy homing beacons (VHF / UHF / FM) usable by all ADF-capable aircraft; battery timer; optional F10 map layer
- **JTAC Auto-Lase** — deploy JTAC units that auto-lase the nearest enemy, mark with smoke, give 9-lines, orbit (drones), optional SRS speech
- **Smoke Drop** — drop coloured smoke grenades from the F10 menu; optional auto-resume keeps smoke visible continuously
- **Recon** — scan areas for enemy contacts and display them as F10 map markers with configurable layer and auto-refresh
- **Minefield** — deploy a staggered landmine field in front of the transport; optional F10 map outline; player-triggered clear
- **AA Systems** — multi-crate assembly: HAWK, NASAMS (BLUE), KUB, BUK (RED), Patriot, S-300; repair crates; configurable limits per coalition; defined once in `CTLDCrateAssemblyManager.TEMPLATES`
- **AI Zones (Feature S)** — configure pickup and dropoff zones for AI transports independently of player zones; supports troops, vehicles, scenes and AA systems
- **Waypoint Zones** — automatically route deployed troops to an objective marker
- **Extract Zones** — count troops rescued to a zone; drive DCS flag triggers
- **i18n** — English (default), French, Spanish, Korean; fully translatable via key files
- **No MIST dependency** — v2 runs standalone (all MIST utilities replaced internally)
- **Events API** — 38 typed events via `EventDispatcher`; subscribe per-event with callbacks
- **CI-built** — every commit produces a validated `CTLD_Next.lua`; releases published on GitHub Releases

---

## Installation

### Static load (production)

1. Download `CTLD_Next.lua` from the [latest GitHub Release](../../releases/latest).
2. In the DCS Mission Editor, add a **MISSION START → DO SCRIPT FILE** trigger pointing to `CTLD_Next.lua`.
3. Optionally add a second trigger loading your `CTLD_userConfig.lua` (configuration overrides).

### Dynamic load (development)

For live development without rebuilding the `.miz` each time:

1. Run `tools/build/merge_CTLD.ps1` after each source edit to regenerate `CTLD_Next.lua`.
2. Place `CTLD_Next.lua` in a fixed local path and use a `DO SCRIPT` trigger with `dofile("your/path/CTLD_Next.lua")`.
3. Reload the mission in DCS (`Left Shift + R`) — no `.miz` re-packaging needed.

### Required sound files

Beacon homing requires two audio files in the mission. Add two **Sound to Country** actions (pick an unused country like Australia so no player hears them at mission start):

| File | Purpose |
|------|---------|
| `assets/beacon.ogg` | Main beacon tone (heard by most aircraft ADF) |
| `assets/beaconsilent.ogg` | Silent beacon (FC3 aircraft — prevents audio bleed) |

If these files are missing, radio beacons will not work.

---

## Configuration

All configuration lives in `CTLD_userConfig.lua` (or in a DO SCRIPT block after the main script).

### Configuration file structure

v2 uses a two-part config system:

#### Part 1 — Scalar parameters (YAML block)

Simple `bool / number / string` values are set in the `ctld.yamlConfigDatas` YAML block. Every line is commented out by default; uncomment and edit only what you need to change.

```lua
ctld.yamlConfigDatas = [[
# ctld.numberOfTroops: 10
# ctld.maximumDistanceLogistic: 200
# ctld.AASystemLimitBLUE: 20
]]
```

#### Part 2 — Complex tables (Lua `_cfg.settings`)

Tables (zones, capabilities, crates, groups…) are set on the `CTLDConfig` instance. The line `local _cfg = CTLDConfig.get()` is already present at the top of `CTLD_userConfig.lua`.

```lua
local _cfg = CTLDConfig.get()
_cfg.settings["troopZones"] = { ... }
_cfg.settings["capabilitiesByType"] = { ... }
_cfg.settings["spawnableCrates"] = { ... }
```

> **Note:** internally CTLD always reads settings via `ctld.gs("paramName")` — never call `config:getSetting()` directly.

### Language

```lua
ctld.language = "en"   -- "en" | "fr" | "es" | "ko"
```

### Zone Naming Conventions

CTLD auto-discovers zones from the Mission Editor using naming prefixes. Declare the zones in the ME, name them according to the convention, and CTLD picks them up at init without any additional configuration.

| Prefix | Type | Format | Purpose |
|--------|------|--------|---------|
| `TRZ_` | Troop zone | `TRZ_<name>_<A/R/B/N>_<stock>_<flag>_<target>` | Player pickup / extract |
| `LGZ_` | Logistic zone | `LGZ_<name>_[R/B/N]` | Crate / vehicle spawning |
| `WPZ_` | Waypoint zone | `WPZ_<name>_[R/B/N]` | Deployed troops march here |

**TRZ fields:**
- Coalition: `A`=all, `R`=RED, `B`=BLUE, `N`=neutral
- `stock`: `0`=no pickup (extract only), `1`–`998`=limited groups, `999`=unlimited
- `flag`: DCS flag name (string) that mirrors the remaining group count, or `nil`
- `target`: `0`=no win condition, `N≥1`=soldier threshold to complete the objective

**LGZ/WPZ fields:**
- Coalition suffix: `R`=RED, `B`=BLUE, `N`=neutral; omit for both sides

Examples:

```text
TRZ_depot_B_999_nil_0          -- BLUE pickup zone, unlimited stock, no flag, no objective
TRZ_exfil_B_0_nil_10           -- BLUE extract zone, no pickup, flag=nil, need 10 troops
LGZ_base_alpha_B               -- BLUE logistic zone
WPZ_objective_nord_B           -- BLUE waypoint zone
```

The legacy config-table approach (`_cfg.settings["troopZones"]`, `_cfg.settings["wpZones"]`) also works for backward compatibility.

### Troop Pickup Zones

Zones where transport units can load troops. Can be a ME trigger zone name or a ship unit name.

```lua
-- { "zone_or_ship_name", "smoke_color", limit, "active", side [, flag] }
--   smoke_color : "green" | "red" | "white" | "orange" | "blue" | "none"
--   limit       : -1 = unlimited ; N = max groups loadable (drops add 1 back)
--   active      : "yes" = available at start ; "no" = deactivated (use ctld.activatePickupZone())
--   side        : 0 = both ; 1 = RED ; 2 = BLUE
--   flag        : optional DCS flag number where remaining count is stored
_cfg.settings["troopZones"] = {
    { "pickzone1",   "blue",  -1, "yes", 0 },
    { "pickzone2",   "red",   -1, "yes", 0 },
    { "pickzone9",   "none",   5, "yes", 1 },      -- limit 5 groups
    { "pickzone11",  "blue",  20, "no",  2 },      -- starts inactive, BLUE only
    { "USA Carrier", "blue",  10, "yes", 0, 1001 },-- ship unit name; count stored in flag 1001
}
```

Smoke colours: `"green"` `"red"` `"white"` `"orange"` `"blue"` `"none"`

Disable all smoke globally: add `# ctld.disableAllSmoke: true` to the YAML block.

### AI Zones (Feature S)

AI Zones define where **AI transport units** automatically pick up and drop off cargo, independently of player menus. The DCS trigger zone provides position and radius only — it is not auto-discovered by prefix.

```lua
-- Required fields:
--   dcsZoneName : ME trigger zone name
--   coalition   : "RED" | "BLUE" | "NEUTRAL"
--
-- Optional pickup fields (isPickup = true):
--   cargoType      : "T"=troops | "V"=vehicles | "TV"=both  (default "T")
--   troopStock     : { [templateName] = N }  N=-1=unlimited, N>0=limited ; key "All"=all templates
--   vehicleStock   : { [typeName] = N }      N=-1=unlimited, N>0=limited
--
-- Optional dropoff fields (isDropoff = true):
--   aiDropMode   : "G"=ground | "P"=parachute | "GP"=both  (default "GP")
_cfg.settings["aiZones"] = {

    -- Pickup: troops only, 2 templates with limited stock
    { dcsZoneName = "AIZ_depot_bleu",  coalition = "BLUE",
      isPickup = true, cargoType = "T",
      troopStock = { ["Standard Group"] = 5, ["Anti Tank"] = 2 } },

    -- Pickup: troops from any template, unlimited stock
    { dcsZoneName = "AIZ_base_inf",    coalition = "BLUE",
      isPickup = true, cargoType = "T",
      troopStock = { ["All"] = -1 } },

    -- Pickup: vehicles — stock managed by CTLD (not physical DCS units)
    { dcsZoneName = "AIZ_depot_hmwv",  coalition = "BLUE",
      isPickup = true, cargoType = "V",
      vehicleStock = { ["Hummer"] = 3, ["M1025 HMMWV Armament"] = -1 } },

    -- Pickup: troops + vehicles combined zone, unlimited troops
    { dcsZoneName = "AIZ_depot_tv",    coalition = "BLUE",
      isPickup = true, cargoType = "TV",
      troopStock = { ["All"] = -1 }, vehicleStock = { ["Hummer"] = 5 } },

    -- Dropoff: ground landing only
    { dcsZoneName = "AIZ_lz_nord",     coalition = "BLUE",
      isDropoff = true, aiDropMode = "G" },

    -- Combined: same zone is both pickup and dropoff
    { dcsZoneName = "AIZ_farp_avance", coalition = "BLUE",
      isPickup = true, isDropoff = true,
      cargoType = "T", troopStock = { ["All"] = -1 }, aiDropMode = "GP" },
}
```

> **Note on vehicles:** entries in `vehicleStock` using a key that matches a FARP scene name or an AA system template name (`isScene`, `isAASystem`) are handled automatically by their respective subsystems.

### Waypoint Zones

Dropped or spawned troops automatically move toward the center of an active waypoint zone if their coalition matches. Use the `WPZ_` naming convention (auto-discovered) or declare them in config:

```lua
-- { "zone_name", "smoke_color", "active", side }
_cfg.settings["wpZones"] = {
    { "wpzone1", "green", "yes", 2 },
    { "wpzone2", "none",  "no",  1 },   -- starts inactive
}
```

Activate / deactivate at runtime: see [Mission Editor Script Functions → Zones](#zones).

### Transport Unit Setup

**Unified capability registry** — `capabilitiesByType` replaces the old `aircraftTypeTable`, `unitActions`, `vehiclesForTransportBLUE/RED` tables. Only aircraft types listed here receive CTLD F10 menus.

```lua
_cfg.settings["capabilitiesByType"] = {
    -- Fields:
    --   cratesEnabled            : can spawn, load and unpack crates
    --   troopsEnabled            : can load, deploy and extract infantry
    --   canParachuteDrop         : enables Parachute F10 entries
    --   canSlingload             : enables hover-pickup and Slingload menus
    --   canTransportWholeVehicle : can load/unload whole vehicles
    --   useNativeDcsCargoSystem  : uses DCS native cargo system for crate spawning
    --   maxTroopsOnboard         : max soldiers (overrides ctld.numberOfTroops)
    --   maxCratesOnboard         : max crates carried simultaneously
    --   maxWholeVehiclesOnboard  : max whole vehicles carried simultaneously
    --   loadableVehiclesRED      : DCS type names of RED vehicles loadable onto this aircraft
    --   loadableVehiclesBLUE     : DCS type names of BLUE vehicles loadable onto this aircraft

    ["UH-1H"]     = { cratesEnabled=true, troopsEnabled=true, canParachuteDrop=true,  canSlingload=true,
                      canTransportWholeVehicle=true,  useNativeDcsCargoSystem=true,
                      maxTroopsOnboard=8,  maxCratesOnboard=1, maxWholeVehiclesOnboard=1,
                      loadableVehiclesRED  = { "BRDM-2", "BTR_D" },
                      loadableVehiclesBLUE = { "M1045 HMMWV TOW", "M1043 HMMWV Armament" } },

    ["Mi-8MT"]    = { cratesEnabled=true, troopsEnabled=true, canParachuteDrop=false, canSlingload=true,
                      canTransportWholeVehicle=true,  useNativeDcsCargoSystem=true,
                      maxTroopsOnboard=16, maxCratesOnboard=2, maxWholeVehiclesOnboard=1,
                      loadableVehiclesRED  = { "BRDM-2", "BTR_D" },
                      loadableVehiclesBLUE = { "M1045 HMMWV TOW", "M1043 HMMWV Armament" } },

    ["CH-47Fbl1"] = { cratesEnabled=true, troopsEnabled=true, canParachuteDrop=false, canSlingload=true,
                      canTransportWholeVehicle=false, useNativeDcsCargoSystem=true,
                      maxTroopsOnboard=33, maxCratesOnboard=8, maxWholeVehiclesOnboard=1,
                      loadableVehiclesRED  = { "BRDM-2", "BTR_D" },
                      loadableVehiclesBLUE = { "M1045 HMMWV TOW", "M1043 HMMWV Armament" } },

    ["C-130J-30"] = { cratesEnabled=true, troopsEnabled=true, canParachuteDrop=false, canSlingload=false,
                      canTransportWholeVehicle=true,  useNativeDcsCargoSystem=true,
                      maxTroopsOnboard=80, maxCratesOnboard=20, maxWholeVehiclesOnboard=2,
                      loadableVehiclesRED  = { "BRDM-2", "BTR_D" },
                      loadableVehiclesBLUE = { "M1045 HMMWV TOW", "M1043 HMMWV Armament" } },
}
```

**Auto-registration (default):** `ctld.addPlayerAircraftByType = true` — any player boarding an aircraft type listed in `capabilitiesByType` automatically receives CTLD F10 menus.

**Manual restriction:** set `_cfg.settings["addPlayerAircraftByType"] = false` and list pilot names explicitly:

```lua
_cfg.settings["transportPilotNames"] = {
    "helicargo1", "helicargo2", "helicargo3",
    "transport1", "transport2",
}
```

> Each player transport should be in its own group (single unit). Otherwise all players in the same group share radio commands they should not receive.

### Logistic Units

Transport units can spawn crates when within `ctld.maximumDistanceLogistic` (default 200 m) of a logistic unit. Use either the `LGZ_` naming convention (auto-discovered) or declare named static objects:

```lua
_cfg.settings["logisticUnits"] = {
    "logistic1",
    "logistic2",
    "logistic3",
}
```

### Spawnable Crates

Crates are identified by weight (must be unique across all sections). The weight also acts as the DCS slingload mass.

```lua
_cfg.settings["spawnableCrates"] = {
    ["Combat Vehicles"] = {
        { weight = 1000.01, desc = "Humvee - MG",   unit = "M1043 HMMWV Armament", side = 2 },
        { weight = 1000.02, desc = "Humvee - TOW",  unit = "M1045 HMMWV TOW",      side = 2, cratesRequired = 2 },
        { multiple = { 1000.02, 1000.02 },           desc = "Humvee - TOW - All crates", side = 2 },
        { weight = 1000.11, desc = "BTR-D",          unit = "BTR_D",                side = 1 },
        { weight = 1000.12, desc = "BRDM-2",         unit = "BRDM-2",               side = 1 },
    },

    ["Support"] = {
        { weight = 1001.01, desc = "Hummer - JTAC", unit = "Hummer",               side = 2, cratesRequired = 2 },
        { multiple = { 1001.01, 1001.01 },           desc = "Hummer - JTAC - All crates", side = 2 },
        { weight = 1001.11, desc = "SKP-11 - JTAC", unit = "SKP-11",               side = 1 },
    },

    ["SAM short range"] = {
        { weight = 1003.01, desc = "M1097 Avenger",  unit = "M1097 Avenger",    side = 2, cratesRequired = 3 },
        { weight = 1003.11, desc = "9K33 Osa",       unit = "Osa 9A33 ln",      side = 1, cratesRequired = 3 },
    },

    -- NOTE: "SAM mid range" and "SAM long range" sections (HAWK, NASAMS, KUB, BUK,
    -- Patriot, S-300) are populated AUTOMATICALLY by CTLDCrateAssemblyManager from
    -- CTLDCrateAssemblyManager.TEMPLATES. Do NOT declare those crates manually here.
    -- See the [AA System Construction] section for how to configure TEMPLATES.
}
```

**Crate descriptor fields:**
- `weight` *(number)* — unique kg value used as lookup key; also used as DCS slingload mass. **Must be unique.**
- `desc` *(string)* — label shown in the F10 menu
- `unit` *(string)* — DCS unit type name spawned when the crate is unpacked
- `cratesRequired` *(number)* — number of identical crates needed to assemble the unit (default 1)
- `side` *(number)* — `1`=RED only, `2`=BLUE only; omit for both coalitions
- `multiple` *(table)* — list of weights; shortcut entry that spawns all listed crates at once

`cratesRequired` forces assembly of N identical crates within 100 m. Do not use on multi-component AA systems (HAWK, KUB, etc.) — those use TEMPLATES.

### Custom Troop Templates

Define infantry group compositions shown in the F10 troop menu:

```lua
_cfg.settings["loadableGroups"] = {
    { name = "Standard Group",  inf = 6, mg = 2, at = 2 },
    { name = "Anti Air",        inf = 2, aa = 3 },
    { name = "Anti Tank",       inf = 2, at = 6 },
    { name = "Mortar Squad",    mortar = 6 },
    { name = "JTAC Group",      inf = 4, jtac = 1 },
    { name = "AT Section RED",  at = 4, inf = 2, side = 1 },   -- RED only
}
```

**Role fields:** `inf` `mg` `at` `aa` `mortar` `jtac` `civ`

**Per-template DCS type override (`componentTypes`)** — override which DCS unit type is spawned for a given role and coalition:

```lua
_cfg.settings["loadableGroups"] = {
    {
        name = "Special Operators",
        inf = 4, mg = 2,
        -- Override infantry to use Paratrooper model for BLUE, standard for RED
        componentTypes = {
            inf  = { [1] = "Soldier AK",       [2] = "Paratrooper RPG-16" },
            mg   = { [1] = "Soldier RPG",       [2] = "Paratrooper AKS-74" },
        },
    },
    {
        name = "Civilian Crowd",
        civ = 8,
        -- Override civ role to use specific civilian models per coalition
        componentTypes = {
            civ  = { [1] = "Civilian",          [2] = "Civilian" },
            civ2 = { [1] = "Infantry AK ver3",  [2] = "Infantry M4" },
        },
    },
}
```

Custom roles beyond the standard set (e.g. `civ1`, `civ2`, `civ3`) are supported: declare their count in the template table and their type names in `componentTypes`. Civilian roles (`civ*`) use a reduced weight constant; all others fall back to rifle weight.

### JTAC Configuration

```lua
-- In the YAML block:
# ctld.JTAC_LIMIT_RED: 10        -- max JTAC units for RED
# ctld.JTAC_LIMIT_BLUE: 10       -- max JTAC units for BLUE
# ctld.JTAC_dropEnabled: true    -- allow JTAC crate spawn from F10 menu
# ctld.JTAC_maxDistance: 10000   -- JTAC line-of-sight range (meters)
# ctld.JTAC_lock: all            -- "vehicle" | "troop" | "all"
# ctld.JTAC_jtacStatusF10: true  -- F10 JTAC Status menu
# ctld.JTAC_location: true       -- include target coords in JTAC message
# ctld.location_DMS: false       -- DMS format instead of decimal degrees
# ctld.JTAC_allowStandbyMode: true
# ctld.JTAC_laseSpotCorrections: true
# ctld.JTAC_allowSmokeRequest: true
# ctld.JTAC_allow9Line: true
# ctld.JTAC_smokeOn_RED: false
# ctld.JTAC_smokeOn_BLUE: false
# ctld.JTAC_smokeColour_RED: 4   -- 0=Green 1=Red 2=White 3=Orange 4=Blue
# ctld.JTAC_smokeColour_BLUE: 1
# ctld.enableAutoOrbitingFlyingJtacOnTarget: false
# ctld.JTAC_laseIntervalSeconds: 15     -- auto-lase loop reschedule delay (s) when actively lasing a target
# ctld.JTAC_searchIntervalSeconds: 10   -- auto-lase loop reschedule delay (s) when searching (no target acquired)
# ctld.JTAC_smokeMarginOfError: 50      -- max position error (m) when popping target smoke
# ctld.JTAC_smokeOffset_x: 0.0         -- additional X offset applied to target smoke position (m)
# ctld.JTAC_smokeOffset_y: 2.0         -- height offset applied to target smoke position (m)
# ctld.JTAC_smokeOffset_z: 0.0         -- additional Z offset applied to target smoke position (m)
```

### Parachute Configuration

Virtual parachute drop simulates inertia and lateral drift for crates, troops and vehicles.

```lua
# In the YAML block:
# ctld.parachuteMinAltitudeCrates: 30     -- minimum AGL (m) for crate drops
# ctld.parachuteMinAltitudeTroops: 50     -- minimum AGL (m) for troop drops
# ctld.parachuteMinAltitudeVehicles: 30   -- minimum AGL (m) for vehicle drops
# ctld.parachuteDescentRateCrates: 5      -- vertical descent speed (m/s)
# ctld.parachuteDescentRateTroops: 5
# ctld.parachuteDescentRateVehicles: 8
# ctld.parachuteInertiaFactor: 0.3        -- fraction of transport speed applied as forward drift
# ctld.parachuteLateralDriftMin: 10       -- minimum lateral drift per unit (m)
# ctld.parachuteLateralDriftMax: 80       -- maximum lateral drift per unit (m)
# ctld.autoUnpackRadiusParachute: 1000    -- search radius for auto-unpack after landing (m)
```

Enable parachute per aircraft type via `canParachuteDrop = true` in `capabilitiesByType`.

### Slingload Configuration

Virtual slingload uses hover detection instead of DCS sling physics (avoids crash bugs).

```lua
# In the YAML block:
# ctld.slingLoad: false             -- false = virtual hover-load; true = real DCS slingload
# ctld.minimumHoverHeight: 7.5      -- minimum hover AGL for pick-up (m)
# ctld.maximumHoverHeight: 12.0     -- maximum hover AGL
# ctld.maxDistanceFromCrate: 5.5    -- maximum horizontal distance from crate center (m)
# ctld.hoverTime: 10                -- seconds to hold hover to complete load
# ctld.maxSlingloadSpeed: 50        -- max speed (m/s) before crate is lost (virtual mode)
```

### FOB Configuration

```lua
# In the YAML block:
# ctld.enabledFOBBuilding: true
# ctld.troopPickupAtFOB: true
# ctld.fobMinDistanceFromZones: 500   -- minimum distance from existing logistic zones (m)
# ctld.fobLogisticZoneRadius: 150     -- logistic zone radius around the built FOB (m)
# ctld.fobDestructionThreshold: 0.5   -- fraction of scene objects destroyed before FOB is considered lost (0.0–1.0)
# ctld.radioSound: beacon.ogg
# ctld.radioSoundFC3: beaconsilent.ogg
# ctld.deployedBeaconBattery: 30      -- beacon battery life (minutes)
```

### Beacon Layer Configuration

When `ctld.beaconLayerEnabled` is true, each deployed beacon is drawn as a coloured circle icon on the F10 map.

```lua
-- In the YAML block:
# ctld.beaconLayerEnabled: false         -- draw beacon positions as icons on the F10 map
# ctld.beaconAutoRefreshLayer: false     -- auto-add newly-dropped beacons to the active layer
# ctld.beaconRefreshInterval: 60         -- seconds between beacon layer refreshes
# ctld.beaconIconRadius: 25              -- radius (m) of each beacon circle icon on the F10 map
# ctld.beaconTextSize: 12                -- font size of beacon name / frequency label
```

Beacon icon colour is set as an RGBA table (not a YAML line) in `CTLD_userConfig.lua`:

```lua
_cfg.settings["beaconIconColor"] = { 1.0, 0.5, 0.0, 1.0 }  -- R, G, B, A  (default: orange)
```

### Smoke Drop Configuration

```lua
# In the YAML block:
# ctld.enableSmokeDrop: true              -- allow transport units to drop smoke from F10 menu
# ctld.smokeAutoResume: false             -- global default for smoke auto-resume (per-player toggle overrides)
# ctld.smokeAutoResumeInterval: 270       -- seconds before a smoke is re-triggered (default 4 min 30 s; DCS smoke lasts ~5 min)
```

### Minefield Configuration

```lua
# In the YAML block:
# ctld.showMinefieldOnF10Map: true        -- draw a bounding outline on the F10 map when a minefield is deployed
# ctld.demineRadius: 150                  -- max distance (m) from player to minefield center for "Clear Mine Field" to appear
```

### Miscellaneous Parameters

```lua
# In the YAML block:
# ctld.groundAglThreshold: 5.0           -- AGL (m) below which a stationary aircraft is considered on the ground
# ctld.crateSpacing: 5                   -- spacing (m) between consecutive crate spawn positions along the drop axis
# ctld.spawnDistanceInCircle: 10         -- extra radius (m) added when placing units in circle formation on deploy
```

---

## Mission Editor Script Functions

### Troops

**Preload an AI transport with troops:**

```lua
CTLDTroopManager.getInstance():preLoadTransport("helicargo1", 10)
-- legacy: ctld.preLoadTransport("helicargo1", 10, true)
```

**Spawn extractable group at a trigger zone:**

```lua
-- Simple count
ctld.spawnGroupAtTrigger("blue", 10, "spawnTrigger", 1000)

-- Custom composition
ctld.spawnGroupAtTrigger("blue", { mg=1, at=2, aa=1, inf=4, mortar=1 }, "spawnTrigger", 2000)
```

**Spawn extractable group at a point:**

```lua
ctld.spawnGroupAtPoint("red", 10, { x=1, y=2, z=3 }, 1000)
```

**Register pre-placed groups as extractable:**

```lua
-- Groups placed in the Mission Editor that players can extract via F10 menu
_cfg.settings["extractableGroups"] = {
    "rescue_team_alpha",
    "downed_pilot_1",
}
```

These groups are registered at CTLD init. Any group not found at that time is skipped.

**Force load / unload an AI unit:**

```lua
ctld.loadTransport("helicargo1")
ctld.unloadTransport("helicargo1")
```

**Auto-unload near enemies (continuous trigger):**

```lua
ctld.unloadInProximityToEnemy("helicargo1", 500)  -- 500 m search radius
```

### Zones

**Activate / deactivate a pickup zone:**

```lua
ctld.activatePickupZone("pickzone3")
ctld.deactivatePickupZone("pickzone3")
```

**Change remaining groups at a pickup zone:**

```lua
ctld.changeRemainingGroupsForPickupZone("pickzone1",  5)   -- add 5 groups
ctld.changeRemainingGroupsForPickupZone("pickzone1", -3)   -- remove 3 groups
```

**Activate / deactivate a waypoint zone:**

```lua
ctld.activateWaypointZone("wpzone1")
ctld.deactivateWaypointZone("wpzone1")
```

**Create an extract zone** (troops dropped here disappear; flag counts them):

```lua
ctld.createExtractZone("extractzone1", 2, -1)
-- param 1: trigger zone name
-- param 2: flag number to accumulate troop count
-- param 3: smoke colour (0=Green … 4=Blue; -1=none)

ctld.removeExtractZone("extractzone1", 2)
```

**Count extractable units / groups in a zone (continuous trigger):**

```lua
ctld.countDroppedUnitsInZone( "zoneName", blueFlag, redFlag)
ctld.countDroppedGroupsInZone("zoneName", blueFlag, redFlag)
```

### Crates

**Watch a zone and store crate count in a flag (continuous trigger):**

```lua
ctld.cratesInZone("crateZone", 1)   -- stores count in flag 1 every 5 s
```

**Spawn a crate at a trigger zone:**

```lua
-- side: "blue" or "red"
-- weight: must match an entry in spawnableCrates
ctld.spawnCrateAtZone("blue", 1000.01, "crateSpawnTrigger")
ctld.spawnCrateAtZone("red",  1000.12, "crateSpawnTrigger")
```

**Spawn a crate at a point:**

```lua
ctld.spawnCrateAtPoint("blue", 1000.01, { x=20, y=10, z=20 })
-- tip: Unit.getByName("pilotName"):getPoint() gives a valid point
```

### JTAC

**Activate a mission-editor JTAC:**

```lua
ctld.JTACAutoLase("JTAC1", 1688)                          -- default smoke + all targets
ctld.JTACAutoLase("JTAC1", 1688, false, "all")            -- no smoke, all targets
ctld.JTACAutoLase("JTAC1", 1688, true,  "vehicle")        -- smoke on, vehicles only
ctld.JTACAutoLase("JTAC1", 1688, true,  "troop",   1)     -- smoke on, troops only, Red smoke
ctld.JTACAutoLase("JTAC1", 1688, true,  "all",     4,     -- Blue smoke + SRS radio
    { freq = "251.50", mod = "AM", name = "JTAC one" })
```

`JTAC1` is the **group name** in the Mission Editor. The group must contain exactly one unit.

**Stop auto-lase:**

```lua
ctld.JTACAutoLaseStop("JTAC1")
```

> JTAC units deployed by crate unpack auto-activate immediately and need no DO SCRIPT call.

**Unit priority targeting** — include `"hpriority"` or `"priority"` in the DCS unit name to affect which target the JTAC locks first.

**SRS speech** requires `DCS-SimpleTextToSpeech.lua` loaded with `STTS.DIRECTORY` and `STTS.SRS_PORT` set.

### Beacons

**Create a radio beacon at a trigger zone:**

```lua
ctld.createRadioBeaconAtZone("beaconZoneBlue", "blue", 20)
-- param 3: duration in minutes
-- optional param 4: beacon name shown in F10 list
```

The beacon broadcasts on HF/FM, UHF and VHF simultaneously. Frequencies are drawn from coalition pools.

---

## Subscribing to CTLD Events

v2 replaces the v1 catch-all `ctld.addCallback` with typed subscriptions. Each event fires only the relevant handlers — no `if/elseif` chain required.

```lua
-- v1 (deprecated — still works via legacy wrapper)
ctld.addCallback(function(event)
    if event.id == ctld.events.S_EVENT_CRATE_SPAWNED then ... end
end)

-- v2 (preferred)
EventDispatcher.getInstance():subscribe("OnCrateSpawned", function(evt)
    -- evt.crateName, evt.coalition, evt.spawnedBy, evt.position
    trigger.action.outText("Crate spawned: " .. evt.crateName, 10)
end)
```

Full event catalogue: [`docs/specs/CTLD_Events.md`](docs/specs/CTLD_Events.md)

Selected events:

| Event | Key fields |
|-------|-----------|
| `OnCrateSpawned` | `crateName`, `coalition`, `spawnedBy`, `position` |
| `OnCrateLoaded` | `crateName`, `transportName`, `playerName` |
| `OnCrateUnpacked` | `unitName`, `unitType`, `builtBy`, `position` |
| `OnVehiclePacked` | `vehicleName`, `vehicleType`, `packedBy` |
| `OnTroopsBoarded` | `groupName`, `transportName`, `troopCount` |
| `OnTroopsDeployed` | `groupName`, `deployedBy`, `position` |
| `OnTroopsExtracted` | `groupName`, `extractedBy`, `extractZone` |
| `OnFOBDeployed` | `fobName`, `position`, `coalition` |
| `OnBeaconDropped` | `beaconId`, `frequency`, `modulation`, `coalition` |
| `OnJTACLaseStart` | `jtacName`, `targetName`, `laserCode` |
| `OnMMCrateDetected` | `staticName`, `position` |

---

## In-Game F10 Menu

The CTLD F10 menu is built dynamically per transport unit. It only shows actions that are currently possible (e.g. "Unload Troops" only appears when troops are aboard).

Menu structure:

```
F10 Other / [Transport Name]
├── Troop Commands
│   ├── Load Troops                  (at pickup zone; one entry per template)
│   ├── Extract Troops from Field    (if extractable troops nearby)
│   ├── Disembark Troops             (on ground with troops aboard)
│   ├── Check Cargo                  (lists current aboard manifest)
│   └── Parachute Troops             (in air, canParachuteDrop enabled)
├── Request Equipment                (at logistic zone: zone → category → crate)
├── Vehicle Commands
│   ├── Load Vehicle                 (whole vehicle pick-up, on ground)
│   ├── Unload Vehicle               (on ground with whole vehicle aboard)
│   └── Parachute Vehicle            (in air, canParachuteDrop enabled)
├── Crate Commands
│   ├── Spawn Crate → [Category] → [Crate]   (at logistic zone)
│   ├── Load Crate                   (hover-load, or menu if loadCrateFromMenu=true)
│   ├── Drop Crate(s)                (releases loaded crate in flight)
│   ├── Unpack Crate                 (on ground, assembles unit)
│   ├── Pack Equipt                  (ground only; pack nearby FARP or vehicle)
│   │   ├── Pack [Vehicle name]      (each packable ground vehicle nearby)
│   │   └── Pack [FARP name]         (each repackable FARP scene nearby)
│   ├── Parachute Crates             (in air, canParachuteDrop enabled)
│   ├── Slingload Release            (virtual sling: controlled drop in flight)
│   └── Slingload Cut                (virtual sling: emergency cut, crate falls)
├── Radio Beacons
│   ├── Drop Beacon                  (deploys beacon at current position)
│   ├── Remove Closest Beacon        (removes nearest active beacon)
│   └── List Beacons                 (shows all active beacons, freq, time remaining)
├── FOBs List                        (lists all active FOBs and their positions)
├── RECON
│   ├── RECON Scan / RECON Stop      (manual scan for enemy contacts)
│   ├── Toggle Auto-Refresh          (enable / disable periodic re-scan)
│   └── Toggle Layer [name]          (show / hide a RECON map layer)
├── Smoke Commands
│   ├── Drop Red / Blue / Orange / Green Smoke
│   └── Toggle Smoke Auto-Resume     (keeps smoke continuously refreshed)
├── Mine Field
│   └── Clear Mine Field             (appears when near a deployed minefield)
└── JTAC Commands
    ├── Request JTAC Equipment       (spawn JTAC crate at logistic zone)
    ├── JTAC Status                  (all active JTACs and their targets)
    └── [JTAC name]
        ├── Toggle Lasing
        ├── Spot Corrections
        ├── Smoke on Target
        └── Request 9-Line
```

---

## Troop Operations

**Loading** — land (or hover, for helicopters) inside a pickup zone. Select **Load Troops** from the F10 menu. AI transports configured in `aiZones` load automatically on entering the zone.

**Default group composition** (when `ctld.numberOfTroops` ≥ 6):
- 2 × MG soldiers
- 2 × RPG/AT soldiers
- 1 × Stinger / Igla (if `ctld.spawnStinger = true`)
- Remainder: standard infantry

**Custom templates** — configure `_cfg.settings["loadableGroups"]` for named groups with exact compositions (see [Custom Troop Templates](#custom-troop-templates)).

**Deploying** — land at the destination. Select **Unload Troops**. Troops spawn around the aircraft with a search radius of `ctld.maximumSearchDistance` for enemies.

**Fast rope** — at low altitude (`ctld.fastRopeMaximumHeight`, default 18 m), troops are deployed directly below the helicopter without landing.

**Parachute** — in flight above `ctld.parachuteMinAltitudeTroops`, select **Parachute Troops**. Each soldier drifts individually based on inertia and lateral drift parameters.

---

## Crate Operations

**Spawn** — at a logistic unit, select **Spawn Crate → [Category] → [Crate type]**.

**Load (virtual hover-load)** — hover between `ctld.minimumHoverHeight` and `ctld.maximumHoverHeight` within `ctld.maxDistanceFromCrate` of the crate for `ctld.hoverTime` seconds. Menu option also available if `ctld.loadCrateFromMenu = true`.

**Drop** — select **Drop Crate** in flight. With virtual slingload active, the crate drifts from the drop point based on speed and altitude.

**Unpack** — land near a dropped crate. Select **Unpack Crate** — the crate is replaced by the corresponding unit. Multi-crate items (e.g. SPH requiring 3 crates) require all crates within 100 m before unpacking.

---

## Virtual Parachute Drop

When `canParachuteDrop = true` on the aircraft type and the unit is airborne above the minimum altitude:

- The menu shows **Parachute [Troops / Crate / Vehicle]**.
- Each item has independent forward inertia (`ctld.parachuteInertiaFactor` × transport speed) plus random lateral drift (`ctld.parachuteLateralDriftMin`–`ctld.parachuteLateralDriftMax`).
- Troops land dispersed; parachuted crates auto-unpack on landing if the target area is clear within `ctld.autoUnpackRadiusParachute`.

> **Crate parachute limitation:** only crates loaded via the **CTLD F10 menu** (Load Crate / hover-load / virtual slingload) are eligible for parachute drop. Crates loaded through the DCS native cargo system (`useNativeDcsCargoSystem = true`) are managed by DCS and cannot be released via CTLD's parachute menu.

---

## Virtual Slingload

When `ctld.slingLoad = false` (default):

1. Hover above the crate within height/distance tolerances for `ctld.hoverTime` seconds → crate auto-loads.
2. In flight, select **Slingload Release** to drop the crate at the current position.
3. Select **Slingload Cut** to drop immediately (emergency; crate falls straight down).
4. If airspeed exceeds `ctld.maxSlingloadSpeed` m/s, the crate is lost.

When `ctld.slingLoad = true`: DCS native sling physics are used (may cause crashes on some versions).

---

## Forward Operating Base (FOB)

A FOB provides a new crate spawn point and optionally a troop pickup point anywhere on the map.

1. Load FOB crates at a logistic zone (large crates require large aircraft; small crates count as 1/3).
2. Drop `ctld.cratesRequiredForFOB` large crates (or equivalent in small) within 100 m of each other.
3. Select **Build FOB** — the FOB spawns with a radio beacon.
4. The built FOB appears in F10 as a new logistic point for crate spawning.
5. If `ctld.troopPickupAtFOB = true`, troops can also be loaded there.

Event `OnFOBDeployed` fires when construction completes.

---

## FARP Deployment

A FARP (Forward Arming and Refuelling Point) is deployed as a scene: a sequence of static objects (helipads, fuel trucks, shelters) spawn around the helicopter.

1. At a logistic zone, spawn and load a FARP crate.
2. Fly to the desired deployment site and land.
3. Select **Deploy FARP** — the scene executes step-by-step over several seconds.
4. The deployed FARP becomes active in DCS for rearming and refuelling.

---

## Radio Beacons

Beacons broadcast on HF/FM, UHF and VHF simultaneously. Frequencies are drawn from coalition pools to avoid conflicts.

**Deploying via F10** — land (or hover), select **Drop Beacon** from the menu. The beacon appears on the F10 map.

**Deploying via script** — `ctld.createRadioBeaconAtZone("zone", "blue", 30, "Waypoint Alpha")`

**Battery life** — configured by `ctld.deployedBeaconBattery` (minutes). After expiry the beacon stops transmitting.

**ADF tuning by aircraft:**

| Aircraft | Band | Notes |
|----------|------|-------|
| A-10C/II | UHF | ADF page in EHSI |
| Ka-50 | UHF | ARK-22 |
| Mi-8 / Mi-24 | VHF/FM | ARC-9 |
| UH-1H | VHF | ADF |
| All others | FM | Tune to displayed frequency |

---

## JTAC Auto-Lase

**Mission-editor JTACs** — place the JTAC unit in a dedicated single-unit group. Activate via `ctld.JTACAutoLase("GroupName", laserCode)`. See full syntax in [Mission Editor Script Functions → JTAC](#jtac).

**Crate-deployed JTACs** — spawn a JTAC crate (`Hummer - JTAC` or `SKP-11 - JTAC`), drop it, and unpack it. The JTAC auto-activates immediately.

**Target priority** — include `hpriority` or `priority` in the unit name (Mission Editor) to control lasing order.

**F10 menu** — if `ctld.JTAC_jtacStatusF10 = true`, a **JTAC Status** entry lists all active JTACs, their target, laser code and options (toggle lasing, request smoke, request 9-line).

**Drone orbit** — if `ctld.enableAutoOrbitingFlyingJtacOnTarget = true`, flying JTAC units (drones) orbit above their lased target; they return to their flight plan when no target is visible.

---

## Smoke Drop

Transport units can drop coloured smoke grenades from the **Smoke Commands** F10 menu.

**Colours available:** Red, Blue, Orange, Green (colours hard-coded; the four entries are always present when `ctld.enableSmokeDrop = true`).

**Auto-Resume** — select **Toggle Smoke Auto-Resume** from the menu to keep smoke continuously active. When enabled, CTLD re-triggers smoke automatically every `ctld.smokeAutoResumeInterval` seconds (default 270 s — just before DCS smoke dissipates at ~300 s). The toggle is per-player; it can be enabled at any time and persists until the player toggles it off or disconnects.

**Disable globally:** set `ctld.enableSmokeDrop = false` in the YAML block.

---

## Recon and Target Marking

CTLD includes a recon layer that places enemy contacts as F10 map markers.

**Activate via F10** — select **Recon Scan** from the transport menu. Contacts within `ctld.reconSearchRadius` appear as icons on the F10 map (unit must be at or above `ctld.reconMinAltitude`).

**Auto-refresh** — enable periodic re-scan via **Toggle Auto-Refresh** in the F10 menu (interval: `ctld.reconRefreshInterval`).

**Icon scale** — `ctld.reconIconScale` multiplier applied to all RECON markers (default 1.0).

**Events fired:**

| Event | When |
|-------|------|
| `OnReconScan` | Manual scan triggered |
| `OnReconScanRefresh` | Auto-refresh cycle |
| `OnReconLayerToggled` | Map layer shown/hidden |

---

## AA System Construction

Multi-crate AA systems are assembled by `CTLDCrateAssemblyManager`. All required crates must be dropped within 100 m of each other before unpacking.

### Available systems (default configuration)

| System | Side | Key components |
|--------|------|----------------|
| HAWK | BLUE | Launcher + Search Radar + Track Radar |
| NASAMS | BLUE | Launcher 120C + Search/Track Radar + Command Post |
| KUB | RED | Launcher + Radar |
| BUK | RED | Launcher + Search Radar + CC Radar |
| Patriot | BLUE | Launcher + Radar + ECS |
| S-300 | RED | TEL C + Flap Lid TR + Clam Shell SR + Big Bird SR + C2 |

Each system also has a **Repair crate** (unpacking it near a damaged system restores it).

**All crates shortcut** — an "All crates" entry in the F10 menu spawns all components at once for each system.

**Limits** — set in YAML:

```
# ctld.AASystemLimitRED: 20
# ctld.AASystemLimitBLUE: 20
```

**Crate stacking** — `ctld.AASystemCrateStacking: true` allows spawning N launcher crates to get N launchers per system.

### Configuring AA system templates

All AA system definitions live in `CTLDCrateAssemblyManager.TEMPLATES` (declared in `CTLD_userConfig.lua` after the crates table). `injectAACrates()` automatically populates the `spawnableCrates` sections — **do not declare HAWK/NASAMS/KUB/BUK/Patriot/S-300 crates in `spawnableCrates` manually.**

```lua
-- Declared in CTLD_userConfig.lua, near the end of CTLDConfig:load()
CTLDCrateAssemblyManager.TEMPLATES = {
    {
        name = "HAWK AA System",
        side = 2,           -- 2 = BLUE
        sectionName = "SAM mid range",
        allCratesLabel = "HAWK - All crates",
        parts = {
            { DCSTypename = "Hawk ln",   desc = "HAWK Launcher",      weight = 1004.01, launcher = true },
            { DCSTypename = "Hawk sr",   desc = "HAWK Search Radar",  weight = 1004.02, amount = 2 },
            { DCSTypename = "Hawk tr",   desc = "HAWK Track Radar",   weight = 1004.03, amount = 2 },
            { DCSTypename = "Hawk pcp",  desc = "HAWK PCP",           weight = 1004.04, NoCrate = true },
            { DCSTypename = "Hawk cwar", desc = "HAWK CWAR",          weight = 1004.05, NoCrate = true, amount = 2 },
        },
        repair = { desc = "HAWK Repair", weight = 1004.06 },
    },
    -- ... other systems follow the same structure
}
```

**Part fields:**
- `DCSTypename` — DCS unit type name spawned as part of the assembled group
- `desc` — label shown in the F10 menu
- `weight` — unique kg value (crate lookup key); required for parts that spawn a crate
- `launcher` — `true` marks this part as the launcher (count affected by `ctld.aaLaunchers` / stacking)
- `amount` — number of units of this type in the assembled group (default 1)
- `NoCrate` — `true` for parts spawned automatically with the group but not separately available as crates

---

## Pack Equipt

The **Pack Equipt** submenu under **Crate Commands** lets players pack deployed equipment back into crates for relocation. It appears only when the helicopter is on the ground and at least one packable item is nearby. It is absent in flight.

### Pack Vehicle

Pack a ground vehicle into crates for air transport, then reassemble it on the other side.

**Packing:**
1. Land near a packable vehicle (within `ctld.maximumDistancePackableUnitsSearch` meters).
2. The F10 menu shows **Pack Equipt → [vehicle name]** under Crate Commands.
3. Selecting it destroys the vehicle and spawns the required number of crates around the helicopter.

**Unpacking:**
1. Drop the crates at the destination.
2. Land near them and select **Unpack Crate** — the vehicle reassembles.

Event `OnVehiclePacked` fires on successful pack.

**Enable:** `_cfg.settings["enablePackingVehicles"] = true`

### Pack FARP

Pack a deployed FARP scene back into crates to redeploy it elsewhere. The FARP warehouse fuel levels are snapshotted and restored when the crates are unpacked at the new location.

**Packing:**

1. Land near a deployed FARP (within 300 m).
2. The F10 menu shows **Pack Equipt → Pack [FARP name]** under Crate Commands.
3. Selecting it captures the current fuel levels, destroys the scene, and spawns crates around the helicopter carrying the fuel snapshot.

**Redeploying:**

1. Fly to the new site, land, and unpack the crates — the FARP respawns with its fuel levels restored.

**Enable:** `_cfg.settings["enableFARPRepack"] = true` (default: `true`)

**Supported scenes:** `Countryside FARP`, `Metal FARP`. Custom scenes can support repack by implementing an `onRepack(scene, repackData)` hook — see [MM guide §16](docs/missionmaker_guide.md).

---

## Minefield Deployment

A minefield deploys a staggered grid of landmine static objects in front of the transport unit. The layout uses a quinconce pattern (alternating row offsets) for realistic coverage.

**Deploying from the F10 menu** — a FARP scene or crate unpack can trigger minefield deployment automatically. The scene calls `mineFieldScene.setLandMineAuto()` internally; the player sees the mines spawn around the aircraft.

**Scripted deployment (Mission Editor):**

```lua
-- Simple call: explicit grid
-- setLandMine(unitObj, distFromUnit, nbColumns, nbPerColumn, colSpacing, rowSpacing)
mineFieldScene.setLandMine(Unit.getByName("helo1"), 20, 5, 6, 12, 15)

-- Parametric call: specify area dimensions and count; spacing computed automatically
-- setLandMineAuto(unitObj, distFromUnit, widthMeters, lengthMeters, nbMines)
local ok, result = mineFieldScene.setLandMineAuto(Unit.getByName("helo1"), 30, 50, 80, 40)
-- deploys ~40 mines in a 50 m wide × 80 m long field starting 30 m ahead
```

**F10 map outline** — when `ctld.showMinefieldOnF10Map = true` (default), a bounding quadrilateral is drawn on the F10 map to mark the minefield extent.

**Clearing** — when the player is within `ctld.demineRadius` (default 150 m) of a minefield center, **Clear Mine Field** appears in the F10 menu. Selecting it destroys all mines in that set and removes the F10 map outline.

---

## Migration from v1

All 22 legacy `ctld.*` functions are preserved as thin wrappers in `src/legacy/legacy_api.lua`. Each wrapper logs a deprecation warning and delegates to the equivalent v2 manager method. **Existing missions continue to work without changes.**

Selected migration table (full table in [`docs/dev-guide.md`](docs/dev-guide.md)):

| v1 call | v2 equivalent |
|---------|--------------|
| `ctld.pickupZones = { ... }` | `_cfg.settings["troopZones"] = { ... }` |
| `ctld.spawnableCrates = { ... }` | `_cfg.settings["spawnableCrates"] = { ... }` |
| `ctld.aircraftTypeTable`, `ctld.unitActions`, `ctld.vehiclesForTransportBLUE/RED` | `_cfg.settings["capabilitiesByType"] = { ... }` |
| `ctld.spawnGroupAtTrigger(name, zone, side)` | `CTLDTroopManager.getInstance():spawnGroupAtTrigger(...)` |
| `ctld.JTACAutoLase(group, code, smoke)` | `CTLDJTACManager.getInstance():autoLase(...)` |
| `ctld.spawnCrateAtZone(type, zone, side)` | `CTLDCrateManager.getInstance():spawnCrateAtZone(...)` |
| `ctld.activatePickupZone(zone)` | `CTLDZoneManager.getInstance():activatePickupZone(zone)` |
| `ctld.addCallback(fn)` | `EventDispatcher.getInstance():subscribe("OnEventName", fn)` |

For the full migration guide including the v1 `addCallback` → typed events transition, see [`docs/dev-guide.md §7`](docs/dev-guide.md).

---

## Developer Guide

See [`docs/dev-guide.md`](docs/dev-guide.md) for:

- Repository structure (`src/`, `tests/`, `tools/`, `docs/`, `source/`)
- Architecture overview (singleton managers, EventDispatcher)
- How to add a new module
- Event pub/sub patterns
- Build instructions (local `merge_CTLD.ps1`, CI via GitHub Actions)
- Unit testing with busted (no DCS required)
- Full v1 → v2 migration guide

**Build locally:**

```
cd tools/build
powershell -ExecutionPolicy Bypass -File tools/build/merge_CTLD.ps1
```

Output: `CTLD_Next.lua` at repo root.

**Testing:**

```
# Install busted once (requires lua5.1 + luarocks)
luarocks install busted

# Run all tests (929 specs, no DCS required)
busted tests/
```

Tests live in `tests/unit/` (L1 — unit) and `tests/functional/` (L2 — functional). DCS stubs and module loaders are in `tests/helpers/`. See `docs/dev-guide.md §8` for the full testing guide including Witchcraft live-DCS tests (L3/L4).

**CI:** every push to `master` or `feature_*` branches runs Lua lint, merge build, and busted tests automatically. Every `v*` tag creates a GitHub Release with `CTLD_Next.lua` attached.
