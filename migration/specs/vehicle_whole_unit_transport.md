# Vehicle Whole-Unit Air Transport

> **Status** : implemented [2026-05-19] — verified against code [2026-06-28]
> **Files** : `src/CTLD_vehicle.lua`, `src/CTLD_crate.lua`

---

## Contexte

Certains appareils (C-130J-30, CH-47Fbl1, Il-76MD) peuvent transporter des véhicules entiers sans les démonter en caisses. Le mécanisme existe en v2 (`canTransportWholeVehicle`, `loadableVehiclesRED/BLUE`, `loadVehicle()`/`unloadVehicle()`), mais présentait trois gaps :

1. **GAP-Q1** : `findLoadableVehicles` ne filtrait pas par coalition → un transport BLUE pouvait charger un véhicule RED.
2. **GAP-Q2** : `findLoadableVehicles` ne filtrait pas par type `loadableVehiclesRED/BLUE` → n'importe quel CTLDVehicle WAITING était proposé.
3. **GAP-Q3** : aucun menu pour spawner un véhicule transportable entier depuis une LGZ (analogue du "Request Equipment" pour caisses).

---

## Source d'un véhicule loadable

Un CTLDVehicle en état `WAITING` peut provenir de trois sources :

| Source | Mécanisme |
| --- | --- |
| Véhicule MM pré-placé | INIT-D `scanMMVehicles()` → si type dans `spawnableCrates` → WAITING |
| Late activation | `S_EVENT_BIRTH` → `onBirth` → `_registerMMVehicleUnit` |
| Request Equipment (nouveau) | Menu LGZ → si type dans `loadableVehiclesRED/BLUE` du transport → `spawnVehicleForTransport()` → WAITING |

---

## Changement 1 — Ordre des menus F10

**Nouvel ordre d'affichage :**

| Order | Menu | Manager |
| --- | --- | --- |
| 20 | Troop Commands | CTLDTroopManager |
| 25 | Request Equipment | CTLDCrateManager |
| 30 | Vehicle Commands | CTLDVehicleSpawner |
| 40 | Crate Commands | CTLDCrateManager |
| 60 | Radio Beacons | CTLDBeaconManager |
| 70 | RECON | CTLDReconManager |
| 80 | Smoke | CTLDCrateManager |
| 90 | JTAC Commands | CTLDJTACManager |

**Motivation** : Request Equipment covers both crates AND whole vehicles. It must precede Vehicle Commands (player requests first, then loads).

**Site** : `CTLD_crate.lua` — `refreshRequestEquipmentSection` → `menu:addSubMenu({ root }, spawnSub, { order = 25 })`.

---

## Changement 2 — `findLoadableVehicles` : filtres coalition + type

**Fichier** : `src/CTLD_vehicle.lua` — `CTLDVehicleSpawner:findLoadableVehicles(transport)`

**Filtres ajoutés** (en plus du filtre distance existant) :

```
1. Coalition :
   veh.spawnData.coalitionId == transport:getCoalition()

2. Type loadable :
   caps = capabilitiesByType[transport:getTypeName()]
   si caps == nil ou caps.canTransportWholeVehicle ~= true → retourner {}
   list = caps.loadableVehiclesRED (coalition 1) ou caps.loadableVehiclesBLUE (coalition 2)
   si list == nil → retourner {}
   veh.vehicleType doit être dans list
```

**Helper interne** : `_isTypeLoadable(vehicleType, transportTypeName, coalition)` → bool.

---

## Changement 3 — `spawnFn` dans `refreshRequestEquipmentSection` : branche vehicle

**Fichier** : `src/CTLD_crate.lua` — `CTLDCrateManager:refreshRequestEquipmentSection(playerObj)`

### Détection au moment de la construction du menu

```lua
local caps = capabilitiesByType[playerObj.typeName]
local loadableList = nil
if caps and caps.canTransportWholeVehicle then
    loadableList = (playerObj.coalition == 1)
        and caps.loadableVehiclesRED
        or  caps.loadableVehiclesBLUE
end

-- Pour chaque singleCrate sc :
local spawnAsVehicle = false
if loadableList then
    for _, t in ipairs(loadableList) do
        if t == sc.unit then spawnAsVehicle = true; break end
    end
end
-- Passer spawnAsVehicle dans arg du addCommand
```

### Callback `spawnFn`

```lua
if arg.spawnAsVehicle then
    -- Spawn CTLDVehicle WAITING (pas de crate)
    local vs = CTLDVehicleSpawner.getInstance()
    vs:spawnVehicleForTransport(arg.unit, transport, selZone)
    -- message : "Un <desc> est prêt à être chargé" (i18n)
else
    -- comportement actuel : spawnCrate (inchangé)
end
```

**Les mixedSets** : `spawnAsVehicle = false` toujours (sets multi-types, pas transportables entiers).

### Nouveaux tokens i18n

| Clé | EN | FR | ES | KO |
| --- | --- | --- | --- | --- |
| `"Vehicle ready for loading"` | `"A %1 is ready for loading."` | `"Un %1 est prêt à être chargé."` | `"Un %1 está listo para cargar."` | `"%1이(가) 적재 준비되었습니다."` |

---

## Recette

| Cas | Description | Attendu |
| --- | --- | --- |
| F-Q-1 | `findLoadableVehicles` — UH-1H (pas canTransportWholeVehicle) | retourne `{}` |
| F-Q-2 | `findLoadableVehicles` — C-130 BLUE + HMMWV BLUE WAITING à portée | HMMWV retourné |
| F-Q-3 | `findLoadableVehicles` — C-130 BLUE + BRDM-2 RED WAITING à portée | exclu (coalition) |
| F-Q-4 | `findLoadableVehicles` — C-130 BLUE + type inconnu dans loadableVehiclesBLUE | exclu (type) |
| F-Q-5 | `spawnFn` avec `spawnAsVehicle=true` | `spawnVehicleForTransport` appelé, pas `spawnCrate` |
| F-Q-6 | `spawnFn` avec `spawnAsVehicle=false` (UH-1H) | `spawnCrate` appelé, pas `spawnVehicleForTransport` |

---

## Relation avec INIT-D (Feature K / Sprint 2b)

`_checkNativeLoading` (Sprint 2b) gère la détection DCS-native pour véhicules entiers (C-130/Il-76 bbox). Sprint 2b reste différé (module C-130J-30/CH-47Fbl1 requis). Feature Q couvre uniquement le flow **menu_ctld**.
