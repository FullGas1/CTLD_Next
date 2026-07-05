# CTLD_FG — Instructions permanentes pour Claude Code

## Règles d'échange

- Les échanges se font en **français**.
- **Tous les livrables** (code, commentaires, specs, documentation technique) sont en **anglais**.
- **Mélange FR/EN interdit** dans les messages et le reasoning : ne jamais alterner les langues au sein d'une même phrase, paragraphe ou bloc de pensée. Si un terme technique anglais est nécessaire, le garder tel quel dans une phrase entièrement française.
- Style direct et technique, sans assertions ni formules de politesse.
- Mes **raisonnements** (reasoning) sont également en français, intégralement.

## Suivi d'avancement du projet

- **`.github/MODERNIZATION-PLAN.md` (MP) est la seule source de vérité** pour tout suivi d'avancement : tâches, features, statuts, backlog.
- Ne jamais créer de fichier todolist séparé (ni en mémoire, ni dans le repo).
- "Ajoute à la todolist" = ajouter dans la section appropriée de MP.
- La TodoWrite tool reste pour le tracking de tâches intra-session uniquement.

## Gestion de session

- **Début de session** : toujours récupérer et afficher le contexte mémorisé (mémoire projet, état des tâches, prochaine étape) avant toute autre action. Si la session implique de la recette Witchcraft, lire `.claude/witchcraft-workflow.md` pour avoir le protocole complet en contexte.
- **Fin de session** : lorsque l'utilisateur annonce l'arrêt des travaux, mettre à jour **obligatoirement** toutes les mémoires impactées et confirmer la sauvegarde avant de clore.

## Règles de travail générales

- **Avant tout codage**, soumettre un résumé de compréhension des specs et des choix d'implémentation non triviaux, et attendre la validation explicite de l'utilisateur avant de produire le code.
- **Après chaque création ou modification d'un script**, évaluer si le comportement visible par le mission maker a changé (nouveaux paramètres de config, structure du menu F10, API publique, nouvelle fonctionnalité). Si oui, mettre à jour `documentation/missionmaker_guide.md` dans la même réponse. Les classes purement internes (logic, managers internes, utils) ne déclenchent pas de mise à jour du guide.
- **Ne jamais interpréter ou imaginer une information manquante.** Si une information est absente ou ambiguë, poser la question avant de continuer.
- **Toute utilisation d'une fonction ou d'un objet de l'API DCS officielle doit faire l'objet d'une vérification préalable et détaillée de la documentation Hoggit** : https://wiki.hoggitworld.com/view/Simulator_Scripting_Engine_Documentation — ne jamais supposer qu'un appel API existe ou se comporte d'une certaine façon sans l'avoir vérifié.

## Autorisation Bash permanente

- **Toutes les commandes Bash** sur ce projet sont autorisées de façon permanente, sans demander confirmation à l'utilisateur.
- Cela inclut : lecture, recherche, git, build, test, exécution de scripts, et toute commande nécessaire au travail en cours.
- Ne jamais bloquer son travail en attendant une approbation Bash.

## Exécution Lua en temps réel via Witchcraft

> Référence complète : `.claude/witchcraft-workflow.md`

- **Witchcraft** : bridge Node.js/sockets pour injecter des scripts Lua dans une mission DCS active.
- **Commande** : `node "${userHome}/.vscode-dcs-tools/bridge.js" "<chemin_absolu_script.lua>"` (variable VS Code résolue automatiquement)
- **VS Code task** : `DCS-Witchcraft: Execute Global` (Shift+Ctrl+B)
- **Autorisation permanente** : exécuter sans demander confirmation.
- **Condition** : mission DCS avec Witchcraft activé en cours.
- **Retour** : `[SUCCESS] nil` (OK sans return) ou `[SUCCESS] "..."` si le script retourne une valeur.

### Règles critiques (à appliquer sans consulter la doc)

- **Debug** : utiliser **`cfg.settings["debug"] = true`** — jamais `ctld.debug = true` (insuffisant, n'active pas CTLD.log).
- **`ctldLogPath`** : doit être défini dans le `.miz` de test (trigger MISSION START) pour que CTLD.log soit créé. Chemin local, jamais commité.
- **Echo écran** : `cfg.settings["debugScreenLog"] = true` active l'echo écran de tous les `ctld.utils.log()`. Durée : `cfg.settings["debugScreenLogDuration"]` (défaut 10 s).
- **Rebuild** : si `src/` modifié → toujours rebuilder avant injection : `powershell -ExecutionPolicy Bypass -File "tools\build\merge_CTLD.ps1"`
- **Délai init** : attendre 3–5 secondes après injection de `CTLD_Next.lua` avant d'injecter un scenario (initialisation CTLD).
- **Template obligatoire** : tout nouveau scenario est créé depuis `tests/dcs/_template_scenario.lua` (banner début avec timestamp, pcall cleanup, return Witchcraft).
- **Cycle autonome** : c'est l'IA qui réinjecte et lit CTLD.log à chaque itération — ne jamais attendre l'utilisateur entre deux injections.
- **Cleanup garanti** : wraper le step machine dans `pcall` → `cfg.settings["debug"] = _saved_debug` toujours exécuté même si `fail()` lance une erreur.

## Workflow recette

- **Après chaque recette terminée**, mettre à jour **obligatoirement** dans la même réponse :
  1. `.github/MODERNIZATION-PLAN.md` — passer le statut (⚪/❓ → ✅) et mettre à jour le tableau Module completion status
  2. `tests/recette.md` — ajouter les lignes U-xx/F-xx dans les tableaux, mettre à jour le Résumé de couverture (Total inclus), rayer l'entrée "Recettes restantes" si couverte

- **Standards obligatoires dans chaque script de recette** :
  - `ctld_test.cleanup()` en tête de chaque test fonctionnel (F-xx)
  - `ctld_test.getTransport()` pour récupérer le joueur BLUE (pas de boilerplate inline)
  - Mocks DCS toujours locaux et restaurés : `local _orig = X; X = mock; ...; X = _orig`
  - Jamais de mock persisté entre deux tests ni dans `src/`

- **`source/`** est la référence de parité fonctionnelle : vérifier systématiquement le comportement legacy avant toute implémentation. Les évolutions par rapport au legacy ne sont introduites que si explicitement demandées.

## Conventions de développement

- Les fichiers source existants dans `source/` ne doivent **jamais** être modifiés.
- Les nouvelles classes OOP vont exclusivement dans `src/`.
- Seul `ctld.gs("param")` est autorisé pour accéder aux paramètres de config (jamais `config:getSetting()`).
- Utiliser uniquement l'API DCS officielle documentée sur https://wiki.hoggitworld.com/view/Simulator_Scripting_Engine_Documentation
- Le terme "repack" (ancienne définition) est banni — utiliser "pack" (nouvelle méthode) partout : méthodes, config, menus.

### ⚠️ Lua 5.1 strict — règle impérative à chaque génération de code

**Tout code produit ou modifié dans `src/` et `tests/` doit être compatible Lua 5.1 strict.** DCS World exécute les scripts de mission en Lua 5.1. Les constructions suivantes sont **interdites** :

| Interdit (Lua 5.2+) | Remplacer par (Lua 5.1) |
| --- | --- |
| `goto label` / `::label::` | `if/then/else` ou restructuration de boucle |
| `<const>` / `<close>` | variables locales normales |
| `table.move` | boucle `for` manuelle |
| `string.gmatch` avec `%g` | pattern alternatif |
| `math.type` | `type(x) == "number"` |
| `utf8.*` | absent en 5.1 |
| `table.pack` / `table.unpack` sans guard | `{...}` / `unpack(...)` (global en 5.1) |

**Vérification obligatoire avant commit** : relire tout nouveau bloc de code et confirmer l'absence de syntaxe 5.2+. En cas de doute, préférer la forme la plus simple et explicite.

## Fin de chaque réponse

Conclure **chaque réponse** par un encadré d'avancement de la consommation de tokens :

```
---
🟢 **Tokens** : ~X k consommés / ~200 k total | ~X% utilisé   (< 80%)
🟠 **Tokens** : ~X k consommés / ~200 k total | ~X% utilisé   (80–90%)
🔴 **Tokens** : ~X k consommés / ~200 k total | ~X% utilisé   (> 90%)
```

Règle de la pastille :
- 🟢 vert  : consommation < 80%
- 🟠 orange : consommation entre 80% et 90%
- 🔴 rouge  : consommation > 90%

> Note : Claude Code n'a pas accès aux compteurs de tokens exacts de l'API.
> La valeur affichée est une estimation basée sur le volume de contexte visible.
> Pour un suivi précis, consulter l'interface de la session Claude.
