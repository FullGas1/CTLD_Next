# CTLD Next — Release Testing Procedure

This document describes the test procedure to be applied before each release.
Testing is organized in four levels (L1→L4); L1 and L2 are automated via GitHub Actions CI,
L3 and L4 require a live DCS session.

---

## 1. Automated testing (GitHub Actions CI)

### Trigger conditions

The CI pipeline (`.github/workflows/ci.yml`) runs automatically on:
- Every push to `master` or any `feature_*` branch
- Every pull request targeting `master`
- Every version tag (`v*`) — also triggers the GitHub Release job

### Jobs and scripts

| Job | Name | Tool | Scope |
|-----|------|------|-------|
| 1 | Lua Syntax Check | Lua 5.4 `loadfile()` | All `src/**/*.lua` |
| 2 | Merge Build | `tools/build/listToMerge.txt` + PowerShell | Produces `CTLD_Next.lua` |
| 3 | busted Tests | `busted tests/` | `tests/unit/` (L1) + `tests/functional/` (L2) |
| 4 | Deploy Docs | MkDocs Material | `docs/` → GitHub Pages (master only) |
| 5 | GitHub Release | `gh release create` | Attaches `CTLD_Next.lua` to the tag (tags only) |

### Test coverage (busted — Job 3)

**L1 — Unit tests** (`tests/unit/*_spec.lua`):
21 spec files covering U-001→U-096, U-106→U-108 (~105 tests).
Scope: Config, EventDispatcher, Zones, Crates, Troops, JTAC, Menu, Utils, i18n, ModValidator.

**L2 — Functional tests** (`tests/functional/*_spec.lua`):
8 spec files covering ~45 tests. No real DCS spawn — all DCS API calls are stubbed via `tests/helpers/dcs_stubs.lua`.

| Spec file | Reference | Coverage |
|-----------|-----------|----------|
| `troop_manager_spec.lua` | F-033→F-036 | embarkFromTroopZone, disembark, returnToTroopZone, embarkFromField |
| `jtac_manager_spec.lua` | F-037→F-040 | spawnJTAC, setJTACInTransit, requestSmoke, killJTAC |
| `parachute_spec.lua` | F-057→F-071 | parachuteCrates/Troops/Vehicles, slingload hover/release/cut |
| `utils_spec.lua` | F-078→F-080 | getCentroid, calcDropPosition, getSpawnObjectPositions |
| `config_spec.lua` | F-101→F-105 | YAML override, singleton reset, i18n fallback chain, FR/ES/KO audit |
| `mark_ids_spec.lua` | F-115 | Global mark ID counter monotonicity and sharing |
| `vehicle_spec.lua` | F-120→F-123 | findLoadableVehicles, loadVehicle, unloadVehicle, _spawnUnpacked |
| `troop_multi_spec.lua` | F-140→F-146 | Multi-group transit, disembarkAll/Index, _menuCheckCargo |

### Failure reporting

- Each job reports its status as a **GitHub commit status check**, visible in pull request checks.
- Syntax errors (Job 1): annotated directly on the failing file with `::error file=...::` format.
- busted failures (Job 3): the failing test name and assertion are printed to the job log.
  Navigate to: GitHub → Actions → run → "busted Tests" → expand "Run busted" step.
- Build failures (Job 2): listed per missing file with `::warning::` or `::error::` annotations.

### Accessing CI logs

1. Go to the repository on GitHub → **Actions** tab.
2. Select the failing workflow run.
3. Click the failing job to expand its steps.
4. Full test output (including busted tap format) is in the "Run busted" step log.

### Running tests locally

```bash
# Install busted (one-time)
luarocks install busted

# Run all tests from the repo root
busted tests/

# Run only functional tests
busted tests/functional/

# Run a single spec file
busted tests/functional/troop_manager_spec.lua
```

---

## 2. Non-automated testing (Witchcraft DCS)

Tests at levels L3 and L4 require a live DCS mission session with Witchcraft active.
They cover features that cannot be stub-tested: visual spawns, real DCS group creation,
physical slingload, player-interactive menus.

### Prerequisites

- DCS World running with mission `missions/Test_CTLDNEXT_01.miz` (or equivalent test mission).
- Witchcraft Node.js bridge installed at `%USERPROFILE%/.vscode-dcs-tools/bridge.js`.
- If `src/` was modified since last test: rebuild first:
  ```powershell
  powershell -ExecutionPolicy Bypass -File "tools\build\merge_CTLD.ps1"
  ```
- `ctldLogPath` must be set in the test mission's MISSION START trigger for CTLD.log to be created.

### Injection command

```bash
node "%USERPROFILE%/.vscode-dcs-tools/bridge.js" "<absolute_path_to_script.lua>"
```

VS Code task shortcut: **Shift+Ctrl+B** → `DCS-Witchcraft: Execute Global`.

### L3 — Automated Witchcraft scenarios (no player required)

Scripts: `live_tests/scenarios/auto/scenario_*.lua` and individual `live_tests/functional/F-xxx.lua` files.

**Procedure:**

1. Start DCS, load the test mission, wait for it to initialize.
2. Inject `CTLD_Next.lua` (the merged build).
3. Wait **3–5 seconds** for CTLD initialization to complete.
4. Inject the target scenario script.
5. Read `CTLD.log`: look for `[PASS]` / `[FAIL]` / `[F-xxx RESULT] pass=N fail=0`.
6. If failures occur: read the `[FAIL]` lines (label, expected, got), fix the issue,
   rebuild if needed, re-inject from step 2.

**Success criterion:** all `[FAIL]` lines absent; `pass=N fail=0` at the end of the script.

**Output format:**
```
[F-120 PASS] U-01 empty before inject
[F-120 PASS] U-02 WAITING found
[F-120 FAIL] F-01 state LOADED  expected=LOADED  got=WAITING
[F-120 RESULT] pass=6 fail=1
```

### L4 — Interactive Witchcraft (player slot required)

Scripts: `live_tests/functional/F-xxx.lua` files that call `ctld_test.getTransport()` and
require a BLUE player in a transport aircraft (typically UH-1H).

**Procedure:**

1. Start DCS, load the test mission, take a **BLUE transport slot** (e.g., UH-1H).
2. Activate Witchcraft (join slot, verify bridge connection).
3. Inject `CTLD_Next.lua` and wait 3–5 s for init.
4. Inject the scenario script.
5. Follow any on-screen instructions (position aircraft, use F10 menus, etc.).
6. Verify: screen messages via `trigger.action.outText`, entries in `CTLD.log`.
7. Perform visual validation where applicable (unit spawns, smoke, beacons).

**Success criterion:** script output shows `pass=N fail=0`; visual checks match expectations.

### Manual test sequences

For complex multi-step scenarios (multi-crate assembly, full FARP/FOB build cycle,
AI transport end-to-end), consult `live_tests/manual_test_sequences.md`.
Each MT-xx entry lists the exact steps and expected outcomes.

---

## 3. Other testing guidance

### Pre-release checklist

Before tagging a release:

- [ ] All CI jobs green on `master` (syntax, build, busted).
- [ ] Any new `src/` files added to `tools/build/listToMerge.txt`.
- [ ] L3 scenarios executed for all modules modified since last release.
- [ ] L4 interactive tests executed for player-visible features (menus, spawns, effects).
- [ ] `live_tests/recette.md` updated: new F-xx / U-xx rows added, coverage summary updated.
- [ ] `migration/MODERNIZATION-PLAN.md` statuses up to date.
- [ ] `docs/missionmaker_guide.md` updated if any mission-maker-visible behavior changed.

### Adding a new test to CI

1. Create `tests/functional/<feature>_spec.lua` following the existing pattern
   (singleton reset in `before_each`, DCS API mocked locally, stubs restored in `after_each`).
2. Reference the corresponding `live_tests/functional/F-xxx.lua` in the file header.
3. Run locally with `busted tests/functional/<feature>_spec.lua` to verify.
4. Update `migration/MODERNIZATION-PLAN.md`: add the spec file to the TODO-CI-4 completion note.

### Debug configuration (Witchcraft sessions)

- Enable verbose logging: `CTLDConfig.get().settings["debug"] = true`
  and `CTLDConfig.get().settings["debugScreenLog"] = true`.
- Screen log duration: `CTLDConfig.get().settings["debugScreenLogDuration"] = 20`.
- All `ctld.utils.log()` calls are then echoed on screen for 20 seconds.
- **Do not use** `ctld.debug = true` alone — it does not activate `CTLD.log`.

### Release tagging

```bash
git tag v2.x.y
git push origin v2.x.y
```

The CI Release job (Job 5) will automatically build `CTLD_Next.lua` and attach it
to a new GitHub Release with installation instructions.
