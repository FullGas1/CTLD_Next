# CTLD — Manual Test Sequences

Centralized catalogue of manual DCS in-game test sequences.
Each sequence targets a specific feature perimeter and should be replayed whenever a change
touches that perimeter.

---

## How to use

1. Identify the modified perimeter (column **Perimeter / files**).
2. Run the listed sequence in a live DCS mission with CTLD + Witchcraft active.
3. Tick each step. Any ❌ = regression to fix before merge.

---

## MT-01 — Multi-group troop transport + disembark menu

**Perimeter / files:** `src/CTLD_troop.lua` — `refreshMenuSection`, `disembark`, `disembarkAll`,
`disembarkIndex`, `embarkFromTroopZone`, `embarkFromFieldByGroup`, `_findAllNearbyDropped`,
`_menuCheckCargo`, `_canEmbark`, `_currentTroopCount`

**Pre-requisites:**
- Mission with ≥ 2 TRZ pickup zones populated with troops (e.g. 2 x JTAC-type loadable groups)
- Player in UH-1H (or any transport with `troops: true`)
- `multiGroupTransport = true` in config (or set via Witchcraft `cfg.settings["multiGroupTransport"] = true`)

### Sequence

| # | Action | Verify |
|---|--------|--------|
| 1 | Land in TRZ. Open Troop Commands → Embark → Load [JTAC group 1]. | ✓ Screen message confirms load. ✓ Check Cargo shows exactly 1 group with name, troop count, weight. ✓ Disembark menu is a **direct command** (no submenu, since only 1 group). |
| 2 | Still in same TRZ. Open Troop Commands → Embark → Load [JTAC group 2]. | ✓ Screen message confirms load. ✓ Check Cargo shows 2 lines [1] and [2] + TOTAL line with summed count and weight. ✓ Disembark menu is now a **submenu** containing exactly 3 entries: "Disembark All", "[1] \<group1 name\>", "[2] \<group2 name\>". |
| 3 | Take off. Open Troop Commands in flight. | ✓ "Disembark Troops" submenu is gone (ground-only). ✓ "Parachute Troops" submenu appears with: "Parachute All" + "[1] \<name\>" + "[2] \<name\>" — exactly 3 entries. |
| 4 | Land. Open Troop Commands → Disembark Troops → choose [1]. | ✓ Group 1 spawns on the ground, not colliding with helicopter. ✓ Screen message names the deployed group. ✓ Check Cargo shows only 1 remaining group (the one NOT chosen). |
| 5 | Still 1 group onboard. A previously deployed JTAC group is within ~125 m. Open Troop Commands → Embark / Extract Troops. | ✓ Section is **visible and enabled** despite troops still onboard. ✓ "Extract from field" shows the nearby group name (direct command if 1 group, submenu if multiple). |
| 6 | Choose remaining group → Disembark. | ✓ Group spawns at different position from step 4 spawn — **not on top of previous group**. ✓ Minimum ~10 m from helicopter. ✓ Check Cargo shows "No troops onboard." |
| 7 | Both groups now dropped nearby. Open Troop Commands → Embark / Extract Troops. | ✓ "Extract from field" is a **submenu** with exactly 2 entries. ✓ Each entry shows group name AND distance in metres (e.g. "Dropped Alpha (45m)"). |
| 8 | Extract one group from the submenu. | ✓ That group embarks. ✓ Check Cargo shows 1 group. ✓ Remaining dropped group still visible on map. |
| 9 | Embark a second group (from TRZ or remaining dropped). Use Disembark All. | ✓ Both groups spawn at **separate positions** — visually distinct, no unit stacking. ✓ Both positions at least ~10 m from helicopter. |
| 10 | Embark 2 groups again. Disembark [2] then [1] separately (back-to-back). | ✓ [2] spawns first, [1] spawns after in a different position — **no overlap between the two spawns**. ✓ Correct group names in confirmation messages match the chosen index. |

### Pass criteria
- Step 4: exactly 3 entries in disembark submenu (All + [1] + [2])
- Step 6: extract menu visible even with 1 group already onboard (capacity > current count)
- Steps 9/10: groups not stacked on the same coordinates

---

## MT-02 — Véhicule entier transport (load / unload / parachute)

**Perimeter / files:** `src/CTLD_vehicle.lua` — `loadVehicle`, `unloadVehicle`, `parachuteVehicle`,
`spawnVehicleAt`, `refreshMenuSection` (Vehicle Commands)

**Pre-requisites:**
- Mission with at least 1 logistic zone containing a vehicle crate (e.g. Hummer, BTR-80)
- Player in UH-1H (or any transport with `vehicles: true` in unitActions config)
- `parachuteMinAltitudeVehicles` reachable with UH-1H (default 30 m AGL)
- Config `ctld.settings["requestEquipmentTypes"]` includes the vehicle crate type

### Sequence

| # | Action | Verify |
|---|--------|--------|
| 1 | Land at logistic zone. Open Request Equipment → request the vehicle crate. | ✓ Crate spawns near helicopter. ✓ Screen message confirms spawn. |
| 2 | Open Crate Commands → Unpack Crates. | ✓ Screen message confirms vehicle spawn. ✓ Ground vehicle unit is visible in the mission. |
| 3 | Open Vehicle Commands → Load Vehicle (select the spawned vehicle). | ✓ Screen message confirms load. ✓ Vehicle unit disappears (destroyed on load for `menu_ctld`). ✓ Vehicle Commands → Check Cargo shows the vehicle type and weight. |
| 4 | Take off to cruise altitude. Open Vehicle Commands in flight. | ✓ "Unload Vehicle" is **not visible** or **disabled** (ground-only). ✓ "Parachute Vehicle" is **visible and enabled** when in-flight. |
| 5 | Land. Open Vehicle Commands → Unload Vehicle. | ✓ Screen message confirms unload. ✓ Vehicle respawns on the ground near the helicopter. ✓ Position is at least ~10 m from helicopter. |
| 6 | Open Vehicle Commands → Load Vehicle (reload the same vehicle). | ✓ Load confirmed. ✓ Vehicle disappears. ✓ Check Cargo still shows vehicle. |
| 7 | Take off to ≥ 50 m AGL. Open Vehicle Commands → Parachute Vehicle. | ✓ **Screen message appears**: "Parachuting vehicle \<type\> — landing in ~Xs". ✓ Message duration ~10 s. |
| 8 | Wait for descent time (shown in step 7 message). | ✓ Vehicle spawns automatically on the ground at the computed drop position. ✓ No player action required after the menu command. |
| 9 | Attempt Parachute Vehicle at < 30 m AGL. | ✓ Error message "Altitude too low for parachute drop..." is shown. ✓ No vehicle is unloaded. ✓ Vehicle Commands still shows vehicle in cargo. |

### Pass criteria
- Step 7: confirmation message present with vehicle type and estimated landing time
- Step 8: vehicle auto-spawns without manual intervention after descentTime
- Step 9: low-altitude guard prevents accidental drop

---

## MT-03 — Multi-véhicule entier : load / unload / parachute

**Perimeter / files:** `src/CTLD_vehicle.lua` — `refreshLoadSection`, `refreshUnloadSection`,
`refreshParachuteVehicleSection`, `loadVehicle`, `unloadVehicle`, `parachuteVehicle`,
`getLoadedVehicleWeight`, `_updateVehicleCargo`

**Pre-requisites:**
- 2 vehicles entiers de types différents (or same type) spawned near the helicopter (via unpack or Witchcraft)
- Player in UH-1H with `vehicles: true` and `canParachute: true` in unitActions config
- Transport weight limit high enough to hold both vehicles (or explicitly lower to test limit guard)

### Sequence

| # | Action | Verify |
|---|--------|--------|
| 1 | Land. Open Vehicle Commands → Load / Extract Vehicles. | ✓ Submenu lists **both** nearby vehicles as separate entries (one per vehicle). ✓ Labels match the descriptor desc (or vehicleType fallback). |
| 2 | Load vehicle A. | ✓ Vehicle A unit disappears. ✓ Load submenu now shows only vehicle B. ✓ Unload Vehicles submenu becomes enabled with 1 entry (vehicle A). ✓ Check Cargo (via Vehicle Commands) shows vehicle A with its weight. |
| 3 | Load vehicle B. | ✓ Vehicle B unit disappears. ✓ Load submenu shows "No vehicles nearby". ✓ Unload Vehicles shows **2 entries** — one for A, one for B. ✓ Check Cargo shows cumulative weight (A + B). |
| 4 | Open Unload Vehicles → choose vehicle A. | ✓ Vehicle A respawns on the ground (≥ 10 m from helicopter). ✓ Unload submenu now shows only vehicle B (1 entry). ✓ Check Cargo weight is reduced by vehicle A's weight. |
| 5 | Take off to ≥ 50 m AGL. Open Vehicle Commands. | ✓ Unload Vehicles → "Land to unload vehicles" (command disabled in air). ✓ "Parachute Vehicle" command is **enabled**. |
| 6 | Parachute Vehicle. | ✓ Screen message: "Parachuting vehicle \<typeB\> — landing in ~Xs". ✓ After descent time, vehicle B auto-spawns on the ground. ✓ Unload Vehicles becomes disabled (no vehicle left). ✓ "Parachute Vehicle" becomes disabled. |
| 7 | Land. Reload both vehicles A and B. Take off. Use Parachute Vehicle twice in sequence. | ✓ First "Parachute Vehicle" drops one vehicle (confirmation message). ✓ "Parachute Vehicle" still enabled after first drop (second vehicle still loaded). ✓ Second "Parachute Vehicle" drops the remaining vehicle. ✓ After second drop: "Parachute Vehicle" becomes disabled. |

### Pass criteria
- Step 3: Unload submenu lists all loaded vehicles — no merge, no duplicate
- Step 4: partial unload does not affect the other loaded vehicle
- Step 6: single "Parachute Vehicle" command drops exactly one vehicle per press
- Step 7: "Parachute Vehicle" re-enables after first drop while second vehicle still loaded

---

## MT-06 — RECON FARP/FOB layer — détection ennemie persistante

**Perimeter / files:** `src/CTLD_recon.lua` — `_syncFarpMarks`, `_clearFarpMarks`,
`drawFarpIcon`, `createIcon` (coalition param), `_matchLayer` (farp_fob guard) ;
`src/CTLD_core.lua` — `CTLDStaticWatcher` (watch/unwatch/tick, `S_EVENT_STATIC_DEAD`)

**Pre-requisites:**
- Mission with group `red_FARP` containing unit `red_FARP-1` (RED coalition FARP)
- Player in BLUE coalition transport (UH-1H recommended)
- Scripts injected **in order**:
  1. `CTLD_Next.lua` — wait 3-5 s
  2. `recette/enable_debug.lua` — sets `debug=true` **and** `reconEnabled=true`
  3. `recette/inject_red_fob.lua` — spawns RED FOB ~300 m north of red_FARP, registers it in CTLDFOBManager

### Sequence

| # | Action | Verify |
|---|--------|--------|
| 1 | Open F10 CTLD menu → RECON → Layers. | ✓ Entry **"FARP / FOB \[activate\]"** is visible. ✓ Layer is **disabled by default** (label shows `[activate]`). |
| 2 | Take off ≥ 50 m AGL. Fly to within ~5 km of the red FARP. Open RECON → Layers → "FARP / FOB \[activate\]". | ✓ Screen message confirms layer activated. ✓ Menu entry becomes **"FARP / FOB \[deactivate\]"**. |
| 3 | Open RECON → Scan (or Refresh Scan). | ✓ **Magenta H-cerclé** icon (circle + left vertical + crossbar) appears on F10 map at red FARP position. ✓ A **second** magenta H-cerclé appears at the RED FOB position (~300 m north). ✓ Total: exactly 2 icons (assuming no other RED FARP in the mission). |
| 4 | Fly > 5 km from both targets (leave LOS). Wait ≤ 60 s for auto-refresh cycle. | ✓ Both icons **remain** on F10 map — persistence is independent of LOS. ✓ CTLD.log shows no `removeIcon` call for the FARP/FOB marks during refresh. |
| 5 | Open RECON → Layers → "FARP / FOB \[deactivate\]". | ✓ Screen message confirms layer deactivated. ✓ Both icons **disappear immediately** from F10 map. ✓ Menu entry reverts to "FARP / FOB \[activate\]". |
| 6 | Reactivate layer. Fly back within 5 km. Scan again. | ✓ Icons reappear after scan. ✓ **No duplicates** — each FARP/FOB has exactly 1 icon. |
| 7 | Inject via Witchcraft: check coalition propagation.<br>`local rm=CTLDReconManager.getInstance(); local sc=rm._activeScans["<player>"]; trigger.action.outText(tostring(sc and sc.playerCoalition),10)` | ✓ Output shows **`2`** (BLUE coalition). ✓ Confirms icons are drawn `circleToAll(2, ...)` not `-1`. |
| 8 | Inject via Witchcraft to destroy red_FARP-1 (coordinates from F10 map — default ~{x=-360432,y=0,z=615168}):<br>`trigger.action.explosion({x=-360432, y=0, z=615168}, 1000)` | ✓ Within **~2 seconds** the FARP icon disappears from F10 map. ✓ CTLD.log shows `S_EVENT_STATIC_DEAD` dispatch for the FARP id. ✓ FOB icon remains (only FARP destroyed). |
| 9 | Destroy RED FOB statics (two explosions near FOB position, ~300 m north of red_FARP):<br>`trigger.action.explosion({x=-360132, y=0, z=615168}, 500)` | ✓ Within ~2 seconds the FOB icon disappears from F10 map. ✓ CTLD.log shows `S_EVENT_STATIC_DEAD` for the FOB id. ✓ F10 map is **clean** — no orphan mark remaining. |

### Pass criteria
- Step 3: 2 distinct magenta H-cerclé icons (FARP + FOB), both positioned correctly
- Step 4: marks persist after leaving LOS (persistent layer logic confirmed)
- Step 5: toggle OFF clears all farp/fob marks immediately
- Step 7: `playerCoalition == 2` confirms coalition-aware rendering (fix vs `-1`)
- Step 8: CTLDStaticWatcher fires within ~2 s of FARP destruction and removes icon
- Step 9: FOB destruction also triggers mark removal via CTLDStaticWatcher

---

## Changelog

| Date | Sequence | Notes |
|------|----------|-------|
| 2026-05-12 | MT-01 | First validation — all 10 steps PASS after fixes: extract guard, spawn offset |
| 2026-05-12 | MT-02 | Sequence defined; bug fix: missing parachute confirmation message added |
| 2026-05-12 | MT-03 | PASS live DCS — bugs fixed: Load menu visible in-flight (inAir guard + refreshLoadSection missing from onTakeoff/onLand) |
| 2026-05-13 | MT-04 | PASS live DCS — bug fix: missing parachute confirmation message in parachuteCrates |
