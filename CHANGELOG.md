# Changelog

All notable changes to DCS-CTLD Next are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
Versioning follows [Semantic Versioning](https://semver.org/).

---

## [2.0.0] — 2026-07-06

Complete ground-up modular rewrite of DCS-CTLD as a maintainable, testable, and extensible Lua project.
Single-file deliverable (`CTLD_Next.lua`) produced by the build system from `src/`.
Backward compatible with missions using the v1 scripting API via the legacy compatibility layer.

### Architecture

- **Modular source tree** — `src/` split into ~32 focused files concatenated by `tools/build/merge_CTLD.ps1`.
  Order controlled by `tools/build/listToMerge.txt`.
- **OOP everywhere** — all entities use `src/core/class.lua` prototype system:
  `CTLDCrate`, `CTLDTroopGroup`, `CTLDPlayer`, `CTLDBeacon`, `CTLDJTACDetector`, and all managers.
- **MIST removed** — all `mist.*` calls replaced by `ctld.utils.*`; no external dependency.
- **Legacy API** — `src/legacy/legacy_api.lua` provides 22 thin wrappers for v1 mission scripts
  (`ctld.addTroops`, `ctld.addCrates`, etc.). Drop-in for existing missions.
- **Single event bridge** — `CTLDDCSEventBridge`: one `world.addEventHandler` with internal
  delegation via `bridge:register()`. No more scattered handler registrations.
- **Version constant** — `ctld.VERSION = "2.0.0"` injected at build time into the output header.

### Features added / rewritten

- **`capabilitiesByType`** — unified per-aircraft capability table replaces the legacy per-feature
  boolean globals. Controls crates, troops, parachute, slingload, whole-vehicle transport,
  DCS native cargo integration, and slot/weight limits per aircraft type.
- **`convertNativeLoadToCTLD`** — per-aircraft flag: when `true`, a DCS-native cargo load is
  immediately converted to a CTLD-managed crate (ghost slot prevention). Required for UH-1H,
  CH-47Fbl1. Leave `false` for C-130 / Il-76 which retain DCS native cargo for ground ops and
  use the DCS native parachute function (provides 3D parachute animation on crates).
- **Scene system** — `CTLDSceneManager` + 9 built-in scenes (FARP Alpha, Countryside FARP,
  Metal FARP, FOB, Minefield…). Polar and axis step types. Mission maker can define custom scenes.
- **FARP Repack** — pack a deployed FARP back into crates; warehouse fuel snapshot preserved
  and restored at next unpack. Controlled by `enableFARPRepack`.
- **Mod Validation Guard** — `CTLDModValidator` probes all DCS type names declared in config at
  mission start. Scenes that depend on missing mod types are automatically disabled with a WARN
  outText. `step.critical = true` on a scene step aborts the scene if the spawn returns nil.
  `requiresMod` scene field triggers a WARN for mod types that cannot be auto-validated
  (heliport-type objects: DCS returns identical API values whether the mod is installed or not).
- **AI Zone config** (Feature S) — `cfg.settings["aiZones"]` table replaces brittle naming
  convention. Full control of pickup/dropoff zones, troop/vehicle stock, templates, drop mode.
- **AI Zone stock per template/type** (Feature T) — `troopStock`/`vehicleStock` per template
  name; rotation algorithm favours highest-stock eligible templates.
- **AA System construction** (Feature U) — `CTLDCrateAssemblyManager` spawns AA systems
  (HAWK, Patriot…) without crate assembly steps; AI transport integration.
- **Vehicle Pack** — pack a ground vehicle into crates at any logistics zone; unpack at
  destination for reassembly.
- **Native DCS Cargo (C-130 / Il-76)** — detection of vehicles in cargo bay bounding box;
  whole-vehicle transport without crate workflow.
- **Virtual Slingload** — hover detection, overspeed loss, release / cut menus. No DCS sling
  physics bugs.
- **Virtual Parachute** — inertia + lateral drift simulation for crates, troops, and vehicles.
  Per-aircraft altitude gates. Distinct from DCS native parachute (C-130).
- **Radio Beacons** — VHF/UHF/FM, battery timer, F10 map layer, `CTLDBeaconManager`.
- **JTAC Auto-Lase** — `CTLDJTACDetector` with laser pool (`LASER_CODE_MIN=1111..LASER_CODE_MAX=1688`),
  toggleStandby, orbit task for air JTACs.
- **Zone validation** — `_validateZoneNames()` with i18n error messages (EN/FR/ES/KO).
  Checks TRZ/LGZ/WPZ/AIZ naming, stock coherence, cargoType/vehicle transport gates.
- **i18n** — `ctld.tr()` runtime engine; EN reference + FR/ES/KO translations;
  `generate_i18n_dicts.ps1` drift detector.

### Quality

- **`.luacheckrc`** — static analysis config; `std = "lua51"`, all DCS globals declared.
- **Lua 5.1 strict** — codebase audited for Lua 5.2+ constructs (`goto`, `table.move`,
  `math.type`, `<const>`, `utf8.*`). All replaced with Lua 5.1 equivalents.
- **Nil-safety guards** — `getGroupId`, `isExist`, `getUnits`, `coalition.getGroups`,
  `Group.getByName` call sites hardened.
- **Dead code removed** — `isParachuting`, `parachuteStartAltitude`, `estimatedLandingTime`
  fields; unused `hoverStatus` and player SMK tables.
- **pcall result checks** — all `pcall()` return values checked; silent failures now log WARN.
- **Named constants** — `LASER_CODE_MIN/MAX` (CTLD_jtac.lua), `BEACON_REMOVAL_RADIUS`
  (CTLD_beacon.lua) replace hardcoded literals.
- **Menu cleanup fix** — `missionCommands.removeItemForGroup` now uses opaque `_dcsHandle`
  (was silently ignored when passed `{item.name}`).
- **inAir logic fix** — corrected inverted nil-transport guard in `CTLD_vehicle.lua`.

### CI / Tooling

- **GitHub Actions** — lint, build, busted, release artifact on tag `v*`, MkDocs deploy to
  GitHub Pages on push to master.
- **busted test suite** — `tests/ci/` L1/L2 unit tests with DCS stub environment
  (`tests/helpers/`). Coverage: config, utils, crate manager, troop group, JTAC, beacon, player.
- **DCS integration scenarios** — `tests/dcs/` Witchcraft-injected scenarios for
  pilotPassive (noPlayer) and interactive recettes.
- **Build header** — `merge_CTLD.ps1` injects version, date, and source URL into
  `CTLD_Next.lua` output.

### Documentation

- `docs/missionmaker_guide.md` — 16 sections covering all features, zone setup, per-aircraft
  config, parachute behavior per aircraft type (C-130 native vs UH-1H/CH-47 CTLD menu), slingload,
  scenes, AI zones, scripting API, events.
- `docs/dev-guide.md` — architecture, module split, OOP pattern, event system, testing guide.
- `docs/api-reference.md` — full public API reference.
- MkDocs site deployed to GitHub Pages.

### Migration from v1

See [docs/missionmaker_guide.md §9 — Legacy API compatibility](docs/missionmaker_guide.md) and
`migration/` for the full modernization plan and per-feature spec sheets.

Key breaking changes:
- `ctld.debug = true` no longer sufficient — use `cfg.settings["debug"] = true`.
- Per-aircraft config moved to `capabilitiesByType` table (replaces `ctld.dynamicTransports` etc.).
- Zone naming for AI zones replaced by `cfg.settings["aiZones"]` config table.
- `repack` terminology replaced by `pack` everywhere (methods, config keys, menus).

---

## [1.x] — Legacy (pre-rewrite)

See `migration/MODERNIZATION-PLAN.md` for the full history of the v1 codebase and the
decision log for each architectural change made during the v2 rewrite.
