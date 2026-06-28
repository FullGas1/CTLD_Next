# EventDispatcher — État des Spécifications

**Date** : 2026-03-27
**Phase** : Pré-implémentation (validation specs globales requise)

---

## ✅ Spécifications Existantes

### 1. Architecture EventDispatcher (TERMINÉE)

**Source** : [CTLD_Events.md](CTLD_Events.md)

**Couverture** :
- ✅ Classe `EventDispatcher` complète
  - `subscribe(eventName, callback)` — O(1)
  - `unsubscribe(eventName, callback)` — parcours inversé pour cleanup
  - `unsubscribeAll(eventName)` — reset complet
  - `publish(eventName, data)` — O(n) où n = subscribers
  - Gestion cycle de vie (closure capture, cleanup via `_onBirthRef`)

- ✅ Classe `DCSEventHandler` (adaptateur)
  - `new(dispatcher)` — injection dépendance
  - `onEvent(event)` — bridge DCS → EventDispatcher
  - Enregistrement via `world.addEventHandler(dcsBridge)`

- ✅ Exemple concret `RadarSystem`
  - Pattern complet : subscribe, traitement, unsubscribe
  - Gestion mémoire (évite fuites via destroy())

**Specs Techniques** :
- ✅ Découplage total (agnostique source events)
- ✅ Complexité algorithmique documentée
- ✅ Contraintes intégrité (unicité subscribers, persistance)
- ✅ Gestion erreurs (checks `type(callback) == "function"`)
- ✅ Pattern Observer pur

**Statut** : 🟢 **Prêt pour implémentation dans src/**

---

### 2. Menu F10 Architecture (TERMINÉE)

**Source** : [F10_menu_tree.md](F10_menu_tree.md)

**Couverture** :
- ✅ Arbre complet actuel (Blocs 1-4)
- ✅ Conditions affichage par entrée
- ✅ Pagination (seuils 9/10 par page)
- ✅ **Matrice responsabilités classes POO** :
  - `CTLDTroop` → "Troop Transport"
  - `CTLDVehicle` → "Vehicle / FOB Transport" + "Pack Vehicles"
  - `CTLDCrate` → "Crates" + "CTLD Commands"
  - `CTLDBeacon`, `CTLDJtac`, `CTLDRecon` → blocs respectifs
  - `CTLDPlayer` → orchestration + "Check Cargo"

**Statut** : 🟢 **Utilisable pour migration progressive menus**

---

### 3. Détection Load/Unload Bounding Box (TERMINÉE)

**Source** : [load_event_analysis.md](load_event_analysis.md)

**Couverture** :
- ✅ Algorithme `isInsideBox(carrier, cargo)` analysé
- ✅ API DCS certifiée (Hoggit Wiki)
- ✅ Polling loop 1s avec registry `loadedObjects`
- ✅ Recommandations optimisation pour CTLDCrateTracker (EVO-14)

**Statut** : 🟢 **Prêt pour intégration CTLDCrateTracker**

---

### 4. Évolutions Crates Business (PARTIELLE)

**Source** : [Aide_memoire_CTLD.md](Aide_memoire_CTLD.md)

**Couverture** :
- ✅ AutoUnpack (gérer spawn auto après parachutage)
- ✅ Détection load/unload DCS natif (proximité, vitesse, altitude)
- ✅ Détection parachutage spécifique (event Birth parachute, tracking descente)
- ✅ **Events CTLD internes souhaités** :
  - OnCrateSpawned
  - OnCrateLoaded (CTLD + DCS natif)
  - OnCrateUnloaded (CTLD + DCS natif)
  - OnCratePacked (manuel/auto)
  - OnCrateUnpacked (manuel/auto)
- ✅ Scènes avec predicates Lua conditionnels

**Statut** : 🟡 **Design conceptuel OK, specs détaillées à compléter**

---

## ❌ Spécifications Manquantes

### 1. Inventaire Events DCS Utilisés (CRITIQUE)

**État actuel core.lua** :
```lua
-- Ligne 4756: world.addEventHandler(ctld.eventHandler)
-- Ligne 4762: function ctld.eventHandler:onEvent(event)

Events écoutés (SEULEMENT 2 actuellement):
✅ S_EVENT_PLAYER_ENTER_UNIT  → Setup menus F10 pour joueur
✅ S_EVENT_BIRTH              → Idem (fallback?)
⚠️  S_EVENT_EJECTION (ligne 4504) → Commenté, usage inconnu
```

**Manque** :
- [ ] **Cartographie exhaustive events DCS** dans core.lua (grep + analyse)
- [ ] Events pour gestion crates (DEAD, LAND, CRASH?)
- [ ] Events pour troops (LAND pour extract?)
- [ ] Events pour FOB/véhicules
- [ ] Callbacks déclenchés par chaque event (flow chart)

**Impact** : 🔴 **BLOQUANT** pour migration — risque oublier events critiques

---

### 2. Mapping DCS Events → CTLD Events (CRITIQUE)

**Manque** :
- [ ] Règles transformation DCS → CTLD
  ```
  Exemple:
  S_EVENT_BIRTH → OnCrateSpawned (si crate CTLD)
  S_EVENT_LAND  → Trigger updatePackMenu (si transport)
  Polling custom → OnCrateLoaded (si bounding box match)
  ```
- [ ] Filtres par type unité (crate vs vehicle vs troop)
- [ ] Gestion coalition (red vs blue)
- [ ] Events "synthétiques" (polling → pseudo-event)

**Impact** : 🔴 **BLOQUANT** pour DCSEventHandler — ne sait pas quoi publier

---

### 3. Catalogue Complet Events CTLD Internes (HAUTE PRIORITÉ)

**État actuel** : Liste partielle dans Aide_memoire (6 events crates)

**Manque** :
- [ ] **Events Crates** (payload détaillé)
  - OnCrateSpawned `{crate, spawner, position}`
  - OnCrateLoaded `{crate, transport, method}` — method: "ctld_menu" | "dcs_native" | "slingload"
  - OnCrateUnloaded `{crate, transport, method}` — idem + "parachute"
  - OnCrateUnpacked `{crate, spawnedGroup, player, manual: bool}`
  - OnCrateAutoUnpacked `{descriptor, crates[], method, radius}`
  - OnCrateDestroyed `{crate, reason}` — reason: "unpacked" | "destroyed" | "timeout"

- [ ] **Events Troops**
  - OnTroopsBoarded `{troops, transport, player}`
  - OnTroopsExtracted `{troops, position, player}`
  - OnTroopsDead `{troops, killer}`

- [ ] **Events Vehicles**
  - OnVehiclePacked `{vehicle, crates[], player}`
  - OnVehicleSpawned `{vehicle, crates[], player}`

- [ ] **Events FOB**
  - OnFOBDeployed `{fob, crates[], position, scene}`
  - OnFOBDestroyed `{fob, killer}`

- [ ] **Events Beacons**
  - OnBeaconDropped `{beacon, position, frequency}`
  - OnBeaconRemoved `{beacon}`

- [ ] **Events JTAC/Recon**
  - OnJTACTargetSet `{jtac, target}`
  - OnReconScan `{player, targets[]}`

**Impact** : 🟠 **HAUTE PRIORITÉ** — définit l'API complète du système

---

### 4. Plan Migration Modules (MOYENNE PRIORITÉ)

**Manque** :
- [ ] Matrice dépendances (modules × events)
  ```
  Exemple:
  | Module          | Events écoutés                     | Events publiés         |
  |-----------------|-----------------------------------|------------------------|
  | CrateManager    | OnCrateLoaded, OnCrateUnloaded    | OnCrateSpawned, ...    |
  | TroopManager    | OnTroopsBoarded                   | OnTroopsExtracted      |
  | VehicleManager  | OnVehiclePacked                   | OnVehicleSpawned       |
  ```

- [ ] Ordre migration optimal (start simple → end complex)
  1. BeaconManager (simple, peu de deps)
  2. ReconManager (simple)
  3. CrateManager (core business, many deps)
  4. TroopManager
  5. VehicleManager + FOBManager
  6. JTACManager
  7. Core orchestration (last)

- [ ] Stratégie cohabitation legacy ↔ POO
  - Bridge EventDispatcher → code legacy durant transition?
  - Migration "big bang" vs progressive?

**Impact** : 🟡 **MOYENNE** — améliore planning mais pas bloquant pour démarrer

---

### 5. Tests & Validation (BASSE PRIORITÉ)

**Manque** :
- [ ] Tests unitaires EventDispatcher
- [ ] Tests intégration DCSEventHandler
- [ ] Mission test régression (avant/après migration)
- [ ] Benchmarks performance (overhead publish)

**Impact** : 🟢 **BASSE** — utile mais pas bloquant pour specs

---

## 📋 Plan d'Action Proposé

### Phase Immédiate (AVANT implémentation)

**1. Inventaire Events DCS** (Session 1)
```bash
# Extraction automatique
grep -n "S_EVENT_" source/CTLD_core.lua > Specs/dcs_events_inventory.txt
grep -n "event.id ==" source/CTLD_core.lua >> Specs/dcs_events_inventory.txt
grep -n "world.event" source/CTLD_core.lua >> Specs/dcs_events_inventory.txt

# Analyse manuelle → doc
# Livrable: Specs/CTLD_dcs_events_analysis.md
```

**Actions** :
- Lister tous events DCS écoutés (actuels + commentés)
- Pour chaque event : callback(s) déclenché(s), module impactés
- Identifier events manquants critiques (LAND, DEAD, CRASH?)

---

**2. Catalogue Events CTLD Internes** (Session 2)
```
# Design document
# Livrable: Specs/CTLD_events_catalog.md
```

**Actions** :
- Consolider events Aide_memoire + nouveaux identifiés
- Spécifier payload chaque event (structure data)
- Définir subscribers potentiels par event
- Valider avec use cases concrets (scénarios mission)

---

**3. Mapping DCS → CTLD** (Session 3)
```
# Translation rules
# Livrable: Specs/CTLD_events_mapping.md
```

**Actions** :
- Matrice DCS Events → CTLD Events
- Règles filtrage (coalition, type unité)
- Events synthétiques (polling → pseudo-event)
- Gestion edge cases (event DCS manquant)

---

**4. Validation Consolidée** (Session 4)
```
# Review & approval
# Livrable: documentation/EventDispatcher_CDC.md (consolidé)
```

**Actions** :
- Intégrer tous docs précédents
- Ajouter diagrammes (Mermaid flowcharts)
- Points validation checklist
- **GO/NO-GO implémentation**

---

### Phase Implémentation (APRÈS validation)

**5. Implémentation EventDispatcher** (src/)
- Copier spec CTLD_Events.md → code
- Tests unitaires
- Intégration DCSEventHandler

**6. Migration Progressive Modules**
- Selon ordre défini Phase 4
- Un module à la fois avec tests

---

## ❓ Questions pour Validation Utilisateur

Avant de démarrer Phase 1 (inventaire), clarifier :

1. **Scope prioritaire** :
   - Commencer par events Crates uniquement (EVO-14/15/16)?
   - Ou faire inventaire complet tous modules d'un coup?

2. **Profondeur analyse core.lua** :
   - Analyse statique (grep + lecture) suffit?
   - Ou debug runtime dans mission test pour capturer tous events?

3. **Format livrables** :
   - Préfères-tu docs Markdown détaillés?
   - Ou diagrammes visuels (Mermaid, PlantUML)?

4. **Validation itérative** :
   - Valider fin de chaque phase (4 sessions)?
   - Ou valider bloc complet avant implémentation?

---

## 🎯 Recommandation

**Démarche optimale** :
1. ✅ **Session 1** : Inventaire events DCS (grep + analyse manuelle core.lua)
2. ✅ **Session 2** : Catalogue events CTLD internes (focus Crates d'abord)
3. ✅ **Session 3** : Mapping DCS → CTLD + règles transformation
4. ✅ **Session 4** : Consolidation CDC + validation GO/NO-GO

**Estimation** : 4 sessions × 1-2h = validation specs complète avant première ligne de code

---

**Tu veux qu'on démarre Session 1 (inventaire events DCS core.lua)?**
