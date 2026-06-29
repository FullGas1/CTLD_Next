# Copilot Instructions for DCS-CTLD

## Working mode / Mode de travail

- **Communication language**: French (français) for all conversations and commit messages.
- **Documentation language**: English for all technical documentation (code comments, docs/, README). French summaries in docs are acceptable but English is the primary language.
- **Development methodology**: TDD (Test-Driven Development) — write tests before implementation when possible.
- **Programming paradigm**: OOP Lua 5.1 with metatables and classes. No procedural spaghetti.
- **Branching strategy**: Git flow on the `next` branch. Feature branches named `feature/<phase>-<description>`. Never commit directly to `main` or `next`.
- **Commit style**: Conventional Commits (`feat:`, `fix:`, `refactor:`, `test:`, `docs:`, `chore:`).
- **Build target**: Individual source modules in `src/` are concatenated into a single `dist/CTLD.lua` deliverable by a build script. Never edit the built file directly.
- **MIST dependency**: CTLD code must never call `mist.*` directly. All MIST usage goes through the middleware layer (`src/mist_compat/`).
- **Legacy API**: When refactoring a public `ctld.*` function, always create a deprecated wrapper in `src/legacy/legacy_api.lua` that logs a warning and delegates to the new API.
- **Refer to the modernization plan**: See `.github/MODERNIZATION-PLAN.md` for the full roadmap and architectural decisions.

## Project context
- This repository contains Lua mission scripts for DCS World.
- The primary script is CTLD.lua.
- Internationalization tables are split between CTLD.lua (English reference keys) and CTLD-i18n.lua (translated values).
- Runtime is DCS mission scripting environment (Lua 5.1, metatables available, no LuaJIT, no goto).
- Assumes desanitized server (io, os, lfs accessible).
- MIST is being progressively replaced by an internal middleware layer.

### Module loading order (v1 / source/)

Defined in `source/CTLD_loader.lua`. Each module depends on globals initialized by previous ones.

1. `mist.lua` — MIST framework
2. `CTLD_extAPI.lua` — MIST/MOOSE abstraction wrappers
3. `CTLD-i18n.lua` — Translations (FR, ES, KO)
4. `CTLD.lua` — Core logic (~8919 lines)
5. `CTLD_utils.lua` — Geo calculations, logging
6. `CTLD_DCSWeaponsDb.lua` — Weapon/equipment database
7. `dcsObjectsDescDb.lua` — Object spawn descriptors
8. `CTLD_scene.lua` — Scene sequencing/animation system
9. `farpSceneDatas.lua` — FARP deployment scene definitions
10. `mineFieldSceneDatas.lua` — Mine field scene definitions

### Module loading order (v2 / source_futur/)

Defined in `merger_futur/listToMerge.txt`. Concatenated into `CTLD_Next.lua` by `merger_futur/merge_CTLD.ps1`.

```
-- Core foundations
CTLD_config.lua, CTLD_i18n*.lua, CTLD_utils.lua, CTLD_menu.lua, CTLD_objectsDescDb.lua
-- Business domain managers
CTLD_scene.lua, CTLD_zone.lua, CTLD_troop.lua, CTLD_crate.lua, CTLD_vehicle.lua,
CTLD_fob.lua, CTLD_aasystem.lua, CTLD_beacon.lua, CTLD_recon.lua, CTLD_jtac.lua, CTLD_player.lua
-- Orchestrator
CTLD_core.lua
-- Scene data (after SceneManager registry is ready)
scenes/CTLD_farpSceneDatas.lua, scenes/CTLD_fobSceneDatas.lua, scenes/CTLD_mineFieldSceneDatas.lua, ...
-- User configuration (always last)
CTLD_userConfig.lua
```

### DCS coordinate system (critical)

- **Axes**: X = North, Z = East, Y = Altitude (3D world); `vec2 = {x, y}` (2D map, Y=South)
- **Angles**: Clockwise from North in radians (0 rad = North, π/2 rad = East)
- **Conversion**: `math.rad(degrees)` / `math.deg(radians)`
- **Helper**: `ctld.utils.getRelativeCoords()` computes polar → absolute world coords, accounting for magnetic declination

### Data flow example: FARP deployment

1. Mission triggers `ctld.scene.playscene(heliUnit, ctld.farpScene)`
2. Scene sequencer iterates `stepsDatas`; each step defines:
   - `polar` = relative position (distance + angle from trigger unit)
   - `registryKey` = lookup in `CTLDObjectRegistry` for spawn template
   - `func` = optional Lua callback (e.g. configure warehouse after spawn)
3. Utils convert polar coords + heli heading → absolute world coords
4. `CTLD_extAPI.dynAdd()` spawns the object via MIST
5. Step's `func` callback executes

### Object spawn pattern

All spawnable objects are registered in `CTLDObjectRegistry` as descriptor tables:

```lua
CTLDObjectRegistry:register("SINGLE_HELIPAD", {
    desc = function(coalitionId, countryId, x, y, headingInRadians, altitudeInMeters)
        return { groupType = "STATIC", type = "SINGLE_HELIPAD", ... }
    end
})
-- Usage: CTLDObjectRegistry:get("SINGLE_HELIPAD").desc(1, 2, 500, 600, 0, 100)
```

## Architecture (v2 target)

- Source modules live in `src/` organized by domain: `lib/`, `core/`, `transport/`, `logistics/`, `jtac/`, `ui/`, `recon/`, `ai/`, `compat/`, `mist_compat/`.
- OOP via a micro class system using metatables (`src/core/class.lua`).
- State is managed by a `StateManager` singleton and per-coalition `Coalition` instances — no more `ctld.xxxRED`/`ctld.xxxBLUE` table pairs.
- Tests live in `test/` and use busted with DCS/MIST mocks.

## Compatibility (v1 legacy)
- Preserve existing public ctld.* APIs used by Mission Editor DO SCRIPT triggers.
- Do not rename exported ctld functions or change their parameter semantics unless explicitly requested.
- Keep behavior compatible with existing .miz missions in this repository.
- Keep script load order assumptions intact: MIST first, CTLD-i18n.lua before CTLD.lua.

## CTLD.lua editing rules
- Keep user-tunable options in the USER CONFIGURATION section with clear comments and safe defaults.
- Keep coalition conventions consistent:
  - 1 = red
  - 2 = blue
  - 0 = both (where applicable)
- Keep pickup/dropoff/waypoint zone tuple formats compatible with current parser logic.
- Keep crate weight values unique in ctld.spawnableCrates.
- Preserve callback behavior and action names used by ctld.processCallback.
- Use defensive nil checks before calling methods on DCS objects (Unit/Group/zone lookups).
- Prefer existing logging patterns (ctld.logInfo, env.info, env.error) over ad-hoc prints.
- Avoid adding heavy polling loops; prefer bounded searches and scheduled checks.

## I18N rules
- For every new player-visible string, add an English reference key and use ctld.i18n_translate at call sites.
- Do not hardcode new menu or gameplay text without i18n_translate.
- When adding keys, keep translation_version alignment in mind and add placeholders in CTLD-i18n.lua tables.
- Do not remove or rename existing i18n keys unless all language tables are updated.

## Testing expectations
- Prefer the dynamic loading workflow documented in README for fast iteration.
- After gameplay logic changes, validate at least:
  - troop load/unload flows
  - crate spawn/load/unpack flows
  - JTAC-related flows (if touched)
- Use repository missions for smoke tests when relevant:
  - test-dev-dynamic.miz
  - test-dev-static.miz
  - test-mission.miz
- If user-facing behavior or configuration changes, update README examples in the same change.

## Code style conventions

- Follow existing file style and indentation.
- OOP Lua 5.1: use the project class system (`src/core/class.lua`) for new classes.
- For internal helpers, follow existing naming patterns (local variables often prefixed with _).
- Keep mission-designer guidance comments concise and practical.
- No direct `mist.*` calls — use the middleware.
- Every new public function should have at least one unit test.

## Common tasks

### Adding a new deployable object (v2)

1. Register a descriptor in `source_futur/CTLD_objectRegistry.lua` (or in the owning manager file for scene-specific objects):
   ```lua
   CTLDObjectRegistry:register("MY_OBJECT", {
       desc = function(coalitionId, countryId, x, y, heading, altitude)
           return { groupType = "STATIC", type = "MY_OBJECT", ... }
       end
   })
   ```
2. Add name/translation key in `source_futur/CTLD_i18n_en.lua` + all language files.
3. Reference the key (`registryKey = "MY_OBJECT"`) in the relevant scene data file under `source_futur/scenes/`.

### Adding a scene (animated sequence)

1. Create a dedicated scene file in `source_futur/scenes/` (one file per scene — contains scene definition + required object registrations).
2. Define the scene table:
   ```lua
   local myScene = {
       name = "My Scene",
       stepsDatas = {
           { polar = {dist=10, angle=0}, delayAfterPreviousStep=2,
             relativeHeadingInDegrees=0, registryKey="MY_OBJECT", func=nil },
           ...
       }
   }
   ```
3. Register at end of file: `CTLDSceneManager:register(myScene)`
4. Add the scene file to `merger_futur/listToMerge.txt` after `CTLD_core.lua`.

### Modifying translations

1. Add/update the English reference key in `source_futur/CTLD_i18n_en.lua`.
2. Add placeholder or translated value in `source_futur/CTLD_i18n_fr.lua`, `_es.lua`, `_ko.lua`.
3. Use `ctld.i18n_translate(key, ...)` at all call sites — never hardcode player-visible strings.
