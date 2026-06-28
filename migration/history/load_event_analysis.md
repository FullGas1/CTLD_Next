# Analyse du Script load_event.lua

## Source
Fichier: [source/load_event.lua](../source/load_event.lua)

## Objectif
Détection du chargement d'objets DCS (crates, véhicules) dans un transporteur via bounding box collision.

## Architecture

### 1. Tracker Object
```lua
local tracker = {
    loadedObjects = {}  -- Registry: cargoID → carrierID
}
```

**État persistant** : Associe chaque cargo chargé à son porteur actuel.

---

### 2. Détection Bounding Box (API Certifiée)

#### Function: `isInsideBox(carrier, cargo)`

**Algorithme** :
1. Récupère position et descripteur du porteur (`carrier:getPosition()`, `carrier:getDesc()`)
2. Récupère position du cargo (`cargo:getPosition()`)
3. Calcul coordonnées relatives cargo → porteur
4. Transformation dans référentiel local porteur (produit scalaire avec axes x, y, z)
5. Test inclusion dans bounding box (via `cDesc.box.min/max`)

**API DCS Utilisée** :
- `Unit:getPosition()` → table `{p, x, y, z}` (position + orientation)
- `Unit:getDesc()` → table descripteur incluant `.box` (bounding box)
- `.box.min` / `.box.max` → limites 3D du volume de collision

**Limites** :
- Dépend de la qualité des bounding boxes DCS (certaines unités ont des box approximatives)
- Pas de détection native API → polling requis

---

### 3. Inventaire Exhaustif des Objets

#### Function: `getAllLiveObjects()`

**Méthode** : Scan exhaustif des 3 coalitions (Neutral=0, Red=1, Blue=2)

**API DCS Utilisée** :
```lua
coalition.getGroups(coalitionID)    -- Liste tous les groupes d'une coalition
Group:getUnits()                    -- Unités d'un groupe
coalition.getStaticObjects(coalID)  -- Objets statiques (crates, etc.)
Unit:isExist()                      -- Vérifie existence
Unit:getLife()                      -- État de vie (> 0 = vivant)
```

**Retour** : Table de tous les objets vivants (Units + Statics)

---

### 4. Tracking Loop

#### Function: `tracker.update()`

**Fréquence** : Polling toutes les 1.0 secondes (via `timer.scheduleFunction`)

**Logique** :
1. Récupère tous objets vivants (`getAllLiveObjects()`)
2. **Double boucle** carrier × cargo (O(n²) mais nécessaire)
3. Pour chaque paire :
   - Test `isInsideBox(carrier, cargo)`
   - **Détection LOAD** : Si dedans ET pas encore tracké
     - Enregistre `loadedObjects[cargoID] = carrierID`
     - Affiche message "EVENT_LOAD_OBJECT"
   - **Détection UNLOAD** : Si dehors ET était tracké pour ce carrier
     - Retire de `loadedObjects[cargoID]`

**Output** : Messages via `trigger.action.outText()`

---

## Utilité pour CTLD_FG

### Intégration dans CTLDCrateTracker (EVO-14)

**Cas d'usage** :
- **Load/Unload DCS natif** : Appareils `dynamicCargoCapable` (C-130, CH-47, Mi-8)
- **Slingload** : Détection crate attachée en external cargo

**Améliorations Requises** :
1. **Filtrage intelligent** : Ne tracker QUE les crates CTLD (pas tous les objets)
2. **Optimisation O(n²)** : Utiliser distance préalable (50m radius) avant bounding box
3. **États crate** : Intégrer avec états `spawned → inTransit → falling → landed`
4. **Events internes** : Publier `OnCrateLoaded` / `OnCrateUnloaded` via EventDispatcher

**Algorithme Optimisé** :
```lua
function CTLDCrateTracker:_pollCrates()
    local carriers = self:_getTransportUnits()  -- Filtrer appareils capables
    local crates = self:_getTrackedCrates()     -- Seulement crates CTLD

    for _, carrier in ipairs(carriers) do
        local carrierPos = carrier:getPoint()
        for _, crate in ipairs(crates) do
            local cratePos = crate:getPoint()
            local distance = ctld.utils.getDistance(carrierPos, cratePos)

            if distance < 50 then  -- Pré-filtre distance
                local inside = self:_isInsideBox(carrier, crate)
                -- Détection state transition...
            end
        end
    end
end
```

**Fréquence Adaptée** :
- 0.5s pour crates `inTransit` (détection unload rapide)
- 2.0s pour crates `spawned` (load moins critique)

---

## API DCS Critique (Vérifiée Hoggit Wiki)

✅ **Certifié** :
- `coalition.getGroups(coalitionID)`
- `coalition.getStaticObjects(coalitionID)`
- `Unit:getPosition()` → `{p, x, y, z}`
- `Unit:getDesc()` → `.box.min/max`
- `Unit:isExist()`, `Unit:getLife()`, `Unit:getName()`, `Unit:getID()`
- `timer.scheduleFunction(func, arg, time)`
- `trigger.action.outText(text, duration)`

⚠️ **Non utilisé** :
- Pas d'event DCS natif pour load/unload cargo dynamique
- Pas d'API `cargo.isLoaded()` ou similaire
- → Polling obligatoire

---

## Conclusion

**Strengths** :
- Détection fonctionnelle via bounding box (seule méthode API disponible)
- État persistant avec registry `loadedObjects`
- Certifié API DCS (pas de fonction inventée)

**Weaknesses** :
- Complexité O(n²) → optimisable avec distance pre-filter
- Polling 1s → ajustable selon état crate
- Tous objets scannés → filtrer seulement crates CTLD

**Recommandation** :
- **Réutiliser** : Fonctions `isInsideBox()` et `getAllLiveObjects()`
- **Adapter** : Filtrage crates CTLD + optimisation distance
- **Intégrer** : CTLDCrateTracker avec EventDispatcher

---

**Date d'analyse** : 2026-03-27
**Phase projet** : Préparation EVO-14 (Détection multi-méthodes load/unload)
