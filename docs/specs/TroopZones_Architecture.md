# TroopZones Architecture Specification

**Status**: Validated
**Date**: 2026-04-20
**Version**: 2.0

## Overview

Unified TroopZone architecture replacing separate PickupZones and ExtractZones systems with a single, flexible zone type supporting troop pickup, mission extraction objectives, or both (mixed).

## Naming Convention

```
TRZ_<name>_<A|R|B|N>_<stock>_<flag>_<target>
```

**All 5 fields are required.** The parser rejects any name with missing or invalid fields.

### Field Reference

| Position | Field | Type | Values | Description |
|----------|-------|------|--------|-------------|
| 1 | `TRZ_` | Prefix | literal | Zone type identifier |
| 2 | `name` | String | any (not a reserved word) | Zone identifier — no underscores |
| 3 | `coalition` | Enum | `A` `R` `B` `N` | **A**=all, **R**=RED, **B**=BLUE, **N**=NEUTRAL |
| 4 | `stock` | Integer 0–999 | `0`=no pickup, `1–998`=limited, `999`=unlimited | Troop boarding capacity |
| 5 | `flag` | String | DCS flag name or `nil` | Objective flag to increment on extract; `nil`=no objective |
| 6 | `target` | Integer ≥0 | `0`=no win condition, `N≥1`=soldier threshold | Soldiers needed to complete objective |

### Reserved Words

These words cannot be used as `name` or (implicitly) are parsed with special meaning:
`nil`, `A`, `R`, `B`, `N`

### Stock Semantics

| Name value | Meaning | Internal `pickMaxStock` |
|------------|---------|------------------------|
| `0` | Zone has no pickup capability | `nil` |
| `1–998` | Limited stock (decrements on load) | `1–998` |
| `999` | Unlimited pickup | `0` |

> Use `999` for unlimited pickup — NOT `0`. `0` means "this zone cannot board troops."

### Flag Semantics

| Name value | Meaning | Internal `objectiveFlag` |
|------------|---------|--------------------------|
| `nil` | No objective flag | `nil` |
| any string | DCS flag name, incremented by soldier count on extract | the string |

### Target Semantics

| Name value | Meaning | Internal `objectiveTarget` |
|------------|---------|---------------------------|
| `0` | No win threshold defined | `nil` |
| `N≥1` | Soldier count required for objective completion | `N` |

> CTLD only increments the flag. The mission maker defines the win condition in DCS Editor using a trigger `"if flag >= target → victory"`.

## Zone Behavior

A TRZ can act as:
- **Pickup zone** (`stock > 0`): troops can board here; boarding decrements stock.
- **Extract zone** (`flag ≠ nil`): troops deployed here increment the objective flag.
- **Mixed zone** (both): supports both boarding and objective extract.
- **Inert zone** (`stock=0`, `flag=nil`): parsed but no functional capability — useful as named marker.

## Examples

| Zone Name | Type | Boarding | Objective | Description |
|-----------|------|----------|-----------|-------------|
| `TRZ_base_B_50_nil_0` | Pickup | 50 soldiers | — | BLUE pickup, limited to 50 |
| `TRZ_depot_A_999_nil_0` | Pickup ∞ | unlimited | — | All-coalition unlimited pickup |
| `TRZ_exfil_R_0_rescue_0` | Extract | — | flag `rescue` | RED extract, no threshold |
| `TRZ_lz_B_0_secure_100` | Extract | — | flag `secure`, 100 soldiers | BLUE extract with win condition |
| `TRZ_fob_N_30_defend_50` | Mixed | 30 soldiers | flag `defend`, 50 soldiers | NEUTRAL mixed zone |
| `TRZ_marker_B_0_nil_0` | Inert | — | — | BLUE named marker, no function |

### Annotated Example: `TRZ_fob_N_30_defend_50`

```
TRZ  _  fob  _  N   _  30     _  defend  _  50
 │       │      │      │          │          │
 │       │      │      │          │          └─ target: 50 soldiers needed for objective
 │       │      │      │          └──────────── flag: "defend" (DCS flag name)
 │       │      │      └─────────────────────── stock: 30 troops max (limited)
 │       │      └────────────────────────────── coalition: NEUTRAL
 │       └───────────────────────────────────── name: "fob"
 └───────────────────────────────────────────── prefix TRZ
```

### Annotated Example: `TRZ_depot_A_999_nil_0`

```
TRZ  _  depot  _  A   _  999      _  nil     _  0
                          │            │          │
                          │            │          └─ target: 0 → no win condition
                          │            └──────────── flag: "nil" → no objective
                          └───────────────────────── stock: 999 → unlimited pickup
```

### Annotated Example: `TRZ_lz_B_0_secure_100`

```
TRZ  _  lz  _  B    _  0         _  secure  _  100
                        │                        │
                        │                        └─ target: 100 soldiers needed
                        └──────────────────────── stock: 0 → no pickup (extract-only)
```

## Data Structure

### CTLDTroopZone Fields (after parsing + construction)

```lua
-- Identification
zone.dcsName         = "TRZ_fob_N_30_defend_50"  -- full DCS zone name
zone.zoneName        = "fob"                       -- name field

-- Coalition
-- Internal value: A→0 (all), R→1, B→2, N→coalition.side.NEUTRAL (0 in DCS)
-- Note: A and N both store 0 internally. In CTLD, 0 = "accept all coalitions".
-- In DCS multiplayer, NEUTRAL (0) players do not exist, so A and N behave identically.
zone.coalition       = 0  -- 0=all/neutral, 1=RED, 2=BLUE

-- Stock management (pickup)
zone.pickMaxStock    = 30        -- nil = no pickup; 0 = unlimited
zone.pickCurrentStock= 30        -- current remaining (decrements on load)

-- Mission objective (extract)
zone.objectiveFlag   = "defend"  -- nil = no objective
zone.objectiveTarget = 50        -- nil = no defined threshold

-- Geometry
zone.center  = { x, y, z }
zone.radius  = 500               -- metres (circular) or nil (polygonal)
zone.verticies = { ... } or nil  -- polygon corners

-- Visuals / state
zone.smoke   = trigger.smokeColor.Green or -1
zone.active  = true
```

### Key Methods

```lua
zone:hasPickup()    -- true if pickMaxStock ~= nil
zone:hasExtract()   -- true if objectiveFlag ~= nil
zone:isInZone(pt)   -- true if point is inside zone (circular or polygon)
zone:consumeStock(n)   -- decrement pickCurrentStock by n (noop if unlimited)
zone:restoreStock(n)   -- restore pickCurrentStock by n (noop if unlimited)
zone:incrementObjective(n)  -- add n to DCS flag objectiveFlag
```

## F10 Menu Behavior

- **In flight**: "Troop Commands" submenu is empty (no options shown).
- **On ground, in a TRZ with pickup**: "Load from `<zoneName>`" appears.
- **On ground, troops onboard**: "Unload / Extract" appears.
- **On ground, no TRZ**: no load options shown.

On `S_EVENT_LAND` / `S_EVENT_TAKEOFF`, the menu branch is rebuilt dynamically based on the player's current position and cargo state.

## Flag Incrementation

On extract (troops deployed in a zone with `objectiveFlag`):

```lua
local current = trigger.misc.getUserFlag(zone.objectiveFlag)
trigger.action.setUserFlag(zone.objectiveFlag, current + soldierCount)
```

Mode: **+N per soldiers** (not per group, not per operation).

CTLD never sets the flag back to 0 at mission start — the mission maker is responsible for flag initialization in the DCS Mission Editor if needed.

## Priority: Extract Before RTB

When a player unloads troops, the zone type is evaluated **in this order**:

1. If in a TRZ with `objectiveFlag` → **extract** (deploy troops, increment flag)
2. If in a TRZ with pickup only → **RTB** (troops return, stock restored)
3. Otherwise → **combat deploy** (troops deployed, no flag, no stock change)

This ensures a mixed zone correctly triggers the objective when used as an extract point.

## Parser Validation

The `_parseTRZ` function returns `nil, errorMessage` for any of these:

| Violation | Error message |
|-----------|--------------|
| Prefix ≠ TRZ | `"not a TRZ"` |
| Missing or empty name | `"missing zoneName"` |
| Name is reserved word | `"zoneName cannot be a reserved word: <word>"` |
| Missing coalition | `"missing coalition (A|R|B|N)"` |
| Coalition not A/R/B/N | `"invalid coalition '<x>' — expected A, R, B or N"` |
| Stock missing / non-integer / out of 0–999 | `"invalid stock '<x>' — expected integer 0-999 ..."` |
| Flag is a number | `"flag must be a string or 'nil', not a number"` |
| Target missing / negative / non-integer | `"invalid target '<x>' — expected integer ≥0 ..."` |

## Migration from Legacy System

### Legacy conventions (source/ only — do not use in new missions)

- `PKZ_Name_Max` → pickup zones
- Separate extract zones via `createExtractZone()`

### New convention

All zones use `TRZ_<name>_<A|R|B|N>_<stock>_<flag>_<target>`.

**No automatic conversion** — mission makers must rename zones manually.

### Old vs New Stock Semantics

| Old meaning | Old value | New value |
|-------------|-----------|-----------|
| Unlimited pickup | `0` | `999` |
| No pickup | (field absent) | `0` |
| Limited (N) | `N` | `N` (unchanged) |

## References

- Source: `src/CTLD_zone.lua` — `CTLDZoneManager:_parseTRZ()`
- Guide: `docs/missionmaker_guide.md` §4 TroopZones
- Tests: `recette/U-08/test.lua` (valid), `recette/U-09/test.lua` (invalid)
