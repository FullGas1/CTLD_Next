# SESSION CTLD — JTAC Lifecycle Analysis
## Date: 2026-05-01 | Pause à 01:20

---

## OÙ ON EN EST

**Problème initial**: Diagnostic diag_crate_load.lua montrait 2 crates "no crates within 50m" dans le menu Load Crate alors que getCratesInRange les trouvait. Cause: race condition de refresh menu après spawnCrate → fix appliqué (timer.scheduleFunction deferred +0.001s).

**Pivot**: Le diagnostic a déclenché une analyse en profondeur de la gestion des états JTAC, qui a révélé des bugs et incomplétudes non détectés jusqu'alors.

---

## RÉSULTAT ANALYSE — JTAC Lifecycle (fichier: docs/specs/JTAC_lifecycle_analysis.md)

### 3 types de JTAC

| Type | Annihilable (pack) | Loadable | Spawn entier (menu) | Spawn via crate |
|------|------------------|----------|---------------------|-----------------|
| **Troop** (infanterie) | Non | Oui | Non | Oui (via loadFromZone → deploy) |
| **Vehicle** (Hummer/SKP-11) | Oui → deregisterJTAC | Oui | Oui (Request JTAC Equipment) | Oui (unpack crate isJTAC=true) |
| **Drone** (MQ-9/RQ-1A) | Non (aircraft) | Non | PROBLÉMATIQUE (category mismatch) | Oui (unpack crate spawnAs=AIRPLANE) |

### Bugs critiques identifiés

**B1 — JTAC Troop: au BOARD** — loadFromZone ne spawn PAS de DCS group. Le JTAC n'est pas encore actif au moment du chargement. Risque potentiel au DEPLOY si startLase() appelé trop tôt (avant que le groupe DCS ne soit prêt).

**B2 — JTAC Troop: après EXTRACT** — nearest.group:destroy() génère-t-il S_EVENT_DEAD? Dépend de la réponse: si oui → killJTAC() appelé proprement; si non → orphan dans jtacs[]. VÉRIFIER: le handler S_EVENT_DEAD dans CTLDDCSEventBridge route-t-il les group:destroy() vers killJTAC?

**B3 — JTAC Troop DEPLOY: startLase appelé sur groupe pas encore alive** — spawnObject() appelé puis startLase() synchronement. Y a-t-il un délai? Y a-t-il un timer.scheduleFunction pour retarder?

**B4 — Détection hasJtac incohérente pour les troupes**:
- extract() ligne 689: `hasJtac = nearest.groupName:lower():find("jtac") ~= nil` (par le nom)
- deploy() ligne 566: `if group.hasJtac then` (par le flag du template loadableGroups)
- Si un groupe JTAC spawné n'a pas "jtac" dans son nom, extract() ne le détectera pas comme JTAC

**B5 — drones dans JTAC_unitTypeNames (CONFIRMÉ)**:
- JTAC_unitTypeNames[BLUE] = {"Hummer", "MQ-9 Reaper"}
- JTAC_unitTypeNames[RED] = {"SKP-11", "RQ-1A Predator"}
- spawnVehicleForTransport("MQ-9 Reaper") crée un groupe GROUND avec type AIRPLANE → CATEGORY MISMATCH
- Les drones ne sont pas cargaables dans les transports CTLD
- Le menu Request JTAC Equipment est trompeur pour les drones
- ACTION: Retirer les drones de JTAC_unitTypeNames

**B6 — Drone unpack ne démarre pas le JTAC (CONFIRMÉ)**:
- _spawnUnpacked pour spawnAs=AIRPLANE → isAir=true
- _dispatchPostSpawn() ne traite QUE les ground vehicles (desc.isJTAC)
- Pour les drones: la fonction ne fait rien
- Le drone est spawned mais le JTAC n'est pas démarré automatiquement
- L'activation JTAC pour drone doit passer par deployAirJTAC() ou par le menu

**B7 — Parachute Vehicle: état DELIVERED — que se passe-t-il après?**
- parachuteVehicle() → setState(DELIVERED) → _parachuteEffect:onStart()
- _parachuteEffect:onLanded() est un no-op (CTLDNullParachuteEffect)
- Où le véhicule est-il réellement respawné après la chute?
- Y a-t-il un subscriber manquant à OnVehicleParachuting?
- Pour un vehicle JTAC en parachute: que se passe-t-il pour le JTAC?

**B8 — Parachute vehicle: onLanded handler缺失**:
- onLanded() est un no-op dans CTLDNullParachuteEffect
- Le véhicule delivered (state=DELIVERED) n'est jamais respawné au sol automatiquement
- Le cycle parachute→respawn n'est pas bouclé

---

## CLEANUP IDENTIFIÉ

### Action à intégrer dans MODERNIZATION-PLAN.md

**FG Cleanup — Supprimer drones de JTAC_unitTypeNames + nettoyer le menu Request JTAC Equipment**

Fait: Les JTAC_unitTypeNames contiennent des aircraft (MQ-9 Reaper, RQ-1A Predator) qui ne sont pas cargaables. Le menu Request JTAC Equipment les expose alors qu'ils ne devraient pas être là.

Raison technique:
- JTAC_unitTypeNames est utilisé par refreshJtacEquipmentSection() pour peupler le menu
- Ce menu appelle spawnJTACVehicleForTransport() qui fait spawnVehicleForTransport() (GROUND category)
- spawnVehicleForTransport avec typeName="MQ-9 Reaper" crée un groupe GROUND avec un DCS type d'aircraft → comportement indéterminé ou erreur DCS
- Les vrais drones JTAC sont disponibles via le système de crate standard (spawnAs=AIRPLANE, isJTAC=true dans spawnableCrates Drone section) et via deployAirJTAC()

Actions nécessaires:
1. Retirer "MQ-9 Reaper" et "RQ-1A Predator" de JTAC_unitTypeNames dans CTLD_config.lua
2. Laisser uniquement les véhicules terrestres: Hummer (BLUE) et SKP-11 (RED)
3. Vérifier que refreshJtacEquipmentSection() ne sert qu'à ce menu (pas d'autre usage)
4. NOTE: Les drones JTAC restent disponibles via le système de crate (spawnAs=AIRPLANE) — pas de perte de fonctionnalité

---

## PROCHAINES ACTIONS (pour quand la session reprend)

### Immédiat (validation avant mise à jour plan)

1. Lire et valider le fichier docs/specs/JTAC_lifecycle_analysis.md
2. Valider les bugs B1-B8 — en particulier B2 (S_EVENT_DEAD sur group:destroy())
3. Décider: les drones doivent-ils rester dans JTAC_unitTypeNames OU être retirés?
4. Décider: que fait-on du drone JTAC unpack (B6)? Laisser en l'état ou implémenter un path?

### Moyen terme (implémentation après validation)

1. **Mettre à jour MODERNIZATION-PLAN.md** avec:
   - Priorité 1: FG JTAC State Reliability (B1-B8, avec scénarios de recette)
   - Sous-priorité: FG Cleanup JTAC menu (retirer drones de JTAC_unitTypeNames)
   - Ajout dans section "Features à implémenter"

2. **Implémenter les corrections** (après validation utilisateur):
   - Cleanup B5: Retirer drones de JTAC_unitTypeNames
   - Investiguer et corriger B1, B2, B3, B4 pour les troupes JTAC
   - Investiguer et corriger B6 pour le drone unpack
   - Investiguer et corriger B7, B8 pour parachute vehicle

3. **Écrire les scénarios de recette** (après implémentation):
   - JTAC-T1 à T5 pour les troupes
   - JTAC-V1 à V8 pour les véhicules
   - JTAC-D1 à D6 pour les drones

---

## FICHIERS CRÉÉS/CE MODIFIÉS DURANT CETTE SESSION

| Fichier | Action |
|---------|--------|
| recette/scenarios/diag_crate_load.lua | Créé (diagnostic original) |
| recette/scenarios/diag_load_menu.lua | Créé (diagnostic menu) |
| recette/scenarios/diag_force_rebuild.lua | Créé (test rebuild menu) |
| docs/specs/JTAC_lifecycle_analysis.md | Créé (analyse complète) |
| src/CTLD_crate.lua | Modifié (fix race condition refresh menu, lignes 1185-1188) |

---

## NOTES TECHNIQUES IMPORTANTES

### Diagnostic Load Crate (bug race condition)
- Cause: OnCrateSpawned publish → _refreshNearbyPlayers (sync) → clearBranch → menu:refresh() appelé avant que le menu DCS ne soit prêt
- Fix: timer.scheduleFunction deferred de +0.001s (1 frame DCS)
- Test: OK — le menu se rebuild correctement après le fix

### Configuration JTAC_unitTypeNames (lignes 370-373 CTLD_config.lua)
```lua
self.settings["JTAC_unitTypeNames"] = {
    [1] = { "SKP-11", "RQ-1A Predator" },  -- RED
    [2] = { "Hummer", "MQ-9 Reaper" },     -- BLUE
}
```
- SKP-11 et Hummer: véhicules terrestres, correct
- RQ-1A Predator et MQ-9 Reaper: aircraft, NE DOIVENT PAS être là

### Configuration spawnAs dans spawnableCrates (Drone section)
```lua
{ weight = 1006.01, desc = "MQ-9 Reaper - JTAC", unit = "MQ-9 Reaper",
  isJTAC = true, spawnAs = "AIRPLANE", specificParams = {...} }
```
- Les drones sont définis comme AIRPLANE spawnAs dans la section Drone de spawnableCrates
- C'est le chemin CORRECT pour les drones JTAC (pas via Request Equipment)
- deployAirJTAC() est le path officiel pour les activer

### JTAC States (src/CTLD_jtac.lua lignes 37-52)
```lua
CTLDJTAC.STATE = {
    IDLE       = "idle",
    LASING     = "lasing",
    ORBITING   = "orbiting",
    IN_TRANSIT = "in_transit",
    DEAD       = "dead",
}
```

### Méthodes de gestion JTAC Manager
- startLase(groupName) → crée entry dans jtacs[], state=IDLE/LASING, laser alloué
- setJTACInTransit(groupName) → state=IN_TRANSIT, jtacs[]=nil, laser FREED
- resumeJTAC(groupName) → state=IDLE, jtacs[] recréé, laser ré-alloué
- deregisterJTAC(groupName) → state=DEAD, jtacs[]=nil, laser FREED, silencieux
- killJTAC(groupName, killer) → state=DEAD, jtacs[]=nil, laser FREED, OnJTACDead publié

---

## POUR REPRENDRE DEMAIN

1. Lire docs/specs/JTAC_lifecycle_analysis.md pour review complet
2. Valider ou infirmer chaque bug B1-B8
3. Décider de la action sur les drones dans JTAC_unitTypeNames (B5)
4. Dire "reprends" pour continuer