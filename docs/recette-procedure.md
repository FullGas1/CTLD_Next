# CTLD Next — Release Testing Procedure

Testing is organized in four levels (L1→L4).
L1 and L2 run automatically via GitHub Actions CI.
L3 and L4 require a live DCS session with Witchcraft active.

For the technical details of running Witchcraft sessions (injection commands, debug
configuration, CTLD.log setup), see [`docs/dev-guide.md`](dev-guide.md) §8 Testing.

---

## Architecture overview

```text
RELEASE
  │
  ├─ L1/L2 — CI busted (automatic, GitHub Actions)
  │    ├─ tests/unit/*_spec.lua         ← ~105 tests U-xxx
  │    └─ tests/functional/*_spec.lua   ← ~45 tests F-xxx selected
  │
  ├─ L3 — Witchcraft AUTO (DCS, no player required)
  │    ├─ live_tests/scenarios/auto/*.lua    ← 20 integration scenarios
  │    └─ live_tests/functional/F-xxx.lua   ← 116 targeted tests
  │
  └─ L4 — Witchcraft INTERACTIVE (DCS + player slot)
       ├─ live_tests/scenarios/interactive/*.lua   ← 32 scenarios
       └─ live_tests/manual_test_sequences.md      ← 4 MT-xx sequences
```

---

## Correct release order

```text
Modify src/
    ↓
[LOCAL] L3 Witchcraft AUTO  — inject relevant F-xxx and scenarios/auto/
    ↓ (PASS)
[LOCAL] L4 Witchcraft INTERACTIVE — if player-visible feature
    ↓ (PASS)
git push → CI L1/L2 runs automatically
    ↓ (CI green)
PR → merge to master
    ↓
git tag vX.Y → CI Release job builds and publishes CTLD_Next.lua
```

L3/L4 must happen **before** the push: the CI only runs stubs, it cannot detect real DCS
regressions. A green CI with a failing L3 means the code is broken without the CI knowing it.

**Exception:** cosmetic changes (comments, docs, non-functional refactors) may be pushed
directly without L3/L4.

---

## L1 — Unit tests (automated)

**Who:** GitHub Actions.
**When:** every push to `master` or `feature_*`, every PR.
**Scripts:** `tests/unit/*_spec.lua` — 21 files, ~105 tests.
**Runner:** `busted tests/` (Job 3 in `.github/workflows/ci.yml`).

Scope: Config, EventDispatcher, Zones, Crates, Troops, JTAC, Menu, Utils, i18n, ModValidator.
All DCS API calls are replaced by stubs in `tests/helpers/dcs_stubs.lua`.

Failure details are printed in the "Run busted" step log on GitHub Actions and annotated on PR checks.

---

## L2 — Functional tests (automated)

**Who:** GitHub Actions.
**When:** same triggers as L1 (same `busted tests/` command).
**Scripts:** `tests/functional/*_spec.lua` — 8 files, ~45 tests.

| Spec file | Reference | Coverage |
| --------- | --------- | -------- |
| `troop_manager_spec.lua` | F-033→F-036 | embarkFromTroopZone, disembark, returnToTroopZone, embarkFromField |
| `jtac_manager_spec.lua` | F-037→F-040 | spawnJTAC, setJTACInTransit, requestSmoke, killJTAC |
| `parachute_spec.lua` | F-057→F-071 | parachuteCrates/Troops/Vehicles, slingload hover/release/cut |
| `utils_spec.lua` | F-078→F-080 | getCentroid, calcDropPosition, getSpawnObjectPositions |
| `config_spec.lua` | F-101→F-105 | YAML override, singleton reset, i18n fallback chain, FR/ES/KO audit |
| `mark_ids_spec.lua` | F-115 | Global mark ID counter monotonicity |
| `vehicle_spec.lua` | F-120→F-123 | findLoadableVehicles, loadVehicle, unloadVehicle, _spawnUnpacked |
| `troop_multi_spec.lua` | F-140→F-146 | Multi-group transit, disembarkAll/Index, _menuCheckCargo |

These tests cover full flows without real DCS spawns — the DCS API is stubbed.
They are distinct from `live_tests/functional/F-xxx.lua` which are Witchcraft injection
scripts for DCS and do **not** use the busted format (no `_spec` suffix, not picked up by CI).

---

## L3 — Witchcraft AUTO (developer, before push)

**Who:** developer.
**When:** before pushing, for every modified module.
**How:** inject scripts into a running DCS mission (no player slot needed). See `dev-guide.md` §8 for setup.

Success criterion: `fail=0` in the result line, no `[FAIL]` entries in `CTLD.log`.

### L3a — `live_tests/functional/F-xxx.lua` (116 files)

Targeted tests, one behavior per file. Inject the F-xxx files covering the modified module.

| Modified module | Scripts to inject |
| --------------- | ----------------- |
| `CTLD_troop.lua` | F-033→F-036, F-059→F-060, F-140→F-146 |
| `CTLD_jtac.lua` | F-037→F-040, F-110→F-112 |
| `CTLD_crate.lua` | F-027→F-032, F-057→F-058, F-061→F-071, F-120→F-123 |
| `CTLD_vehicle.lua` | F-015→F-020, F-120→F-123 |
| `CTLD_core.lua` (AI) | F-133, F-134, F-176→F-182 |
| `CTLD_zone.lua` | F-003→F-005 |
| `CTLD_recon.lua` | F-009→F-011, F-115→F-119 |
| `CTLD_config.lua` / i18n | F-101→F-105 |

### L3b — `live_tests/scenarios/auto/*.lua` (20 files)

Wider integration scenarios without a player. Run those matching the modified feature.
Examples: `scenario_b3_load_crate_from_menu.lua`, `aiTransport_featureT_*.lua`,
`scenario_jtac_toggle_lasing.lua`.

---

## L4 — Witchcraft INTERACTIVE (developer + player slot, before push)

**Who:** developer in a BLUE transport slot (typically UH-1H).
**When:** before pushing, only for player-visible features (F10 menus, visual spawns, effects).
**How:** inject scripts after taking the slot. See `dev-guide.md` §8 for setup.

### L4a — `live_tests/scenarios/interactive/*.lua` (32 files)

Scenarios that manipulate real DCS objects via the player. Follow on-screen instructions
for positioning and menu actions.
Examples: `scenarioTroopsFullCycle_v2.lua`, `scenario_multigroup_transport.lua`,
`scenario_fob_scene.lua`, `scenario_warehouse_cycle.lua`.

Success criterion: `fail=0` in result line + visual checks pass.

### L4b — `live_tests/manual_test_sequences.md` (4 MT-xx sequences)

Purely manual step-by-step checklists (no script):

| Sequence | Feature | Steps |
| -------- | ------- | ----- |
| MT-01 | Multi-group troop transport + disembark menu | 10 |
| MT-02 | Whole-vehicle load / unload / parachute | 9 |
| MT-03 | Multi-vehicle load / unload / parachute | — |
| MT-06 | RECON FARP/FOB layer | — |

Run the relevant MT-xx whenever modifying the corresponding perimeter.
MT-07→MT-16 are covered by `scenarios/interactive/scenario_mt07_*.lua` scripts (L4a).

---

## Summary: who does what per release

| Level | Who | When | Approx. effort |
| ----- | --- | ---- | -------------- |
| L1 CI unit | GitHub Actions | Automatic (push / PR) | 0 |
| L2 CI functional | GitHub Actions | Automatic (push / PR) | 0 |
| L3a F-xxx targeted | Developer | Before push, modified modules only | ~5 min/module |
| L3b scenarios/auto | Developer | Before push, complex features | ~10 min |
| L4a scenarios/interactive | Developer + player slot | Before tag `vX.Y` | ~20–30 min |
| L4b MT-xx manual | Developer + player slot | New player-visible features only | ~15 min/MT |

---

## Pre-release checklist

Before tagging `vX.Y`:

- [ ] All CI jobs green on `master` (syntax, build, busted).
- [ ] Any new `src/` file added to `tools/build/listToMerge.txt`.
- [ ] L3 executed for all modules modified since last release.
- [ ] L4 executed for all player-visible features modified since last release.
- [ ] `live_tests/recette.md` updated (new F-xx / U-xx rows, coverage summary).
- [ ] `migration/MODERNIZATION-PLAN.md` statuses up to date.
- [ ] `docs/missionmaker_guide.md` updated if any mission-maker-visible behavior changed.
