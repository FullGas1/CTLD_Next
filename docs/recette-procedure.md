# CTLD Next — Release Testing Procedure

Testing is organized in six levels (L1 to L6).
L1 and L2 run automatically via GitHub Actions CI.
L3 to L5 require a live DCS session with Witchcraft active.
L6 is purely manual (player + checklist).

For Witchcraft injection setup (commands, debug config, CTLD.log), see [`docs/dev-guide.md`](dev-guide.md) §8 Testing.

---

## Folder to level mapping

| Folder | Level | Execution context |
| --- | --- | --- |
| `tests/ci/unit/` | L1 | GitHub Actions — busted, no DCS |
| `tests/ci/functional/` | L2 | GitHub Actions — busted, no DCS |
| `tests/dcs/noPlayer/` | L3 | Developer local — DCS + Witchcraft, no player slot |
| `tests/dcs/pilotPassive/` | L4 | Developer local — DCS + player in cockpit, script drives |
| `tests/dcs/pilotActive/` | L5 | Developer local — DCS + player takes F10 actions |
| `tests/manual_test_sequences.md` | L6 | Developer local — player, step-by-step checklist |

---

## Architecture overview

```text
RELEASE
  |
  +- L1  CI busted unit        tests/ci/unit/*_spec.lua          ~105 tests  (automatic)
  +- L2  CI busted functional  tests/ci/functional/*_spec.lua    ~45 tests   (automatic)
  |
  +- L3  DCS noPlayer          tests/dcs/noPlayer/               ~136 scripts (developer, before push)
  |         U-xxx  unit-level Witchcraft scripts
  |         F-xxx  targeted functional Witchcraft scripts
  |         scenario_*  multi-step integration scenarios
  |
  +- L4  DCS pilotPassive      tests/dcs/pilotPassive/           ~30 scripts  (developer, before push)
  |         player in cockpit, script drives all steps automatically
  |
  +- L5  DCS pilotActive       tests/dcs/pilotActive/            2 scripts    (developer, before push)
  |         player in cockpit AND must take F10 actions between steps
  |
  +- L6  Manual sequences      tests/manual_test_sequences.md    4 MT-xx      (developer, new features only)
```

---

## Release order

```text
Modify src/
    |
[LOCAL] L3 noPlayer  -- inject relevant F-xxx + scenario_* for modified module
    | (PASS)
[LOCAL] L4 pilotPassive  -- if feature touches player flow (menus, spawns, effects)
    | (PASS)
[LOCAL] L5 pilotActive  -- if feature modifies an F10 menu visible to the player
    | (PASS, or skip if not applicable)
git push  ->  CI L1/L2 runs automatically
    | (CI green)
PR  ->  merge to master
    |
git tag vX.Y  ->  CI Release job builds and publishes CTLD_Next.lua
```

> **Rule:** L3 to L5 must pass **before** the push. CI (L1/L2) uses DCS stubs and cannot
> detect real-DCS regressions. A green CI with a failing L3 means the code is broken
> without CI knowing it.
>
> **Exception:** documentation, comments, non-functional refactors may be pushed without L3 to L5.

---

## L1 — CI busted unit (automatic)

**Who:** GitHub Actions.
**When:** every push to `master` or `feature_*`, every PR.
**Scripts:** `tests/ci/unit/*_spec.lua` — 21 files, ~105 tests.
**Runner:** `busted tests/ci/` (Job 3 in `.github/workflows/ci.yml`).

Scope: Config, EventDispatcher, Zones, Crates, Troops, JTAC, Menu, Utils, i18n, ModValidator.
All DCS API calls replaced by stubs in `tests/ci/helpers/dcs_stubs.lua`.

---

## L2 — CI busted functional (automatic)

**Who:** GitHub Actions.
**When:** same triggers as L1.
**Scripts:** `tests/ci/functional/*_spec.lua` — 8 files, ~45 tests.

| Spec file | Tests |
| --- | --- |
| `troop_manager_spec.lua` | embarkFromTroopZone, disembark, returnToTroopZone, embarkFromField |
| `jtac_manager_spec.lua` | spawnJTAC, setJTACInTransit, requestSmoke, killJTAC |
| `parachute_spec.lua` | parachuteCrates/Troops/Vehicles, slingload hover/release/cut |
| `utils_spec.lua` | getCentroid, calcDropPosition, getSpawnObjectPositions |
| `config_spec.lua` | YAML override, singleton reset, i18n fallback/FR/ES/KO |
| `mark_ids_spec.lua` | Global mark ID counter monotonicity |
| `vehicle_spec.lua` | findLoadableVehicles, loadVehicle, unloadVehicle, _spawnUnpacked |
| `troop_multi_spec.lua` | Multi-group transit, disembarkAll/Index, _menuCheckCargo |

> Note: `tests/dcs/noPlayer/F-xxx.lua` and `U-xxx.lua` are Witchcraft injection scripts (L3),
> not busted specs. They are not picked up by CI (no `_spec` suffix).

---

## L3 — DCS noPlayer (developer, before push)

**Who:** developer.
**When:** before every push that modifies `src/`.
**How:** inject scripts into a running DCS mission. No player slot required.
**Success:** `fail=0` in result line + no `[FAIL]` in `tests/dcs/CTLD.log`.

### L3a — Targeted tests (U-xxx / F-xxx)

Inject the files covering the modified module:

| Modified module | Files to inject |
| --- | --- |
| `CTLD_troop.lua` | F-033 to F-036, F-059, F-060, F-140 to F-146 |
| `CTLD_jtac.lua` | F-037 to F-040, F-110 to F-112 |
| `CTLD_crate.lua` | F-027 to F-032, F-057, F-058, F-061 to F-071, F-120 to F-123 |
| `CTLD_vehicle.lua` | F-015 to F-020, F-120 to F-123 |
| `CTLD_core.lua` (AI) | F-133, F-134, F-176 to F-182 |
| `CTLD_zone.lua` | F-003 to F-005 |
| `CTLD_recon.lua` | F-009 to F-011, F-115 to F-119 |
| `CTLD_config.lua` / i18n | F-101 to F-105 |
| `CTLD_menu.lua` | U-045 to U-053, U-057 to U-066 |

### L3b — Integration scenarios

Run scenarios matching the modified feature:

| Feature area | Scenario |
| --- | --- |
| AI transport / stocks | `aiTransport_featureT_*.lua`, `aiTransport_featureU_*.lua` |
| JTAC toggle / corrections | `scenario_jtac_toggle_lasing.lua`, `scenario_jtac_spot_corrections.lua` |
| Crate menu / load | `scenario_b3_load_crate_from_menu.lua`, `scenario_crate_menu_flight_visibility.lua` |
| Vehicle transport | `scenario_fq_vehicle_whole_transport.lua`, `scenario_mt05_crate_vehicle.lua` |
| AI zones | `scenario_fr_ai_zones.lua` |
| Extractable groups | `scenario_fo_extractable_groups.lua` |
| Countryside/Metal FARP spawn | `scenario_farp_countryside_spawn.lua`, `scenario_farp_metal_spawn.lua` |

---

## L4 — DCS pilotPassive (developer + player slot, before push)

**Who:** developer in a BLUE transport slot (UH-1H or equivalent).
**When:** before push, for player-visible feature changes.
**How:** take the slot, inject the scenario, watch — no F10 action required.
**Success:** all steps report `[PASS]`, visual checks match expected.

Key scenarios:

| Scenario | Feature |
| --- | --- |
| `scenarioTroopsFullCycle_v2.lua` | Troops + JTAC full lifecycle |
| `scenario_multigroup_transport.lua` | Multi-group transport |
| `scenario_fob_scene.lua`, `scenario_p2_fob_parachute.lua` | FOB scene + parachute |
| `scenario_p3_csfarp_parachute.lua`, `scenario_p4_metal_farp.lua` | FARP scenes |
| `scenario_farp_repack.lua`, `scenario_warehouse_cycle.lua` | FARP repack + warehouse |
| `scenario_feature_f_recon_farp.lua` | RECON FARP/FOB layer |
| `scenario_feature_k_jtac_vehicle.lua` | JTAC vehicle in-transit |
| `scenario_mt07_ai_troops.lua` to `scenario_mt16_countryside_farp.lua` | Full MT-xx live |

---

## L5 — DCS pilotActive (developer + player F10 actions, before push)

**Who:** developer in a BLUE transport slot — must execute F10 menu actions on demand.
**When:** before push, only when F10 menu structure or visibility changes.

| Scenario | What the player must do |
| --- | --- |
| `scenario_crate_menu_sol_vol_visual.lua` | Confirm Crate Commands menu on ground / in flight / after landing |
| `scenario_troop_menu_sol_vol_visual.lua` | Confirm Troop Commands menu on ground / in flight / after landing |

---

## L6 — Manual sequences (developer, new features only)

Step-by-step checklists in `tests/manual_test_sequences.md`. No script — pure observation.

| Sequence | Feature | Trigger |
| --- | --- | --- |
| MT-01 | Multi-group troop transport + disembark menu | Any troop transport change |
| MT-02 | Whole-vehicle load / unload / parachute | Vehicle transport change |
| MT-03 | Multi-vehicle load / unload / parachute | Vehicle capacity or multi-load change |
| MT-06 | RECON FARP/FOB layer | RECON or CTLDStaticWatcher change |

---

## Summary — effort per release

| Level | Who | When | Approx. effort |
| --- | --- | --- | --- |
| L1 CI unit | GitHub Actions | Automatic | 0 |
| L2 CI functional | GitHub Actions | Automatic | 0 |
| L3a F-xxx targeted | Developer | Before push — impacted modules only | ~5 min/module |
| L3b scenario noPlayer | Developer | Before push — impacted features only | ~10 min |
| L4 pilotPassive | Developer + cockpit | Before push — player-visible features | ~20 min |
| L5 pilotActive | Developer + cockpit | Before push — F10 menu changes only | ~10 min |
| L6 Manual MT-xx | Developer + cockpit | New player-visible features | ~15 min/MT |

---

## Pre-release checklist

Before tagging `vX.Y`:

- [ ] All CI jobs green on `master` (lint, build, busted).
- [ ] Any new `src/` file added to `tools/build/listToMerge.txt`.
- [ ] L3 passed for all modules modified since last tag.
- [ ] L4 passed for all player-visible features modified since last tag.
- [ ] L5 passed if any F10 menu structure changed.
- [ ] `tests/recette.md` updated (new rows + coverage summary).
- [ ] `migration/MODERNIZATION-PLAN.md` feature statuses up to date.
- [ ] `docs/missionmaker_guide.md` updated if any mission-maker-visible behavior changed.
