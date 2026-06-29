# JTAC Lifecycle & State Transitions Analysis

> Status: FINAL — all B1–B8 bugs resolved. Updated 2026-06-28 against code.
> Initial analysis: 2026-05-01

---

## 1. Les 3 types de JTAC — Annihilabilité vs Loadabilité

| Type | Catégorie DCS | Spawnable entier (menu) | Spawnable par crate | Packable (annihilable) | Loadable (embarquable) | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| **Troop** (infanterie) | GROUND (Group) | Non | Oui — crate infantry | Non | Oui — `_inTransit` | Route `embarkFromTroopZone`→`disembark()` |
| **Vehicle** (Hummer/SKP-11) | GROUND (Group) | Oui — `spawnVehicleForTransport` | Oui — unpack | Oui — `packVehicle` → `deregisterJTAC` | Oui — `loadVehicle` (virtuel + DCS native) | Route directe `spawnJTACVehicleForTransport` |
| **Drone** (MQ-9/RQ-1A) | AIRPLANE via `deployAirJTAC` ou crate spawnAs=AIRPLANE | Oui — `deployAirJTAC()` | Oui — drone crate (spawnAs=AIRPLANE) | Non (aircraft) | Non — aéronefs non cargaables dans CTLD | `_dispatchPostSpawn` appelle `startLase` pour isJTAC=true même sur air vehicles |

---

## 2. Spawn methods détaillées par type

### A. JTAC Troop (infantry group with jtac=N in loadableGroups)

| Méthode | Code path | DCS group créé | JTAC registered par |
|---------|-----------|---------------|-------------------|
| Load via TRZ → deploy | `embarkFromTroopZone()` → `disembark()` | Oui, dans `disembark()` → `spawnObject()` | `disembark()` → `startLase(groupName)` |
| Extract dropped group | `embarkFromField()` | Non — groupes déjà spawnés | `deregisterJTAC()` × N appelé avant `group:destroy()` |

**Note**: `embarkFromTroopZone` ne crée pas de JTAC directement — elle stocke un `CTLDTroopGroup` dans `_inTransit`. Le JTAC n'est créé que lors du `disembark()` (spawn DCS group + startLase).

### B. JTAC Vehicle (ground vehicle, isJTAC=true in spawnableCrates)

| Méthode | Code path | JTAC registered | Notes |
|---------|-----------|----------------|-------|
| **Request JTAC Equipment** (menu entier) | `spawnJTACVehicleForTransport()` → `spawnVehicleForTransport()` + `registerJTACVehicle()` + `startLase()` | `registerJTACVehicle()` + `startLase()` dans `spawnJTACVehicleForTransport` | Spawne le véhicule au sol, immediately lasing |
| **Unpack crate isJTAC=true (GROUND)** | `_spawnUnpacked()` → `_dispatchPostSpawn()` → `registerJTACVehicle()` + `startLase()` | `_dispatchPostSpawn()` appelle `startLase()` + `registerJTACVehicle()` | Route standard unpack |

### C. JTAC Drone (aéronef AI, isJTAC=true, spawnAs=AIRPLANE)

| Méthode | Code path | JTAC registered | Notes |
|---------|-----------|----------------|-------|
| **Unpack drone crate** | `_spawnUnpacked()` → `_dispatchPostSpawn()` | `_dispatchPostSpawn()` checks `desc.isJTAC` sans distinction air/ground → `startLase()` appelé ✅ | Résolu B6 [2026-04-26 / CL-4] |
| **deployAirJTAC()** | `deployAirJTAC()` → `spawnFromDescriptor(AIRPLANE)` + `startLase()` | `startLase()` appelé directement | Chemin correct pour drone JTAC |

**Note**: `JTAC_unitTypeNames` supprimé (CL-4). Les drones n'apparaissent plus dans un menu "Request JTAC Equipment" séparé — ils passent par le système de crate standard (spawnAs=AIRPLANE dans spawnableCrates).

---

## 3. Modes de drop et gestion JTAC

### Terminologie des drops

| Terme | Description | Unit DCS |
|--------|-------------|----------|
| **Drop Virtuel CTLD** | `Drop Crate(s)` menu — unload crates from transport to ground | Static objects (crates) |
| **Parachute Virtuel CTLD** | `Parachute Crates` — crates fall with parachute effect | Static objects (crates) |
| **Parachute Vehicle Virtuel CTLD** | `Parachute Vehicle` — vehicle falls with parachute effect | DCS ground unit respawned at landing |
| **Unpack (crate)** | `Unpack Crate` menu — destroys crate, spawns vehicle/group | DCS unit (vehicle or group) |
| **DCS Native Load** | Vehicle enters transport bbox (C-130, CH-47F) | DCS unit stays alive (linked in aircraft) |
| **DCS Native Unload** | Vehicle exits transport bbox | DCS unit reappears on ground |

### JTAC Vehicle — Transitions par mode de drop

```
[GROUND VEHICLE JTAC — spawnAs=nil ou GROUND]

PATH 1: Unpack crate isJTAC=true (spawnAs=GROUND)
  unpack → _spawnUnpacked(spawnAs=GROUND) → _dispatchPostSpawn() → startLase() + registerJTACVehicle()
  État: jtacs[gname]=entity, LASING/IDLE ✅

  → LOAD (menu): loadVehicle(method=menu_ctld)
      setJTACInTransit(gname) → state=IN_TRANSIT, jtacs[gname]=nil (laser FREED)
      vehicle.unit:DESTROY() (DCS unit destroyed)
      ✅ Correct

  → LOAD (DCS native, C-130): loadVehicle(method=dcs_native)
      setJTACInTransit(gname) → state=IN_TRANSIT, jtacs[gname]=nil (laser FREED)
      vehicle.unit stays alive (linked in aircraft)
      ✅ Correct

  → UNLOAD (menu): unloadVehicle(method=menu_ctld)
      dynAdd() → respawn new DCS unit
      resumeJTAC(gname) → jtacs[gname]=entity, IDLE → startLase() → LASING
      ✅ Correct

  → UNLOAD (DCS native): unloadVehicle(method=dcs_native)
      DCS unit already on ground → Group.getByName(spawnData.groupName) → found
      resumeJTAC(gname) → jtacs[gname]=entity, startLase()
      ✅ Correct

  → PACK (menu): packVehicle()
      deregisterJTAC(gname) → state=DEAD, jtacs[gname]=nil, laser FREED
      vehicle.unit:DESTROY()
      ✅ Correct

PATH 2: Request JTAC Equipment — spawnVehicleForTransport (ground vehicle, entire)
  spawnVehicleForTransport(typeName) → dynAdd GROUND group
  → registerJTACVehicle() → vehicle registered in _vehicles
  → startLase() in spawnJTACVehicleForTransport
  État: jtacs[gname]=entity, LASING ✅

  Transitions from this point are identical to PATH 1 (LOAD/UNLOAD/PACK same code paths)
```

### JTAC Troop — Transitions par mode

```
[TROOP JTAC — loadableGroups with jtac=N]

PATH 1: Load via TRZ → Deploy
  embarkFromTroopZone(template) → _inTransit[unitName] = CTLDTroopGroup(jtac=N)
  (no JTAC spawned yet at this point)

  → DISEMBARK (transport lands, drops troops):
      spawnObject() → DCS group created
      _syncFromDCSGroup() → _jtacUnits rebuilt from real DCS unit names
      disembark() → startLase() × N (loop on _jtacUnits) → jtacs[unitName]=entity, LASING
      ✅ Correct

  → EMBARK FROM FIELD (transport picks up dropped group):
      embarkFromField() → loop on _jtacUnits → deregisterJTAC() × N BEFORE group:destroy()
      S_EVENT_DEAD NOT triggered for JTAC (already deregistered)
      ✅ Correct — B2 resolved [2026-05-02]

PATH 2: Parachute Troops
  parachuteTroops() → drops loaded CTLDTroopGroup from transport
  → disembark() called for each group (same JTAC handling as PATH 1 disembark)
  ✅ Same as DISEMBARK for JTAC handling

PATH 3: Unpack crate with isJTAC infantry (crate contains infantry group)
  Not applicable — infantry JTAC groups are defined in loadableGroups (TRZ system),
  not as standalone unpackable crates. The crate isJTAC=true flag applies to vehicle/drone types only.
```

### JTAC Drone — Transitions par mode

```
[DRONE JTAC — spawnAs=AIRPLANE, isJTAC=true]

PATH 1: Unpack drone crate
  _spawnUnpacked(desc, spawnAs=AIRPLANE) → isAir=true
  → _dispatchPostSpawn(desc, gname) → desc.isJTAC=true → startLase(gname) ✅
  État: jtacs[gname]=entity, ORBITING (via deployAirJTAC internal path)
  ✅ Correct — B6 resolved [2026-04-26 / CL-4]

PATH 2: deployAirJTAC() (direct menu path)
  deployAirJTAC() → spawnFromDescriptor(AIRPLANE) + startLase()
  État: jtacs[gname]=entity, ORBITING ✅

  → Drone destroyed (S_EVENT_DEAD): killJTAC(gname) → state=DEAD, jtacs[gname]=nil
  ✅ Correct

  IN_TRANSIT: N/A — drones cannot be loaded onto transports
```

---

## 4. Bug resolution status (verified 2026-06-28)

All bugs identified in this analysis were resolved in subsequent implementation sessions.

### B1 — JTAC Troop: JTAC active during BOARD
**Status**: ✅ NOT A BUG — `embarkFromTroopZone()` does not spawn a DCS group.
The troop group is stored as `CTLDTroopGroup` in `_inTransit` (virtual state, no DCS entity).
JTAC is only started on `disembark()`, after the DCS group is spawned.

### B2 — JTAC Troop: orphan JTAC after field extract
**Status**: ✅ RESOLVED [2026-05-02] — Troop lifecycle refactor.
`embarkFromField()` explicitly calls `deregisterJTAC(jtacName)` for each entry in `_jtacUnits`
**before** `group:destroy()`. This prevents `S_EVENT_DEAD` from falsely triggering `killJTAC()`.
Code: `CTLD_troop.lua` — `embarkFromField()`, loop on `_jtacUnits` before destroy.

### B3 — JTAC Troop DEPLOY: startLase on group not yet alive
**Status**: ✅ NOT A BUG — `startLase()` uses `_tryInitFlying()` with T+2s retry logic.
If the DCS group is not yet alive at first poll, the loop retries until the unit is found.

### B4 — Troop JTAC: inconsistent hasJtac detection (substring vs flag)
**Status**: ✅ RESOLVED [2026-05-02] — Troop lifecycle refactor eliminated the substring approach.
`_jtacUnits = { [unitName] = true }` map is built from template roles at `embarkFromTroopZone()` time
(role == "jtac") and rebuilt from real DCS unit names after `_syncFromDCSGroup()`.
Old `extract()` substring approach (`groupName:find("jtac")`) no longer exists.

### B5 — JTAC Drone: Request JTAC Equipment menu listed non-loadable drones
**Status**: ✅ RESOLVED [2026-04-26 / CL-4] — `JTAC_unitTypeNames` setting deprecated and removed.
The "Request JTAC Equipment" menu is now built from `getJTACDescriptors()` which returns crates
with `isJTAC=true`. Drones (MQ-9, RQ-1A) appear only in the standard Request Equipment crate menu
(spawnAs=AIRPLANE path), not in a separate vehicle spawn menu.

### B6 — Drone JTAC: unpack crate did not start JTAC automatically
**Status**: ✅ RESOLVED [2026-04-26 / CL-4] — `_dispatchPostSpawn(desc, gname)` checks `if desc.isJTAC`
without ground/air distinction. For drones with `isJTAC=true` and `spawnAs=AIRPLANE`, `startLase(gname)` IS called.
Code: `CTLD_crate.lua` — `_dispatchPostSpawn()`.

### B7 — JTAC Vehicle DCS native: vehicle.unit stays alive after loadVehicle dcs_native
**Status**: ✅ CORRECT BY DESIGN — DCS native load keeps the unit alive (linked in aircraft).
`setJTACInTransit()` → state=IN_TRANSIT, jtacs[]=nil, laser freed. Confirmed correct.

### B8 — Parachute Vehicle: JTAC state after landing
**Status**: ✅ RESOLVED [2026-05-06 / Feature K GAP-K1] — `parachuteVehicle()` now calls
`vehicle:setState(WAITING)` and `jtacMgr:resumeJTAC(gname)` in the landing callback.
Code: `CTLD_vehicle.lua` — `parachuteVehicle()`.

---

## 5. Tableau synthétique des transitions par type

### JTAC TROOP (infantry, jtac=N in loadableGroups)

| Transition | Trigger | state avant | state après | jtacs[] | laserCode | DCS group | Action JTAC |
|-----------|---------|------------|------------|---------|-----------|-----------|------------|
| BOARD (embarkFromTroopZone) | Menu → TRZ | N/A | N/A | N/A | N/A | Pas encore créé | Aucun — group pas encore spawné |
| DISEMBARK | Menu → transport posé | N/A | IDLE | Créé × N | Alloué | Spawned par spawnObject() | startLase() × N → LASING |
| Parachute Deploy | Menu → Altitude OK | N/A | IDLE | Créé × N | Alloué | Spawned par spawnObject() | startLase() × N → LASING |
| EMBARK FROM FIELD | Menu → transport posé | LASING/IDLE | DEAD | nil × N | freed | group:destroy() après deregisterJTAC × N | deregisterJTAC() × N BEFORE destroy ✅ |
| Troop destroyed (combat) | S_EVENT_DEAD | LASING/IDLE | DEAD | nil | freed | Détruit | killJTAC() |

### JTAC VEHICLE (ground, isJTAC=true, spawnAs=nil ou GROUND)

| Transition | Trigger | state avant | state après | jtacs[] | laserCode | DCS unit | Action JTAC |
|-----------|---------|------------|------------|---------|-----------|-----------|------------|
| Unpack crate | Unpack menu | N/A | IDLE | Créé | Alloué | Spawned via dynAdd | startLase() |
| Request JTAC Equip | Menu → Request Equipment | N/A | IDLE | Créé | Alloué | Spawned via spawnVehicleForTransport | startLase() dans spawnJTACVehicleForTransport |
| LOAD menu_ctld | Menu → Load Vehicle | IDLE/LASING | IN_TRANSIT | nil | FREED | vehicle.unit:destroy() | setJTACInTransit() → stopLase + jtacs[]=nil |
| LOAD dcs_native | Vehicle enters transport bbox | IDLE/LASING | IN_TRANSIT | nil | FREED | Unit stays alive (linked) | setJTACInTransit() → stopLase + jtacs[]=nil |
| UNLOAD menu_ctld | Menu → Unload Vehicle | IN_TRANSIT | IDLE | Recréé | Alloué | dynAdd respawn new unit | resumeJTAC() → startLase() |
| UNLOAD dcs_native | Vehicle exits transport bbox | IN_TRANSIT | IDLE | Recréé | Alloué | Unit already on ground | resumeJTAC() → startLase() |
| PARACHUTE DROP | Menu → Parachute Vehicle | LOADED | WAITING | Recréé | Alloué | Unit respawned at landing | resumeJTAC() dans landing callback ✅ |
| PACK | Menu → Pack Vehicle | IDLE/LASING | DEAD | nil | FREED | vehicle.unit:destroy() | deregisterJTAC() → silent, no OnJTACDead |
| Vehicle destroyed (combat) | S_EVENT_DEAD | any | DEAD | nil | freed | Détruit | killJTAC() |

### JTAC DRONE (air, spawnAs=AIRPLANE, isJTAC=true)

| Transition | Trigger | state avant | state après | jtacs[] | laserCode | DCS group | Action JTAC |
|-----------|---------|------------|------------|---------|-----------|-----------|------------|
| Unpack drone crate | Unpack menu | N/A | ORBITING | Créé | Alloué | Spawned (spawnAs=AIRPLANE) | startLase() via _dispatchPostSpawn ✅ |
| deployAirJTAC() | Menu direct | N/A | ORBITING | Créé | Alloué | AIRPLANE via spawnFromDescriptor | startLase() → ORBITING ✅ |
| Drone destroyed (combat) | S_EVENT_DEAD | ORBITING/LASING | DEAD | nil | freed | Détruit | killJTAC() |

---

## 6. Scénarios de recette de référence

| ID | Scenario | Résultat | Ref |
| --- | --- | --- | --- |
| JTAC-T-full | Troops full cycle v2 (8 steps, 2 JTAC) | ✅ 8/8 PASS | `scenarioTroopsFullCycle_v2.lua` [2026-05-04] |
| JTAC-V-full | JTAC vehicle in-transit lifecycle | ✅ F-125→F-127 PASS | `scenario_feature_k_jtac_vehicle.lua` [2026-05-06] |
| JTAC-V-pack | JTAC vehicle crate pack/deregister | ✅ F-132 7/7 PASS | `scenario_jtac_crate_pack.lua` [2026-05-06] |
| JTAC-D-orbit | Drone JTAC orbit lifecycle | ✅ F-106 visual PASS | [2026-04-25] |
| JTAC-sol-e2e | JTAC sol Hummer end-to-end (Request Equipment → unpack → 9-Line) | ✅ PASS live DCS | [2026-05-12] |
