# CTLD_FG — Plan de recette C1 + M1–M10 + R1–R5 + FA–FD + scenes fob/farp

## Modules couverts

| Module | Fichier source | Classes |
|--------|---------------|---------|
| C1 | `src/CTLD_core.lua` | EventDispatcher, CTLDDCSEventBridge, CTLDPlayerTracker, CTLDCoreManager |
| M1 | `src/CTLD_zone.lua` | CTLDTroopZone, CTLDLogisticZone, CTLDZoneManager |
| M2 | `src/CTLD_beacon.lua` | CTLDBeacon, CTLDBeaconManager |
| M3 | `src/CTLD_recon.lua` | CTLDReconRenderer, CTLDReconManager |
| M4 | `src/CTLD_fob.lua` | CTLDFOB, CTLDFOBManager |
| M5 | `src/CTLD_vehicle.lua` | CTLDVehicle, CTLDVehicleSpawner |
| M6 | `src/CTLD_aasystem.lua` | CTLDCrateAssemblyManager |
| M7 | `src/CTLD_player.lua` | CTLDPlayer, CTLDPlayerManager |
| R4 | `src/CTLD_sceneManager.lua` | CtldScene, CTLDSceneManager + fobScene (auto-enregistrement) |
| R5 | `src/CTLD_player.lua` + tous managers | buildMenu() Option D — registerMenuSection + config-variant |
| FB | `src/CTLD_crate.lua` | CTLDCrateManager — virtual slingload (hover pickup + release/cut) |
| M8 | `src/CTLD_menu.lua` | ctld.Menu, ctld.MenuManager |
| M9 | `src/CTLD_utils.lua` | ctld.utils.* (math, vecteurs, géométrie, données) |
| M10 | `src/scenes/CTLD_mineFieldScene.lua` | mineFieldScene (setLandMine, auto-registration) |

## Environnement d'exécution

- Scripts injectés via **Witchcraft** dans DCS en cours de mission.
- Commande : `node "$USERPROFILE/.vscode-dcs-tools/bridge.js" "<chemin_absolu>/recette/<cas>/test.lua"`
- Log dual : `env.info()` → DCS.log  +  `io.open()` → `recette/CTLD.log`
- Chaque script de cas purge `CTLD.log` en début d'exécution.
- **Purge des objets DCS** entre tests visuels : `node bridge.js recette/purge_scene.lua` — détruit tous les statics/groupes spawnés par les scènes (prefixes SINGLE_HELIPAD, FOB_Outpost, CTLDBeacon, etc.).

## Mission martyr — prérequis

Mission DCS : **`Test_CTLDNEXT_01.miz`**

La mission de test doit contenir :
- Au moins un appareil joueur BLUE (slot occupé ou coalition)
- Zones DCS nommées : `TRZ_alpha_B_10_nil_0`, `TRZ_beta_R_999_obj1_5`, `LGZ_base_B`
- Un static objet de type cargo (pour F-01)
- Un groupe nommé `jtac_test` ou contenant "jtac" (pour F-02, F-09 à F-11)

---

## Techniques particulières

### Clone IA — scénarios pilotPassive répétables sans redémarrage DCS

**Problème** : `grp:activate()` consomme définitivement l'unité late-activation de la mission. Après la première exécution, l'unité est activée → le scénario ne peut plus être rejoué sans redémarrer DCS.

**Solution** : spawner un clone temporaire depuis `env.mission` + `coalition.addGroup`, nommé différemment, détruit en cleanup. La source (late-activation dans le `.miz`) reste intacte.

**Règles critiques** :

- `clone.lateActivation = false` — OBLIGATOIRE, sinon le clone naît inactif (invisible en mission)
- `coalition.addGroup` retourne une `table` (pas userdata) → toujours récupérer via `Group.getByName(cloneName)` après le spawn
- `ctld.utils.deepCopy` retourne `nil` → utiliser une deepCopy locale récursive (voir MT-10 v4.0)
- `getInitialRoute()` n'existe pas dans l'API DCS → la route est dans `env.mission` (template)
- Cleanup obligatoire : `destroyClone(cloneName)` + destruction des troupes déposées via `_droppedGroups[2]`

**Pattern de nommage** :

- Source `.miz` (jamais touchée) : `heliai_mtXX`
- Clone temporaire : `mtXXa_run` / `mtXXb_run` (nom correspondant à `transportPilotNames`)

**Contamination CTLD.log multi-runs** : les lignes FAIL des runs précédents contiennent les keywords (ex. `[FAIL] MT-10.4.2: CTLD.log contient 'AttackNearestEnemyOnLos'`). Solution : logger un marker unique (`MT10_CYCLE_A_START`) au début de chaque cycle et utiliser `scanLogAfter(marker, keyword)` qui ne lit qu'après ce marker.

**Référence** : `tests/dcs/pilotPassive/scenario_mt10_ai_postspawn_task.lua` v4.0 [2026-07-01] — implémentation complète avec `spawnClone()`, `findGrpInMission()`, `deepCopy` locale, `scanLogAfter()`, cleanup clones + troupes.

---

## Scénarios interactifs (recette/scenarios/)

Scripts multi-injections exécutés via Witchcraft en mission réelle. Chaque scénario gère son propre état via une variable Lua globale persistante entre injections.

| Script | Module(s) | Cas couverts | Statut | Mode |
|--------|-----------|--------------|--------|------|
| `scenarios/scenario_recon_layers.lua` | M3 — CTLDReconManager, CTLDReconRenderer | F-116 (6 layers × détection LOS), F-117 reconEnabled, F-118 toggle-OFF, F-119 AA icon | ✅ PASS [2026-04-29] | Interactif — 1 injection par layer + sandbox + reset |

| `scenarios/scenarioTroopsFullCycle_v2.lua` | R2+R3 — CTLDTroopManager, CTLDTroopGroup, CTLDJTACManager | F-T1→F-T8 (8 steps : spawn RED targets + template → embark no lase → deploy 2 JTACs lasing → re-embark idle+freed → re-deploy 2nd cycle → 1 JTAC dead target freed → timer destruction successive reacquisition → cleanup) | ✅ PASS 8/8 [2026-05-05] — lifecycle complet troops+JTAC transitions validé (Feature J déconfliction + claim/release lifecycle + reacquisition successive après destroy) | Witchcraft — 9 injections (step 7 phase A+B) |

| `scenarios/interactive/scenario_farp_repack.lua` | TODO[I]+[Q] — CTLDSceneManager.packScene + CTLDCrate.metadata | F-MT16.1→F-MT16.8 (3 injections : deploy CS FARP → findNearbyRepackable + packScene + repackData → metadata.warehouseSnapshot + scene._params.repackData transmis) | ✅ PASS 12/12 [2026-06-28] — mod absent (warehouseSnapshot nil) comportement attendu ✅ | Witchcraft — 3 injections |

| `scenarios/interactive/scenario_warehouse_cycle.lua` | TODO[I]+[Q] — Cycle complet deploy→pack→snapshot→redeploy→vérif warehouse | W.1→W.3 (3 injections : setup enableFARPRepack + cratesRequired=1 → crate présente + snapshot metadata → fuel restauré 5k/10k/15k/20k sur CS FARP-26) | ✅ PASS 3/3 [2026-06-28] — cycle complet live DCS avec CS FARP invisible warehouse validé | Witchcraft — 3 injections |

---

## Section U — Tests unitaires (U-01 à U-80)

| N° | Nom | Module | Objectif | Statut | Temps estimé |
|----|-----|--------|----------|--------|--------------|
| U-01 | EventDispatcher — singleton | C1 | Vérifier que deux appels getInstance() retournent la même instance | ✅ PASS 3/3 | 2 min |
| U-02 | EventDispatcher — subscribe + publish | C1 | Callback reçoit le bon payload après subscribe/publish | ✅ PASS 6/6 | 3 min |
| U-03 | EventDispatcher — unsubscribe | C1 | Callback non appelé après unsubscribe | ✅ PASS 6/6 | 3 min |
| U-04 | EventDispatcher — isolation erreur | C1 | Un callback qui throw n'empêche pas l'exécution des suivants | ✅ PASS 5/5 | 3 min |
| U-05 | CTLDDCSEventBridge — singleton + register + route | C1 | Singleton unique, register enregistre, onEvent dispatche vers le bon handler | ✅ PASS 9/9 | 4 min |
| U-06 | CTLDPlayerTracker — getPlayerByUnit / isPlayerUnit | C1 | Index byUnit : retrouver playerName depuis unitName | ✅ PASS 6/6 | 4 min |
| U-07 | CTLDPlayerTracker — getUnitByPlayer / getAllPlayers | C1 | Index byPlayer : retrouver unitName + coalition depuis playerName | ✅ PASS 11/11 | 4 min |
| U-08 | CTLDZoneManager._parseTRZ — formats valides | M1 | Parser TRZ strict 5 champs : pickup limité/illimité, extract-only, extract+cible, mixte, coalition A | ✅ PASS 40/40 | 5 min |
| U-09 | CTLDZoneManager._parseTRZ — formats invalides | M1 | Parser TRZ strict : mauvais préfixe, champs manquants, coalition invalide, stock hors plage, flag numérique, target négatif, zoneName réservé | ✅ PASS 39/39 | 3 min |
| U-10 | CTLDZoneManager._parseLGZ — formats valides et invalides | M1 | Parser LGZ : noms bien formés et malformés | ✅ PASS 14/14 | 3 min |
| U-11 | CTLDTroopZone.isInZone — circulaire | M1 | Point dedans / dehors sur zone circulaire | ✅ PASS 7/7 | 3 min |
| U-12 | CTLDTroopZone consumeStock / restoreStock | M1 | Stock limité + stock illimité (pickMaxStock==0) | ✅ PASS 15/15 | 4 min |
| U-13 | CTLDLogisticZone isInZone + getCenter | M1 | Zone statique : point dedans / dehors + center constant | ✅ PASS 12/12 | 3 min |
| U-14 | CTLDBeacon isBatteryAlive / batteryRemaining / freqText | M2 | Batterie infinie (-1), finie et expirée ; format texte fréquences | ✅ PASS 10/10 | 4 min |
| U-15 | CTLDBeaconManager _buildFreqPools | M2 | Pools VHF/UHF/FM générées ; NDB skippés dans VHF ; UHF < 399 MHz | ✅ PASS 9/9 | 4 min |
| U-16 | CTLDReconRenderer.createIcon — routing | M3 | Dispatch vers la bonne fonction de dessin selon layer.iconRenderer | ✅ PASS 14/14 | 4 min |
| U-17 | CTLDReconManager._matchLayer — layer assignment | M3 | Unité avec attribut Infantry → layer infantry retourné | ✅ PASS 9/9 | 4 min |
| U-18 | CTLDFOB isAlive / getIntegrityPercent | M4 | Seuils : 0 objet, 1/3 vivants, tous vivants | ✅ PASS 10/10 | 4 min |
| U-19 | CTLDVehicle états (WAITING → LOADED → DELIVERED) | M5 | Transitions d'état | ✅ PASS 15/15 | — |
| U-20 | CTLDVehicleSpawner singleton | M5 | getInstance() retourne la même instance | ✅ PASS 6/6 | — |
| U-21 | _worldToLocal + bbox inclusion | M5 | Algo géométrique pur (point dans boîte 3D) | ✅ PASS 8/8 | — |
| U-22 | getDesc().box sur C-130J-30 | M5 | API DCS : vérification existence desc.box | ✅ PASS 1/1 (skip: C-130 absent) | — |
| U-23 | CTLDCrateAssemblyManager singleton + getTemplateForUnit | M6 | Singleton unique, template trouvé pour parts/repair/nil | ✅ PASS 16/16 | — |
| U-24 | countComplete + getAllowedCount + guards | M6 | 0 sans systèmes, config limits, tryUnpackOrRepair guards | ✅ PASS 11/11 | — |
| U-25 | _buildSpawnArrays géométrie | M6 | Positions distinctes, counts corrects KUB et NASAMS | ✅ PASS 13/13 | — |
| U-26 | CTLDPlayer entity — construct + cargo helpers | M7 | Propriétés init correctes, add/removeLoadedVehicle/Crate | ✅ PASS 20/20 | — |
| U-27 | CTLDPlayerManager singleton + getPlayer nil | M7 | getInstance() idempotent, getPlayer inconnu == nil | ✅ PASS 5/5 | — |
| U-28 | _detectCapabilities — isTransport + canCarryVehicles | M7 | UH-1H/Hercules/F-16C_50 détectés correctement | ✅ PASS 6/6 | — |
| U-29 | onPlayerEnterUnit + onPlayerLeaveUnit état _players | M7 | Player créé puis supprimé, propriétés correctes | ✅ PASS 9/9 | — |
| U-30 | CTLDCrate états + helpers | R1 | SPAWNED→LOADED→LANDED→UNPACKED, isOnGround/isLoaded | ✅ PASS 22/22 | — |
| U-31 | canUnpack logique | R1 | canBeUnpacked, isOnGround guards (no movement constraint) | ✅ PASS 4/4 | forceCrateToBeMoved dropped — unpack anywhere |
| U-32 | CTLDCrateManager singleton + getCrateByName + getCratesInRange | R1 | Singleton, lookup, filtre distance | ✅ PASS 9/9 | — |
| U-33 | findDescriptorByTypeName | R1 | Match typeName dans spawnableCrates, nil si inconnu | ✅ PASS 9/9 | — |
| U-34 | checkAssemblyReady | R1 | cratesRequired=1 toujours ready, =2 avec/sans crate manquante | ✅ PASS 9/9 | — |
| U-35 | CTLDTroopGroup entity — init + états + transitions | R2 | LOADED→DEPLOYED→EXTRACTED, isInTransit, deploy(nil) EXZ | ✅ PASS 19/19 | — |
| U-36 | CTLDTroopManager singleton + _registerTemplates | R2 | getInstance() idempotent, templates → db entries, total/hasJtac | ✅ PASS 17/17 | — |
| U-37 | hasTroops / getInTransit / getWeight | R2 | Lookup direct, absent/présent, suppression | ✅ PASS 10/10 | — |
| U-38 | _transportLimit | R2 | Default numberOfTroops + byType override | ✅ PASS 8/8 | — |
| U-39 | CTLDJTAC entity — init + transitions d'états | R3 | IDLE→LASING→ORBITING→IN_TRANSIT→DEAD, updateLaseSpot | ✅ PASS 25/25 | — |
| U-40 | CTLDJTACDetector.calculateFMRadio | R3 | Formule FM, limites 1111-1688, edge cases | ✅ PASS 11/11 | — |
| U-41 | CTLDJTACDetector.calculateCorrectedSpot | R3 | Algo pur: anticipation vel + correction vent | ✅ PASS 9/9 | — |
| U-42 | CTLDJTACManager singleton + laser pool | R3 | getInstance idempotent, pool 578 codes, assign/free | ✅ PASS 12/12 | — |
| U-43 | CTLDSceneManager singleton + registerSceneModel | R4 | getInstance idempotent, register/guards/getModel, built-in FARP Alpha | ✅ PASS 9/9 | — |
| U-44 | CtldScene step execution engine — func-only, delay=0 | R4 | 3 steps en ordre, onComplete appelé, _params transmis | ✅ PASS 8/8 | — |
| U-54 | CTLDObjectRegistry get() + findByDCSType() | P1 | Lookup direct + reverse lookup par DCS typeName + nil guards | ✅ PASS 14/14 | — |
| U-55 | CTLDObjectRegistry spawnObject() STATIC | P1 | coalition.addStaticObject appelé, champs injectés, overrides, unknown key nil | ✅ PASS 16/16 | — |
| U-56 | CTLDObjectRegistry spawnObject() GROUND | P1 | 3 unités, coalition-aware unitType BLUE/RED, rotation heading 0° et 90° | ✅ PASS 13/13 | — |
| U-57 | ctld.MenuManager singleton | M8 | getInstance() idempotent — même instance retournée | ✅ PASS 3/3 | — |
| U-58 | createMenuForGroup | M8 | Succès, idempotence, guards (nil / string) | ✅ PASS 6/6 | — |
| U-59 | _sortByOrder | M8 | Tri ascendant par order, sans-order → fin | ✅ PASS 7/7 | — |
| U-60 | addSubMenu succès + idempotence + opts | M8 | Création nœud, idempotence, opts order/enabled | ✅ PASS 10/10 | — |
| U-61 | addSubMenu guards | M8 | name nil, parent=command node → failure | ✅ PASS 4/4 | — |
| U-62 | addCommand succès + guards | M8 | Succès, anyArgument nil→{}, guards fn/arg/name invalides | ✅ PASS 9/9 | — |
| U-63 | clearBranch | M8 | Vide children, container intact, guards | ✅ PASS 7/7 | — |
| U-64 | setBranchEnabled | M8 | Toggle true/false, guard path inconnu | ✅ PASS 6/6 | — |
| U-65 | removeMenuBranch | M8 | Suppression + removedCount, root guard, path inconnu | ✅ PASS 8/8 | — |
| U-66 | _rebuildPagedChildren pagination | M8 | ≤10 inline, 11→9+NextPage+2, 20→deux niveaux | ✅ PASS 6/6 | — |
| U-67 | ctld.utils math utilities | M9 | round, radianToDegree, normalizeHeadingInDegrees, kmphToMps | ✅ PASS 14/14 | — |
| U-68 | vec3Mag + get2DDist + getDistance | M9 | Triangle 3-4-5, Vec2 input, guards nil→0 | ✅ PASS 11/11 | — |
| U-69 | addVec3 + subVec3 + multVec3 | M9 | Opérations vectorielles, nil guards | ✅ PASS 13/13 | — |
| U-70 | makeVec3FromVec2OrVec3 + makeVec2FromVec3OrVec2 | M9 | Conversions Vec2↔Vec3, passthrough, nil→nil | ✅ PASS 14/14 | — |
| U-71 | rotateVec3 + polarToCartesian | M9 | Heading 0°/90° exacts ; polarToCartesian distance×2 | ✅ PASS 13/13 | — |
| U-72 | deepCopy + isValueInIpairTable + countTableEntries + getNextUniqId | M9 | Copie indépendante, lookup, count, compteur monotone | ✅ PASS 16/16 | — |
| U-73 | zoneToVec3 branche table | M9 | {point=}, {x,y,z} direct, nil→nil | ✅ PASS 8/8 | — |
| U-74 | mineFieldScene structure + auto-registration | M10 | Modèle 'mineField' enregistré dans CTLDSceneManager, stepsDatas, setLandMine | ✅ PASS 7/7 | — |
| U-75 | mineFieldScene.setLandMine guards | M10 | nil unit → false ; nbMinesColumns=0 + unit réel → false | ✅ PASS 5/5 | — |
| U-76 | createLoadableGroup — valid cases | FD | Minimal (1 champ), full (6 champs), side=nil ; total/hasJtac/_dbKey/ObjectRegistry | ✅ PASS 21/21 | — |
| U-77 | createLoadableGroup — guard cases | FD | nil config, no name, empty name, no composition, zero composition, duplicate std, duplicate custom | ✅ PASS 15/15 | — |
| U-78 | removeLoadableGroup | FD | Remove custom + clear ObjectRegistry, remove standard, not-found error | ✅ PASS 12/12 | — |
| U-79 | editLoadableGroup | FD | Edit composition + side, recompute total/hasJtac, refuse standard, not-found, zero composition | ✅ PASS 21/21 | — |
| U-80 | disableLoadableGroup / enableLoadableGroup | FD | Toggle disabled, template count unchanged, not-found error | ✅ PASS 15/15 | — |
| U-81 | CTLDTroopManager:_resolveTemplateForLegacy | Q1 | int exact/closest, table sum, disabled template skippé, no templates → nil | ✅ PASS 14/14 | — |
| U-82 | CTLDCrateManager:findDescriptorByUnitType | Q1 | match typeName, nil si inconnu, BLUE only invisible RED | ✅ PASS 25/25 | — |
| U-83 | CTLDVehicleSpawner:findPackableVehicles | Q1 | scan ground units coalition, filtre distance, exclude transport | ✅ PASS 23/23 | — |
| U-84 | CTLDConfig singleton pattern | Config | get() × 2 → même instance, isLoaded, mutation partagée | ✅ PASS 5/5 | — |
| U-85 | CTLDConfig load() idempotency | Config | 2nd load() retourne tôt, mutation préservée | ✅ PASS 4/4 | — |
| U-86 | CTLDConfig getSetting() defaults | Config | 10 valeurs par défaut clés vérifiées | ✅ PASS 10/10 | — |
| U-87 | ctld.gs() shortcut | Config | 3 clés connues + clé inconnue → nil | ✅ PASS 4/4 | — |
| U-88 | CTLDConfig.to_type() | Config | bool/int/float/string/quotes | ✅ PASS 8/8 | — |
| U-89 | CTLDConfig.parseYAML() | Config | k/v simple, types, dotted keys, multi-line, empty | ✅ PASS 9/9 | — |
| U-90 | CTLDi18n — audit() exists | i18n | ctld.i18n_audit + ctld.i18n_auditAll existent et sont appelables | ✅ PASS 4/4 | — |
| U-91 | CTLDi18n — audit() structure | i18n | audit("fr") → table avec version_match, en_version, lang_version, missing, untranslated | ✅ PASS 8/8 | — |
| U-92 | CTLDi18n — audit() lang inconnue | i18n | audit("zz") → nil + string d'erreur contenant le code langue | ✅ PASS 4/4 | — |
| U-93 | CTLDi18n — audit() détecte clé manquante | i18n | mock: supprimer clé FR → missing contient la clé, untranslated ne la contient pas | ✅ PASS 4/4 | — |
| U-94 | CTLDi18n — audit() détecte clé non traduite | i18n | mock: FR[key]=EN[key] → untranslated contient la clé, missing ne la contient pas | ✅ PASS 4/4 | — |
| U-95 | CTLDi18n — audit() détecte version mismatch | i18n | mock: FR version="0.0" → version_match=false ; restore → version_match=true | ✅ PASS 5/5 | — |
| U-96 | CTLDi18n — auditAll() | i18n | fr+es+ko présents, "en" absent, chaque entrée a la structure attendue | ✅ PASS 14/14 | — |
| U-97 | capabilitiesByType["UH-1H"] — champs renommés | Config | tous nouveaux noms présents + valeurs correctes ; tous anciens noms absents (nil/false) | ✅ PASS 18/18 | — |
| U-98 | capabilitiesByType["Mi-24P"] — champs renommés | Config | nouveaux noms présents, canParachuteDrop/canSlingload/canTransportWholeVehicle = false | ✅ PASS 10/10 | — |
| U-99  | groundVehicleWeights — valeurs + ancien nom absent | Config | 4 poids vérifiés (BRDM-2 / BTR_D / HMMWV) ; "vehiclesWeight" retourne nil | ✅ PASS 5/5 | — |
| U-100 | ctld.tr crate capacity (%1/%2) | i18n | ctld.tr("Maximum...", 1, 1) → contient "(1/1)" | ✅ PASS 1/1 | — |
| U-101 | ctld.tr lasing key (%1) | i18n | activated + deactivated : "JTAC-Alpha" substitué | ✅ PASS 2/2 | — |
| U-102 | ctld.tr altitude key (%1/%2) | i18n | min=30 / cur=15 → "30m" et "15m" substitués | ✅ PASS 2/2 | — |
| U-103 | ctld.tr vehicle capacity key (%1/%2) | i18n | loaded=1/max=1 → contient "(1/1)" | ✅ PASS 1/1 | — |
| U-104 | ctld.tr packed-into key (%1/%2) | i18n | nom véhicule + nb caisses substitués | ✅ PASS 2/2 | — |
| U-105 | ctld.tr troop capacity key (%1/%2) | i18n | current=6/limit=8 → contient "(6/8" | ✅ PASS 1/1 | — |
| U-106 | CTLDModValidator — _probeGround valid + invalid | ModValidator | BRDM-2→cache=true ; invalid→cache=false ; 2× cache hit sans re-probe | ✅ PASS 4/4 | — |
| U-107 | CTLDModValidator — _probeStatic valid + invalid | ModValidator | outpost_road→cache=true ; invalid→cache=false ; 2× cache hit sans re-probe | ✅ PASS 4/4 | — |
| U-108 | CTLDModValidator — Heliport probe via getDesc().life | ModValidator | SINGLE_HELIPAD→cache=true (life>0) ; invalid→cache=false (life==0) ; 2× cache hit sans re-probe | ✅ PASS 4/4 | — |

---

## Section F — Tests fonctionnels (F-01 à F-108)

| N° | Nom | Module | Objectif | Statut | Temps estimé |
|----|-----|--------|----------|--------|--------------|
| F-01 | CTLDCoreManager INIT-B — statics cargo MM | C1 | coalition.getStaticObjects → cargo détectés et loggés | ✅ PASS 3/3 | 5 min |
| F-02 | CTLDCoreManager INIT-C — groupes JTAC MM | C1 | coalition.getGroups → groupe "jtac" détecté et loggé | ✅ PASS 3/3 | 5 min |
| F-03 | CTLDZoneManager discovery TRZ | M1 | env.mission.triggers.zones → TRZ chargées dans _troopZones | ✅ PASS 6/6 | 5 min |
| F-04 | CTLDZoneManager discovery LGZ | M1 | env.mission.triggers.zones → LGZ chargées dans _logisticZones | ✅ PASS 6/6 | 5 min |
| F-05 | CTLDZoneManager onDead → suppression + event | M1 | Simulation S_EVENT_DEAD sur linked unit → zone retirée + OnLogisticZoneUpdated | ✅ PASS 8/8 | 6 min |
| F-06 | CTLDBeaconManager dropBeacon | M2 | Unit spawné + fréquences assignées + OnBeaconDropped publié | ✅ PASS 18/18 | 6 min |
| F-07 | CTLDBeaconManager removeClosestBeacon | M2 | Beacon le plus proche supprimé + OnBeaconRemoved publié | ✅ PASS 10/10 | 6 min |
| F-08 | CTLDBeaconManager toggleLayer | M2 | Layer ON/OFF + OnBeaconLayerToggled publié avec bon newState | ✅ PASS 14/14 | 5 min |
| F-09 | CTLDReconManager scan | M3 | Marks F10 créés + OnReconScan publié avec targets | ✅ PASS 9/9 | 7 min |
| F-10 | CTLDReconManager hideScan | M3 | Marks supprimés + OnReconHideTargets publié | ✅ PASS 8/8 | 5 min |
| F-11 | CTLDReconManager enableAutoRefresh / disable | M3 | OnReconAutoRefreshEnabled + OnReconAutoRefreshDisabled publiés | ✅ PASS 20/20 | 6 min |
| F-12 | CTLDFOBManager unpackFOBCrates → scène + OnFOBDeployed | M4 | Scène jouée, FOB créé, OnFOBDeployed avec fobId | ✅ PASS 17/17 | 10 min |
| F-13 | CTLDFOBManager onDead → intégrité + OnFOBDestroyed | M4 | Simulation destruction objet scène → OnFOBDestroyed si seuil atteint | ✅ PASS 21/21 | 7 min |
| F-14 | CTLDZoneManager registerFOBAsLogistic / unregisterLogistic | M4 | register → zone accessible + event ; unregister → zone retirée + event | ✅ PASS 20/20 | 5 min |
| F-15 | CTLDVehicleSpawner spawnVehicleForTransport | M5 | OnVehicleSpawnedForTransport | ✅ PASS 19/19 | — |
| F-16 | loadVehicle method=menu_ctld | M5 | Unit détruite + OnVehicleLoaded | ✅ PASS 18/18 | — |
| F-17 | unloadVehicle method=menu_ctld | M5 | Unit respawn + OnVehicleUnloaded | ✅ PASS 15/15 | — |
| F-18 | load DCS natif C-130 bbox | M5 | Bbox inclusion détectée → OnVehicleLoaded | ✅ PASS 13/13 | — |
| F-19 | unload C-130 au sol | M5 | Sortie bbox → OnVehicleUnloaded method=dcs_native | ✅ PASS 11/11 | — |
| F-20 | unload C-130 en vol | M5 | Sortie bbox → OnVehicleUnloaded method=parachute | ✅ PASS 11/11 | — |
| F-21 | _assemble KUB complet | M6 | OnAASystemDeployed publié, countComplete==1, crates détruites | ✅ PASS 11/11 | — |
| F-22 | _assemble KUB incomplet | M6 | Pas de déploiement, pas de crates détruites | ✅ PASS 6/6 | — |
| F-23 | _repair KUB → OnAASystemRepaired | M6 | Repair crate détruite, système remplacé dans _completeSystems | ✅ PASS 14/14 | — |
| F-24 | onPlayerEnterUnit → menu créé | M7 | CTLDPlayer dans _players + sous-menu 'CTLD' dans ctld.MenuManager | ✅ PASS 6/6 | — |
| F-25 | OnVehicleLoaded/Unloaded → loadedVehicles | M7 | ctldVehicleObject ajouté puis retiré de player.loadedVehicles | ✅ PASS 6/6 | — |
| F-26 | onPlayerLeaveUnit → player + menu supprimés | M7 | getPlayer == nil après Leave, _players vide | ✅ PASS 5/5 | — |
| F-27 | registerMMCrate → crate enregistrée | R1 | Mock static cargo → getCrateByName retourne la crate | ✅ PASS 9/9 | — |
| F-28 | loadCrate → OnCrateLoaded | R1 | État LOADED + event publié avec payload correct | ✅ PASS 11/11 | — |
| F-29 | unloadCrate → OnCrateUnloaded | R1 | État LANDED + event publié method=menu_ctld | ✅ PASS 11/11 | — |
| F-30 | unpackCrate → OnCrateUnpacked + destroy | R1 | État UNPACKED + event + crate retirée du registry | ✅ PASS 10/10 | — |
| F-31 | dropCrate ≤ maxDropHeight → OnCrateUnloaded | R1 | Drop safe → method=drop, crate en LANDED | ✅ PASS 10/10 | — |
| F-32 | dropCrate > maxDropHeight → OnCrateDestroyed | R1 | Drop haute → reason=drop_impact, crate détruite | ✅ PASS 8/8 | — |
| F-33 | loadFromZone — guards + success | R2 | Guards coalition/active/limit/capacity + load OK + limit décrément | ✅ PASS 13/13 | — |
| F-34 | deploy — on ground, pas d'EXZ | R2 | spawnObject appelé, troupes vidées, groupe dans _droppedGroups | ✅ PASS 9/9 | — |
| F-35 | returnToBase | R2 | Troupes retournées, zone.limit incrémenté, unlimited inchangé | ✅ PASS 9/9 | — |
| F-36 | extract | R2 | Groupe mock nearby → état EXTRACTED, retiré de _droppedGroups | ✅ PASS 8/8 | — |
| F-37 | spawnJTAC + markPending | R3 | Mock group → OnJTACSpawned + registry + pending flags | ✅ PASS 13/13 | — |
| F-38 | setJTACInTransit → état + OnJTACInTransit | R3 | Lase stoppé, état IN_TRANSIT, payload correct, guards | ✅ PASS 9/9 | — |
| F-39 | requestSmoke → OnJTACSmokeTarget | R3 | Payload smokePos déterministe (margin=0), guards | ✅ PASS 11/11 | — |
| F-40 | killJTAC → OnJTACDead + laser libéré | R3 | État DEAD, registry vidé, laser pool +1, guards | ✅ PASS 11/11 | — |
| F-41 | registerMMCrate → OnMMCrateDetected | FC | Event publié avec payload correct, guards double/inconnu | ✅ PASS 9/9 | — |
| F-42 | playScene — guards | R4 | nil unit, dead unit, unknown model → nil ; valid call → scene | ✅ PASS 4/4 | — |
| F-43 | FARP Alpha scene — structure validation | R4 | 14 steps, registryKeys, types polar, func, delayAfterPreviousStep | ✅ PASS 11/11 | — |
| F-44 | fobScene auto-enregistrement | R4 | Absent avant dofile, présent après + 4 steps + clés correctes | ✅ PASS 10/10 | — |
| F-45 | buildMenu() initial — UH-1H + all ON | R5 | Menu F10 construit : FOB disabled, sections présentes — VISUAL CHECK | ✅ PASS (visual) | — |
| F-46 | Double refresh() idempotent | R5 | Deuxième refresh() → menu identique — VISUAL CHECK | ✅ PASS (visual) | — |
| F-47 | Enable FOB + clearBranch + pagination | R5 | FOB activé + Pack Vehicles 11 items → 9+NextPage — VISUAL CHECK | ✅ PASS (visual) | — |
| F-48 | buildMenu() tous flags true — toutes sections | R5 | isTransport=true, canCarryVehicles=false : 8 sections + Pack Vehicle présents | ✅ PASS 10/10 | — |
| F-49 | enableCrates=false → Request Equipment + Crate Commands absent | R5 | Smoke + Beacons + Troops toujours présents | ✅ PASS 5/5 | — |
| F-50 | enabledRadioBeaconDrop=false → Radio Beacons absent | R5 | Toutes autres sections présentes | ✅ PASS 5/5 | — |
| F-51 | reconF10Menu=false → RECON absent | R5 | Toutes autres sections présentes | ✅ PASS 4/4 | — |
| F-52 | JTAC_jtacStatusF10=false → JTAC absent | R5 | Toutes autres sections présentes | ✅ PASS 4/4 | — |
| F-53 | enabledFOBBuilding=false → List FOBs absent | R5 | Crate Commands présent, Pack Vehicle présent | ✅ PASS 3/3 | — |
| F-54 | enablePackingVehicles=false → Pack Vehicle absent | R5 | Crate Commands présent, List FOBs présent | ✅ PASS 3/3 | — |
| F-55 | non-transport → pas de sections transport | R5 | isTransport=false : Troops/Crates/Smoke/Beacons absents ; RECON+JTAC présents | ✅ PASS 8/8 | — |
| F-56 | canCarryVehicles=true → Vehicle Commands présent | R5 | UH-1H canCarryVehicles=true : Vehicle Commands + Troops + Crates présents | ✅ PASS 3/3 | — |
| F-57 | parachuteCrates — altitude OK | FA | OnCrateParachuting publié, crate FALLING, estimatedLandingTime set | ✅ PASS 7/7 | — |
| F-58 | parachuteCrates — altitude trop basse | FA | Aucun event, crate reste LOADED | ✅ PASS 3/3 | — |
| F-59 | parachuteTroops — altitude OK | FA | OnTroopsDeployed(trigger=parachute), groupe retiré du transport | ✅ PASS 4/4 | — |
| F-60 | parachuteTroops — altitude trop basse | FA | Aucun event, groupe intact dans _inTransit | ✅ PASS 2/2 | — |
| F-61 | parachuteVehicle — altitude OK | FA | OnVehicleParachuting publié, vehicle DELIVERED | ✅ PASS 6/6 | — |
| F-62 | parachuteVehicle — altitude trop basse | FA | Aucun event, vehicle reste LOADED | ✅ PASS 2/2 | — |
| F-63 | canParachute=false → menus parachute absents | FA | UH-1H canParachute=false : Parachute Crates/Troops/Vehicle absents | ✅ PASS 6/6 | — |
| F-64 | canParachute=true → menus parachute présents | FA | UH-1H canParachute=true : 3 menus présents | ✅ PASS 3/3 | — |
| F-65 | canSlingload=false → menus Release/Cut absents | FB | transport en vol, canSlingload=false : menus absents | ✅ PASS 2/2 | — |
| F-66 | canSlingload=true, transport au sol → menus absents | FB | inAir=false : Release/Cut absents | ✅ PASS 2/2 | — |
| F-67 | canSlingload=true, transport en vol → menus présents | FB | inAir=true : Release/Cut présents | ✅ PASS 2/2 | — |
| F-68 | checkHoverStatus — hover OK → OnCrateLoaded(slingload) | FB | hoverTime=1, hauteur et distance OK → hook + inTransitOnSlingload=true | ✅ PASS 4/4 | — |
| F-69 | checkHoverStatus — hauteur hors plage → pas d'accrochage | FB | transport trop haut → hoverStatus reset, crate intacte | ✅ PASS 4/4 | — |
| F-70 | releaseSlingload — AGL ≤ maxH → OnCrateUnloaded(slingload_release) | FB | AGL=8m ≤ 12m : release propre | ✅ PASS 4/4 | — |
| F-71 | cutSlingload — AGL > 40m → OnCrateLost(slingload_cut_impact) | FB | AGL=190m : crate détruite | ✅ PASS 4/4 | — |
| F-72 | refreshMenuForGroup séquence complète | M8 | create+addSubMenu+addCommand+refresh → missionCommands dans bon ordre | ✅ PASS 7/7 | — |
| F-73 | disabled nodes invisibles en DCS | M8 | setBranchEnabled(false)+refresh → pas d'appel DCS ; re-enable → apparaît | ✅ PASS 4/4 | — |
| F-74 | order détermine l'ordre de rendu DCS | M8 | 3 submenus ordre 30/10/20 → rendus 10/20/30 | ✅ PASS 4/4 | — |
| F-75 | clearBranch + repopulate + refresh | M8 | Pattern proximité : 3 nouvelles commandes, anciennes absentes | ✅ PASS 5/5 | — |
| F-76 | removeMenuBranch permanent — mémoire + _lookup | M8 | Nœud absent du parent + _lookup nettoyé | ✅ PASS 8/8 | — |
| F-77 | refreshMenuForGroup sans menu connu → failure | M8 | success=false + message + refreshedCount=0 | ✅ PASS 3/3 | — |
| F-81 | Pagination visuelle DCS F10 | M8 | 11 items → 9 en page 1 + "→ Next Page" → 2 items — VISUAL CHECK | ✅ PASS (visual) | — |
| F-82 | Ordering visuel DCS F10 | M8 | Submenus ordre 30/10/20 → rendus A→B→C dans F10 — VISUAL CHECK | ✅ PASS (visual) | — |
| F-78 | getCentroid | M9 | 4 points → centroïde x/z correct, empty→nil (mock land.getHeight) | ✅ PASS 8/8 | — |
| F-79 | calcDropPosition | M9 | descentTime==AGL/rate, position décalée selon vitesse (mock Unit) | ✅ PASS 5/5 | — |
| F-80 | getSpawnObjectPositions | M9 | n positions, structure {positions,clock,distance}, spacing vérifié | ✅ PASS 16/16 | — |
| F-83 | mineFieldScene setLandMine 1×1 single mine | M10 | 1 mine spawnée réelle + carré F10 — VISUAL CHECK | ✅ PASS 5/5 | — |
| F-84 | mineFieldScene setLandMine 5×15 quinconce | M10 | 68 mines quinconce + grand quad F10 — VISUAL CHECK | ✅ PASS 4/4 | — |
| F-85 | mineFieldScene setLandMine 4×3 quinconce | M10 | 11 mines quinconce + quad F10 — VISUAL CHECK | ✅ PASS 4/4 | — |
| F-86 | mineFieldScene showMinefieldOnF10Map config guard | M10 | drawQuad non appelé si false, appelé si true | ✅ PASS 4/4 | — |
| F-87 | mineFieldScene setLandMineAuto parametric | M10 | 50×80 ~40 mines, nbMines=1, guards — VISUAL CHECK | ✅ PASS 11/11 | — |
| F-88 | _loadUserConfig — ctld_config_user | FD | 3 customs créés, 2 standards désactivés, ObjectRegistry peuplé | ✅ PASS 18/18 | — |
| F-89 | buildMenu filtre disabled / side / capacity | FD | 2 Load visibles (Standard+BLUE Recon), 4 exclus (disabled×2, side×1, cap×1) | ✅ PASS 7/7 | — |
| F-90 | fobScene structure + spawn visuel | R4 | 4 steps, registryKeys, prescript, container + watchtower en mission | ✅ PASS 18/18 | — |
| F-91 | farpScene structure + spawn visuel | R4 | 6 steps (prescript+5), ref 50m devant hélico, tous objets relatifs au helipad | ✅ PASS 24/24 | — |
| F-92 | FOB beacon — dropBeacon au centroid | CTLD_fob+beacon | beacon spawné au centroid FOB (dx=0), batterie infinie, 3 groupes VHF/UHF/FM | ✅ PASS 13/13 | — |
| F-93 | FOB unpack complet — fobScene + beacon | CTLD_fob+beacon | flow complet _onFOBBuilt : container+watchtower+beacon au centroid ✅ visual | ✅ PASS visual | — |
| U-81 | _resolveTemplateForLegacy | Q1 | integer exact/closest, composition table, disabled skip, empty → nil | ✅ PASS 14/14 | — |
| U-82 | CTLDZoneManager new methods | Q1 | createExtractZone/removeExtractZone/changeRemainingGroups/isUnitInZone | ✅ PASS 25/25 | — |
| U-83 | CTLDCrateManager:spawnCrate + findDescriptorByUnitType | Q1 | coalition.addStaticObject, model selection, OnCrateSpawned, guards | ✅ PASS 23/23 | — |
| F-94 | Legacy API — Troops wrappers | Q1 | 6 wrappers : routing + deprecation warning | ✅ PASS 18/18 | — |
| F-95 | Legacy API — Zones wrappers | Q1 | 10 wrappers : routing correct vers CTLDZoneManager + CTLDTroopManager | ✅ PASS 23/23 | — |
| F-96 | Legacy API — Crates wrappers | Q1 | spawnCrateAtZone/Point functional + cratesInZone watcher | ✅ PASS 12/12 | — |
| F-97 | Legacy API — Beacon wrapper | Q1 | createRadioBeaconAtZone → createAtZone + warning | ✅ PASS 6/6 | — |
| F-98 | Legacy API — JTAC wrappers | Q1 | 3 wrappers JTACAutoLase/JTACStart/JTACAutoLaseStop | ✅ PASS 11/11 | — |
| F-99 | Pack Vehicle flow | Q1 | findPackableVehicles + packVehicle : destroy, spawnCrate, OnVehiclePacked, menu refresh | ✅ PASS 16/16 | — |
| F-100 | spawnCrate — VISUAL CHECK | Q1 | 2 statics réels (load + dynamic) ~30/60 m devant hélico, StaticObject.getByName ✅, OnCrateSpawned×2 | ✅ PASS 14/14 visual ✅ [2026-04-15] | — |
| F-101 | CTLDConfig userConfig override | Config | ctld.yamlConfigDatas → 3 settings overridés, 1 non-overridé intact, report string | ✅ PASS 6/6 | — |
| F-102 | CTLDConfig singleton reset + fresh defaults | Config | reset _instance → fresh load → defaults restaurés, isLoaded=true | ✅ PASS 5/5 | — |
| F-103 | CTLDi18n — ctld.tr() fallback chain | i18n | FR→EN→key, paramètres %1/%2, langue inconnue, clé inconnue | ✅ PASS 6/6 | — |
| F-104 | CTLDi18n — audit complet FR | i18n | audit("fr") : version_match, 0 missing (untranslated intentionnels loggés, pas d'échec) | ✅ PASS 4/4 | — |
| F-105 | CTLDi18n — audit complet ES+KO | i18n | audit("es") + audit("ko") : version_match, 0 missing, untranslated loggés | ✅ PASS 10/10 | — |
| F-106 | JTAC drone full lifecycle — deployAirJTAC + orbit route + autoOrbit + restore | JTAC | Spawn MQ-9 → _setOrbitRoute (2s retry) → autoOrbit sur cible lasée → cible détruite → popTask + setTask(initialRoute) → drone retour route initiale complète (cercle 2000 m) | ✅ PASS visual [2026-04-25] | Witchcraft diag_jtac_deploy_test + diag_force_target_loss |
| F-107 | Hummer JTAC — Request Equipment → unpack → autoLase | JTAC STEP1+3 | isJTAC=true sur Hummer → Request Equipment visible + unpack → startLase déclenché → laser code attribué → menu JTAC F10 actif | ✅ PASS visual [2026-04-25] | Mission réelle BLUE |
| F-108 | FOB beacon radio — VHF/UHF/FM reçus après ajout sons mission | Beacon | Drop FOB → beacon spawné → VHF ADF actif + FM homing actif (ARC-131 UH-1H) après ajout beacon.ogg + beaconsilent.ogg dans Mission→Sons | ✅ PASS visual [2026-04-26] | Sons .ogg obligatoires dans .miz |
| F-110 | JTAC InTransit — Request JTAC Vehicle config visibility | JTAC STEP3 | JTAC_unitTypeNames[1] RED + [2] BLUE définis, strings valides, Hummer/SKP-11 présents (MQ-9/RQ-1A dans unitList, pas dans JTAC_unitTypeNames) | ✅ PASS 8/8 [2026-05-07] | UH-1H uniquement |
| F-111 | JTAC InTransit — spawnJTACVehicleForTransport + registration | JTAC STEP3 | spawnJTACVehicleForTransport → CTLDVehicle retourné, gname set, deregisterJTAC→nil, registerJTACVehicle→_vehicles (startLase async → live F-109b visual ✅) | ✅ PASS 6/6 [2026-04-27] | UH-1H uniquement |
| F-112 | JTAC InTransit — Repack → deregisterJTAC, no OnJTACDead | JTAC STEP3 | inject fake jtac → deregisterJTAC → jtacs nil, OnJTACDead NOT published, laser code freed, idempotent | ✅ PASS 7/7 [2026-04-27] | UH-1H uniquement |
| F-116 | RECON scenario layers — détection par couche (6 layers) | CTLDReconManager | Infantry/Ground Vehicles/Air Defense/Aircraft/Helicopters/Ships : 1 scan par couche, LOS + markId + autoRefresh=true, menu RECON [Stop] après Start, icône couleur coalition (rouge=RED) | ✅ PASS 6/6 visual [2026-04-28] | scenario_recon_layers.lua interactif |
| F-117 | RECON reconEnabled=false → message explicite (non silencieux) | CTLDReconManager | reconEnabled=false → outTextForGroup émis contenant "reconEnabled" ; reconEnabled=true → pas de message disabled | ✅ PASS 3/3 [2026-04-29] | — |
| F-118 | RECON toggle-OFF → suppression immédiate des marks | CTLDReconManager | scan() avec prevScan injecté + toutes layers OFF → _activeScans[player]=nil immédiatement, mark circle DCS supprimé | ✅ PASS 5/5 [2026-04-29] | — |
| F-119 | RECON icône AA — circleToAll rempli + 2 apex lineToAll | CTLDReconRenderer | drawAAIcon : 1 circleToAll(slot+1) fill alpha=0.3 + 2 lineToAll(slot+2,+3) ; radius=hs*0.9 scale=1.0→15.75 / scale=2.0→31.5 | ✅ PASS 11/11 [2026-04-29] | — |
| F-120 | GAP-1 : findLoadableVehicles + loadVehicle menu_ctld | CTLDVehicleSpawner | WAITING vehicle dans rayon → listé ; hors rayon → exclu ; LOADED → exclu ; loadVehicle → state LOADED + destroy + loadMethod + loadTransportName | ✅ PASS 9/9 [2026-04-29] | UH-1H (vehicleTransportEnabled override) |
| F-121 | GAP-1 : findLoadedVehicles + unloadVehicle menu_ctld | CTLDVehicleSpawner | LOADED vehicle sur ce transport → listé ; autre transport → exclu ; unloadVehicle → state DELIVERED + dynAdd ; après unload → liste vide | ✅ PASS 6/6 [2026-04-29] | UH-1H |
| F-122 | GAP-1 : lifecycle JTAC sur load/unload menu_ctld | CTLDVehicleSpawner + CTLDJTACManager | loadVehicle → setJTACInTransit(groupName) ; unloadVehicle → resumeJTAC(groupName) ; états LOADED/DELIVERED corrects | ✅ PASS 6/6 [2026-04-29] | UH-1H |
| F-123 | GAP-1 bugfix : _dispatchPostSpawn enregistre véhicule GROUND dans CTLDVehicleSpawner | CTLDCrateManager + CTLDVehicleSpawner | après _spawnUnpacked(desc non-JTAC GROUND) → count spawner +1 ; findLoadableVehicles retourne le véhicule | ✅ PASS 2/2 [2026-04-29] | UH-1H (vehicleTransportEnabled) |
| F-124 | GAP-1 fix : refresh menu Load + Pack après unpack | CTLDCrateManager:_spawnUnpacked + CTLDVehicleSpawner | après unpack, refreshLoadSectionForUnit(playerName) + refreshPackSectionForUnit(playerName) appelés → Hummer visible dans Load ET Pack sans re-entry menu | ✅ PASS live [2026-04-30] | UH-1H |
| F-125 | Feature K Sprint 1 — Baseline JTAC vehicle load/setJTACInTransit | CTLDVehicleSpawner + CTLDJTACManager | Hummer spawné+registerJTACVehicle+autoLase → IDLE/LASING ; loadVehicle → state LOADED + JTAC IN_TRANSIT | ✅ PASS 10/10 [2026-05-06] | UH-1H |
| F-126 | Feature K Sprint 1 — GAP-K1 : parachuteVehicle → WAITING + resumeJTAC | CTLDVehicleSpawner:parachuteVehicle | après parachute : vehicle state WAITING (pas DELIVERED), loadTransportName nil, JTAC intact (resumeJTAC timer) | ✅ PASS 4/4 [2026-05-06] | UH-1H |
| F-127 | Feature K Sprint 1 — GAP-K2 : transport détruit → JTAC deregister + vehicle purge | CTLDVehicleSpawner:onDead | transport S_EVENT_DEAD avec vehicle LOADED → jtacs[groupName]=nil + _vehicles[id]=nil + unitToVehicle nil + OnVehicleDead publié | ✅ PASS 5/5 [2026-05-06] | UH-1H |
| F-128 | Sprint 2a — DCS native LOAD : _nativeCrateLink mémorisé | CTLDCrateManager:_checkNativeDCSCargo | crate dans bbox → linkOffsetRef {lx,ly,lz} enregistré, state LOADED | ✅ PASS 5/5 [2026-05-06] | mock |
| F-129 | Sprint 2a — DCS native UNLOAD au sol : drift > 1m → LANDED, fromParachute=false | CTLDCrateManager:_checkNativeDCSCargo | static déplacé 5m → drift calculé > 1m → state LANDED + fromParachute=false + _nativeCrateLink nil | ✅ PASS 5/5 [2026-05-06] | mock |
| F-130 | Sprint 2a — DCS native UNLOAD en vol : fromParachute=true | CTLDCrateManager:_checkNativeDCSCargo | transport AGL=200m → inFlight=true → fromParachute=true après unload | ✅ PASS 5/5 [2026-05-06] | mock |
| F-131 | Sprint 2a — autoUnpack crateSet complet après parachutage | CTLDCrateManager:_checkAutoUnpack | 3 crates LANDED+fromParachute=true+même descriptor → _spawnUnpacked au centroïde, toutes 3 dé-enregistrées | ✅ PASS 4/4 [2026-05-06] | mock |
| F-132 | JTAC vehicle via crate — pack → deregisterJTAC | CTLDVehicleSpawner:packVehicle + CTLDJTACManager:deregisterJTAC | startLase+register → packVehicle → deregCalled + jtacs=nil + laserCode freed | ✅ PASS 7/7 [2026-05-06] | Witchcraft |
| F-133 | Feature N — `_aiTeams` population après `_initAITransports()` | `CTLDCoreManager:_initAITransports` | `_aiTeams` existe + `_aiTeams[1]` et `[2]` ≥1 entrée + toutes actives et nommées | ✅ PASS 4/4 [2026-05-12] | Witchcraft |
| F-134 | Feature N — `_checkAIStatus` pickup / dropoff branches | `CTLDCoreManager:_checkAIStatus` | pickup AI→embark appelé (1×, bonne zone+tmpl) ; human ignoré ; dropoff AI+troops→disembarkAll ; dropoff sans troupes→non appelé | ✅ PASS 6/6 [2026-05-12] | Witchcraft mock |
| F-135 | ctld.scheduler — ops de base (register/cancel/cancelAll) | `ctld.scheduler` (CTLD_utils.lua) | register stocke ID ; re-register annule ancien+stocke nouveau ; cancel supprime entrée+appelle removeFunction ; cancelAll vide _ids | ✅ PASS 9/9 [2026-05-12] | Witchcraft mock |
| F-136 | ctld.scheduler — enregistrement beacon_refresh à l'init | `CTLDBeaconManager:_scheduleRefresh` | _scheduleRefresh enregistre "beacon_refresh" ; re-schedule remplace ID stale | ✅ PASS 3/3 [2026-05-12] | Witchcraft |
| F-137 | ctld.scheduler — enregistrement ai_transport + pas de doublon | `CTLDCoreManager:_initAITransports` | _initAITransports enregistre "ai_transport" ; second register remplace (pas doublon) | ✅ PASS 3/3 [2026-05-12] | Witchcraft |
| F-138 | ctld.scheduler — guard B zombie loop auto-stop | `CTLDBeaconManager:_scheduleRefresh` closure | closure retourne nil si _instance remplacée (zombie stoppé) ; exécution normale si instance inchangée | ✅ PASS 3/3 [2026-05-12] | Witchcraft mock |
| F-139 | ctld.scheduler — cancelAll + re-registration | `ctld.scheduler.cancelAll` | cancelAll vide _ids ; register fonctionne après cancelAll ; beacon re-enregistré après _scheduleRefresh | ✅ PASS 4/4 [2026-05-12] | Witchcraft |
| F-140 | Feature L — menu disembark 1 groupe = commande directe | `CTLDTroopManager:refreshMenuSection` | 1 group onboard → "Disembark Troops" est une commande directe (pas sous-menu) | ✅ PASS 2/2 [2026-05-12] | Witchcraft mock |
| F-141 | Feature L — menu disembark 2 groupes = sous-menu 3 entrées | `CTLDTroopManager:refreshMenuSection` | 2 groups onboard → sous-menu "Disembark Troops" avec Disembark All + [1] + [2] = exactement 3 entrées | ✅ PASS 5/5 [2026-05-12] | Witchcraft mock |
| F-142 | Feature L — disembarkAll vide _inTransit | `CTLDTroopManager:disembarkAll` | disembarkAll sur 2 groupes → _inTransit nil + 2 appels disembark | ✅ PASS 2/2 [2026-05-12] | Witchcraft mock |
| F-143 | Feature L — disembarkIndex(2) sort le groupe 2 en premier | `CTLDTroopManager:disembarkIndex` | disembarkIndex(2) → group 2 disembarked first, group 1 reste onboard | ✅ PASS 2/2 [2026-05-12] | Witchcraft mock |
| F-144 | Feature L — _menuCheckCargo multi-groupe | `CTLDTroopManager:_menuCheckCargo` | 2 groupes → message multi-lignes avec [1] [2] + ligne TOTAL | ✅ PASS 4/4 [2026-05-12] | Witchcraft mock |
| F-145 | Feature L — extract menu 1 groupe nearby = commande directe | `CTLDTroopManager:refreshMenuSection` | 1 groupe dropped nearby → commande "Extract:" directe, pas de sous-menu | ✅ PASS 2/2 [2026-05-12] | Witchcraft mock |
| F-146 | Feature L — extract menu 2 groupes nearby = sous-menu avec distances | `CTLDTroopManager:refreshMenuSection` | 2 groupes dropped nearby → sous-menu "Extract from field" avec 2 entrées annotées distance (m) | ✅ PASS 5/5 [2026-05-12] | Witchcraft mock |
| F-159 | _transportLimit UH-1H → 8 | `CTLDTroopManager` | _transportLimit("UH-1H") retourne maxTroopsOnboard=8 | ✅ PASS 1/1 [2026-05-18] | Witchcraft mock |
| F-160 | _transportLimit Mi-24P → 10 | `CTLDTroopManager` | _transportLimit("Mi-24P") retourne maxTroopsOnboard=10 | ✅ PASS 1/1 [2026-05-18] | Witchcraft mock |
| F-161 | _transportLimit fallback → numberOfTroops | `CTLDTroopManager` | _transportLimit("unknown_type_xyz") retourne cfg.numberOfTroops | ✅ PASS 1/1 [2026-05-18] | Witchcraft mock |
| F-162 | _isDynamicCapable UH-1H → true | `CTLDCrateManager` | mock.getTypeName()="UH-1H" → useNativeDcsCargoSystem=true | ✅ PASS 1/1 [2026-05-18] | Witchcraft mock |
| F-163 | _isDynamicCapable SK-60 → false | `CTLDCrateManager` | mock.getTypeName()="SK-60" → absent de capabilitiesByType → false | ✅ PASS 1/1 [2026-05-18] | Witchcraft mock |
| F-164 | _detectCapabilities UH-1H | `CTLDPlayerManager` | isTransport=true, canCarryVehicles=true | ✅ PASS 2/2 [2026-05-18] | Witchcraft mock |
| F-165 | _detectCapabilities Mi-24P | `CTLDPlayerManager` | isTransport=true, canCarryVehicles=false | ✅ PASS 2/2 [2026-05-18] | Witchcraft mock |
| F-166 | loadVehicle bloqué par maxWholeVehiclesOnboard=1 | `CTLDVehicleSpawner` | 1 véhicule déjà LOADED → 2ème chargement refusé (WARNING + veh1 reste WAITING) | ✅ PASS 2/2 [2026-05-18] | Witchcraft mock |
| F-167 | Guard caisses à bord — message avec compteur | `CTLDCrateManager` | trigger.action intercepté → message contient "(1/1)" | ✅ PASS 1/1 [2026-05-18] | Witchcraft mock |
| F-168 | refreshCrateFlightSection ground — items sol activés | `CTLDCrateManager` | inAir=false → Load/Drop/Unpack/List enabled=true | ✅ PASS 4/4 [2026-05-18] | Witchcraft mock |
| F-169 | refreshCrateFlightSection ground — items vol désactivés | `CTLDCrateManager` | inAir=false → Parachute/Release/Cut enabled=false | ✅ PASS 3/3 [2026-05-18] | Witchcraft mock |
| F-170 | refreshCrateFlightSection air — items sol désactivés | `CTLDCrateManager` | inAir=true → Load/Drop/Unpack/List enabled=false | ✅ PASS 4/4 [2026-05-18] | Witchcraft mock |
| F-171 | refreshCrateFlightSection air + crate → Parachute activé | `CTLDCrateManager` | inAir=true + 1 crate CTLD chargée → Parachute Crates enabled=true | ✅ PASS 1/1 [2026-05-18] | Witchcraft mock |
| F-172 | refreshCrateFlightSection air sans crate → Parachute désactivé | `CTLDCrateManager` | inAir=true + 0 crate → Parachute Crates enabled=false, Release/Cut disabled | ✅ PASS 3/3 [2026-05-18] | Witchcraft mock |
| F-173 | Crate visible au sol après parachutage | `CTLDCrateManager` | 1 crate parachutée (2 requises) → static DCS visible + interactable au sol | ✅ PASS 1/1 [2026-05-18] | Witchcraft live |
| F-174 | Release/Cut Slingload menu après hover pickup | `CTLDCrateManager` | hover pickup → Release/Cut activés en vol ; release → désactivés | ✅ PASS 1/1 [2026-05-18] | Witchcraft live |
| F-175 | Msg confirmation slingload efface décompte | `CTLDCrateManager` | outTextForGroup clearview=true → décompte remplacé par confirmation | ✅ PASS 1/1 [2026-05-18] | Witchcraft live |

---

## Statuts

| Symbole | Signification |
|---------|--------------|
| ⬜ TODO | À exécuter |
| 🔄 WIP | En cours |
| ✅ PASS | Passé (tous asserts OK) |
| ❌ FAIL | Échec (au moins un assert KO) |
| ⬜ PENDING | Script non codé — en attente d'implémentation |

---

## Résumé de couverture

- **C1** : 7 unitaires + 2 fonctionnels = **9 cas** ✅ PASS [2026-04-02]
- **M1** : 6 unitaires + 3 fonctionnels = **9 cas** ✅ PASS [2026-04-02]
- **M2** : 2 unitaires + 3 fonctionnels = **5 cas** ✅ PASS [2026-04-02]
- **M3** : 2 unitaires + 3 fonctionnels = **5 cas** ✅ PASS [2026-04-02]
- **M4** : 1 unitaire  + 3 fonctionnels = **4 cas** ✅ PASS [2026-04-02]
- **M5** : 4 unitaires + 6 fonctionnels = **10 cas** ✅ PASS [2026-04-07]
- **M6** : 3 unitaires + 3 fonctionnels = **6 cas** ✅ PASS [2026-04-07]
- **M7** : 4 unitaires + 3 fonctionnels = **7 cas** ✅ PASS [2026-04-07]
- **R1** : 5 unitaires + 6 fonctionnels = **11 cas** ✅ PASS [2026-04-07]
- **R2** : 4 unitaires + 4 fonctionnels = **8 cas** ✅ PASS [2026-04-07]
- **R3** : 4 unitaires + 4 fonctionnels = **8 cas** ✅ PASS [2026-04-07]
- **R4** : 2 unitaires + 5 fonctionnels = **7 cas** ✅ PASS (F-90 18/18 + F-91 24/24 ✅ visual) [2026-04-14]
- **FOB beacon** : 2 fonctionnels = **2 cas** ✅ PASS (F-92 13/13 + F-93 visual ✅ — flow complet fobScene+beacon) [2026-04-14]
- **R5** : 0 unitaires + 12 fonctionnels = **12 cas** ✅ PASS (F-45→F-47 visual ✅, F-48→F-56 45/45 ✅) [2026-04-08]
- **FA** : 0 unitaires + 8 fonctionnels = **8 cas** ✅ PASS (F-57→F-64 33/33 ✅) [2026-04-08]
- **FB** : 0 unitaires + 7 fonctionnels = **7 cas** ✅ PASS (F-65→F-71 22/22 ✅) [2026-04-08]
- **FC** : 1 fonctionnel = **1 cas** ✅ PASS [2026-04-07]
- **ObjectRegistry** : 3 unitaires = **3 cas** ✅ PASS (U-54→U-56 43/43 ✅) [2026-04-08]
- **M8** : 10 unitaires + 8 fonctionnels = **18 cas** ✅ PASS (U-57→U-66 + F-72→F-77 97/97 ✅ + F-81→F-82 visual ✅) [2026-04-09]
- **M9** : 7 unitaires + 3 fonctionnels = **10 cas** ✅ PASS (U-67→U-73 + F-78→F-80 118/118 ✅) [2026-04-09]
- **M10** : 2 unitaires + 5 fonctionnels = **7 cas** ✅ PASS (U-74→U-75 12/12 ✅ + F-83→F-87 28/28 visual ✅) [2026-04-09]
- **FD** : 5 unitaires + 2 fonctionnels = **7 cas** ✅ PASS (U-76→U-80 + F-88→F-89 109/109 ✅) [2026-04-14]
- **Q1** : 3 unitaires + 7 fonctionnels = **10 cas** ✅ PASS (U-81→U-83 62/62 + F-94→F-100 100/100 ✅) [2026-04-15]
- **Config** : 6 unitaires + 2 fonctionnels = **8 cas** ✅ PASS (U-84→U-89 46/46 + F-101→F-102 11/11 ✅) [2026-04-16]
- **i18n** : 7 unitaires + 3 fonctionnels = **10 cas** ✅ PASS (U-90→U-96 43/43 + F-103→F-105 20/20 ✅) [2026-04-16]
- **JTAC drone orbit** : 1 fonctionnel = **1 cas** ✅ PASS visual (F-106 [2026-04-25])
- **JTAC Hummer** : 1 fonctionnel = **1 cas** ✅ PASS visual (F-107 [2026-04-25])
- **FOB beacon radio** : 1 fonctionnel = **1 cas** ✅ PASS visual (F-108 [2026-04-26]) — sons .ogg obligatoires dans .miz
- **spawnableCrates refactor** : 1 fonctionnel = **1 cas** ✅ PASS visual (F-109 [2026-04-26]) — singleTypeSets auto-générés, mixedSets en fin, ordre garanti
- **JTAC InTransit (UH-1H)** : 3 fonctionnels = **3 cas** ✅ PASS (F-110 10/10 + F-111 6/6 + F-112 7/7 [2026-04-27]) — Request JTAC Vehicle config + spawn + repack anti-false-KIA
- **Mark IDs** : 1 fonctionnel = **1 cas** ✅ PASS (F-115 11/11 [2026-04-27]) — compteur global monotonique partagé Recon/Beacon/drawQuad, fix moved-target icon
- **RECON layers scenario** : 1 scénario = **6 cas** ✅ PASS visual (F-116 6/6 [2026-04-28]) — détection par couche (Infantry/GV/AA/Aircraft/Helo/Ships), menu [Start]/[Stop], coalition color (rouge=RED), reconEnabled patch scenario
- **RECON bugfixes** : 3 fonctionnels = **19 cas** ✅ PASS (F-117 3/3 + F-118 5/5 + F-119 11/11 [2026-04-29]) — reconEnabled=false message, toggle-OFF immédiat, AA icon circleToAll+apex
- **GAP-1 Load/Unload vehicle menu** : 3 fonctionnels = **21 cas** ✅ PASS (F-120 9/9 + F-121 6/6 + F-122 6/6 [2026-04-29]) — findLoadableVehicles, findLoadedVehicles, loadVehicle/unloadVehicle menu_ctld, lifecycle JTAC
- **GAP-1 bugfix — unpack register** : 1 fonctionnel = **2 cas** ✅ PASS (F-123 2/2 [2026-04-29]) — _dispatchPostSpawn enregistre véhicules GROUND dans CTLDVehicleSpawner + UH-1H dans vehicleTransportEnabled
- **GAP-1 fix — refresh Load+Pack menus après unpack** : 1 fonctionnel = **1 cas** ✅ PASS live (F-124 [2026-04-30]) — _spawnUnpacked refreshLoadSectionForUnit + refreshPackSectionForUnit → Hummer visible dans Load ET Pack sans re-entry menu
- **GAP-1 scénario end-to-end** : 1 scénario = **4 étapes** ✅ PASS (scenario_vehicle_load_unload [2026-04-29]) — cleanup→crate→unpack→load→unload cycle complet UH-1H, lazy unit-ref resolve
- **TroopsFullCycle v2 — lifecycle complet** : 1 scénario = **8 steps** ✅ PASS (scenarioTroopsFullCycle\_v2 [2026-05-05]) — lifecycle troops+JTAC transitions validé : embark(no lase)→deploy(2 lasing)→re-embark(idle+freed)→re-deploy(2 lasing)→1 JTAC dead(target freed)→timer destruction successive→reacquisition chain. Feature J déconfliction + claim/release lifecycle intégral + reacquisition après destroy confirmés.
- **Feature H — Smoke auto-resume** : diag validés ✅ PASS live DCS [2026-05-05] — smoke bleue persistante en boucle (270s interval), toggle label bascule [activate]↔[deactivate], désactivation purge mémoire. CTLDSmokeManager singleton (diag_smoke_mgr.lua + diag_smoke_menu.lua).
- **Feature K Sprint 1 — JTAC vehicle in-transit (GAP-K1+K2)** : 3 fonctionnels = **3 cas** ✅ PASS (F-125 10/10 + F-126 4/4 + F-127 5/5 [2026-05-06]) — parachuteVehicle setState WAITING + resumeJTAC ; transport destroy → deregisterJTAC + purge vehicle
- **Sprint 2a — DCS native crate load/unload + autoUnpack parachute** : 4 fonctionnels = **19 cas** ✅ PASS (F-128 5/5 + F-129 5/5 + F-130 5/5 + F-131 4/4 [2026-05-06]) — nativeCrateLink linkOffsetRef 3D, drift>1m UNLOAD sol+vol, fromParachute, checkAutoUnpack centroïde
- **JTAC vehicle via crate pack** : 1 fonctionnel = **7 cas** ✅ PASS (F-132 7/7 [2026-05-06]) — deregisterJTAC@packVehicle, jtacs=nil, laserCode freed
- **Feature N — AI transport INIT-A** : 2 fonctionnels = **10 cas** ✅ PASS (F-133 4/4 + F-134 6/6 [2026-05-12]) — `_aiTeams` population ; pickup/dropoff branch logic (mocks)
- **ctld.scheduler — registre central + guard B** : 5 fonctionnels = **22 cas** ✅ PASS (F-135 9/9 + F-136 3/3 + F-137 3/3 + F-138 3/3 + F-139 4/4 [2026-05-12]) — register/cancel/cancelAll ; beacon+AI registration ; zombie guard ; re-registration post-cancelAll
- **Feature L — Multi-group transport menus + disembark/extract** : 7 fonctionnels = **22 cas** ✅ PASS (F-140 2/2 + F-141 5/5 + F-142 2/2 + F-143 2/2 + F-144 4/4 + F-145 2/2 + F-146 5/5 [2026-05-12]) — menu direct vs sous-menu disembark (1 vs N groupes) ; disembarkAll/Index ; _menuCheckCargo multi-ligne ; extract from field 1 vs N groupes avec distances ; bugfixes : extract visible avec troupes à bord si capacité dispo, spawn center décalé (safeR+spreadR) pour éviter overlap
- **Feature F — RECON FARP/FOB layer (mock)** : 9 fonctionnels = **22 cas** ✅ PASS (F-150 3/3 + F-151..152 7/7 + F-153 3/3 + F-154..157 6/6 + F-158 3/3 [2026-05-17]) — CTLDStaticWatcher watch/tick/dead ; coalition rendering fix (-1→playerCoalition) ; drawFarpIcon H cerclé ; farp_fob layer _matchLayer skip ; _syncFarpMarks FARP+FOB detect/dedup/clear ; watcher onDeadFn
- **MT-06 — RECON FARP/FOB live DCS** : 9 steps ✅ PASS [2026-05-17] — icône T-dans-carré magenta visible en LOS ; persistence hors LOS confirmée ; toggle [deactivate] efface marks immédiatement ; toggle [activate] refait apparaître (MarkIdCounter préservé) ; playerCoalition=2 confirmé ; FARP détruit → mark disparaît <2s (CTLDStaticWatcher) ; FOB détruit → mark disparaît <2s
- **Feature P — capabilitiesByType rename + groundVehicleWeights** : 3 unitaires + 8 fonctionnels = **11 cas** ✅ PASS (U-97 18/18 + U-98 10/10 + U-99 5/5 + F-159→F-166 11/11 [2026-05-18]) — champs renommés (cratesEnabled/troopsEnabled/canParachuteDrop/canSlingload/canTransportWholeVehicle/useNativeDcsCargoSystem/maxTroopsOnboard/maxCratesOnboard/maxWholeVehiclesOnboard) ; anciens noms absents ; bugfix actions→caps (menu Parachute/Slingload) ; bugfix internalCargoLimits→maxWholeVehiclesOnboard (capacity guard)
- **i18n string.format migration + capacity counters** : 6 unitaires + 1 fonctionnel = **7 cas** ✅ PASS (U-100→U-105 8/8 + F-167 1/1 [2026-05-18]) — substitution %1/%2 vérifiée (crate capacity / lasing / altitude / vehicle capacity / packed-into / troop capacity) ; guard messages affichent (x/y)
- **Feature — Crate Commands sol/vol split** : 5 fonctionnels = **15 cas** ✅ PASS (F-168 4/4 + F-169 3/3 + F-170 4/4 + F-171 1/1 + F-172 3/3 [2026-05-18]) — refreshCrateFlightSection ground/air visibility ; setBranchEnabled mocked ; Parachute Crates exclut slingloaded ; Release/Cut conditionnés slingload actif
- **Bugfixes session 2026-05-18 — parachute/slingload/poids** : 3 fonctionnels = **3 cas** ✅ PASS live DCS (F-173→F-175 [2026-05-18]) — crate visible au sol après parachutage (_respawnStatic) ; Release/Cut Slingload apparaissent après hover pickup et disparaissent après release/cut ; décompte slingload effacé par msg confirmation (clearview=true)
- **B3 — loadCrateFromMenu config guard** : 5 fonctionnels = **5 cas** ✅ PASS (F-B3-1→F-B3-5 5/5 [2026-05-19]) — refreshLoadCrateSection early-return false ; buildMenuSection skip addSubMenu "Load Crate" false ; refreshCrateFlightSection skip setBranchEnabled false ; comportements symétriques quand true
- **B4 — maximumSearchDistance câblé dans AttackNearestEnemyOnLos** : 3 fonctionnels = **3 cas** ✅ PASS (F-B4-1→F-B4-3 3/3 [2026-05-19]) — radius=4000 (défaut) ; radius=1500 (custom) ; fallback 10000 quand config=nil
- **CL-9 — pickupZones legacy → CTLDTroopZone** : 4 fonctionnels = **18 cas** ✅ PASS (F-CL9-1→F-CL9-4 18/18 [2026-05-19]) — trigger zone stock/smoke/active/coalition ; limit=-1→unlimited ; stockFlagName auto "zoneName_count" + setUserFlag sur consume/restore ; ship unit fallback position+radius
- **CL-10 — addPlayerAircraftByType gate** : 3 fonctionnels = **3 cas** ✅ PASS (F-CL10-1→F-CL10-3 3/3 [2026-05-19]) — byType=true→menu construit ; byType=false+whitelist→menu construit ; byType=false+absent→early return pas de menu
- **Feature O — extractableGroups INIT-E** : 3 fonctionnels = **7 cas** ✅ PASS (F-O-1→F-O-3 7/7 [2026-05-19]) — groupe existant blue→_droppedGroups[2] ; groupe inexistant→skip WARN ; deux groupes red→_droppedGroups[1] les deux présents
- **Feature Q — Vehicle whole-unit transport** : 6 fonctionnels = **9 cas** ✅ PASS (F-Q-1→F-Q-6 9/9 [2026-05-19]) — UH-1H→{} ; C-130+HMMWV BLUE→retourné ; C-130+BRDM RED→exclu coalition ; C-130+type inconnu→exclu type ; C-130 spawnAsVehicle=true ; UH-1H spawnAsVehicle=false
- **Feature R+S — AI transport zones (config-only + _loadAIZonesFromConfig + onAILand pickup + validation)** : 49 fonctionnels = **147 cas** ✅ PASS (F-R-1→F-R-49 147/147 [2026-05-20]) — `_loadAIZonesFromConfig` : pickup T stock=10/unlimited/disabled/erreur, dropoff, cargoType pass-through ; `getAIPickupZoneAt`/`getAIDropoffZoneAt` : filtre coalition + lat/lon ; `getTroopZoneAtPoint` : guard isAIPickup exclu menu joueur ; aiDropMode G/P/GP default + invalide→stocké "GP" (Fix 6) ; `cleanupDeadTransports` câblé S_EVENT_DEAD ; `onAILand` pickup fallback scan templates (F-R-21→F-R-26) : premier compatible sélectionné, scan circulaire random, hasTroops guard, teams vide guard ; Feature S whitelists (F-R-27→F-R-32) : troopTemplates stocké sur zone, vehicleTypes stocké, filtrage pickup par nameSet ; `_validateZoneNames` AIZ (F-R-33→F-R-40) : coalition manquante→ERROR+skip, doublon→ERROR+both skipped, zone absente ME→ERROR+skip, cargoType invalide→WARN (warns[], Fix 5)+créée, aiDropMode invalide→WARN+créée, troopTemplates inconnu→WARN+créée, overlap P+D→WARN+both créées, rapport outText avec "CTLD"+"error" ; Nouveaux checks G1→G5 (F-R-41→F-R-46) : ni isPickup ni isDropoff→ERROR+skip (G1), tous troopTemplates inconnus→WARN distinct (G2), troopStock=0 sur pickup troop→WARN (G3), tous vehicleTypes inconnus dans loadableVehicles→WARN (G4), coalition "ROUGE"→ERROR+skip, cargoType=V sans canTransportWholeVehicle→ERROR+skip (G5) ; vehicleTypes filtre pickup (F-R-47/48) : Hummer dans whitelist→passe, BTR-80 hors whitelist→filtré ; Rapport MM live (F-R-49) : 5 ERRORs + 4 WARNs injectés, rapport outText réel sur écran DCS + CTLD.log (5 error(s) 4 warning(s) confirmés)
- **MT-07 — AI troupes cycle complet** : 4 steps ✅ PASS live DCS [2026-05-19] — onAILand (S_EVENT_LAND) pickup sur AIZ_base_B_P_5, vol, disembark sur AIZ_front_B_D ; msgs coalition avec count (pickup + dropoff) validés ; transportPilotNames requis (auto-patch step 1)
- **MT-08 — AI véhicule entier cycle complet** : 4 steps ✅ PASS live DCS [2026-05-19] — onAILand pickup Hummer sur AIZ_depot_B_P_V_10 (cargoType=V, stock=10), vol, unload sur AIZ_livraison_B_D_G ; msg coalition load/unload validés ; aiCargoType V = vehicles only (pas de troupes)
- **MT-09 — AI cycle complet troupes + véhicule entier (zone TV)** : 4 steps ✅ PASS live DCS [2026-05-19] — onAILand pickup troupes + Hummer en un seul posé sur AIZ_depot_B_P_TV_5_10 (cargoType=TV) ; dropoff troupes + véhicule sur AIZ_livraison_B_D_G ; ipairs bug fix (pilotNames hash) + weight gate (Hummer 1250 kg < UH-1H 1360 kg)
- **Feature S — AIZ zones config-only** : activé dans `CTLD_userConfig.lua` (7 zones MT-07→MT-10 déclarées nativement, `if false then` retiré) — re-recette MT-07→MT-10 ✅ PASS [2026-07-05]
- **MT-10a — AI _assignPostSpawnTask gotoNearestWPZ** : ✅ PASS live DCS [2026-05-20] — troupes IA déposées → marche vers WPZ_mt10_B confirmée (CTLD.log + mouvement DCS) ; bugfix grpName nil hors WPZ inline
- **MT-10b — AI _assignPostSpawnTask AttackNearestEnemyOnLos** : ✅ PASS live DCS [2026-05-20] — log confirme coords ennemi RED en LOS (727m, LOS=true) + mouvement troupes vers ennemi observé DCS
- **Feature T — stock par template/type AIZ (troopStock/vehicleStock tables)** : 5 fonctionnels = **58 cas** ✅ PASS (F-176 20/20 + F-177 6/6 + F-178 10/10 + F-179 11/11 + F-180 11/11 [2026-06-06]) — `parseStockTable` : isAll/init/current ; `pickMaxStock=0` gate ; `aiPickTroopTemplate` rotation : highest-stock priority, ex-aequo random, all-zero→nil, _aiTroopStock nil→legacy ; `aiConsumeTroopStock`/`aiConsumeVehicleStock` : décrément sans négatif, no-op isAll, no-op stock=-1 ; `aiRestoreTroopStock`/`aiRestoreVehicleStock` : capped at init, no-op isAll/maxS=-1/key absent ; `aiPickVehicleEntry` : nil si isAll/nil/zero, type DCS isScene=false, modèle CTLDSceneManager isScene=true, priorité stock max, stock=-1 prioritaire
- **Feature U — AI AA system deployment (spawnSystemAt + isAASystem flag)** : 2 fonctionnels = **30 cas** ✅ PASS (F-181 19/19 + F-182 11/11 [2026-06-06]) — `getTemplateByName` : 6 templates connus + inconnu→nil + nil guard ; `aiPickVehicleEntry` isAASystem : HAWK→isAASystem=true/isScene=false, FARP Alpha→isScene=true/isAASystem=false, Hummer→DCS natif ; `spawnSystemAt` : inconnu→false, limite atteinte→false, HAWK 10 unités (3ln+2tr+2sr+1pcp+2cwar) positions cercle, OnAASystemDeployed event, _completeSystems peuplé ; **MT-14 ✅ PASS live DCS [2026-06-07]** — pickup HAWK isAASystem=true confirmé, dropoff spawnSystemAt 10 unités HAWK déployées, stock 1→0 ; bugfix spawn position (computeSafeDropPos rearSector) + i18n "loaded/unloaded/delivered" sans "vehicle"
- **Mise en conformité scénarios recette — format v2** : ✅ 52 fichiers migrés [2026-06-30] — Witchcraft guard, \_RUNNING guard, do..end isolation, \_savedDebugScreenLog save/restore, `trigger.action.outText(summary, duration, true)` clearview sur tous les retours finaux. Template `_template_scenario.lua` v2.0 créé. Validé DCS live : FR all pass, F181 all pass, F-SC 11/11, MT-12 step=1 OK, MT-05 11/12 (1 FAIL pré-existant non lié).
- **MT-11 — AI troop stock pickup/dropoff (v4.0)** : ✅ PASS live DCS [2026-06-07] — pickup troopStock template, dropoff deploy troupes ; migré clone pattern [2026-07-01] : spawnClone(heliai_mt11→heliai_mt11_run), destroyClone+dropped troops en cleanup
- **MT-12 — AI vehicle native pickup/dropoff (v4.0)** : ✅ PASS live DCS [2026-06-07] — pickup vehicleStock Hummer, dropoff computeSafeDropPos rearSector ~42m derrière hélico ; migré clone pattern [2026-07-01] : spawnClone(heliai_mt12→heliai_mt12_run), destroyClone en cleanup
- **MT-13 — AI vehicle scene pickup/dropoff (v4.0)** : ✅ PASS live DCS [2026-06-07] — pickup FARP Alpha isScene=true, dropoff playScene confirmé ; migré clone pattern [2026-07-01] : spawnClone(heliai_mt13→heliai_mt13_run), destroyClone en cleanup ; layout FARP Alpha validé visuellement [2026-07-05] : Cargo06+ammo_cargo×2 orientations 90°/95° correctes, tous éléments en position ✅
- **MT-15 — Request Vehicle pur (spawn/load/unload sans crate)** : 1 scénario = **13 checks** ✅ PASS live DCS [2026-06-07] — spawnVehicleForTransport→WAITING ; findLoadableVehicles→HMMWV ; loadVehicle→LOADED (DCS unit détruite) ; findLoadedVehicles→HMMWV ; unloadVehicle→WAITING (DCS unit respawnée). Config override UH-1H canTransportWholeVehicle sauvegardée/restaurée. Visual F10 menu ✅ PASS [2026-06-07] — Request Equipment→spawn / Load Vehicle / Unload Vehicle confirmés joueur (diag_mt15_vehicle_menu_visual.lua).
- **MT-16 — Countryside FARP scène complète (load/unload/deploy)** : ✅ PASS live DCS [2026-06-08] — crate descriptor poids=1001.24 trouvé ; crate spawnée à portée ; unpack→CTLDSceneManager:playScene("Countryside FARP") ; Invisible FARP spawné→accessible Airbase.getByName() ✅ ; étiquette (T) F10 map après délai DCS normal ✅ ; warehouse zeroed (4×0L via setLiquidAmount) ✅ ; trucks+tent(t+5.1s)+gardes+lumière+windsock+carrier shooter(20m/0°/hdg90°) présents. Layout validé [2026-06-08b].
- **TODO [D] — Unified scene workflow** : ✅ PASS live DCS [2026-06-08] — 4 scènes (FOB/FARP Alpha/Countryside FARP/Mine Field) opérationnelles menu Request Equipment ; late injection Metal FARP via Witchcraft post-init : scene_model=true, weight_entry=w=1001.26, in_processedCrates=true ✅ ; architecture callback order-independent validée.
- **Metal FARP scene — layout validé live DCS [2026-06-08]** — helipad 58m, camions sous tente (t+5/t+5.5s), windsock 28m/340°, us carrier shooter 67m/2° hdg90°, warehouse 10000L×4. CTLDPlayerManager.deferMenuSection() fix init-order.
- **Mine field demine menu [2026-06-08]** — drawQuad retourne markId, _sets tracking, buildDemineSection/refreshDemineSection, clearSet, demineRadius=150, onLand generic refreshMethod loop.
- **TODO [P] — Recette scènes CtldScene** : 4/4 sous-cas ✅ PASS live DCS [2026-06-28] — (P1) FOB F10 step 21 → `_registerDeployedFOB` LGZ+beacon ✅ ; (P2) FOB parachute guard block (LGZ fictive) + auto-unpack → FOB enregistré ✅ ; (P3) CS FARP parachute `_checkAutoUnpack` → `playSceneAtPos` chemin generic ✅ ; (P4) Metal FARP F10 `addLiquid` warehouse (skip propre si mod absent) ✅. Scripts : `scenario_fob_scene.lua` (fixé), `scenario_p2_fob_parachute.lua`, `scenario_p3_csfarp_parachute.lua`, `scenario_p4_metal_farp.lua`.
- **TODO [I]+[Q] — FARP Repack** : `scenario_farp_repack.lua` **12/12 PASS** live DCS [2026-06-28] — `playSceneAtPos` CS FARP démarre ✅ ; `_modelName="Countryside FARP"` dans `_active` ✅ ; `findNearbyRepackableScenes(300m)` trouve la scène ✅ ; `packScene` retire `_active[name]` ✅ ; `repackData` table retournée ✅ ; `warehouseSnapshot` nil (mod absent) → comportement attendu ✅ ; `crate.metadata.warehouseSnapshot` assigné + `liquid[0]` numérique ✅ ; `scene._params.repackData.warehouseSnapshot.liquid[0]==7777` transmis via `playSceneAtPos` ✅.
- **warehouse_cycle — TODO[I]+[Q] cycle complet live DCS [2026-06-28]** : `scenario_warehouse_cycle.lua` **3/3 PASS** — setup enableFARPRepack + cratesRequired=1 ✅ ; crate présente + snapshot metadata ✅ ; fuel 5k/10k/15k/20k restauré sur CS_FARP-26 ✅. Bugfixes validés : `getLiquidAmount` (API correcte), menu Pack FARP conditionnel, `findPackableVehicles` guard `if uName then`, `enableFARPRepack` non restauré par cleanup scénario.
- **Bugfixes menu crates live DCS [2026-06-30]** : ✅ PASS — `scenario_crate_menu_sol_vol_visual.lua` 5/5 PASS live DCS — Pack Equipt sol uniquement (setBranchEnabled+clearBranch) ; Parachute Crates vol uniquement ; menu sol restauré après atterrissage. Fixes validés : `findPackableVehicles` (veh.spawnData.unitName) ; `_isFlying` flag onTakeoff/onLand ; `overrideInAir` param `refreshCrateFlightSection`/`refreshPackEquiptSection` ; `addSubMenu` idempotent met à jour order+enabled (`CTLD_menu.lua`) ; dead code `CTLDTroopManager:buildMenu` (missionCommands brut) supprimé.
- **F-183/F-184/F-185 — Troop Commands menu sol/vol/sol** : ✅ PASS 5/5 live DCS [2026-06-30] — `scenario_troop_menu_sol_vol_visual.lua` — F-183 sol (Embark visible, Parachute absent) ✅ ; F-184 vol (Parachute Troops visible) ✅ ; F-185 sol restauré (Embark visible, Parachute absent) ✅.
- **pilotPassive — scenario_unpack_jtac_drone (DRONE.1/2/V1/V2/V3/V4)** : 6/6 PASS [2026-07-01] — lifecycle MQ-9 complet : spawn crate → unpack → orbit initial → autoLase → target RED lasé → target détruit → drone retour orbit initial (795s)
- **pilotPassive — scenario_weight_aggregation (F-WGT.1→4)** : 4 checks ✅ PASS [2026-07-01] — `ctld.utils.updateTransportWeight` agrège correctement troupes+crates+véhicules : 320→2820→2500→0 kg
- **pilotPassive — scenario_ai_transport_visual (AI-VIS)** : 6/6 PASS [2026-07-04] — `CTLDCoreManager:onAILand()` direct call : clone AI heli spawné via `env.mission`+`coalition.addGroup`, `getAIPickupZoneAt(isAIPickup=true)` résolution dynamique, embarquement 5 troupes, hasTroops=true ; note: `coalition.addGroup` helis toujours airborne → `S_EVENT_LAND` absent → solution: appel direct `onAILand` +2s
- **pilotPassive — scenario_ai_goto_wpz v3.0 (FI-WPZ)** : 6/6 PASS [2026-07-01] — `_assignPostSpawnTask(gotoNearestWPZ)` : CTLDZoneManager dispo, `getNearestWaypointZone` mock WPZ, groupe spawné, task loggée dans CTLD.log
- **pilotPassive — scenario_ai_attack_enemy v3.0 (FI-ATK)** : 6/6 PASS [2026-07-01] — `_assignPostSpawnTask(AttackNearestEnemyOnLos)` : RED target spawné, BLUE group spawné, task loggée `AttackNearestEnemyOnLos` dans CTLD.log
- **MT-10 — AI post-spawn task gotoNearestWPZ + AttackNearestEnemyOnLos (pilotPassive v4.0)** : 6 steps = **23/23 PASS** ✅ live DCS [2026-07-01] — spawn clones via `env.mission`+`coalition.addGroup` (`lateActivation=false`), two-phase waitFor pickup→dropoff (timeout 900s), `scanLogAfter(MARKER_A/B)` évite contamination anciens runs, cleanup détruit clones+troupes déposées ; répétable sans redémarrage mission
- **pilotPassive — scenario_extract_menu v3.0 (EXTRACT-MENU)** : 7/7 PASS [2026-07-04] — F-145 (1 groupe: direct Extract command) + F-146 (2 groupes: subMenu Extract from field avec annotations distance) — mock-based
- **pilotPassive — scenario_multigroup_transport v3.0 (MG-TRANSPORT)** : 15/15 PASS [2026-07-04] — F-140/141 (single vs multi-group menu), F-142/143 (disembarkAll + disembarkIndex), F-144 (_menuCheckCargo TOTAL line) — mock-based
- **pilotPassive — scenario_jtac_crate_pack v3.0 (PACK_JTAC F-132)** : ALL PASS [2026-07-04] — startLase+registerJTACVehicle, F-132.1-6: JTAC enregistré+lasing+laserCode, packVehicle → deregisterJTAC appelé, JTAC retiré
- **pilotPassive — scenario_feature_k_jtac_vehicle v3.0 (FEAT-K)** : ALL PASS [2026-07-04] — F-125 (JTAC spawned+registered+IN_TRANSIT après load), F-126 (parachuteVehicle → WAITING + JTAC intact), F-127 (transport destroy → JTAC deregistered + vehicle purged)
- **pilotPassive — scenario_feature_f_recon_farp v3.0 (FARP)** : 4 steps ALL PASS [2026-07-04] — F-150 (CTLDStaticWatcher watch/unwatch/tick), F-151-153 (renderer coalition param), F-154-157 (_syncFarpMarks mock FARP+FOB, dedup, clearFarpMarks), F-158 (onDeadFn) ; inject_red_fob.lua requis pour F-155
- **pilotPassive — scenario_ai_troops v3.0 (MT-07 single-injection)** : 9/9 PASS [2026-07-04] — init AIZ zones, hasTroops=false initial, pickup auto `AIZ_base_B_P_5` (8 soldats Anti Tank), dropoff auto `AIZ_front_B_D` ; waitFor pattern injection unique
- **pilotPassive — scenario_p2_fob_parachute v3.0 (P2-FOB-PARA)** : 6/6 PASS [2026-07-04] — P2.1 (FOB descriptor), P2.2 (3 crates LANDED+fromParachute), P2.3 (guard LGZ bloque auto-unpack), P2.4-P2.6 (FOB enregistré+isAlive+integrity 100%) ; note: ctld_test.lua requis ; v3.0 contourne le blocage LGZ réelle via `_logisticZones={}`
- **pilotPassive — scenarioTroopsFullCycle_v2 (TFC)** : 8 steps ALL SUCCESS [2026-07-04] — S1 spawn RED+template, S2 TRZ_LOADED, S3-S4 deploy+re-embark (2 JTACs lasing+deregister), S5-S6 re-deploy+JTAC mort (target freed), S7 destruction successive+reacquisition, S8 cleanup ; note: zone TRZ_alpha non nécessaire (commentaire obsolète)
- **TODO-MENU-1/2/3 — Bugfixes menu F10** : ✅ PASS live DCS [2026-07-05] — (1) CH-47 smoke bug : click "Drop Crate(s)" → crates déposées, plus de smoke bleue parasite (debounce 150ms `deferredRefreshForGroup` + `_noRefresh` parameter) ; (2) Request Equipment éjection : navigation "Both → Countryside FARP - All crates" stable, 3 crates spawned correctement (`_lgzGroundPoll` zone-change-only via `_lgzKey`) ; (3) Menu post-scene : "Pack Countryside FARP" apparaît sans décoller/atterrir (`onComplete` → `refreshUnpackSectionForUnit`).
- **TODO-MENU-4 — Cycle infini Countryside FARP + mémoire warehouse** : ✅ PASS live DCS [2026-07-05] — cycle complet : Request Equipment → 3 crates FARP → load CH-47 → unpack → FARP déployé → Pack Equipt → crates respawnées (warehouseSnapshot) → reload → re-unpack → FARP redéployé avec stock warehouse restauré. Cycle répétable sans limite.
- **F-TL — JTAC toggleStandby (Toggle Lasing)** : **12/12 PASS** ✅ live DCS [2026-07-05] — `toggleStandby` : basculement `standbyMode` ON/OFF, arrêt/reprise lasing, labels dynamiques menu (`[Pause Lasing]`/`[Resume Lasing]`), messages confirmation capturés via mock `outTextForGroup`, `_rebuildJTACCommandBranch` appelé ; mock JTAC sans unité DCS réelle
- **Re-recette MT-07→MT-10 Feature S [2026-07-05]** : ✅ 56/56 PASS (debug mode, mission accélérée) — MT-07 7+7 PASS (clone AI, pickup Anti Tank 8 soldats, disembark AIZ_front_B_D) ; MT-08 12/12 PASS (Hummer load/unload, canTransportWholeVehicle) ; MT-09 14/14 PASS (troupes+Hummer TV, dropoff) ; MT-10 23/23 PASS (gotoNearestWPZ + AttackNearestEnemyOnLos, scanLogAfter MARKER A/B) — zones chargées via `_loadAIZonesFromConfig()` (Feature S native)
- **Total** : **669 cas** — 1501/1501 PASS ✅ + MT-06 9/9 PASS + MT-07 4/4 PASS + MT-08 4/4 PASS + MT-09 4/4 PASS + MT-10 23/23 PASS (pilotPassive) + MT-11 PASS + MT-12 PASS + MT-13 PASS + MT-14 PASS + MT-15 13/13 PASS + MT-16 PASS + TODO[D] PASS + Metal FARP layout PASS + Countryside FARP layout PASS [2026-06-08b] + U-106/U-107/U-108 (ModValidator) 12/12 PASS + TODO[P] 4/4 PASS [2026-06-28] + TODO[I+Q] 12/12 PASS [2026-06-28] + warehouse_cycle 3/3 PASS [2026-06-28] + CMFV menu sol/vol/sol 5/5 PASS live DCS [2026-06-30] + TMFV Troop Commands menu sol/vol/sol 5/5 PASS live DCS [2026-06-30] + F-WGT 4/4 PASS + FI-WPZ v3.0 6/6 PASS + FI-ATK v3.0 6/6 PASS [2026-07-01] + AI-VIS 6/6 PASS [2026-07-04] + TODO-MENU-1/2/3 PASS + TODO-MENU-4 (CS FARP cycle) PASS [2026-07-05] + Feature S re-recette MT-07→MT-10 56/56 PASS [2026-07-05]

---

## Recettes restantes à générer

| Module | Fichier source | Priorité | Notes |
| --- | --- | --- | --- |
| ~~**CTLD_config.lua**~~ | ~~`src/CTLD_config.lua`~~ | ~~Basse~~ | ✅ Recette complète [2026-04-16] — U-84→U-89 + F-101→F-102 |
| ~~**CTLD_i18n.lua**~~ | ~~`src/CTLD_i18n.lua` + `CTLD_i18n_en.lua`~~ | ~~Basse~~ | ✅ Recette complète [2026-04-16] — U-90→U-96 + F-103→F-105 |
| ~~**CTLD_farpScene.lua**~~ | ~~`src/scenes/CTLD_farpScene.lua`~~ | ~~Moyenne~~ | ✅ Recette complète [2026-04-14] — F-91 22/22 PASS (bugfix stepsDatas→steps) |
| ~~**CTLD_fobScene.lua**~~ | ~~`src/scenes/CTLD_fobScene.lua`~~ | ~~Moyenne~~ | ✅ Recette complète [2026-04-14] — F-90 18/18 PASS |
| ~~**Feature D — LoadableGroups**~~ | ~~`src/CTLD_troop.lua`~~ | ~~Haute~~ | ✅ Recette complète [2026-04-14] — U-76→U-80 + F-88→F-89 |
| ~~**Q1 — Legacy API**~~ | ~~`src/legacy/legacy_api.lua`~~ | ~~Haute~~ | ✅ Implémenté + recetté [2026-04-15] — 22 wrappers + packVehicle + spawnCrate, U-81→U-83 + F-94→F-99, 148/148 PASS |
