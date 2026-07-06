# DCS-CTLD Modernization Plan

> **This is the single source of truth for all ongoing work.**
> Status: **✅ PUBLISHED** | PR dev→master ouvert [2026-07-06] | Version: CTLD v2.0.0

---

## Vision

Rewrite CTLD as a modern, modular, and testable Lua project while
preserving backward compatibility with existing missions.
Deliverable: single `.lua` file produced by `tools/build/merge_CTLD.ps1`.

---

## Architectural decisions

| # | Topic | Decision |
| - | ----- | -------- |
| 1 | Module split | ✅ **Done** — `src/` files concatenated → `CTLD_Next.lua` by `tools/build/merge_CTLD.ps1`. Order: `tools/build/listToMerge.txt` |
| 2 | OOP | ✅ **Done** — `src/core/class.lua` created (P1). All entity classes refactored. |
| 3 | MIST | ✅ **Done** — all `mist.*` calls replaced by `ctld.utils.*`. No active `mist.*` call in `src/` |
| 4 | Legacy API | ✅ **Done** — `src/legacy/legacy_api.lua` (22 wrappers, thin delegates) [2026-04-15] |
| 5 | Lua env | Lua 5.1 DCS sandbox, desanitized server (`io`, `os`, `lfs` accessible) |
| 6 | Testing | ✅ **Done** — busted infrastructure in `tests/helpers/` + `tests/specs/` + CI job [2026-04-15] |
| 7 | Docs | ✅ **Done** — `docs/missionmaker_guide.md` (§1–16) + `docs/dev-guide.md` [2026-04-15] |
| 8 | i18n | ✅ **Done** — `src/CTLD_i18n*.lua` (EN/FR/ES/KO), `ctld.tr()` at all sites, generator `tools/build/generate_i18n_dicts.ps1` |
| 9 | Branching | Feature branches `feature/<description>`. `master` stays stable |
| 10 | Events | ✅ **Done** — 38 CTLD events specified. EventDispatcher ✅. CTLDDCSEventBridge ✅. StateManager + Coalition supprimés (absorbés par managers). C1 impl ✅ [2026-04-02]. |
| 11 | Scenes | ✅ **Done** — `src/scenes/` (9 files). Auto-register via `CTLDSceneManager.getInstance():registerSceneModel(...)` |
| 12 | Registry | ✅ **Done** — `src/core/CTLD_objectRegistry.lua` relocated. Scope: spawn descriptors + scenes only. |
| 13 | Core bridge | ✅ **Done** — `CTLDDCSEventBridge` + `CTLDPlayerTracker` specs validated. C1 impl ✅ [2026-04-02]. |
| 14 | Review | Ongoing — for every implemented file: analyse → propose improvements → validate → fix before moving on |

---

## Progress overview

| Phase | Description | Status |
| ----- | ----------- | ------ |
| **0** | Specification & Architecture | ✅ 100% — all events + features specs done |
| **1** | Dead code cleanup (`source/`) | ✅ Done — 9 fichiers redondants supprimés, 3 références conservées [2026-04-16] |
| **2** | Module split + OOP (`src/`) | ✅ 100% — impl + recette + Q1–Q5 ✅ [2026-04-16] |
| **3** | MIST middleware | ✅ Done |
| **4** | Legacy API compatibility | ✅ Done — src/legacy/legacy_api.lua, 22 wrappers [2026-04-15] |
| **5** | Unit tests (busted) | ✅ Infrastructure done — tests/helpers/ + tests/specs/ + CI job [2026-04-15] |
| **6** | CI infrastructure | ✅ Done — `.github/workflows/ci.yml` (lint + build + busted + release + docs) [2026-04-16] |
| **7** | i18n cleanup + tooling | ✅ Done |
| **8** | Documentation | ✅ Done — missionmaker_guide.md (§1–16) + dev-guide.md [2026-04-16] |

---

## PRIORITY ORDER — Next steps

```text
── FONDATIONS IMPLÉMENTÉES, RECETTE COMPLÈTE ─────────────────────────────────
✅ P1  src/core/class.lua + objectRegistry          recette: N/A (lib interne)
✅ C1  src/CTLD_core.lua                           recette: 9/9  100% [2026-04-02]
✅ M1  src/CTLD_zone.lua                           recette: 9/9  100% [2026-04-02]
✅ M2  src/CTLD_beacon.lua                         recette: 5/5  100% [2026-04-02]
✅ M3  src/CTLD_recon.lua                          recette: 5/5  100% [2026-04-02]
✅ M4  src/CTLD_fob.lua                            recette: 4/4 + F-90/F-93 visual ✅ 100% [2026-04-14]
✅ M5  src/CTLD_vehicle.lua                        recette: 10/10 100% [2026-04-07]
✅ M6  src/CTLD_aasystem.lua                       recette: 6/6  100% [2026-04-07]
✅ M7  src/CTLD_player.lua                         recette: 7/7  100% [2026-04-07]

── IMPLÉMENTÉS — RECETTE MANQUANTE ──────────────────────────────────────────
✅ R1  src/CTLD_crate.lua  (CTLDCrate + CTLDCrateManager)
       recette: 11/11  100% [2026-04-07]
       bugfixes: getDistance caller manquant dans getCratesInRange + checkAssemblyReady

✅ R2  src/CTLD_troop.lua  (CTLDTroopGroup + CTLDTroopManager)
         Old recette: 8/8  100% [2026-04-07] (basic lifecycle — PRE-refactor)
         Refactor done [2026-05-02]: terminologie + états rename + _aliveUnits/_jtacUnits +
         S_EVENT_DEAD sync + deregisterJTAC × N + multi-JTAC + orphan cleanup
         New recette: `live_tests/scenarios/scenarioTroopsFullCycle_v2.lua` (8 steps) — ✅ 8/8 PASS [2026-05-04]
         Re-validated: startLaseTroopUnit unit-keyed path — ✅ 8/8 PASS [2026-05-04]
         Validated: BUG-02 (wasJtac before _removeDeadUnit), BUG-03 (_syncFromDCSGroup real DCS names), BUG-04/06/07/08
         ✅ BUGFIX: menu "Load from X" — (A) libellé [2026-05-04]
               Affiche désormais "TRZ_" .. zoneName (ex. "TRZ_pz1") : court et sans ambiguïté avec une LGZ.
               Le callback conserve `zoneName` (nom court) pour getTroopZone().
         ✅ BUGFIX RESOLVED: menu "Load from X" — (B) filtre LGZ_ absent
               Non-issue : getTroopZonesForCoalition() itère uniquement _troopZones (table distincte
               de _logisticZones). Une LGZ ne peut structurellement pas apparaître dans le menu troops.
               La note PENDING était préventive — confirmé par lecture code [2026-05-12].

✅ R3  src/CTLD_jtac.lua  (CTLDJTAC + CTLDJTACManager)
       recette: 8/8  100% [2026-04-07]
       ✅ BUGFIX: JTAC troop unit-level lasing [2026-05-05]
         Les JTACs des groupes de troupes sont suivis et gérés AU NIVEAU UNITÉ (unitName),
         et non au niveau groupe DCS (groupName), car ils font partie d'un groupe composite
         multi-unités (inf + jtac ensemble). Conséquence :
           • `startLase(groupName)` → `spawnJTAC` → `Group.getByName(groupName)` → nil (unitName ≠ groupName)
             Le lasing ne démarrait jamais sur un disembark de troupes.
           • `_autoLaseLoop` : `dcsGroup:getUnits()[1]` cible la mauvaise unité.
           • `deregisterJTAC(jtacName)` dans embarkFromField/returnToTroopZone : sans effet
             car jtacs[unitName] n'existait jamais.
         Corrections :
           • `CTLDJTAC:init()` : nouveau champ `unitName` (nil = group-keyed, set = unit-keyed)
           • `CTLDJTACManager:startLaseTroopUnit(unitName)` : nouvelle méthode unit-keyed
             (Unit.getByName, jtacs[unitName], loop via _autoLaseLoop)
           • `_autoLaseLoop` : branche unitName → Unit.getByName() ; mort = return nil sans killJTAC
             (S_EVENT_DEAD → onUnitDead → deregisterJTAC gère déjà la mort)
           • `disembark()` : startLase(jtacName) → startLaseTroopUnit(jtacName)
           • `_autoLaseLoop` (groupStopMoving) : `dcsGroup` portée locale au bloc else — hors portée
             à la ligne groupStopMoving → nil crash. Fix : `jtacUnit:getGroup()` (fonctionne pour les
             deux chemins, unit-keyed et group-keyed).
           • `CTLDCoreManager:_initMMJTACs()` : `group:isActive()` non défini sur les groupes créés
             dynamiquement (coalition.addGroup). Fix : pcall avec fallback `true`.

✅ R4  src/CTLD_sceneManager.lua  (CTLDSceneManager)
       recette: 7/7  100% [2026-04-14]
         U-43: singleton + registerSceneModel  9/9
         U-44: CtldScene step execution engine  8/8
         F-42: playScene guards  4/4
         F-43: FARP Alpha structure validation  11/11
         F-44: fobScene self-registration  10/10
         F-90: fobScene structure + spawn visuel  18/18 PASS ✅ [2026-04-14]
         F-91: farpScene structure + spawn visuel  24/24 PASS ✅ [2026-04-14]
         bugfix: CTLD_farpScene.lua — stepsDatas→steps, polar.dist→polar.distance, prescript 50m ref point
         F-92: FOB beacon au centroid (overridePosition)  13/13 PASS ✅ [2026-04-14]
         bugfix: CTLD_beacon.lua — dropBeacon overridePosition param (supprime getPointAt12Oclock inexistant)
         bugfix: CTLD_fob.lua — beacon spawné au centroid FOB, pas sous le transport
         F-93: FOB flow complet (fobScene + beacon)  visual ✅ [2026-04-14]

✅ R5  src/CTLD_menu.lua + CTLD_player.lua + tous managers  (buildMenu Option D)  [2026-04-08]
       Architecture: registerMenuSection() + configKey gateway + order sort
       Fix: CTLDTroopManager._instance migré de local→public + init() appelé dans getInstance()
       Recette: F-48→F-56 45/45 PASS ✅ + F-45→F-47 visual checks ✅ 3/3 PASS [2026-04-08]

── FEATURES À IMPLÉMENTER ───────────────────────────────────────────────────
✅  FD  Feature D — Custom LoadableGroups API (CTLDTroopManager)
        implémenté dans _registerTemplates() — validé R2 [2026-04-07]

✅  FC  Feature C — MM crate detection (INIT-B OnMMCrateDetected)
        registerMMCrate() + OnMMCrateDetected ajouté — validé F-41 [2026-04-07]

✅  FE  Feature E — CTLD log file dédié (ctld.utils.log → ctld.log)
        implémenté dans CTLD_utils.lua (initLog/log/closeLog/reopenLogAppend) [2026-04-07]

✅  FA  Feature A — Virtual parachute (crates + troops + vehicles)  [2026-04-08]
        CTLDParachuteEffect + NullParachuteEffect (src/core/)
        ctld.utils.calcDropPosition() ajouté (CTLD_utils.lua)
        8 params parachute + canParachute dans unitActions (CTLD_config.lua)
        parachuteCrates/Troops/Vehicle() + menus F10 conditionnels (canParachute)
        spawnVehicleAt() ajouté à CTLDVehicleSpawner
        Recette FA: F-57→F-64 33/33 PASS ✅ [2026-04-08]
        Fix: groupName→templateName, vehicle:transit()→setState(DELIVERED), carrierUnitName→loadTransportName

✅  FB  Feature B — Virtual slingload  [2026-04-08]
        CTLDCrateManager: checkHoverStatus() polling 1s, releaseSlingload(), cutSlingload()
        canSlingload dans unitActions, maxSlingloadSpeed param, inTransitOnSlingload flag
        P1 overspeed loss, P3 Release/Cut menus distincts, P2 inertia drift (calcDropPosition)
        Recette FB: F-65→F-71 22/22 PASS ✅ [2026-04-08]

── FEATURES EN ATTENTE ──────────────────────────────────────────────────────
✅  FG  DCS native cargo detection — CTLD polling to detect std DCS load/unload
        No S_EVENT_CARGO_LOADED/UNLOADED in DCS API. Implemented in
        CTLDCrateManager:_checkNativeDCSCargo() called from checkHoverStatus() (1 s tick).
        LOAD: dcsStatic altitude rises > 3 m AND dynamic transport within 15 m.
        UNLOAD: crate.state LOADED, dcsStatic still alive (CTLD loads nil-ify it),
        distance from transport > 15 m. Publishes OnCrateLoaded/OnCrateUnloaded
        with method="dcs_native". Refreshes Unpack/LoadCrate/RequestEquipment menus.
        [2026-04-22]

✅  FG  JTAC drone orbit lifecycle — deployAirJTAC + initialRoute + autoOrbit + restore [2026-04-25]
        CTLDJTACManager:deployAirJTAC() spawns MQ-9/drone, isFlying detected via _tryInitFlying()
        with T+2s retry (DCS 1s spawn delay). _setOrbitRoute() builds 8-WP circular Mission route
        (SwitchWaypoint on rotated[n] for full-circle coverage). _updateOrbit() branches:
          • target acquired → GROUP pushTask(Circle) → onTargetOrbit=true (ORBITING)
          • target lost     → GROUP popTask() + GROUP setTask(initialRoute) → IDLE
        Validated F-106 [2026-04-25] via Witchcraft: full circle restoration confirmed.

✅  FG  FOB construction scene — animated build sequence (120 s) [2026-04-14]
        Implemented in CTLD_fobScene.lua: 20 timed steps over 120 s —
        crane + workers (fh1/fh2/fh3) + progressive structure spawns,
        transition props cleaned up at T+120. Validated F-90/F-93 live DCS.

✅  FG  STEP 1 — Factorisation rôle JTAC : isJTAC descriptor + suppression _jtacUnitTypes [2026-04-25]
        Périmètre :
          1. Ajouter isJTAC=true sur Hummer (1001.01) et SKP-11 (1001.11)
          2. Remplacer _isJTACUnitType(crate.unit) par crate.isJTAC==true dans le menu builder
             Pour les multi-crates (pas de champ unit): _multiIsJTAC(multiple) = true si au moins
             un weight de la liste résout vers un descriptor avec isJTAC=true (via findDescriptorByWeight)
          3. Supprimer _jtacUnitTypes locale + CTLDCrateManager:_isJTACUnitType()
          4. Supprimer jtacUnitTypes de ctld_config.lua + section userConfig (ou marquer deprecated)
        Priorité : HAUTE — prérequis pour les recettes JTAC sol

✅  FG  STEP 2 — Bug troop JTAC : hasJtac → startLase non implémenté en OOP [2026-04-26]
        Fix: CTLDTroopManager:deploy(), si group.hasJtac → CTLDJTACManager:startLase()
        Recette: scenario_troop_jtac.lua — 2/2 PASS [2026-04-26]

✅  FG  STEP 3 — JTAC InTransit : suspend/resume cycle + Request JTAC Vehicle menu [2026-04-27]
        Implémentations :
          • setJTACInTransit() appelé dans loadVehicle avant destroy/suspend
          • _autoLaseLoop : check IN_TRANSIT AVANT Group.getByName (anti-faux killJTAC)
          • deregisterJTAC() : silencieux, sans OnJTACDead — appelé dans packVehicle avant destroy
          • resumeJTAC() : relance autoLaseLoop après unload, laser code préservé
          • spawnJTACVehicleForTransport() : spawn + startLase combiné
          • registerJTACVehicle() : enregistre un véhicule JTAC externe dans CTLDVehicleSpawner
          • Menu F10 "Request JTAC Vehicle" : sous JTAC Commands, par coalition (JTAC_unitTypeNames)
          • JTAC_droneRadius + JTAC_droneAltitude + JTAC_unitTypeNames dans bloc [9] config
        Crates JTAC confirmées isJTAC=true (parité legacy jtacUnitTypes "SKP","Hummer","MQ","RQ") :
          • weight=1001.01 Hummer - JTAC        (unit="Hummer",        side=2, isJTAC=true)
          • weight=1001.11 SKP-11 - JTAC        (unit="SKP-11",        side=1, isJTAC=true)
          • weight=1006.01 MQ-9 Reaper - JTAC   (unit="MQ-9 Reaper",   side=2, isJTAC=true)
          • weight=1006.11 RQ-1A Predator - JTAC (unit="RQ-1A Predator", side=1, isJTAC=true)
        ✅ F-110: config JTAC_unitTypeNames — 8/8 PASS [2026-05-07] (assertions MQ-9/RQ-1A retirées : non dans JTAC_unitTypeNames)
        ✅ F-111: spawnJTACVehicleForTransport + registerJTACVehicle + deregister — 6/6 PASS [2026-04-27]
        ✅ F-112: deregisterJTAC anti-false-KIA + laser pool freed + idempotent — 7/7 PASS [2026-04-27]
        ✅ F-113: virtual load/unload suspend+resume — FERMÉ [2026-06-28] : parachutage des crates chargées via UI DCS std exclu par conception (CTLD-loaded only) ; cas C-130 hors périmètre.
        ✅ F-114: DCS native bbox load/unload — FERMÉ [2026-06-28] : même décision que F-113 ; Sprint 2a couvre le bbox CTLD (F-128→F-131 ✅).

✅  FG  Troop lifecycle rewrite — terminologie, états, transitions [2026-05-02]
         Schema: `docs/assets/troops_jtac_lifecycle.svg`
         Terminologierename :
           • loadFromZone() / load()         → embarkFromTroopZone()
           • deploy() / unload()             → disembark()  (alias `deploy = disembark` pendant transition)
           • extract()                       → embarkFromField()
           • returnToBase()                 → returnToTroopZone()
           • dispatchToEXZ() (cas spécial)  → dispatchToEXZ() (inchangé)
         États rename :
           • LOADED      → TRZ_LOADED  (virtual, pas de DCS group)
           • EXTRACTED   → FIELD_LOADED (DCS group destroy, mémoire préservée)
           • RETURNED_TO_PICKUP → RETURNED_TO_TRZ
           • DEPLOYED (silent) → DEPLOYED_EXZ (comptage flag, pas de spawn)
         CTLDTroopGroup:_aliveUnits map[unitName] = dcsUnit (référence DCS, pas index)
         CTLDTroopGroup:_jtacUnits map[unitName] = true (JTAC units only)
         S_EVENT_DEAD sync : CTLDTroopManager:onUnitDead() + _findGroupByAliveUnit()
           met à jour _aliveUnits / _jtacUnits à chaque mort d'unité dans un deployed group
           + deregisterJTAC() si l'unité était un JTAC.
         Bridge: CTLDDCSEventBridge → CTLDTroopManager:onUnitDead() (world.event.S_EVENT_DEAD)
         [2026-05-02]

✅  FG  Multi-JTAC per troop group — N instances instead of boolean [2026-05-02]
         template jtac=N → N JTAC instances on disembark()
         CTLDTroopGroup._jtacUnits = { [unitName] = true } — populated on disembark()
         CTLDTroopManager:disembark() :
           1. group:hasAliveJtac() (ex-boolean hasJtac)
           2. loop sur _jtacUnits → startLase() × N par unité JTAC
         preLoadTransport : _aliveUnits / _jtacUnits construits depuis template (suppression hasJtac)
         [2026-05-02]

✅  FG  JTAC lifecycle in troop transitions — deregisterJTAC on all exit paths [2026-05-02]
         embarkFromField() (FIELD_LOADED) :
           → loop sur _jtacUnits → deregisterJTAC() × N AVANT group:destroy()
           → sinon S_EVENT_DEAD trigger killJTAC() (fausse mort combat)
         returnToTroopZone() :
           → loop sur _jtacUnits → deregisterJTAC() × N AVANT de niler _inTransit[unitName]
           → sinon JTAC zombies dans CTLDJTACManager.jtacs
         disembark() after FIELD_LOADED :
           → startLase() × N pour chaque JTAC alive dans _jtacUnits (1ère fois)
         [2026-05-02]

✅  FG  Transport destroyed with FIELD_LOADED troops — orphan JTAC cleanup [2026-05-02]
         Contexte : transport détruit en vol → cleanupDeadTransports() nil _inTransit[unitName]
         Solution : cleanupDeadTransports() boucle sur _inTransit[deadUnit]._jtacUnits
           → deregisterJTAC() pour chaque JTAC avant de niler _inTransit[unitName]
         [2026-05-02]

✅  FG  TROOPS — Refonte complète CTLDTroopGroup/CTLDTroopManager [2026-05-06]
        Regroupe 4 évolutions identifiées + 4 bugs critiques découverts en révision de code.

        A. Terminologie actions / états — clarification
           Actions (transitions) :
             embarkFromTroopZone()   = charger depuis une TRZ (au sol dans zone)
             disembark()             = déposer sur le terrain (fast-rope / ground drop)
             embarkFromField()       = récupérer depuis le terrain (group DCS existant)
             returnToTroopZone()     = ramener à la TRZ (restaure le stock)
             dispatchToEXZ()         = dépôt silencieux dans une EXZ_ (flag++)
           États CTLDTroopGroup.STATE :
             TRZ_LOADED    = à bord, chargé depuis TRZ (aucun DCS group)
             DEPLOYED      = au sol en tant que DCS group actif
             FIELD_LOADED  = à bord, récupéré depuis le terrain (DCS group détruit, mémoire préservée)
             DEPLOYED_EXZ  = dépôt silencieux EXZ_ (aucun DCS group, flag incrémenté)
             RETURNED_TO_TRZ = retourné à la TRZ, instance à discarder
           Note: supprimer STATE.EXTRACTED (n'existe pas dans l'enum, cf. BUG-01 ci-dessous).

        B. Multi-JTAC : identification fiable post-spawn
           Problème : _jtacUnits utilise des noms de slot template ("JTAC Group 2_u5") qui
           ne correspondent pas aux noms DCS réels après coalition.addGroup → startLase() échoue.
           Solution : après disembark() + _syncFromDCSGroup(), identifier les JTACs par le
           namePrefix "JTAC" des unités DCS (convention définie dans _registerOneTemplate) et
           reconstruire _jtacUnits avec les vrais noms DCS. Supprimer le mécanisme true→gname
           dans _syncFromDCSGroup (source d'incohérence de valeur dans la map).

        C. Mémoire de groupe après embarkFromField (field pickup préserve l'état)
           embarkFromField() doit reconstruire _aliveUnits/_jtacUnits depuis les unités DCS
           vivantes au moment du pickup, PAS depuis le template d'origine.
           → Group avec 2 JTAC dont 1 mort → field pickup → CTLDTroopGroup avec 1 seul JTAC.
           → Disembark suivant : respawn uniquement les unités encore vivantes.
           Actuellement : templateName est mis à gname (nom DCS), pas au nom template d'origine.
           Fix : préserver templateName = _droppedTemplates[nearest.groupName] → nom template.
           Fix : poids = somme des vrais poids rôles des unités restantes (pas 130 kg flat).

        D. Multi-JTAC : aucun lasing de la même cible par deux JTACs simultanés (option)
           Config : JTAC_noSameTargetLasing (bool, défaut false).
           Si true : avant startLase(), CTLDJTACManager vérifie si la target potentielle
           est déjà lasée par un autre JTAC du même groupe (ou de tout groupe).
           Chaque JTAC cherche alors une target non encore lasée à portée.
           Faisabilité DCS : vérifier si plusieurs Spot sur la même Unit sont possibles
           → si oui, le flag est utile ; si DCS rejette silencieusement le 2e Spot, c'est un
           bug natif hors périmètre. À vérifier sur Hoggit avant implémentation.

✅  FG  JTAC menu toggles — Toggle Lasing + laseSpotCorrections [2026-05-13]
        toggleStandby + toggleSpotCorrections + _rebuildJTACCommandBranch + _buildJTACCommandsForGroup
        Labels dynamiques [activate]/[deactivate], i18n EN/FR/ES/KO, confirmation outText.
        Recette : F-TL 12/12 PASS + F-SC 11/11 PASS (scénarios auto Witchcraft)

✅  FG  JTAC InTransit — recettes live manquantes (modules requis) — FERMÉ [2026-06-28]
        F-113 + F-114 fermés : parachutage crates DCS native exclu par conception (CTLD-loaded only).
        Décision MM-placed vehicle [2026-05-06] :
          • Les caisses posées par le MM sont du décor — CTLD ne peut pas connaître leur contenu
            (même type de static pour tous les objets DCS transportables).
          • Traitement : considérées comme caisses vides, aucun hook JTAC au load.
          • CTLDVehicleSpawner._checkNativeLoading ne tentera pas de détecter isJTAC sur MM crates.

✅  FG  GAP-1 — Load / Unload vehicle menu  [2026-04-30]
         findLoadableVehicles + refreshLoadSection + findLoadedVehicles + refreshUnloadSection
         buildMenuSection : deux sous-menus dynamiques (pattern refreshPackSection)
         JTAC : setJTACInTransit / resumeJTAC déjà dans loadVehicle / unloadVehicle
         Refresh : OnVehicleLoaded / OnVehicleUnloaded + _refreshNearbyPackPlayers étendu
         i18n : 6 clés EN/FR/ES/KO ajoutées
         Recette : F-120 (9/9) + F-121 (6/6) + F-122 (6/6) = 21/21 PASS — UH-1H
         Bugfix [2026-04-29] : UH-1H + Mi-8 ajoutés vehicleTransportEnabled ; _dispatchPostSpawn
         enregistre les véhicules GROUND dans CTLDVehicleSpawner (F-123 2/2 PASS)
         Fix [2026-04-30] : _spawnUnpacked — après registerJTACVehicle, appel de
         refreshLoadSectionForUnit + refreshPackSectionForUnit(playerName) → menu Load ET Pack
         rafraîchis après unpack sans re-entry F10 (F-124 1/1 PASS live)

✅  FG  GAP-2 — Auto-unpack post-parachute crates [2026-05-06]
        Implémenté dans CTLDCrateManager:_checkAutoUnpack() :
          • fromParachute=true posé par parachuteCrates() callback ET _checkNativeDCSCargo UNLOAD en vol
          • Scan LANDED+fromParachute dans autoUnpackRadiusParachute autour de la dernière caisse atterrie
          • Si cratesRequired trouvées → unpackCrate() + _spawnUnpacked() au centroïde, sans joueur
          • Fonctionne mixte CTLD menu + DCS natif (intégrité du set suffit)
          • Sprint 2a : _nativeCrateLink {lx,ly,lz} remplace _nativeLoadDist (linkOffsetRef 3D, seuil 1m)

✅  FG  Correction poids appareil — agrégateur ctld.utils.updateTransportWeight [2026-05-06]
        Implémentation : agrégateur central (conforme legacy ctld.getWeightOfCargo) :
          • ctld.utils.updateTransportWeight(unitName) — unique appel setUnitInternalCargo
          • CTLDTroopManager:_updateWeight → délègue à l'agrégateur
          • CTLDVehicleSpawner:getLoadedVehicleWeight + _updateVehicleCargo → délègue
          • CTLDCrateManager:getLoadedCrateWeight + weight update à tous les call sites :
              load sol, slingload virtuel, unload, drop safe, drop impact
          • DCS native exclu : isLoadedByCTLD() guard + loadMethod=="menu_ctld" filtre
          • StaticObject.getCargoWeight() : lecture seule du type, pas setter → non utilisable
        Recette : scenario_weight_aggregation.lua — 4/4 PASS (320→2820→2500→0 kg) ✅

✅  FG  Spawn/load/drop direct de véhicule sans crate (use case Request Vehicle pur)
        Use case : spawn d'un véhicule via "Request Vehicle" (logistic zone) → load dans transport
        → drop à un autre endroit, sans aucune crate intermédiaire.
        Recette : scenario_mt15_request_vehicle_pure.lua — MT-15 13/13 PASS live DCS [2026-06-07]
          • spawnVehicleForTransport → WAITING, DCS unit alive ✅
          • findLoadableVehicles → HMMWV trouvé ; loadVehicle → LOADED, DCS unit détruite ✅
          • findLoadedVehicles → HMMWV trouvé ; unloadVehicle → WAITING, DCS unit respawnée ✅
          • Visual F10 menu — diag_mt15_vehicle_menu_visual.lua ✅ PASS [2026-06-07]
            Request Equipment→HMMWV spawn / Load Vehicle / Unload Vehicle confirmés joueur

✅  FG  Bibliothèque de recettes fonctionnelles avancées — scénarios joueur end-to-end
        Objectif : créer une bibliothèque de scripts Lua injectables via Witchcraft qui reproduisent
        des séquences d'actions joueur réelles et vérifient leur bon déroulement.
        Contrairement aux tests unitaires (mocks Lua standalone), ces scénarios tournent en mission
        DCS réelle et valident le comportement observable de bout en bout.

        Architecture :
          • Répertoire : live_tests/scenarios/ (séparé des diag/)
          • Chaque scénario = script Lua autonome injectable via Witchcraft
          • Mode d'exécution : mission lancée en mode CTLD debug (ctld.debug = true)
          • Tous les messages outText envoyés à l'écran doivent AUSSI être insérés dans CTLD.log
            → ctld.utils.log("INFO", ...) systématique sur chaque point de contrôle
          • Traces techniques supplémentaires (positions, distances, états internes) injectées
            dans le script de test uniquement — jamais dans le code de production src/
          • Vérification : lecture de CTLD.log seule (pas d'assert runtime)

        Scénarios prioritaires :
          • JTAC sol (Hummer) : Request Equipment → unpack près ennemi → lasing actif
            → laser code dans log → menu JTAC F10 → 9-Line → Toggle Lase
          • Drone JTAC (MQ-9) : unpack → route initiale (orbite) → ennemi entre dans LOS
            → autoOrbit sur cible → cible mobile suivie → cible hors LOS → retour route initiale
          • Troupes JTAC : charger "JTAC Group" → déposer → lasing actif → menu JTAC F10
          • IN_TRANSIT : embarquer JTAC sol → log IN_TRANSIT → débarquer → lasing reprend
• Troops full cycle (2 JTAC) — remplacé par `scenarioTroopsFullCycle_v2.lua` ✅ 8/8 PASS [2026-05-05] :
               - Créer template de test `jtac = 2` (2 JTAC soldiers dans le group)
               - embarkFromTroopZone() → TRZ_LOADED (log state)
               - disembark() 1er déploiement → DCS group spawn, 2 JTAC instances créées
                 → vérifier _jtacUnits map contient 2 entries, startLase() ×2 appelé
               - Simuler destruction de l'unité JTAC N°2 (S_EVENT_DEAD injecté)
                 → _jtacUnits mis à jour (1 entry restante), _aliveUnits mis à jour
                 → deregisterJTAC() appelé pour l'unité détruite, laser pool -1
               - embarkFromField() → FIELD_LOADED
                 → deregisterJTAC() appelé pour le JTAC restant (alive) AVANT group:destroy()
                 → group:destroy() ne déclenche PAS killJTAC (JTAC déjà deregistré)
               - disembark() après field → DCS group respawn avec 1 seul JTAC alive
                 → resumeJTAC() appelé pour le JTAC vivant
               - returnToTroopZone() → RETURNED_TO_TRZ
                 → deregisterJTAC() appelé pour le JTAC restant, stock TRZ restauré
          • Beacon radio — vérification des 3 émetteurs :
              - VHF (200–1250 kHz AM) : entendu sur ADF + aiguille ADF pointe vers balise
              - UHF (220–399 MHz AM) : entendu par modules FC3 (son beaconsilent.ogg)
              - FM  (30–76 MHz FM)   : bip entendu sur radio FM hélico full fidelity (UH-1H ARC-131)
                                       + indicateur de cap FM actif en mode DF
              Vérification : drop beacon depuis hélico → log fréquences → positionner à 500m
              → accordes successives sur chaque freq → confirmer réception bip + comportement
              navigation (ADF pour VHF, homing pour FM). Test post-fix délai 1s.

        Statut partiel [2026-05-12] :
          ✅ TroopsFullCycle v2 (8 steps PASS [2026-05-05]) — couvre JTAC troops lifecycle
          ✅ Drone JTAC orbit (F-106 visual PASS [2026-04-25])
          ✅ IN_TRANSIT vehicle (F-125→F-127 PASS [2026-05-06])
          ✅ JTAC sol Hummer end-to-end (Request Equipment → unpack → 9-Line) — PASS live DCS [2026-05-12]
          ✅ Beacon radio 3 émetteurs (VHF/UHF/FM) — PASS live DCS [2026-05-12]
             VHF ADF ✅ | FM homing ARC-131 ✅ | UHF soundSilent (beaconsilent.ogg) normal par design

✅  FG  Refonte système spawnableCrates — singleTypeSets auto + mixedSet [2026-04-26]
        - Suppression ~25 entrées multiple={w,w,...} manuelles dans config
        - Renommage multiple → mixedSet pour sets multi-types (HAWK, NASAMS, KUB, BUK, Patriot, S-300)
        - showSets=false sur FOB Crate (sentinel), enableAllCrates garde global
        - _processSpawnableCrates() : 3 passes (séparation / auto-génération / validation)
        - singleTypeSet auto-généré : desc = sc.desc + ctld.tr("All crates"), adjacent dans menu
        - mixedSet validé : weights résolus dans catégorie, entrée bloquée + alerte MM si manquant
        - findDescriptorByWeight/ByTypeName/ByUnitType : O(1) via _weightIndex
        - Ordre menu garanti : singleCrates (+ singleTypeSet adjacent) → mixedSets en fin
        - Recette visuelle ✅ PASS [2026-04-26] F-109

✅  FG  Beacon FM — investigation activateBeacon HOMER [2026-05-06]
        Conclusion tests live (2 balises simultanées, UH-1H ARC-131) :
          - activateBeacon type=8 system=4 et system=7 sur unités infantry → aucun signal reçu
          - radioTransmission mode=1 (FM) à 1000W → signal fort et clair sur les 2 fréquences simultanément
          - radioTransmission FM à 100000W → idem (la puissance n'est pas le facteur limitant)
        Décision : aucun changement de code — radioTransmission FM est correct et fonctionnel.
        La root cause du problème d'origine était l'absence de beacon.ogg/beaconsilent.ogg dans le .miz
        (déjà diagnostiqué et documenté en session 2026-04-26). Le MM doit ajouter ces sons.
        activateBeacon HOMER : abandonné pour usage CTLD sur ground units.

✅  FG  Mark IDs — compteur global monotonique app-wide [2026-04-27]
        ctld.utils.getNextMarkId() / MarkIdCounter : compteur partagé par Recon, Beacon, drawQuad.
        Fix bugs :
          - CTLDReconManager._nextMark() + CTLDBeaconManager._nextMark() : délèguent désormais
            à getNextMarkId() (suppression des compteurs locaux démarrant à 1 → collisions silencieuses)
          - drawQuad : utilise getNextMarkId() au lieu de getNextUniqId() (séparation mark/unit IDs)
          - _doRefresh moved-target : alloue un nouveau markId après removeIcon (DCS invalide
            définitivement tout ID passé à removeMark — réutilisation = mark invisible)
        Recette F-115 : 11/11 PASS [2026-04-27]

✅  FG  Shutdown propre des boucles timer.scheduleFunction à la réinjection CTLD_Next [2026-05-12]
        Implémentation :
          ✅ (A+B) `ctld.scheduler` (CTLD_utils.lua) : registre central register/cancel/cancelAll
          ✅ beacon refresh loop : return-t+interval + guard B (zombie auto-stop) + register "beacon_refresh"
          ✅ AI transport loop : guard B + register "ai_transport"
          ✅ live_tests/shutdown_ctld.lua : script Witchcraft → ctld.scheduler.cancelAll() avant réinjection
        Vérifié live DCS : cancelAll annule 2 boucles (beacon_refresh + ai_transport) ✅
        Note : l'item "CTLDCoreManager:shutdown()" du backlog est couvert par ctld.scheduler.cancelAll()
               → aucun wrapper shutdown() séparé nécessaire
        (D) Bonne pratique recette : ne pas détruire de vrais groupes DCS dans les scénarios
            Witchcraft (déclenche S_EVENT_DEAD → rebuild menu concurrent) — documenté ici

✅  FG  Feature F — RECON layer FARP/FOB ennemis persistants
        Objectif : détecter les FARP/FOB ennemis en LOS pendant un vol de reconnaissance et les
        marquer sur la F10 map jusqu'à leur destruction (pas de re-LOS requis après première détection).

        Spec validée :
        ─ Coalition-aware rendering (inclus dans Feature F) :
          • Changement transversal : toutes les icônes RECON passent de coalition=-1 à
            coalition=playerUnit:getCoalition() (BLUE scout → marques visibles BLUE seulement)
          • drawXxxIcon() reçoit un paramètre coalition supplémentaire
          • target.playerCoalition alimenté dans _scanLOS et _scanStaticLOS
          ⚠️  Tests existants vérifiant coalition=-1 devront être mis à jour

        ─ Nouveau layer "farp_fob" :
          • Ajouté à _defaultLayers (fin de liste), enabled=false par défaut
          • couleur : {0.95, 0.30, 0.60} (magenta)
          • filterAttrib = nil (pipeline dédié, pas _matchLayer)
          • Menu toggle F10 : "FARP / FOB [activate]" / "FARP / FOB [deactivate]"
            → bascule via toggleLayer() existant → scan() appelé si scan actif

        ─ Nouveau renderer CTLDReconRenderer.drawFarpIcon (3 slots) :
          • slot1 : circleToAll (cercle fond alpha 0.3)
          • slot2 : lineToAll barre verticale gauche du H
          • slot3 : lineToAll barre horizontale (crossbar H)
          → H cerclé (helipad standard), distinct du layer helicopter

        ─ Sources de détection  [empirique 2026-05-17 — inject_red_fob.lua] :

          Source A — FARPs/helipads (a+c) :
          • coalition.getAirbases(enemySide) → Object.getCategory=4 (BASE), typeName="FARP"
          • Filtre : desc.attributes.Helipad == true  (confirmé empiriquement)
          • FARPs natifs DCS ✅  helipads MM ✅
          • LOS : land.isVisible({x,y=abPos.y+180,z}, {x,y=playerPos.y+180,z})

          Source B — CTLD FOBs ennemis (b) :
          • Filtre par attrs statics NON fiable : "Fortifications" trop générique (false positives)
          • Solution propre : interroger CTLDFOBManager._fobs pour coalition ennemie directement
            → position + coalition déjà disponibles, LOS check sur fob.position
          • Avantage : pas de scan statics, pas de faux positifs, couplage limité

        ─ _farpMarks[player] = { [id] = { markId, ref } } (id = ab:getName() ou fobId) :
          • Dédup par id : 1 seule marque par FARP ou FOB (skip si déjà marqué)
          • Marks ajoutées sur scan/refresh quand objet en LOS pour la 1ère fois

        ─ CTLDStaticWatcher (nouveau singleton, CTLD_core.lua) :
          Interface générique : watch(id, checkFn, onDeadFn)
          • checkFn()  : retourne true si l'objet est encore vivant
          • onDeadFn() : appelé quand checkFn() → false → dispatch S_EVENT_STATIC_DEAD
          • Timer interne 1s — auto-unwatch après onDeadFn
          Pour FARP  : checkFn = function() return ab:isExist() end
          Pour FOB   : checkFn = function() return fob:isAlive() end
          ⚠️  S_EVENT_DEAD non garanti pour statics/bases → watcher compense fiablement

        ─ CTLDReconManager :
          • À la création d'une farp mark → CTLDStaticWatcher:watch(id, checkFn, onDeadFn)
          • onDeadFn → removeIcon(markId) + retirer de _farpMarks + dispatch ReconFarpLost
          • _removeAllMarks étendu : efface _farpMarks[player] + unwatch chaque id
            → Toggle OFF layer farp_fob / "Hide All Targets" → marks et watchers supprimés

        ─ Nouveaux events CTLD : S_EVENT_STATIC_DEAD (infra), ReconFarpDetected, ReconFarpLost
        ─ Nouveaux i18n : aucune clé (nom layer = "FARP / FOB" identique 4 langues)
        ─ Config : aucun nouveau paramètre (réutilise reconSearchRadius, reconIconScale)

        ─ Pré-requis implémentation : ✅ TOUS VALIDÉS empiriquement (2026-05-17)
          • diag_farp_statics.lua — attributs FARP confirmés
          • inject_red_fob.lua   — FOB CTLD spawné + détection validée

        ─ Guide documentation (même réponse que implémentation) :
          • documentation/missionmaker_guide.md : §RECON — tableau layers + icônes + descriptions
          • Placeholder screenshots à compléter post-implémentation

        Recette :
          Recette auto (mock) ✅ [2026-05-17] :
            F-150 CTLDStaticWatcher watch/unwatch/tick (3 cas) PASS
            F-151..152 coalition rendering FARP+infantry+vehicle (7 cas) PASS
            F-153 _matchLayer skip farp_fob (3 cas) PASS
            F-154..157 _syncFarpMarks FARP+FOB detect/dedup/clear (6 cas) PASS
            F-158 watcher onDeadFn (3 cas) PASS → 22 cas / 22 PASS
            ⚠️  F-154.2 marks=0 car player unit hors LOS de la position test (normal en mock)
          • MT-06 (live DCS) : 9/9 PASS ✅ [2026-05-17]
            FARP en LOS → marqué ; hors LOS → mark reste (persistence) ;
            toggle OFF → marks effacés immédiatement ; toggle ON → marks réappraissent ;
            playerCoalition=2 confirmé ; FARP détruit → mark <2s (CTLDStaticWatcher) ;
            FOB détruit → mark <2s

🚫  FG  Feature G — Toggle "Share my RECON to coalition" [OBSOLÈTE]
        Raison : les fonctions DCS Draw API (lineToAll/circleToAll/rectToAll) avec coalition=2
        rendent les marks visibles à TOUS les joueurs BLUE — pas uniquement au groupe du pilote.
        Le partage coalition est donc le comportement par défaut de Feature F.
        Feature G n'apporte aucune valeur ajoutée. Abandonnée [2026-05-17].

✅  FG  Feature H — Smoke auto-resume (toggle [activate]/[deactivate]) [2026-05-05]
        Objectif : simuler une durée de fumée perpétuelle en relançant automatiquement
        toutes les fumées actives avant leur expiration (~5 min DCS fixe).
        Comportement attendu :
          • Toggle F10 "Smoke Auto-Resume [activate]" / "[deactivate]" par joueur
            → label dynamique : [activate] quand désactivé, [deactivate] quand activé
            → scope : par joueur (chaque pilote gère ses propres smokes)
          • Quand activé : toutes les fumées lancées par ce joueur (position + couleur mémorisées)
            sont relancées automatiquement via trigger.action.smoke() juste avant l'expiration
          • Quand désactivé : les fumées en cours expirent naturellement + mémoire effacée
          • Stockage : { pos, color, launchTime } par smoke active ; timer périodique (15s) vérifie
            si launchTime + smokeAutoResumeInterval atteint → trigger.action.smoke(pos, color)
          • Une relance repart le compteur de la smoke relancée (launchTime = now)
          • Scope des smokes suivies : toutes celles déclenchées via le menu CTLD F10
            (Drop Smoke) — tracées systématiquement, le tick filtre sur active
        Config :
          • smokeAutoResume (bool, défaut false) — état initial global (surchargeable par joueur)
          • smokeAutoResumeInterval (int, défaut 270 s = 4min30) — délai avant relance
        Implémentation : CTLDSmokeManager singleton (src/CTLD_crate.lua) + buildSmokeSection
        Recette : diag_smoke_mgr.lua + diag_smoke_menu.lua ✅ PASS [2026-05-05]
        Validé en live DCS : smoke bleue persistante en boucle, menu label bascule, désactivation purge ✅

✅  FG  Feature I — Route/behaviour assignment post-deploy [2026-05-11]
        Objectif : assigner automatiquement une route ou un comportement prédéfini
        à un groupe de troupes au moment de leur dépose (disembark ou parachute).
        Implémentation :
          • CTLDTroopGroup.specificParams propagé depuis loadableGroups template
            (embark, field extract, parachute — incluant _droppedTemplates)
          • CTLDZoneManager:getNearestWaypointZone(point, coalition) — nouvelle méthode
          • CTLDTroopManager:_assignPostSpawnTask — helper schedulé +2 s post-spawn
          • Tâches supportées :
            - "gotoNearestWPZ"               → route vers le centre de la WPZ la plus proche
            - "AttackNearestEnemyOnLos"       → route vers l'ennemi le plus proche avec LOS
              (world.searchObjects sphere 10 km + land.isVisible +2m offset)
          • ROE OPEN_FIRE + ALARM_STATE AUTO dans les deux cas
          • Fallback silencieux si aucune cible trouvée
          • Exemples commentés dans loadableGroups (CTLD_config.lua)
        Scope : troupes uniquement (disembark + parachute). Crates/véhicules = backlog.

✅  FG  Feature J — JTAC target deconfliction (multi-JTAC, anti-doublon) [2026-05-04]
        Objectif : lorsque plusieurs JTACs actifs (infantry slot, vehicle, drone) sont concurrents
        et dans la portée d'une même cible ennemie, empêcher qu'ils lasent tous la même cible.
        La déconfliction doit rester compatible avec le renouvellement de cible après destruction :
        quand une cible est détruite, chaque JTAC doit automatiquement se repositionner sur une
        autre cible disponible (vivante, dans portée LOS, non claimée).

        Structure de données (minimaliste) :
          • Une seule table partagée dans CTLDJTACManager :
              `_claimedTargets` = { [unitName_cible] = jtacKey }
                → jtacKey = unitName (unit-keyed) ou groupName (group-keyed)
            Cette table est la liste des targets **en cours de lasing actif**.
            Aucune structure supplémentaire par JTAC n'est nécessaire.

        Comportement dans `_autoLaseLoop` :
          Phase RECHERCHE (pas de target courante) :
            1. Appeler `findAllVisibleEnemies()` → liste de candidats triée par distance
               (vivants + LOS + dans portée)
            2. Filtrer la liste : exclure les unitNames déjà présents dans `_claimedTargets`
            3. Prendre le premier candidat restant → claim + lase
               Si liste vide après filtre → return t + searchInterval
          Phase LASE (target courante valide) :
            4. Vérification cible existante inchangée (isExist, LOS) — comportement actuel conservé
            5. Si cible perdue (détruite OU hors LOS) — CAS CRITIQUE :
               → `_stopLaseAndPublish` → retire `_claimedTargets[cible]`
               → repasser immédiatement en Phase RECHERCHE (steps 1-3) dans le même cycle
          Note : c'est lors du step 5 (renouvellement de cible) que la déconfliction est
          la plus critique. Plusieurs JTACs perdant simultanément leur cible (ex. explosion)
          itèrent chacun la liste filtrée → chacun prend un candidat différent.

        Gestion du claim :
          • Claim posé : à l'instant où le JTAC démarre le lase sur une nouvelle cible
          • Claim levé : dans `_stopLaseAndPublish`, quelle que soit la raison
            (TARGET_DESTROYED, TARGET_LOST, STANDBY_MODE, UNIT_DEAD, etc.)
          • Claim levé aussi dans `deregisterJTAC` (pour toutes les entrées pointant ce JTAC)
          • Pas de TTL / expiry : le claim vit aussi longtemps que le lase est actif

        Refactoring requis :
          • `CTLDJTACDetector.findNearestVisibleEnemy()` → `findAllVisibleEnemies()`
            Retourne une table `{ {unitName, dcsUnit, position, distance}, ... }` triée par distance.
            Le caller (autoLaseLoop) fait l'itération et la sélection deconflictée.
          • Rétrocompatibilité : l'ancien `findNearestVisibleEnemy` peut devenir un thin wrapper
            appelant `findAllVisibleEnemies()[1]` pour les callsites existants non JTAC.

        Config :
          • `JTAC_targetDeconfliction` (bool, défaut true) — désactivable si mission = JTAC solo
          • `JTAC_deconflictPriority` = "distance" | "laserCode" (défaut "distance")
            → "distance" : le JTAC le plus proche de la cible gagne le claim en cas de race
            → "laserCode" : le code laser le plus bas gagne (ordre de spawn/inscription)
            Note : la race est peu probable en pratique (loops décalées), mais doit être gérée.

        ✅ Implémenté [2026-05-05] — voir entrée Feature J ci-dessus (✅ FG Feature J).

✅  FG  Feature K — JTAC vehicle in-transit lifecycle (idle/active on load/unload)
        (Sprint 1 + Sprint 2a ✅ — Sprint 2b différé : C-130/Il-76 requis)
        Objectif : garantir que les JTACs de type vehicle (autoLase group-keyed) transitent
        correctement entre états LASING ↔ idle lors des opérations load/unload du transport,
        symétrique au comportement déjà implémenté pour les JTACs infantry (troop unit-keyed).

        Analyse flows [2026-05-06] :
          FLOW 1 (caisses) : 0 gap JTAC — JTAC vehicle inexistant pendant transport caisses.
            Seules transitions : PACK→deregisterJTAC ✅ ; UNPACK→startLase+register ✅
          FLOW 2 (vehicle entier) : 2 gaps JTAC identifiés :
            GAP-K1 : parachuteVehicle ne résumait pas JTAC → fixé [2026-05-06]
            GAP-K2 : transport détruit avec vehicle LOADED → JTAC orphelin → fixé [2026-05-06]
          GAP-K3 (Sprint 2) : _checkNativeLoading stub vide → logique linkOffsetRef à implémenter

        Sprint 1 — JTAC pur [2026-05-06] :
          ✅ GAP-K1 fix : parachuteVehicle → setState(WAITING) + resumeJTAC dans callback landing
             (CTLD_vehicle.lua:parachuteVehicle)
          ✅ GAP-K2 fix : onDead transport → purge vehicles LOADED + deregisterJTAC + OnVehicleDead
             (CTLD_vehicle.lua:onDead)
          ✅ F-125 : baseline JTAC vehicle load/setJTACInTransit — 10/10 PASS [2026-05-06]
          ✅ F-126 : GAP-K1 parachuteVehicle → WAITING + resumeJTAC — 4/4 PASS [2026-05-06]
          ✅ F-127 : GAP-K2 transport destroy → deregisterJTAC + purge — 5/5 PASS [2026-05-06]
          Scénario : live_tests/scenarios/scenario_feature_k_jtac_vehicle.lua (4/4 steps ALL SUCCESS)

        Sprint 2a — bbox crates (GAP-K3 Flow 1) [2026-05-06] :
          ✅ _checkNativeDCSCargo refactorisé : _nativeCrateLink {lx,ly,lz} remplace _nativeLoadDist
             LOAD : _pointInBBox → mémoriser offset local 3D via getPosition() + dot product
             UNLOAD : drift > 1m → unload détecté immédiatement (appareil stationnaire OK)
             Airborne UNLOAD (AGL > 5m) : fromParachute=true → _checkAutoUnpack()
          ✅ _checkAutoUnpack() : autoUnpack crateSet complet au centroïde, sans joueur
          Recette Sprint 2a : ✅ F-128→F-131 (19/19 PASS [2026-05-06], mock)

        Sprint 2b — bbox vehicles entiers (GAP-K3 Flow 2) :
          CTLDVehicleSpawner._checkNativeLoading stub vide → même logique linkOffsetRef.
          Recette nécessite C-130/Il-76 physique.

        Recette :
          • F-125→F-127 : scenario_feature_k_jtac_vehicle.lua (Sprint 1) ✅
          • Sprint 2a : ✅ F-128→F-131 (19/19 PASS [2026-05-06], mock)
          • F-113/F-114 : FERMÉS [2026-06-28] — voir décision ci-dessus

✅  FG  JTAC vehicle in-transit — vérification code coverage [2026-05-06]
        Analyse + recette des 4 hooks JTAC (vehicle via crate + vehicle entier) :
          • deregisterJTAC @ packVehicle (vehicle via crate)   → ✅ F-132 7/7 PASS [2026-05-06]
            scenario_jtac_crate_pack.lua — deregCalled + jtacs=nil confirmés
          • setJTACInTransit @ loadVehicle (vehicle entier)    → ✅ F-125 PASS [2026-05-06]
          • resumeJTAC @ unloadVehicle (vehicle entier)        → ✅ F-125 PASS [2026-05-06]
          • resumeJTAC @ parachuteVehicle (vehicle entier)     → ✅ F-126 PASS [2026-05-06]
          • deregisterJTAC @ onDead transport (vehicle entier) → ✅ F-127 PASS [2026-05-06]
          • startLase @ unpackCrate(isJTAC) (vehicle via crate) → ✅ F-107/F-108 PASS live
        Code coverage : 6/6 hooks implémentés et recettés. groupName cohérent entre
        enregistrement et appel (respawn conserve sd.groupName). ✅

✅  FG  Feature L — Multi-group transport [2026-05-12]
        Spec validée : multiGroupTransport guard, _inTransit list, _currentTroopCount/_canEmbark
        Codé :
          ✅ _inTransit[unitName] → {CTLDTroopGroup,...} toujours liste
          ✅ hasTroops/getWeight/getInTransit mis à jour
          ✅ _currentTroopCount/_canEmbark helpers (count + poids)
          ✅ embarkFromTroopZone/embarkFromField : multi-group append quand multiGroupTransport=true
          ✅ disembark/returnToTroopZone/parachuteTroops : consume list[1]
          ✅ disembarkAll/disembarkIndex/parachuteAll/parachuteTroopsIndex
          ✅ cleanupDeadTransports/_findGroupByAliveUnit : iterate list
          ✅ refreshMenuSection : sous-menus Unload/Parachute si N>1, Check Cargo
          ✅ _menuCheckCargo : affiche tous les groupes + total
          ✅ config : multiGroupTransport=false, maxVehiclesByType
          ✅ i18n EN/FR/ES/KO : Unload All, Parachute All, Check Cargo, weight limit
          ✅ MM guide §Troop Commands mis à jour
          ✅ Bugfix : extract from field visible avec troupes à bord si capacité disponible
          ✅ Bugfix : spawn center décalé à (safeR + spreadR) en direction aléatoire — évite overlap
        Recette :
          ✅ F-140→F-146 : 22/22 PASS [2026-05-12] — menu direct/sous-menu disembark, disembarkAll/Index,
             _menuCheckCargo multi-ligne+TOTAL, extract 1/N groupes avec distances
          ✅ MT-01 : test manuel 10 étapes PASS live DCS [2026-05-12] (live_tests/manual_test_sequences.md)
          ✅ MT-02 : test manuel véhicule entier PASS live DCS [2026-05-12] — bug fix: message confirmation parachutage manquant (parachuteVehicle)
          ✅ MT-03 : test manuel multi-vehicle entier PASS live DCS [2026-05-12] — bugs fixed: inAir guard load closure + refreshLoadSection absent de onTakeoff/onLand
          ✅ MT-04 : test manuel combinaison crate + troops PASS live DCS [2026-05-13] — bug fix: message confirmation parachutage crates manquant (parachuteCrates)
          ✅ MT-05 : crate + véhicule entier isolation 12/12 PASS auto [2026-05-13] — scénario Witchcraft (poids UH-1H insuffisant pour test manuel)


✅  FG  Feature M — JTAC smoke x/z offset [2026-05-12]
        Objectif : appliquer un décalage horizontal configurable (x et z) sur la fumée JTAC,
        en plus du margin of error aléatoire et du décalage vertical y déjà présent.
        Implémentation :
          ✅ `requestSmoke()` : lit `JTAC_smokeOffset_x` et `JTAC_smokeOffset_z` via ctld.gs()
          ✅ Clés documentées dans CTLD_userConfig.lua (Section JTAC smoke offsets)
        Recette : intégrée aux tests JTAC existants (smoke position vérifiée visuellement).

✅  FG  Feature N — AI transport auto-pickup / auto-dropoff (INIT-A) [2026-05-12]
        Objectif : porter `ctld.checkAIStatus()` legacy — les unités listées dans
        `transportPilotNames` sans pilote humain chargent automatiquement un template
        de troupes en zone pickup et les déchargent en zone dropoff.
        Implémentation :
          ✅ `CTLDCoreManager:_initAITransports()` — construit `_aiTeams[1/2]` filtrés par side,
             démarre la boucle timer (2 s, same as legacy). Stub `-- self:_initAITransports()` retiré.
          ✅ `CTLDCoreManager:_checkAIStatus()` — pickup : `getTroopZoneForUnit` + random template
             (si `allowRandomAiTeamPickups`) ou first-available ; dropoff : `getDropoffZoneAt` + `disembarkAll`.
          ✅ `allowRandomAiTeamPickups` gate : random si true, sinon premier template disponible.
          ✅ pcall par unité, log WARN sur erreur.
        Recette : `live_tests/scenarios/scenario_ai_transport.lua` — F-133 (_aiTeams), F-134 (pickup/dropoff).

✅  FG  Feature O — Extractable groups (INIT-E) [2026-05-19]
        Objectif : porter le legacy `extractableGroups` — groupes DCS placés par le MM extractibles via F10.
        Décision : complémentaire aux TRZ (pas de zone, pas de stock — évacuation de groupes existants).
        Implémentation : CTLDCoreManager:_initExtractableGroups() — Group.getByName() → _droppedGroups[coa].
        Pas de late-activation (iso-legacy). Poids fallback 130 kg/unité (iso-legacy, pas de template).
        Doc : MM guide §5 (Pre-placed extractable groups) + dev-guide §2 (init sequence table) + README §Troops.
        Recette F-O-1→F-O-3 7/7 PASS ✅

✅  FG  Feature P — Unified aircraftCapabilities table [2026-05-18]
        Table `capabilitiesByType[typeName]` — renommage complet des champs pour clarté maximale :
          • `crates` → `cratesEnabled`, `troops` → `troopsEnabled`
          • `unitLoadLimits` → `maxTroopsOnboard`, `internalCargoLimits` → `maxCratesOnboard`
          • `maxVehicles` → `maxWholeVehiclesOnboard`
          • `vehicleTransportEnabled` → `canTransportWholeVehicle`
          • `canParachute` → `canParachuteDrop`
          • `dynamicCargoUnits` → `useNativeDcsCargoSystem`
          • `vehiclesRED` → `loadableVehiclesRED`, `vehiclesBLUE` → `loadableVehiclesBLUE`
          • `vehiclesWeight` → `groundVehicleWeights`
        Bugfix : CTLD_vehicle.lua:loadVehicle lisait `internalCargoLimits` (limite caisses)
          au lieu de `maxWholeVehiclesOnboard` pour la capacité véhicules entiers.
        Bugfix : buildMenuSection (CTLD_crate.lua) référençait `actions` (nil) au lieu de `caps`
          → Parachute Crates et Release Slingload jamais ajoutés au menu. Corrigé → `caps`.
        Tous les managers (CTLDCrateManager, CTLDTroopManager, CTLDVehicleSpawner, CTLDPlayerManager)
          et les fichiers config (CTLD_config.lua, CTLD_userConfig.lua) mis à jour.

✅  FG  Crate Commands menu — sol/vol split (refreshCrateFlightSection) [2026-05-18]
        Nouveau : CTLDCrateManager:refreshCrateFlightSection(playerObj)
          • Sol uniquement : Load Crate, Drop Crate(s), Unpack Crate, List Nearby Crates, Pack Vehicle
          • Vol uniquement : Parachute Crates (canParachuteDrop + crates non-slingloadées à bord),
                            Release Slingload, Cut Slingload (canSlingload + slingload actif)
        Appelé depuis buildMenuSection, onTakeoff, onLand.
        Slingload menu triggers : refreshCrateFlightSection après hover pickup, release, cut.
        Recette : F-168→F-172 15/15 PASS + F-173→F-175 live DCS ✅

✅  FG  Bugfixes parachute/slingload/poids cargo [2026-05-18]
        • parachuteCrates : _respawnStatic après land() → crate visible au sol (F-173 PASS live)
        • parachuteCrates + cutSlingload + parachuteVehicle : updateTransportWeight manquant → ajouté
        • updateTransportWeight : guard Unit.getByName+isExist → plus de crash si transport détruit
        • Timers déférés : _transportName capturé avant timer (parachuteCrates + parachuteVehicle)
          → plus de risque getName() sur objet DCS invalide
        • Parachute Crates : exclut crates inTransitOnSlingload du comptage onboard
        • outTextForGroup slingload confirmation : clearview=true → efface décompte hover (F-175 PASS live)

✅  FG  Bugfixes menu crates live DCS — sol/vol/sol validation [2026-06-30]
        • findPackableVehicles : veh.unitName → veh.spawnData.unitName (Pack Vehicle ne listait aucun véhicule)
        • refreshCrateFlightSection(playerObj, overrideInAir) : param tristate (nil/true/false)
            + flag _isFlying sur CTLDPlayer pour refresh immédiat sans attendre onTakeoff/onLand
        • refreshPackEquiptSection : setBranchEnabled(false) après clearBranch → menu propre en vol
        • onTakeoff : _isFlying=true + appel immédiat refreshCrateFlightSection(playerObj, true)
        • onLand : _isFlying=false immédiat + timer 1 s → refreshCrateFlightSection(playerObj, false)
        • addSubMenu : idempotent — met à jour order + enabled si sous-menu déjà existant
        Recette : tests/dcs/pilotActive/scenario_crate_menu_sol_vol_visual.lua 5/5 PASS live DCS [2026-06-30]

✅  FG  Feature — Troop Commands menu sol/vol/sol split [2026-06-30]
        CTLD_troop.lua + CTLD_menu.lua : refreshTroopFlightSection analogue à refreshCrateFlightSection
        • Sol : Load Troops, Unload Troops, List Nearby Troops, Disembark All/By Index
        • Vol : Parachute Troops
        Recette : F-183 (sol) / F-184 (vol) / F-185 (sol restauré)
        tests/dcs/pilotActive/scenario_troop_menu_sol_vol_visual.lua 5/5 PASS live DCS [2026-06-30]

✅  FG  Feature Q — Vehicle whole-unit air transport [2026-05-19]
        GAP-Q1: findLoadableVehicles coalition filter (BLUE transport cannot see RED vehicles).
        GAP-Q2: findLoadableVehicles type filter via loadableVehiclesRED/BLUE + _isTypeLoadable helper.
        GAP-Q3: Request Equipment unified — spawnAsVehicle=true for loadable types → spawnVehicleForTransport.
        Menu order updated: Request Equipment order=25 (after Troops 20, before Vehicle Commands 30).
        i18n: "Vehicle ready for loading" added (EN/FR/ES/KO).
        Spec: docs/specs/feature_q_spec.md
        Recette: 9/9 PASS (F-Q-1→F-Q-6, scenarios/auto/scenario_fq_vehicle_whole_transport.lua)

✅  FG  Feature R — AI transport extended (AIZ_ zones + vehicle whole-unit) [2026-05-19]
        GAP-R1 : `_checkAIStatus` ne gère pas les véhicules entiers (troops only).
        GAP-R2 : `cleanupDeadTransports()` existe mais n'est jamais appelé.
        Implémentation :
          ✅ AIZ_ étendu : `AIZ_name_[R|B|N]_[P|D]_[cargoType|mode][_stock1[_stock2]]`
            P zones : cargoType T / V / TV / VT ; TV/VT = order defines stock1/stock2
            D zones : mode G / P / GP (défaut GP)
          ✅ `aiCargoType` sur CTLDTroopZone : copié dans init() (T/V/TV), stocks séparés troop/vehicle
          ✅ `getAIPickupZoneAt()` / `getAIDropoffZoneAt()` : plus petit rayon en cas de zones superposées
          ✅ Pickup/dropoff basculé sur `S_EVENT_LAND` (`onAILand`) — remplacement du timer loop
            ordre : dropoff (véhicule + troupes) → early return | ou pickup (véhicule + troupes)
          ✅ `_checkAIStatus` réduit au seul `cleanupDeadTransports()` (maintenance orphelins)
          ✅ `aiDropMode` : "G"=sol uniquement, "P"=parachute uniquement, "GP"=les deux (défaut)
          ✅ `cleanupDeadTransports()` câblé sur `S_EVENT_DEAD` dans CTLDDCSEventBridge
          ✅ `_validateZoneNames` : AIZ_ parsing étendu + WARN chevauchement P+D même coalition
          ✅ `allowRandomAiTeamPickups` conservé tel quel
          ✅ Fix critique : `onAILand` utilisait `ipairs` sur `transportPilotNames` (hash table)
            → `isAI` toujours false → aucun pickup/dropoff AI. Corrigé par lookup direct.
          ✅ Weight gate : `maxVehicleWeight` par type dans `capabilitiesByType`
            UH-1H=1360 kg, CH-47Fbl1=11000 kg, C-130J-30/76MD/Hercules=20000 kg
            Si aucun véhicule compatible poids → WARN CTLD.log, heli non bloqué
        Recette auto : 71/71 PASS (F-R-1→F-R-26, scenarios/auto/scenario_fr_ai_zones.lua [2026-05-19])
          F-R-21→F-R-26 : fallback scan templates — premier compatible, circulaire random, guards
        Recette live DCS :
          MT-07 4/4 PASS [2026-05-19] — pickup troupes AIZ_P_T, dropoff AIZ_D, msgs coalition + count
          MT-08 4/4 PASS [2026-05-19] — pickup véhicule AIZ_P_V (stock=10), dropoff AIZ_D
          MT-09 4/4 PASS [2026-05-19] — pickup troupes+véhicule AIZ_P_TV, dropoff AIZ_D
          MT-10a ✅ PASS [2026-06-06] — re-recette Feature S (zones depuis userConfig) : gotoNearestWPZ PASS
          MT-10b ✅ PASS [2026-06-06] — re-recette Feature S : AttackNearestEnemyOnLos PASS
          ✅ Re-recette MT-07→MT-10 PASS [2026-07-05] — 7+12+14+23=56/56 PASS (debug mode, mission accélérée, clone AI + waitFor)

✅  FG  SVG troops transport flows — schéma visuel transport troupes  [2026-06-28]
        docs/assets/troops_transport_flows.svg produit (même format que transport_flows.svg)
        Flows couverts :
          • Flow 1 BOARD    : embarkFromTroopZone — sol, TRZ requise
          • Flow 2 DISEMBARK : context-sensitive (sol/hors TRZ→DEPLOYED, TRZ+flag→EXZ, TRZ pickup→RTB, vol→parachute)
          • Flow 2d parachute virtuel (Feature A) : alt ≥ parachuteMinAltitudeTroops, startLase au landing
          • Feature I post-spawn route : gotoNearestWPZ / AttackNearestEnemyOnLos
          • Flow 3 EXTRACT  : embarkFromField — sol, préserve survivants
          • Transport détruit (S_EVENT_DEAD) — deregisterJTAC×N protège contre zombies
          • AI Transport (Feature R) : AIZ_ P/D zones, S_EVENT_LAND trigger
          • State machine summary : TRZ_LOADED → DEPLOYED → FIELD_LOADED → DEPLOYED_EXZ → RETURNED_TO_TRZ
          • JTAC annotations sur chaque flow (startLase×N, deregisterJTAC×N, IN_TRANSIT)
        Lien ajouté dans missionmaker_guide.md §5 (Troop Transport).

── APRÈS PHASE 2 COMPLÈTE ───────────────────────────────────────────────────
✅  Q1  src/legacy/legacy_api.lua  [2026-04-15]
        22 wrappers (Troops×6, Zones×10, Crates×3, Beacons×1, JTAC×3) — thin delegates
        Bugfix: CTLDTroopManager:deploy() exzZone.flagName → exzZone.objectiveFlag
        New: CTLDZoneManager:isUnitInZone() (méthode manquante appelée par deploy)
        Nouvelles méthodes managers: TroopManager×8, ZoneManager×6, CrateManager×4,
          BeaconManager×1, JTACManager×3
        Pack Vehicle implémenté (gap critique comblé) [2026-04-15]:
          CTLDCrateManager:spawnCrate() — coalition.addStaticObject, model auto (load/sling/dynamic),
            OnCrateSpawned publié, crate enregistrée
          CTLDCrateManager:findDescriptorByUnitType() — lookup par champ unit dans spawnableCrates
          CTLDVehicleSpawner:findPackableVehicles(transport) — scan ground units coalition,
            filtre par maximumDistancePackableUnitsSearch, match descriptor par typeName
          CTLDVehicleSpawner:packVehicle(transportName, packableUnitName, playerObj) —
            destroy vehicle, spawn cratesRequired crates (secteur avant hélico / arrière C-130),
            OnVehiclePacked publié, menu rafraîchi
          CTLDVehicleSpawner:_checkPackingLanding() — timer 3s, transition inAir→landed → refreshForUnit
          Menu F10 "Pack Vehicle" (sous Crate Commands) — populé dynamiquement avec véhicules packables
        Recette Q1: U-81→U-83 (62/62) + F-94→F-99 (86/86) = 148/148 PASS ✅
✅  Q2  tests/ busted infrastructure  [2026-04-15]
        tests/helpers/dcs_stubs.lua — stubs DCS complets (coalition, Unit, Group, timer, trigger, Spot…)
        tests/helpers/loader.lua    — charge tous les modules src/ dans l'ordre listToMerge, idempotent
        tests/helpers/init.lua      — point d'entrée busted (référencé dans .busted)
        tests/specs/crate_manager_spec.lua — 8 specs findDescriptorByUnitType + spawnCrate
        .busted                     — config busted (pattern _spec, helper init.lua)
        Job 3 busted ajouté dans ci.yml (choco lua + luarocks install busted + busted tests/specs/)
        Note: busted non installé localement — validation uniquement via GitHub Actions CI

✅  Q3  GitHub Actions CI  [2026-04-15]
        .github/workflows/ci.yml créé
        Job 1 — lua-lint : choco install lua 5.4 → loadfile() syntax-check sur tous src/**/*.lua
        Job 2 — build    : merge PowerShell (replique merger.cmd sans pause interactif) → CTLD_Next.lua
          - fichiers manquants (AA scenes, userConfig) → warning seulement (parité merger.cmd)
          - artifact uploadé 7 jours (actions/upload-artifact@v4)
        Triggers : push sur master + feature_* , PR vers master
✅  Q4a Réorganisation arborescence repo  [2026-04-15]
        Suppressions : old/, merger/ (V1), src/tests/, conversation.text, witchcraft_test.lua
        Déplacements : build/ → tools/build/,
          documentation/ + Specs/ → docs/, *.ogg → assets/, *.png → docs/,
          *.miz → missions/, CTLD.lua (v1) → source/
        .gitignore : ajout CTLD_Next.lua
        ci.yml : chemin corrigé tools/build/listToMerge.txt
✅  Q4b source/ dead code cleanup  [2026-04-16]
        Supprimés : CTLD_beacon.lua, CTLD_config.lua, CTLD_core.lua, CTLD_i18n.lua,
          CTLD_jtac.lua, CTLD_menu.lua, CTLD_recon.lua, CTLD_utils.lua, load_event.lua
        Conservés : CTLD.lua (référence v1 complète), CTLD_userConfig.lua
✅  Q5  documentation complète  [2026-04-15]
        ✅  Q5-A  docs/missionmaker_guide.md — guide complet  [2026-04-15]
                   §1–9 existants + §10 Crates + §11 Vehicles + §12 FOB + §13 Beacons
                   + §14 JTAC + §15 Recon + §16 AA Systems
                   Chaque section : description bloc, actions (utilité/fonctionnement/activation/exemple),
                   paramètres config, events

        ✅  Q5-B  docs/dev-guide.md  [2026-04-15]
                   Sections : repo structure, architecture managers, new module howto,
                   events pub/sub, build + test workflow, migration v1→v2 (table 22 wrappers,
                   addCallback → subscribe, pack vehicle, exemple complet DO SCRIPT)
```

---

## Phase 0 — Specification & Architecture ✅ COMPLETE

### 0.1 — CTLD Events (38 events — 100%)

| Module | Events | Spec file |
| ------ | ------ | --------- |
| Crates | 6 ✅ | `Specs/project_ctld_events_crates_spec.md` |
| Troops | 6 ✅ | `Specs/project_ctld_events_troops_spec.md` |
| JTAC | 9 ✅ | `Specs/project_ctld_events_jtac_spec.md` |
| Beacons | 5 ✅ | `Specs/project_ctld_events_beacons_spec.md` |
| Recon | 4 ✅ | `Specs/project_ctld_events_recon_spec.md` |
| Zones + Vehicles + FOB | 6 ✅ | `Specs/project_ctld_events_zones_vehicles_fob_spec.md` |
| Core Init | 1 ✅ (OnMMCrateDetected) | covered by S2 — memory: project_feature_c_spec.md |
| **Total** | **38** | |

### 0.2 — Features

| ID | Feature | Status |
| -- | ------- | ------ |
| A | Virtual parachute drop (crates + troops + vehicles) | ✅ Spec validée (2026-04-02) — memory: project_feature_a_spec.md |
| B | Virtual slingload | ✅ Integrated in crates spec |
| C | MM crate detection at startup (INIT-B + OnMMCrateDetected) | ✅ Spec validée (2026-04-02) — memory: project_feature_c_spec.md |
| D | Custom LoadableGroups API for mission makers | ✅ Implemented + recette [2026-04-14] |
| E | Dedicated CTLD log file (`ctld.log`) | ✅ Implemented + recette [2026-04-09] |

### 0.3 — Architecture validated

- `CTLDObjectRegistry` scope rule: spawn descriptors + scenes only
- `CTLDCrateAssemblyManager`: AA system assembly manager name retained
- `CTLDDCSEventBridge`: single DCS event handler — spec in `Specs/project_dcs_event_bridge_spec.md`
- `CTLDPlayerTracker`: player tracking without MIST — spec in `Specs/project_ctld_player_tracker_spec.md`
- INIT-A: AI transport detection — spec in `Specs/project_ctld_init_a_spec.md`
- INIT-B: MM crate detection — spec in `Specs/project_ctld_init_b_spec.md`
- INIT-C: MM JTAC detection — spec in `Specs/project_ctld_init_c_spec.md`
- Init order: EventBridge → PlayerTracker → CoreManager (INIT-A/B/C) → other managers

### 0.4 — Build infrastructure ✅

- `tools/build/merge_CTLD.ps1`: concatenates `src/` → `CTLD_Next.lua`
- `tools/build/listToMerge.txt`: canonical load order
- `tools/build/generate_i18n_dicts.ps1`: syncs i18n keys across languages

---

## Phase 1 — Dead code cleanup (`source/`) ✅ COMPLETE [2026-04-15]

Removed 9 redundant partial files (CTLD_beacon, CTLD_config, CTLD_core, CTLD_i18n, CTLD_jtac,
CTLD_menu, CTLD_recon, CTLD_utils, load_event). Retained 3 reference files:
`source/CTLD.lua` (full v1 monolith), `source/CTLD_userConfig.lua`.

---

## Phase 2 — Module split + OOP (`src/`) ✅ COMPLETE [2026-04-15]

### 2.0 — OOP micro-framework ✅ DONE (P1)

Create `src/core/class.lua`:

```lua
local function class(base)
    local cls = {}
    cls.__index = cls
    if base then setmetatable(cls, { __index = base }) end
    function cls:new(...)
        local instance = setmetatable({}, cls)
        if instance.init then instance:init(...) end
        return instance
    end
    return cls
end
```

Then refactor existing files to use it: `CTLD_crate.lua`, `CTLD_troop.lua`, `CTLD_jtac.lua`, `CTLD_sceneManager.lua`, `CTLD_objectRegistry.lua`.

### 2.1 — Implemented files ✅

| File | Classes | Date |
| ---- | ------- | ---- |
| `src/CTLD_config.lua` | CTLDConfig (singleton) | 2026-03-31 |
| `src/CTLD_objectRegistry.lua` | CTLDObjectRegistry | 2026-03-31 |
| `src/CTLD_crate.lua` | CTLDCrate, CTLDCrateManager | 2026-03-31 |
| `src/CTLD_troop.lua` | CTLDTroopGroup, CTLDTroopManager | 2026-03-31 |
| `src/CTLD_jtac.lua` | CTLDJTAC, CTLDJTACDetector, CTLDJTACMessage, CTLDJTACManager | 2026-04-01 |
| `src/CTLD_core.lua` | EventDispatcher, CTLDDCSEventBridge, CTLDPlayerTracker, CTLDCoreManager | 2026-04-02 |
| `src/CTLD_zone.lua` | CTLDTroopZone, CTLDLogisticZone, CTLDZoneManager | 2026-04-02 |
| `src/CTLD_beacon.lua` | CTLDBeacon, CTLDBeaconManager | 2026-04-02 |
| `src/CTLD_recon.lua` | CTLDReconRenderer, CTLDReconManager | 2026-04-02 |
| `src/CTLD_fob.lua` | CTLDFOB, CTLDFOBManager | 2026-04-03 |
| `src/scenes/CTLD_mineFieldScene.lua` | mineFieldScene, setLandMine, setLandMineAuto | 2026-04-09 — ✅ recette complète (U-74→U-75, F-83→F-87, visual ✅) |
| `src/scenes/CTLD_farpScene.lua` | farpScene | 2026-04-14 — ✅ F-91 visual recette PASS |
| `src/scenes/CTLD_fobScene.lua` | fobScene | 2026-04-14 — ✅ F-90/F-93 visual recette PASS |
| ~~`src/scenes/CTLD_aa*Scene.lua`~~ | ~~6 fichiers AA~~ | 🗑️ **Supprimés 2026-04-07** — compositions AA dans CTLDCrateAssemblyManager.TEMPLATES |

> All scenes validated visually in DCS: farpScene ✅ F-91, fobScene ✅ F-90/F-93, mineFieldScene ✅ F-83–F-87 [2026-04-09/14].

### 2.2 — All files ✅ DONE

All P1/C1/M1–M7 classes implemented, recette 100%. See Module completion status table below.

### 2.3 — ~~CTLDCoalition~~ / ~~CTLDStateManager~~ — SUPPRIMÉS ✅

**Décision 2026-04-02** : ces deux classes sont supprimées du plan.

Les managers OOP absorbent naturellement l'état coalition sans couche intermédiaire :

- État coalition-splitté → convention uniforme `self._data = { [1]={}, [2]={} }` dans chaque manager
- Les 50+ branches `if coalition==1` du legacy disparaissent par construction (indexation directe par `coalitionId`)
- Pas de registre central nécessaire : chaque manager est propriétaire de son état

**C1 se réduit à 4 classes :** CTLDDCSEventBridge, CTLDPlayerTracker, CTLDCoreManager, EventDispatcher.

### 2.5 — Features ✅ ALL DONE

FA (parachute) ✅, FB (slingload) ✅, FC (MM crate detection) ✅, FD (LoadableGroups) ✅, FE (ctld.log) ✅

---

## Phase 3 — MIST middleware ✅ COMPLETE

All `mist.*` API calls replaced by `ctld.utils.*` in `src/`.
Remaining "mist" occurrences in source are string literals in log messages only.

---

## Phase 4 — Legacy API compatibility ✅ COMPLETE [2026-04-15]

22 wrappers in `src/legacy/legacy_api.lua`. Migration guide in `docs/dev-guide.md` §7.
Each wrapper logs a deprecation warning and delegates to the v2 manager.

---

## Phase 5 — Unit tests ✅ Infrastructure done [2026-04-15]

| Task | Status | Detail |
| ---- | ------ | ------ |
| 5.1 | ✅ | busted config (`.busted`), CI job (choco lua + luarocks + busted) |
| 5.2 | ✅ | `tests/helpers/dcs_stubs.lua` — full DCS API stubs |
| 5.3 | ✅ (partial) | `tests/specs/crate_manager_spec.lua` (8 specs) — more specs pending |
| 5.4 | ✅ | In-game recette via Witchcraft (all modules 100%) |

---

## Phase 6 — CI infrastructure ✅ Core done [2026-04-15]

| Task | Status | Detail |
| ---- | ------ | ------ |
| 6.1 | ✅ Done | `tools/build/merge_CTLD.ps1` → `CTLD_Next.lua` |
| 6.2 | ✅ Done | GitHub Actions — run busted tests [2026-04-15] |
| 6.3 | ✅ Done | GitHub Actions — build `CTLD_Next.lua` on push [2026-04-15] |
| 6.4 | ✅ Done | GitHub Actions — release artifact on tag `v*` → GitHub Release + CTLD_Next.lua [2026-04-16] |
| 6.5 | ✅ Done | GitHub Actions — MkDocs deploy to GitHub Pages (push master → gh-pages) [2026-04-16] |
| 6.6 | ✅ Done | i18n lint: `tools/build/generate_i18n_dicts.ps1` |

---

## Phase 7 — i18n ✅ COMPLETE

| File | Content |
| ---- | ------- |
| `src/CTLD_i18n.lua` | Runtime engine: `ctld.tr()`, language selection, fallback EN |
| `src/CTLD_i18n_en.lua` | English reference keys (authoritative) |
| `src/CTLD_i18n_fr.lua` | French translations |
| `src/CTLD_i18n_es.lua` | Spanish translations |
| `src/CTLD_i18n_ko.lua` | Korean translations |
| `tools/build/generate_i18n_dicts.ps1` | Key sync — detects drift between languages |

Rules: all player-visible strings use `ctld.tr()`. Key added to EN first, propagated by generator.

---

## Phase 8 — Documentation ✅ COMPLETE [2026-04-15]

| Audience | File | Status |
| -------- | ---- | ------ |
| Mission maker | `docs/missionmaker_guide.md` | ✅ §1–16 complete |
| Developer | `docs/dev-guide.md` | ✅ Complete (architecture, new module, events, build, tests, migration v1→v2) |
| MkDocs / GitHub Pages | `mkdocs.yml` + `docs/index.md` | ✅ Done — CI job 6.5 (gh-deploy on push master) [2026-04-16] |

---

## Module completion status

| Module | Impl | Spec | Recette | % recette | Notes |
| ------ | ---- | ---- | ------- | --------- | ----- |
| Config (`CTLD_config.lua`) | ✅ | ✅ | ✅ | 100% | U-84→U-89 + F-101→F-102, 57/57 PASS [2026-04-16]. CL-4/5/6: JTAC_unitTypeNames supprimé, poids soldats connectés, 7 clés undeclared exposées [2026-05-12] |
| Utils (`CTLD_utils.lua`) | ✅ | N/A | ✅ | 100% | M9: U-67→U-73 + F-78→F-80, 118/118 PASS [2026-04-09] |
| Menu (`CTLD_menu.lua`) | ✅ | ✅ | ✅ | 100% | M8: U-57→U-66 + F-72→F-77 + F-81→F-82 visual ✅ [2026-04-09] |
| SceneManager (`CTLD_sceneManager.lua`) | ✅ | ✅ | ✅ | 100% | R4: U-43→U-44 + F-42→F-44, 2026-04-07 |
| **Crates** (`CTLD_crate.lua`) | ✅ | ✅ | ✅ | **100%** | R1 ✅ [2026-04-07]. CL-4: quota gate _spawnUnpacked + getJTACDescriptors() [2026-05-12] |
| **Troops** (`CTLD_troop.lua`) | ✅ | ✅ | ✅ | **100%** | R2 ✅ [2026-04-07]. CL-5: _weightForGroup() randomisation `[SW×0.9,SW×1.2]` + config keys actifs [2026-05-12]. Feature L: multi-group `_inTransit`, disembark/extract menus, bugfixes spawn overlap+extract guard, F-140→F-146 22/22 PASS + MT-01 live DCS [2026-05-12]. Feature I bugfix: grpName nil hors WPZ block dans disembark, MT-10 5/5 PASS [2026-05-20] |
| **JTAC** (`CTLD_jtac.lua`) | ✅ | ✅ | ✅ | **100%** | R3 ✅ [2026-04-07]. CL-4: _consumeJTACSlot + getJTACDescriptors + spawnJTACFromDescriptor [2026-05-12] |
| Core (`CTLD_core.lua`) | ✅ | ✅ | ✅ | 100% | 9/9 PASS [2026-04-02]. Feature N: INIT-A _initAITransports/_checkAIStatus, F-133/F-134 [2026-05-12]. Feature R: onAILand (S_EVENT_LAND) pickup+dropoff véhicule+troupes, ipairs fix, maxVehicleWeight gate, MT-07→MT-10 PASS [2026-05-20]. Feature T: _aiTransportVehicle runtime tracking, onAILand virtual vehicle pickup/dropoff (playScene/spawnVehicleAt), stock consume/restore calls, F-176→F-180 PASS [2026-06-06] |
| Zones (`CTLD_zone.lua`) | ✅ | ✅ | ✅ | 100% | 9/9 PASS [2026-04-02]. Feature R+S: `_loadAIZonesFromConfig`, `_validateZoneNames` AIZ section, `troopTemplates`/`vehicleTypes` whitelists, `getAIPickupZoneAt`/`getAIDropoffZoneAt`, F-R-1→F-R-49 147/147 PASS [2026-05-20]. Feature T: `parseStockTable`, `_aiTroopStock`/`_aiVehicleStock` fields, 6 méthodes aiPick/aiConsume/aiRestore, F-176→F-180 58/58 PASS [2026-06-06] |
| Beacons (`CTLD_beacon.lua`) | ✅ | ✅ | ✅ | 100% | 5/5 PASS [2026-04-02] |
| Recon (`CTLD_recon.lua`) | ✅ | ✅ | ✅ | 100% | 5/5 PASS [2026-04-02] + F-116→F-119 19/19 PASS [2026-04-29] + F-150→F-158 22/22 PASS [2026-05-17] + MT-06 9/9 PASS [2026-05-17] — Feature F: CTLDStaticWatcher, farp_fob layer, drawFarpIcon, coalition rendering, MarkIdCounter persistence ; bugfixes menu: reconF10Menu guard, labels [activate]/[deactivate], no early-return 0 layers |
| FOB (`CTLD_fob.lua`) | ✅ | ✅ | ✅ | 100% | 4/4 + F-90/F-93 visual ✅ [2026-04-14] |
| Vehicles (`CTLD_vehicle.lua`) | ✅ | ✅ | ✅ | 100% | 10/10 PASS [2026-04-07]. CL-4: spawnJTACFromDescriptor (ground+air) [2026-05-12] |
| AA System (`CTLD_aasystem.lua`) | ✅ | ✅ | ✅ | 100% | 6/6 PASS [2026-04-07] |
| Player (`CTLD_player.lua`) | ✅ | ✅ | ✅ | 100% | 7/7 PASS [2026-04-07] |
| mineFieldScene | ✅ | ✅ | ✅ | 100% | U-74→U-75 + F-83→F-87, 40/40 PASS visual ✅ [2026-04-09] — quinconce + setLandMineAuto + showMinefieldOnF10Map |
| Scenes fob/farp | ✅ | ✅ | ✅ | 100% | F-90/F-91 visual ✅ [2026-04-14] |
| i18n | ✅ | ✅ | ✅ | 100% | U-90→U-96 + F-103→F-105, 63/63 PASS [2026-04-16] — ctld.i18n_audit/auditAll, fallback chain, completeness FR/ES/KO |
| ObjectRegistry (`lib/CTLD_objectRegistry.lua`) | ✅ | ✅ | ✅ | 100% | U-54→U-56 43/43 PASS [2026-04-08] |
| Feature A (parachute) | ✅ | ✅ | ✅ | 100% | F-57→F-64 33/33 PASS [2026-04-08] |
| Feature B (slingload) | ✅ | ✅ | ✅ | 100% | F-65→F-71 22/22 PASS [2026-04-08] |
| Feature C (MM crate) | ✅ | ✅ | ✅ | 100% | registerMMCrate + OnMMCrateDetected, F-41 PASS [2026-04-07] |
| Feature D (LoadableGroups) | ✅ | ✅ | ✅ | 100% | U-76→U-80 + F-88→F-89, 102/102 PASS [2026-04-14] |
| Feature E (CTLD log) | ✅ | ✅ | ✅ | 100% | initLog/log/closeLog dans CTLD_utils.lua — validé via utils recette M9 [2026-04-09] |
| **Troop + JTAC Lifecycle** (`src/CTLD_troop.lua`) | ✅ impl | ✅ spec | ✅ 8/8 | 100% | ✅ Terminologie rename + États rename + _aliveUnits/_jtacUnits + S_EVENT_DEAD sync + deregisterJTAC × N + multi-JTAC N× + orphan cleanup [2026-05-02]. Recette: `live_tests/scenarios/scenarioTroopsFullCycle_v2.lua` 8/8 PASS [2026-05-04] |
| **Mise en conformité scénarios recette** | ✅ template | — | ✅ 100% | 100% | ✅ 52 scénarios auto/ + interactive/ migrés au format v2 (Witchcraft guard, \_RUNNING guard, do..end, \_savedDebugScreenLog, clearview outText final). Template v2.0 créé. Validé DCS live : FR all pass, F181 all pass, F-SC 11/11, MT-12 OK, MT-05 11/12 [2026-06-30] |

---

## Branching strategy

```text
master (stable v1.x)
  └── feature_modularisation_and_Config  (v2 in progress)
        └── feature/<description>        (sub-features)
```

Tags: `v2.0-alpha.1`, `v2.0-beta.1`, `v2.0-rc.1`, `v2.0`

---

## Code cleanup backlog

Minor cleanups identified — low priority, no functional impact.

- ~~**CL-1**~~ ✅ `findDescriptorByTypeName` — fallback `descriptor.type` déjà absent du code [vérifié 2026-05-19].
  `_weightIndex` path et fallback config scan testent uniquement `descriptor.unit`. Rien à modifier.
- ~~**CL-2**~~ ✅ `forceCrateToBeMoved` dropped intentionally. `canUnpack()` has no movement constraint. U-31 updated (7→4 cases, force param removed). recette.md updated.
- ~~**CL-3**~~ ✅ Nettoyage clés config obsolètes [2026-05-12] :
  Supprimées (remplacées par mécanismes POO) : `CTLD_ctldStatusF10` (menu CTLD Status non porté),
  `staticBugWorkaround` (bug DCS obsolète), `spawnRPGWithCoalition` (remplacé par loadableGroups),
  `spawnStinger` (remplacé par loadableGroups), `InfantryInGameCount` (remplacé par `_countDroppedTroops()`).
  Conservées (actives via configKey) : `enableCrates`, `JTAC_jtacStatusF10`.
  Portées dans la même session : `JTAC_smokeOffset_x` / `_z` (feature JTAC smoke x/z, cf. ci-dessous).
  `loadCrateFromMenu` : conserver (gate menu "Request Crate").
- ~~**CL-4**~~ ✅ Quota `JTAC_LIMIT_RED/BLUE` implémenté. `_consumeJTACSlot(coalition)` sur CTLDJTACManager;
  consommé avant spawn dans `_spawnUnpacked` (crate) et `spawnJTACFromDescriptor` (menu).
  Quota définitif (legacy), MM JTACs et soldiers exemptés. `JTAC_unitTypeNames` supprimé —
  menu "Request JTAC Equipment" reconstruit depuis `getJTACDescriptors()` (crates `isJTAC=true`).
  Drones supportés via `deployAirJTAC`. i18n+guides mis à jour. [2026-05-12]
- ~~**CL-5**~~ ✅ Poids soldats connectés à la config. `_ROLE_WEIGHTS` (hardcodée, base=84 figée) remplacée par
  `_ROLE_EQUIP_WEIGHTS` (fallback), `_initWeightConfig()` (lecture `ctld.gs()` à l'init) et
  `_weightForGroup()` (randomisation par soldat dans [SW×0.9, SW×1.2] + kit + équipement).
  Clés `SOLDIER_WEIGHT`, `KIT_WEIGHT`, `RIFLE_WEIGHT`, `MANPAD_WEIGHT`, `MG_WEIGHT`,
  `MORTAR_WEIGHT`, `JTAC_WEIGHT`, `RPG_WEIGHT` désormais actives. [2026-05-12]
- ~~**CL-6**~~ ✅ 15 clés orphelines (lues via `ctld.gs()` mais sans défaut dans config) ajoutées à `CTLD_config.lua` [2026-05-17] :
  Crates : `crateSpacing`=5, `spawnDistanceInCircle`=10, `maxDropHeight`=7.5.
  Troupes : `maxTransportWeight`=0, `transportLimitByType`=nil.
  Beacons : `beaconLayerEnabled`=false, `beaconAutoRefreshLayer`=false, `beaconRefreshInterval`=60,
    `beaconIconRadius`=25, `beaconIconColor`={orange}, `beaconTextSize`=12.
  Zones : `dynamicZoneRadius`=200, `smokeRefreshInterval`=300,
    `logisticZoneSmokeColor`=nil, `troopZoneSmokeColor`=nil.
  Note : CL-6 marqué ✅ en [2026-05-12] mais jamais appliqué — corrigé dans cette session.
- ~~**CL-7**~~ ✅ 5 params obsolètes supprimés de `CTLD_config.lua` + `docs/missionmaker_guide.md` [2026-05-17] :
  `addPlayerAircraftByType`, `aircraftTypeTable` (arch. v2 utilise typeName natif),
  `buildTimeFOB` (timing FOB interne), `crateWaitTime` (état manager),
  `minimumDeployDistance` (garde LGZ-unpack obsolète, FOB a `fobMinDistanceFromZones`).
- ~~**CL-8**~~ ✅ Points config — tous traités (audit 2026-05-17) :
  • ~~`dynamicLogisticUnitsIndex`~~ ✅ — feature résilience portée via `CTLDLogisticZone:isAlive()` + `CTLDFOBManager:_destroyFOB()` → `unregisterLogistic()`. FOB = seul moyen de créer une LGZ dynamique. MM guide §4 + §12 mis à jour [2026-05-19].
  • ~~`loadCrateFromMenu`~~ ✅ — gate `refreshLoadCrateSection` + `buildMenuSection` + `refreshCrateFlightSection` (3 sites câblés) ; recette F-B3-1→F-B3-5 5/5 PASS [2026-05-19]
  • ~~`maximumSearchDistance`~~ ✅ — câblé dans `_assignPostSpawnTask` `AttackNearestEnemyOnLos` (remplace hardcode 10000) ; recette F-B4-1→F-B4-3 3/3 PASS [2026-05-19]
  • ~~`maximumMoveDistance`~~ ✅ — supprimé de `CTLD_config.lua` + `CTLD_userConfig.lua` [2026-05-19]. V2 n'a pas d'errance aléatoire : `_assignPostSpawnTask` utilise des tâches explicites (`gotoNearestWPZ` / `AttackNearestEnemyOnLos`), pas de fallback random.
  • ~~`unitLoadLimits`~~ — absorbé par Feature P ✅ (`maxTroopsOnboard` dans `capabilitiesByType`)
  • ✅ `vehiclesForTransportRED/BLUE` + `maxVehiclesByType` — fusionnés en `vehicleTransportCapabilities` [2026-05-17] (Feature Q)

- ~~**CL-9**~~ ✅ `ctld.pickupZones` → instanciation en CTLDTroopZone [2026-05-19]
  Analyse : instanciation correcte pour trigger zones. Deux gaps identifiés et corrigés :
  • GAP-1 — Ship unit name fallback : `Unit.getByName` si `trigger.misc.getZone` retourne nil → snapshot position ship + rayon `maximumDistancePackableUnitsSearch`
  • GAP-2 — `stockFlagName` auto-dérivé : `zoneName.."_count"` (ex. "pickzone1_count") ; `_syncStockFlag()` appelé dans `consumeStock` + `restoreStock`
  Note : `zd[6]` (flag numérique legacy) ignoré — remplacé par dérivation automatique du nom de flag.
  Recette F-CL9-1→F-CL9-4 18/18 PASS.

- ✅ **CL-10** Algo ouverture accès CTLD aux pilotes — `addPlayerAircraftByType` / `transportPilotNames`
  Réimplémenté dans CTLDPlayerManager.onPlayerEnterUnit + config default=true + userConfig doc + MM guide §Access control.
  Recette F-CL10-1→F-CL10-3 3/3 PASS.

- ✅ **CL-11** Renommage `dynamic` → `NativeDcsCargoSystem` — **décision : Option A, statu quo**
  Analyse : clé `"dynamic"` rarement surchargée par les MMs, breaking change non nul pour gain de lisibilité marginal. Cohérence avec `CTLD_zone.lua:isDynamic()` (contexte différent). Pas de modification de code.

- ✅ **POST-PROJECT** Mise à jour specs techniques (`migration/specs/`) [2026-07-04]
  `CTLD_DesignSpec.md` : statuts classes (tous ✅), CTLDObjectsDescDb → CTLDObjectRegistry, isTransport/unitActions → capabilitiesByType, build system (`tools/build/`, `merge_CTLD.ps1`), EVOs tous ✅. Autres specs déjà à jour (2026-06-28/29).

- ~~**CL-12**~~ ✅ Refonte README [2026-06-29]
  Toutes sections v2 documentées : capabilitiesByType, zone naming conventions (TRZ_/LGZ_/WPZ_),
  extract zones (TRZ_ stock=0), AI zones, extractableGroups, all scripting API avec paramètres complets.
  Fix : lien README_old.md cassé remplacé par anchor interne #migration-from-v1.

---

## Backlog ideas

- **Feature T — AIZ stock par template/type** ✅ IMPLÉMENTÉE + RECETTÉE [2026-06-06]
  Remplace `troopStock: number` par des tables `troopStock`/`vehicleStock` `{[name]=N}` (N=-1=illimité, N>0=limité).
  Clé spéciale `"All"=-1` = tous les types disponibles, illimité.
  Algorithme rotation (C) : parmi les templates eligibles (stock>0 ET capacité compatible), choisir au hasard parmi ceux à stock courant le plus élevé.
  Véhicules virtuels : `aiPickVehicleEntry()` → `{type, isScene}` ; si isScene=true → `playScene()` à la livraison ; sinon → `spawnVehicleAt()`.
  `_aiTransportVehicle[unitName]` : tracking runtime du véhicule virtuel en transit (set au pickup, clear au dropoff).
  `pickMaxStock=0` (gate illimitée) sur les zones AIZ_P so que `embarkFromTroopZone` ne bloque jamais sur stock.
  Restauration stock sur dropoff si `dropZone.isAIPickup=true` (navette).
  Recette : F-176→F-180 58/58 PASS [2026-06-06] — parsing tables, rotation, consume, restore, isScene flag.
  ~~**AIZ_P vehicle stock** : réfléchir à la possibilité de définir et gérer un stock de véhicules loadables sur une zone AIZ_P~~ → résolu par Feature T.

- **Feature S — AIZ config-only** ✅ IMPLÉMENTÉE + RECETTÉE [2026-05-20]
  Remplacement complet de la convention de nommage `AIZ_name_[R|B|N]_[P|D]_...` par une table `cfg.settings["aiZones"]` dans userConfig. Coupure franche — aucune rétrocompatibilité naming.
  Paramètres par zone : `dcsZoneName`, `coalition`, `isPickup`, `isDropoff`, `cargoType`,
    `troopStock` (0=désactivé, -1=illimité), `troopTemplates` (nil/{}=tous, 1=garanti, N=random parmi listés ET compatibles), `vehicleTypes` (whitelist DCS typeNames, nil=tous présents dans zone), `aiDropMode` (dropoff only).
  Véhicules = présents physiquement dans la zone DCS (pas de stock CTLD).
  Implémentation : `_parseAIZ` supprimé ; `_loadAIZonesFromConfig()` ajouté ; `onAILand` filtres troopTemplates+vehicleTypes ; `_validateZoneNames` section AIZ ; `CTLD_userConfig.lua` zones MT-07→MT-10 natives actives ; guide MM §4.4 réécrit.
  Recette : F-R-1→F-R-49 147/147 PASS [2026-05-20] — Section 11 (G1→G5), Section 12 (rapport MM live outText écran).
  Fixes [2026-05-20] : Fix 5 (cargoType invalide → `warns[]` correctement) ; Fix 6 (aiDropMode invalide → zone stocke "GP" réellement dans `_loadAIZonesFromConfig`).
  Nouveaux checks [2026-05-20] : G1 ni isPickup ni isDropoff→ERROR ; G2 tous troopTemplates inconnus→WARN distinct ; G3 troopStock=0 sur pickup troop→WARN ; G4 tous vehicleTypes inconnus dans loadableVehicles→WARN ; G5 cargoType=V/TV + aucun transport canTransportWholeVehicle→ERROR.
  ✅ **TODO [1] DONE [2026-05-21] : renommage `gotoAttackNearestEnemyOnLos` → `AttackNearestEnemyOnLos` — tous fichiers impactés mis à jour (src/CTLD_troop.lua, src/CTLD_config.lua, scénarios recette, diags, recette.md, missionmaker_guide.md, MODERNIZATION-PLAN.md).**
  ✅ **TODO [2] DONE [2026-06-06] : re-recette MT-07→MT-10 en interactif — lifecycle complet validé live DCS, zones chargées via _loadAIZonesFromConfig() depuis userConfig.**
  ✅ **TODO [3] DONE [2026-06-06] : zones `aiZones` de recette placées dans userConfig sous `if _cfg.settings["debug"] == true then` — code source propre, aucune donnée de test dans _initAITransports().**
  ✅ **TODO [4] DONE [2026-06-06] : `_validateZoneNames()` i18n complet — 15 clés EN/FR/ES/KO via ctld.tr(), substitutions %1/%2, commit 7dbb45b.**
  ✅ **TODO [5] DONE [2026-06-06] : docs/CTLD_CDC.md §4.6 (réécriture Feature S + AIZ + validation + onAILand/_checkAIStatus) + §4.16 (CTLDCoreManager, séquence init 21 étapes) + docs/missionmaker_guide.md §4.4 subsection "Validation report" (G1-G5/Fix5/Fix6/Overlap), commit b4efb5e.**

- **Feature U — AI AA system deployment** ✅ IMPLÉMENTÉE + RECETTÉE [2026-06-06]
  `CTLDCrateAssemblyManager:getTemplateByName(name)` — lookup par `tmpl.name` (6 systèmes).
  `CTLDCrateAssemblyManager:spawnSystemAt(templateName, point, coa, countryId)` — bypass caisses, cercle _SPAWN_RADIUS, aaLaunchers config, limit gate, OnAASystemDeployed event.
  `_spawnGroup` refactorisé : signature `(positions, types, headings, countryId)` — plus de dépendance heli.
  `CTLDTroopZone:aiPickVehicleEntry()` — 3e catégorie isAASystem : CTLDSceneManager (isScene) → CTLDCrateAssemblyManager (isAASystem) → DCS natif.
  `CTLDCoreManager:onAILand` dropoff — branche `elseif vEntry.isAASystem then spawnSystemAt()`.
  `CTLD_userConfig.lua` — zones MT-14 debug (AIZ_mt14_B_P_V vehicleStock=HAWK/AIZ_mt14_B_D).
  Recette F-181 (19/19 PASS) + F-182 (11/11 PASS) [2026-06-06].
  **MT-14 ✅ PASS live DCS [2026-06-07]** — pickup HAWK isAASystem=true, dropoff spawnSystemAt 10 unités, stock 1→0 ; bugfix `computeSafeDropPos` rearSector + i18n "loaded/unloaded/delivered" sans "vehicle".
  **TODO [6] ✅ [2026-06-07]** — FARP Alpha scene : Cargo06 + ammo_cargo×2 pivotés à 90° (orientation correcte) + repositionnés (d+3m extérieur, angle+1.2° droite pour Cargo06).
  **MT-13 ✅ PASS live DCS [2026-07-05]** — layout FARP Alpha validé visuellement (spawn depuis UH-1H via `spawn_farp_alpha_uh1h.lua`) : Cargo06+ammo_cargo×2 orientations 90°/95° confirmées, windsock 80m/10°, tente 130m/5°, trucks 110-125m/15°. Note ⚠️ recette.md soldée.

- **Templates de troupes paramétriques (composants configurables)** ✅ IMPLÉMENTÉ [2026-06-07]
  `_UNIT_TYPES` → `_ROLE_TYPENAMES` + rôle `civ` (Civilian, CIV_WEIGHT=2kg).
  `componentTypes` par template : override DCS typeName par rôle/coalition.
  Rôles custom libres (civ1/civ2/civ3…) via componentTypes — processés après `_ROLE_ORDER`.
  Fallback : typeName invalide (mod absent) → soldat standard coalition + WARN log.
  `_weightForGroup` : rôles custom `civ*` → CIV_WEIGHT, autres → RIFLE_WEIGHT.
  `CTLDModValidator` probing couvre les typeNames de componentTypes au INIT-MOD.
  Exemple "Civilian Crowd" commenté dans `CTLD_config.lua`. Commit ec8cf6a.

- **CTLDModValidator** ✅ IMPLÉMENTÉ ET RECETTÉ [2026-06-07]
  Sonde tous les DCS typeNames déclarés dans CTLD au INIT-MOD, avant tout spawn joueur.
  GROUND : `coalition.addGroup` + `unit:getTypeName() != requested` (DCS substitue Leopard-2 si inconnu).
  STATIC : `coalition.addStaticObject` → nil = inconnu. Passe tous les champs du descriptor (shape_name, livery_id…).
  HELIPORT : `StaticObject:getDesc().life` — valide → `life>0`, invalide → `life==0`. Spawn off-map +800km est
    (ghost hors zone jouable). Confirmé empiriquement + visuellement [2026-06-07] :
    type invalide → icône punaise F10 (vs T pour valide) + life==0 dans getDesc().
    DCS substitue visuellement par SINGLE_HELIPAD mais `getTypeName()` conserve le nom demandé (anomalie DCS).
  Sources couvertes : CTLDObjectRegistry._db, spawnableCrates (filtre `_repairFor` et `spawnAs`), TEMPLATES parts.DCSTypename, loadableGroups componentTypes.
  77 types sondés, 0 NOT FOUND sur config standard. Rapport WARN in-game si type manquant.
  Recette : U-106/U-107/U-108 — 12/12 PASS [2026-06-07]
  Commits : ec8cf6a, be54adf, f7eb611, d459120, b48a5a3.

- **Refactor repair crates AA + TEMPLATES source unique** ✅ IMPLÉMENTÉ [2026-06-07]
  `buildableGroups` ne contient plus de sentinelles `"HAWK Repair"` etc. — ces entrées étaient des identifiants internes CTLD, non des DCS typeNames.
  `TEMPLATES.repair` : string → struct `{ desc, weight }` (side hérité du template).
  `TEMPLATES` déplacé dans `CTLD_config.lua` (après spawnableCrates) — source unique MM pour décrire un système AA (assembly + caisses menu + repair).
  `injectAACrates(spawnableCrates)` : injecte parts (avec weight), mixedSet auto, repair — appelé depuis `CTLDCrateManager._processSpawnableCrates()`.
  Sections "SAM mid range"/"SAM long range" supprimées de spawnableCrates.
  `getTemplateForUnit(unitName, repairFor)` : détection repair via `_repairFor` flag.
  Clé config corrigée : `"buildableGroups"` → `"spawnableCrates"` (bug pré-existant).
  Commits : d459120, b48a5a3.

- **Feature V — Repack de scène (Countryside FARP / FARP Alpha)** ✅ IMPLÉMENTÉE [2026-06-28] — voir TODO [I]/[Q]/[P] ci-dessous
  Permettre au joueur de "repacker" une scène déployée en recréant la caisse d'origine dans l'inventaire logistique.
  Prérequis techniques :
  1. `CTLDSceneManager` doit conserver les références des objets spawned après `_execute()` terminé (purger `_active` seulement sur repack/destroy, pas après la dernière step).
  2. Implémenter `CTLDSceneManager:destroyScene(name)` : détruire tous les `_spawnedObjs` et nettoyer `_active`.
  3. **Bloquant : l'Invisible FARP (Heliport)** est non destructible via DCS scripting — **confirmé empiriquement [2026-06-07]** via `diag_farp_destroy_test.lua` (spawn hors hélico, pleine nature) :
     - `Airbase:destroy()` **fonctionne partiellement** [2026-06-07] — confirmé empiriquement :
       · Après destroy() : `Airbase.getByName()` → nil ✓ (airbase retirée du registre DCS)
       · Après destroy() : `world.getAirbases()` ne la liste plus ✓
       · FARP non fonctionnel (ravitaillement/réarmement désactivé) ✓
       · MAIS modèle 3D et pastille carte F10 restent comme artefacts visuels orphelins ✗
     - `StaticObject:destroy()` → sans effet (ni registre ni visuel)
     - `Airbase:getUnit(1)` → nil (pas d'objet sous-jacent exposé)
     - `coalition.getStaticObjects()` n'énumère PAS les Heliport statics (uniquement via getByName/world.getAirbases)
     - `coalition.addStaticObject` ne vérifie pas l'unicité du nom → chaque appel crée une entrée distincte.
       `world.getAirbases()` liste TOUTES les entrées ; `Airbase.getByName()` n'en retourne qu'une.
       Cleanup correct : itérer `world.getAirbases()`, filtrer par nom, destroy() sur chacune.
     - Conclusion pour Feature V : repack fonctionnellement possible via Airbase:destroy() sur chaque instance.
       Limitation résiduelle : ghost visuel (3D + F10) non suppressible par script.
     - ✅ Piste ModValidator Heliport CLOSE [2026-06-08] : pour les mods custom heliport,
       `getDesc().life == 0` ET `getLife() == 3600` (constante DCS) que le mod soit installé ou non —
       aucun discriminant API existant. Solution finale : `probeSkip = true` dans ObjectRegistry +
       skip dans `_collectTypeNames` (supprime le faux NOT FOUND). Seuls les types built-in
       (SINGLE_HELIPAD, FARP : life=10000000) peuvent être validés par la probe.
     Deux options :
     a. Remplacer l'Invisible FARP par un static de catégorie non-Heliport (FARP ne fonctionne plus en refuelling, mais le pad visuel reste) → repack possible.
     b. Attendre une future API DCS permettant la destruction des Heliport statics.
  4. Ajouter un menu F10 "Pack [nom scène]" visible quand le joueur est au sol dans le rayon des objets de scène.
  5. Respawner la caisse d'origine (descriptor identique à l'entrée spawnableCrates) à la position du joueur.
  Note : les Black_Tyre de marquage (coins) sont des Fortifications → destructibles sans problème.
  **TODO [A] ✅ DONE [2026-06-08]** — Countryside FARP migré dans `src/scenes/CTLD_countrysideFarpScene.lua`
    (self-registration + déclarations registry via `CTLDObjectRegistry.registerIfAbsent()`).
    Validé live DCS MT-16 [2026-06-08] : crate→unpack→Invisible FARP airbase OK, warehouse zeroed (4×0L),
    formation complète (trucks+tent+gardes+lumière+windsock+us carrier shooter). Délai F10 label = comportement DCS normal.
    Layout finalisé [2026-06-08] : trucks t+5s, tente t+5.1s (délai minimum 0.1s), shooter 20m/0°/hdg90°,
    warehouse vidé via setLiquidAmount(i,0) (Invisible FARP démarre avec carburant DCS par défaut).
  **TODO [A2] ✅ DONE [2026-06-08]** — FARP Alpha migré dans `src/scenes/CTLD_farpAlphaScene.lua`.
    _registerBuiltins() vidé. Toutes les scènes self-contained dans src/scenes/.
  **TODO [B] ✅ DONE [2026-06-08]** — `Farp_FG_Petit_Helipad` utilisé par la scène Metal FARP.
  **TODO [C] ✅ DONE [2026-06-08]** — `src/scenes/CTLD_metalFarpScene.lua` créé et validé live DCS.
    Farp_FG_Petit_Helipad (probeSkip=true) + 10 000L × 4 types de carburant + us carrier shooter.
    Layout : helipad 58m, camions sous tente (t+5/t+5.5s), windsock, lumière, ammo. Validé player.
  **TODO [D] ✅ DONE [2026-06-08]** — **Généralisation auto-menu scènes + auto-crate** implémentée.
  `refreshUnpackSection` : boucle générique `sm_ref:getModel(ut)` (remplace SCENE_SENTINELS + blocs dédiés).
  `CTLDCrateManager:_injectSceneCrate()` : injection idempotente, résolution collision de poids.
  `CTLDCrateManager._instance` exposé : callback dans `registerSceneModel()` → registration order-independent.
  Chaque scène dans un seul fichier (i18n + registry + model + self-registration).
  Validé live DCS : 4 scènes initiales PASS + late injection Metal FARP via Witchcraft PASS.
  **TODO [G] ✅ DONE [2026-06-09]** — **Menu register joueur déjà en vol — 3 sous-cas résolus** :
    (1) `onLand` appelle déjà `refreshLoadCrateSection` (ligne 304) ; CH-47 correctement détecté
    au sol depuis fix TODO [L] (groundAglThreshold + velocity). (2) `embarkFromTroopZone` appelle
    `refreshMenuSection` (ligne 750) → parachutage visible après réembarcation. (3)
    `CTLDTroopManager:buildMenu` jamais appelé hors PlayerManager → pas d'orphan submenu.

  **TODO [L] ✅ DONE [2026-06-09]** — **`groundAglThreshold` global — détection sol universelle** :
    `ctld.gs("groundAglThreshold")` (défaut 5.0 m) dans config section [3].
    `ctld.utils.inAir()` : si `unit:inAir()=true` ET AGL < seuil ET vitesse < 0.5 m/s → posé.
    Couvre tous les appareils à châssis haut sans config par type.
    `CTLDTroopManager:_isInAir()` et 3 appels `u:inAir()` dans `CTLD_core.lua` alignés.

  **TODO [K] ✅ DONE [2026-06-09]** — **Audit uniformité menus — pipeline déjà conforme** :
    Audit complet : aucun `typeName == "..."` hardcodé dans `CTLD_player.lua`, `CTLD_troop.lua`,
    `CTLD_crate.lua`. Pipeline uniforme : `onLand` refresh toutes sections ; `onTakeoff` refresh
    sections in-flight. Toute logique conditionnelle passe par `capabilitiesByType`. No action needed.

  **TODO [J]** ✅ DONE [2026-06-09] — **Recette : menu parachutage CH-47** :
    Validé live DCS. Bug root cause identifié et corrigé : `refreshMenuSection` retournait
    prématurément car `playerObj` passé depuis le callback menu était une table arg brute
    (sans `isTransport`). Fix : récupération du vrai `CTLDPlayer` via `getPlayer(unitName)`.
    Menu multi-groupe → 1 groupe → vide : comportement correct. commit e964eab.

  **TODO [I] ✅ DONE [2026-06-28]** — **Feature : repack FARP avec mémorisation du stock warehouse** :
    Implémenté via `CTLDCrate.metadata = {}` (bag arbitraire par instance) + `crate.metadata.warehouseSnapshot`
    (`{ liquid={[0]=v,[1]=v,[2]=v,[3]=v} }`) porté par la première crate du set. `CTLDSceneManager:packScene`
    appelle `model.onRepack(scene, repackData)` (pcall) avant destruction, stocke dans `repackData.warehouseSnapshot`.
    À l'unpack (manuel + auto), `repackData` extrait des crates avant `unpackCrate`, passé à `playScene`/
    `playSceneAtPos` → step warehouse lit `ctx.scene._params.repackData.warehouseSnapshot` si présent
    (`setLiquidAmount`) sinon initialise aux valeurs par défaut de la scène. Config `enableFARPRepack`
    (défaut `false`) contrôle l'affichage du menu "Pack FARP". Conditionné sur `ctld.gs("enableFARPRepack")`.

  **TODO [F] ✅ DONE [2026-06-09]** — **S_EVENT_PLAYER_ENTER/LEAVE_UNIT — comportement validé** :
    Tests live DCS (2026-06-09) : LEAVE+ENTER se déclenchent sur tout changement réel de slot
    (statique→statique, statique→dynamic, dynamic→dynamic). Seul cas aveugle : revalider le même
    slot sans naviguer dans l'UI → sans conséquence (état CTLD intact). Scan 30 s conservé comme
    filet de sécurité pour joiners tardifs MP.

  **TODO [H] ✅ DONE [2026-06-09]** — **Broadcast refresh Load Crate — déjà implémenté** :
    `CTLDCrateManager:_refreshNearbyPlayers(position)` (ligne 472) : broadcast `refreshLoadCrateSection`
    + `refreshUnpackSection` à tous les joueurs dans 300 m. Appelée depuis `spawnCrate`,
    `spawnCratesAligned`, event subscribers OnCrateSpawned. TODO obsolète.

  **TODO [E] ✅ DONE [2026-06-09]** — **Debug test mod absent/présent** : comportement Metal FARP
    validé live DCS dans les deux cas. Mod présent : scène complète (helipad + décor + warehouse
    stockée). Mod absent : step 1 `Farp_FG_Petit_Helipad` échoue silencieusement (`spawnObject` → nil,
    `farpName` non enregistré, step warehouse court-circuité) ; décor spawné (camions, tente, ammo,
    lumière, windsock) ; réparation + réarmement disponibles via camions DCS natifs ; pas de
    ravitaillement carburant ni d'airbase fonctionnelle. Aucun crash. Comportement conforme aux specs.

  **TODO [N] ✅ DONE [2026-06-09]** — **Parachutage crates — auto-unpack scène validé** :
    `_checkAutoUnpack` dispatche correctement : crate scène générique → `CTLDSceneManager:playSceneAtPos`
    (mock unit centroïde) ; crate équipement → `_spawnUnpacked` ; scène `autoUnpack=false` (FOB) →
    crates laissées au sol. `land.getHeight` bugfix (vec2 table). Validé live DCS :
    `Countryside FARP#1` auto-unpacké en 11 steps après parachutage crate unique.

  **TODO [O] ✅ DONE [2026-06-09]** — **FOB scene auto-unpack + CtldScene preFunc/abort** :
    `CtldScene`: `abort(reason)` + `preFunc` hook par step (avant spawn, `false`=skip spawn,
    `abort()`=stop scène) + `model.onComplete` fallback + `playSceneAtPos` accepte `params`.
    `fobScene` : `autoUnpack=false` supprimé ; step 21 (func-only) appelle
    `CTLDFOBManager:_registerDeployedFOB(scene)` (LGZ+beacon+event, self-contained).
    `CTLDFOBManager` : `_registerDeployedFOB(scene)` lit tout depuis `scene._params` ;
    `checkSpatialGuards()` public ; `unpackFOBCrates` passe params complets sans closure.
    `_checkAutoUnpack` : guards spatiaux FOB avant destruction crates ; params `cratesUsed`+
    `centroid` passés à `playSceneAtPos`. CS FARP + Metal FARP : compatibles sans modification.

  **TODO [P] ✅ DONE [2026-06-28]** — **Recette : scènes FOB + CS FARP + Metal FARP avec nouvelle logique CtldScene** :
    4/4 sous-cas validés live DCS :
    (1) FOB F10 — step 21 (func-only) appelle `_registerDeployedFOB(ctx.scene)` → LGZ+beacon enregistrés ✅
    (2) FOB parachute — `checkSpatialGuards` bloque si LGZ proche, `_checkAutoUnpack` déclenche scene+FOB ✅
    (3) CS FARP parachute — `_checkAutoUnpack` route vers `playSceneAtPos` (generic, pas fobCompatible) ✅
    (4) Metal FARP F10 — step 9 `addLiquid` warehouse stocking (ou skip propre si mod absent) ✅
    Scripts : `scenario_fob_scene.lua` (fixé : nom "FOB", params complets, plus de callback `_onFOBBuilt`),
    `scenario_p2_fob_parachute.lua`, `scenario_p3_csfarp_parachute.lua`, `scenario_p4_metal_farp.lua`.

  **TODO [Q] ✅ DONE [2026-06-28]** — **Feature : cycle de vie scène complet — onRepack, warehouse** :
    Implémenté conjointement avec TODO [I]. Architecture finale (simplifiée par rapport aux specs) :
    - `CtldScene._modelName` : nom du modèle pour lookup inverse dans le registry.
    - `CTLDSceneManager:findNearbyRepackableScenes(pos, radius)` : itère `_active`, filtre distance²
      et `model.onRepack` présent, retourne liste CtldScene candidats.
    - `CTLDSceneManager:packScene(scene)` : appelle `model.onRepack` (pcall), détruit tous `_spawnedObjs`
      (pcall par objet), retire de `_active`, retourne `repackData`.
    - `countrysideFarpScene.onRepack` / `metalFarpScene.onRepack` : lecture warehouse live (`getLiquidAmount(0-3)`)
      stockée dans `repackData.warehouseSnapshot`.
    - Steps warehouse adaptatifs : snapshot présent → `setLiquidAmount`; absent → init par défaut.
    - Menu "Pack FARP" (`refreshPackSection`) : sous-menu créé dynamiquement dans Crates, uniquement
      si `enableFARPRepack=true` ET scènes repackables à portée. Enabled/disabled selon sol/vol.
    - `findPackableVehicles` : itère `self._vehicles` WAITING (guard `if uName then`) au lieu de scanner
      `coalition.getGroups` — évite crash `Unit.getByName(nil)` et faux positifs.
    - `_spawnedComponents` et index inverse non implémentés (hors scope — `_spawnedObjs` suffisant).
    - i18n 4 langues (EN/FR/ES/KO) + MM guide mis à jour.
    - Recette warehouse_cycle : 3/3 PASS live DCS [2026-06-28] — crate présente, snapshot metadata, fuel restauré 5k/10k/15k/20k.

## CI Recette Workflow — Architecture cible

> Objectif : couvrir ≥60% des features principales en CI automatisé à chaque release.

### Taxonomie des recettes (6 niveaux)

| Niveau | Type | Dossier | Exécution | Outils |
| --- | --- | --- | --- | --- |
| **L1** | Busted unit | `tests/ci/unit/` | CI automatique (GitHub Actions) | busted, dcs_stubs.lua |
| **L2** | Busted functional | `tests/ci/functional/` | CI automatique (GitHub Actions) | busted, dcs_stubs.lua |
| **L3** | Witchcraft noPlayer | `tests/dcs/noPlayer/` | Développeur local — DCS + Witchcraft, pas de slot joueur | Witchcraft inject + CTLD.log |
| **L4** | Witchcraft pilotPassive | `tests/dcs/pilotPassive/` | Développeur local — DCS + joueur en cockpit, script pilote | Witchcraft inject + CTLD.log |
| **L5** | Witchcraft pilotActive | `tests/dcs/pilotActive/` | Développeur local — DCS + joueur doit agir au menu F10 | Witchcraft inject + F10 menu |
| **L6** | Manuel | `tests/manual_test_sequences.md` | Développeur local — joueur, checklist étape par étape | Observation pure |

> Les scripts L3/L4/L5 (U-*, F-*, scenario_*) sont injectés via Witchcraft dans une mission DCS active.
> Les specs L1/L2 (`*_spec.lua`) sont exécutées par busted sans DCS — l'API DCS est remplacée par `tests/ci/helpers/dcs_stubs.lua`.

### Structure `tests/`

```text
tests/
├── ci/                         ← scripts busted — exécutés par GitHub Actions CI
│   ├── helpers/
│   │   ├── dcs_stubs.lua       ← stubs DCS partagés
│   │   ├── loader.lua          ← charge src/ dans l'ordre listToMerge
│   │   └── init.lua            ← point d'entrée busted
│   ├── unit/                   ← L1 — ~105 tests (~21 spec files)
│   │   └── *_spec.lua
│   └── functional/             ← L2 — ~45 tests (8 spec files)
│       └── *_spec.lua
├── dcs/                        ← scripts Witchcraft — exécutés en DCS local par le développeur
│   ├── noPlayer/               ← L3 — U-xxx, F-xxx, scenario_* (pas de slot joueur requis)
│   ├── pilotPassive/           ← L4 — scenario_* (joueur en cockpit, script pilote tout)
│   ├── pilotActive/            ← L5 — scenario_* (joueur doit agir au menu F10)
│   ├── dev/                    ← diag/, legacy/ (scripts de diagnostic et référence)
│   └── util/                   ← utilitaires (reset_steps, wait_ctld_ready, init_log…)
├── recette.md                  ← historique de recette (qui/quand/résultat)
└── manual_test_sequences.md    ← L6 — checklists MT-xx manuelles
```

### Sélection L1/L2 — candidats CI

**L1 — Unit (tous migrables)** : U-001→U-096, U-106→U-108
Config, EventDispatcher, Zones, Crates, Troops, JTAC, Menu, Utils, i18n, ModValidator — ~105 tests

**L2 — Functional sélectifs** (stubs suffisants, pas de spawn DCS réel) :
F-033→F-040 (troop/JTAC lifecycle), F-057→F-071 (parachute/slingload),
F-078→F-080 (utils), F-101→F-105 (config/i18n), F-115 (markIds),
F-120→F-123 (vehicle load/unload), F-140→F-146 (multi-group) — ~45 tests

**Hors CI** (spawn DCS réel requis) : F-090, F-091, F-093 (scènes visuelles), F-081→F-082 (DCS F10 rendu), scenarios/*

**Coverage estimée** : ~150 tests CI → **~65% des features principales**

### Procédure de recette par niveau

#### L1/L2 — CI busted (automatique)

1. Push sur `master` ou `feature_*` → GitHub Actions déclenche job busted
2. Job : `busted tests/ci/` (pattern `_spec`)
3. Résultat : PASS/FAIL dans PR checks
4. Aucune action manuelle requise

#### L3 — noPlayer (DCS + Witchcraft, pas de slot joueur)

1. Lancer DCS avec la mission de test, Witchcraft activé
2. Injecter `CTLD_Next.lua` (après rebuild si src/ modifié) + attendre 3–5 s
3. Injecter le script `tests/dcs/noPlayer/F-xxx.lua` ou `scenario_xxx.lua`
4. Lire `tests/dcs/CTLD.log` : `fail=0` + aucun `[FAIL]`

#### L4 — pilotPassive (DCS + joueur en cockpit, script pilote)

1. Prendre un slot transport BLUE (UH-1H ou équivalent)
2. Injecter `CTLD_Next.lua` + attendre init
3. Injecter le scénario `tests/dcs/pilotPassive/scenario_xxx.lua`
4. Observer — aucune action F10 requise
5. Vérifier `[PASS]` sur tous les steps + contrôles visuels

#### L5 — pilotActive (DCS + joueur doit agir au menu F10)

1. Prendre un slot transport BLUE
2. Injecter `CTLD_Next.lua` + attendre init
3. Injecter le scénario `tests/dcs/pilotActive/scenario_xxx.lua`
4. Suivre les instructions à l'écran — effectuer les actions F10 demandées
5. Vérifier `[PASS]` + validation visuelle menu

#### L6 — Manuel (checklist pure)

Suivre `tests/manual_test_sequences.md` — aucun script, observation directe.

### TODOs

- ✅ **TODO-CI-1** : Déplacer les ~35 `diag_*` de `live_tests/` racine → `live_tests/dev/diag/`
- ✅ **TODO-CI-2** : Créer `tests/unit/` + `tests/functional/` + ajuster `.busted` pour scanner ces dossiers
- ✅ **TODO-CI-3** : Migrer U-001→U-096 + U-106→U-108 en busted `tests/unit/*_spec.lua` (Option C — réécriture format, pas copie)
  - 21 spec files couvrent l'ensemble du périmètre L1 ; U-022 (getDesc().box) et sondes DCS probes marqués `pending`
  - Correctif loader.lua : `lib/` → `core/` après renommage `src/lib` → `src/core`
- ✅ **TODO-CI-4** : Migrer F-* sélectifs (~45) en busted `tests/functional/*_spec.lua`
  - 8 spec files : troop_manager (F-033→036), jtac_manager (F-037→040), parachute (F-057→071),
    utils (F-078→080), config (F-101→105), mark_ids (F-115), vehicle (F-120→123), troop_multi (F-140→146)
  - ~45 tests couverts [2026-06-29]
- ✅ **TODO-CI-5** : Étendre `.github/workflows/ci.yml` — job busted sur `tests/unit/` + `tests/functional/`
  - Déjà satisfait : `busted tests/` scanne récursivement avec pattern `_spec` → couvre les deux répertoires
  - Ajout `workflow_dispatch` pour permettre les runs manuels sans PR [2026-06-29]
- ✅ **TODO-CI-6** : Documenter la procédure L3/L4 dans `docs/dev-guide.md` §Testing
  - `docs/dev-guide.md` §8 réécrit : busted, Witchcraft, CTLD.log, debug config, format sortie, cleanup [2026-06-29]
  - `docs/recette-procedure.md` créé : procédure complète L1→L4 (qui/quand/quoi, ordre, checklist) [2026-06-29]
- ✅ **TODO-CI-7** : Restructuration `live_tests/` → `tests/ci/` + `tests/dcs/` (noPlayer/pilotPassive/pilotActive) [2026-07-01]
  - 6 niveaux L1→L6 avec noms de dossiers reflétant le contexte d'exécution
  - Toutes les références `live_tests/` mises à jour : docs/, CLAUDE.md, .claude/witchcraft-workflow.md, src/
  - `docs/recette-procedure.md` réécrit avec taxonomie L1→L6 + tableaux de mapping par niveau
- ✅ **TODO-DOC-1** : Audit documentation MM + dev — vérifier que chaque module/feature de `src/` est couvert dans `docs/missionmaker_guide.md` et `docs/dev-guide.md` ; vérifier que `README.md` couvre toutes les fonctionnalités. Livrables : liste des lacunes + mises à jour des fichiers concernés.
  - `docs/dev-guide.md` §12–§19 ajoutés : Zone management, Vehicle system, Beacon, Recon, F10 Menu, Player tracking, AA System, Internal libraries [2026-06-29]
  - `README.md` : subsection Testing ajoutée avec commandes busted et pointeur vers `tests/` [2026-06-29]

- ✅ **TODO-CARGO-1** [2026-07-04] : Poids correctement mis à zéro après parachutage DCS-native — confirmé via `weight_trace.lua` (intercept `setUnitInternalCargo`) : après parachutage depuis menu CTLD, `ctld.utils.updateTransportWeight` est bien appelé et émet `setUnitInternalCargo(unitName, 0)`. Résolu en conjonction avec TODO-CARGO-4 (conversion `canParachuteDrop` au moment du chargement).

- ✅ **TODO-CARGO-2** [2026-07-04] : Aligné maxCratesOnboard=22 sur la capacité réelle DCS du C-130J-30 (22 caisses via UI cargo native). Correction dans CTLD_config.lua ligne C-130J-30.

- ✅ **TODO-CARGO-4** [2026-07-04] : Ghost cargo DCS UI après parachutage résolu — implémentation conversion `canParachuteDrop` : au moment de la détection DCS native load (`_checkNativeDCSCargo`), si l'appareil a `canParachuteDrop=true`, la crate est immédiatement convertie en CTLD-managed (`loadedByDCSNative=false`, `dcsStatic=nil`) via `UnloadCargo()` (opération sol) + destroy différé 0.5 s. Le slot DCS est libéré proprement avant décollage. Testé et validé sur UH-1H [2026-07-04] : chargement successif de nouvelles caisses possible après parachutage.

- ✅ **TODO-CARGO-3** [2026-07-04] : Faux positifs détection cargo DCS native réduits — deux correctifs implémentés :
  1. **Filtre vitesse** (`_checkNativeDCSCargo`) : rejet de tout transport dont la vitesse dépasse 0,5 m/s (spd²>0.25) — élimine les faux positifs de taxi.
  2. **Boucle anti-collision spawn** (`getSpawnObjectPositions`) : au spawn d’une caisse via menu CTLD, l’axe est tourné de 45° (8 essais max) jusqu’à ce qu’aucun point candidat ne soit dans la bbox d’un appareil DynamicCargo voisin — élimine les faux positifs post-spawn. Implémenté via `CTLDCrateManager:_getDynamicBBoxes()` + `_pointInBBoxLocal` dans `CTLD_utils.lua`.
  Note : dwell-time (appareil stationnaire glissant lentement sur une caisse) non implémenté — hors scope (gain nul avec le filtre vitesse).

- ✅ **TODO-MENU-1** [2026-07-05] : **CH-47 smoke bug — menu refresh éjection** — root cause : oscillation LAND↔TAKEOFF du flight-state poller déclenchait 4-6 `menu:refresh()` simultanés par transition, reconstruisant le menu DCS et éjectant le joueur de sa position dans le sous-menu. Fix en deux parties :
  1. **`_noRefresh` parameter** (`CTLD_crate.lua`) : `refreshUnpackSection` + `refreshPackEquiptSection` n’appellent plus `menu:refresh()` quand appelées depuis `refreshUnpackSectionForUnit` ou `refreshCrateFlightSection` — le refresh est consolidé en 1 seul appel en fin.
  2. **Debounce 150ms** (`CTLD_menu.lua`) : `ctld.Menu:refresh()` → `deferredRefreshForGroup()` : tous les appels dans une fenêtre de 150ms sont coalesçés en un seul rebuild DCS. `CTLDPlayerManager:refreshForUnit` utilise également `deferredRefreshForGroup` directement.
  Validé live DCS [2026-07-05] : CH-47 au sol avec crates chargées, click "Crate Commands → Drop Crate(s)" → crates déposées correctement, plus de smoke bleue parasite.

- ✅ **TODO-MENU-2** [2026-07-05] : **`_lgzGroundPoll` éjection menu Request Equipment** — le poller LGZ (10s tick) reconstruisait le menu `Request Equipment` pour tous les joueurs au sol toutes les 10s, éjectant le joueur de tout sous-menu en cours de navigation. Fix : le rebuild n’est déclenché que si le set de zones logistiques change (`_lgzKey` par joueur, calculé via `getLogisticZonesAtPoint` + tri+concat). Un joueur stationnaire dans la même zone ne déclenche plus aucun rebuild périodique.
  Validé live DCS [2026-07-05] : navigation "Request Equipment → Both → Countryside FARP - All crates" stable, 3 crates FARP spawned correctement.

- ✅ **TODO-MENU-3** [2026-07-05] : **Menu non mis à jour après déploiement de scène** — après `playScene` (ex. Countryside FARP), le menu "Pack Equipt" ne montrait pas le bouton Pack et "Unpack Crate" conservait l’entrée consommée, jusqu’au prochain décollage/atterrissage. Fix : ajout d’un `onComplete` callback sur l’appel `playScene` dans le chemin unpack générique qui appelle `refreshUnpackSectionForUnit(unitName)` à la fin de la scène (~30s pour CS FARP). Cela déclenche un refresh unpack+pack en un seul rebuild DCS.
  Validé live DCS [2026-07-05] : après déploiement CS FARP, "Pack Countryside FARP" apparaît dans Crate Commands sans décoller/atterrir.

- ✅ **TODO-MENU-4** [2026-07-05] : **Cycle infini unpack→pack→unpack Countryside FARP avec mémoire warehouse** — recette complète du cycle : Request Equipment → 3 crates FARP → load CH-47 → unpack → FARP déployé → pack → crates respawnées avec `warehouseSnapshot` → reload → re-unpack → FARP redéployé avec stock warehouse restauré. Validé live DCS [2026-07-05] PASS.

---

## Risks and mitigations

| Risk | Impact | Mitigation |
| ---- | ------ | ---------- |
| Gameplay regressions after OOP refactor | High | Review discipline (analyse → fix) + Witchcraft recette |
| Legacy API coverage incomplete | Low | 22 wrappers done — all documented public functions covered |
| Scene positions incorrect | Low | Validated via F-90/F-91 visual recette in DCS |
