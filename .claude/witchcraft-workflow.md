# Witchcraft — Workflow de recette et debug

> Référence complète pour l'injection de scripts Lua dans une mission DCS active via le bridge Witchcraft.
> Pour les règles de comportement essentielles, voir `CLAUDE.md` §Exécution Lua en temps réel via Witchcraft.

---

## Infrastructure

| Élément | Valeur |
|---------|--------|
| Bridge Node.js | `${userHome}/.vscode-dcs-tools/bridge.js` (variable VS Code — définie dans `.vscode/tasks.json`) |
| Commande | `node "${userHome}/.vscode-dcs-tools/bridge.js" "<chemin_absolu_script.lua>"` |
| VS Code task | `DCS-Witchcraft: Execute Global` (Shift+Ctrl+B, utilise `${file}`) |
| Condition | Mission DCS avec Witchcraft activé en cours |
| Retour succès | `[SUCCESS] nil` (injection OK, script sans return) |
| Retour avec valeur | `[SUCCESS] "..."` (script retourne une string) |
| Retour erreur | `[ERR] ...` (erreur Node.js ou Lua non capturée) |

---

## Config debug — 3 modes

Deux clés de config contrôlent les sorties de `ctld.utils.log()` :

| `debug` | `debugScreenLog` | env.info | CTLD.log | Écran DCS |
|---------|-----------------|----------|----------|-----------|
| false | false | ✅ | — | — |
| true | false | ✅ | ✅ | — |
| false | true | ✅ | — | ✅ |
| true | true | ✅ | ✅ | ✅ |

- `debugScreenLogDuration` (défaut `10`) : durée d'affichage en secondes quand `debugScreenLog=true`

**Activation dans un script :**
```lua
local cfg = CTLDConfig.get()
local _saved_debug = cfg.settings["debug"]
cfg.settings["debug"] = true
-- cfg.settings["debugScreenLog"] = true  -- optionnel : active aussi l'écran
```

> ⚠️ **Ne jamais utiliser `ctld.debug = true`** — insuffisant, n'active pas l'écriture CTLD.log.

**Restauration obligatoire en fin de script (même sur erreur) :**
```lua
cfg.settings["debug"] = _saved_debug
```

---

## Prérequis — `ctldLogPath`

Pour que `ctld.utils.log` écrive dans `CTLD.log`, le chemin doit être défini **avant le démarrage de CTLD** :

```lua
cfg.settings["ctldLogPath"] = ctld.path .. "live_tests\\"  -- ctld.path défini dans le trigger MISSION START du .miz
```

> Ce chemin est **local à la machine**. Le définir via un trigger **MISSION START → DO SCRIPT FILE** dans le `.miz` de test. Ne jamais commiter ce chemin dans le repo.

---

## Traces disponibles

### 1. `ctld.utils.log("INFO", "[tag] message")` — recommandé

- Écrit dans `env.info()` (DCS.log) ET dans `CTLD.log` (si `debug=true`)
- Ajoute l'echo écran si `debugScreenLog=true`
- Tag obligatoire entre crochets pour filtrage

### 2. `trigger.action.outText(msg, duration)` — feedback immédiat

- Affiche à l'écran du joueur dans DCS
- Utiliser pour les banners de début/fin de scenario

### 3. `env.info(msg)` — fallback toujours disponible

- Écrit dans DCS.log (`%USERPROFILE%\Saved Games\DCS\Logs\DCS.log`)
- Fonctionne sans aucune config CTLD
- Accès restreint (lecture seule depuis PowerShell)

### 4. `io.open` — disponible uniquement serveur désanitisé

```lua
local f = io.open("c:/temp/diag.txt", "a")
if f then f:write(os.date() .. " " .. msg .. "\n"); f:close() end
```

> `io.open` fonctionne uniquement si le serveur DCS est désanitisé (`io` débloqué). Ne pas utiliser comme méthode principale.

---

## Lecture des logs

```powershell
# CTLD.log — filtré par tag  ($ctldLogPath = valeur de cfg.settings["ctldLogPath"])
Get-Content "$ctldLogPath\CTLD.log" | Select-String "[mon_tag]"

# Lecture complète
Get-Content "$ctldLogPath\CTLD.log"
```

Chemins :
```
CTLD.log  →  {ctldLogPath}CTLD.log       (ex: live_tests/CTLD.log)
diag.log  →  live_tests/diag.log
DCS.log   →  %USERPROFILE%\Saved Games\DCS\Logs\DCS.log
```

---

## Workflow recette complet — 7 étapes

```
1. CRÉER     copier _template_scenario.lua → live_tests/scenarios/scenario_<nom>.lua
             remplacer SCENARIO_TAG partout

2. CONFIG    ctldLogPath défini dans le .miz (trigger MISSION START → DO SCRIPT FILE)
             fichier hors repo, chemin local uniquement

3. MODIFIER  modifier src/ si besoin

4. REBUILD   si src/ modifié :
             powershell -ExecutionPolicy Bypass -File "tools\build\merge_CTLD.ps1"

5. INJECTER  CTLD_Next.lua :
             node bridge.js "C:\...\CTLD_Next.lua"
             puis ATTENDRE 3-5 secondes (initialisation CTLD)

6. INJECTER  le scenario :
             node bridge.js "C:\...\recette\scenarios\scenario_<nom>.lua"
             → Witchcraft retourne "[SCENARIO_TAG] step=N SUCCESS" ou "FAIL: ..."

7. LIRE      CTLD.log + écran DCS
             Get-Content "recette\CTLD.log" | Select-String "[mon_tag]"
```

**Script d'attente** : `live_tests/wait_ctld_ready.lua` — injecter si CTLDTroopManager n'est pas encore disponible.

---

## Cycle de debug autonome (règle permanente)

**C'est l'IA qui pilote entièrement le cycle.** L'utilisateur n'intervient pas entre les injections.

```
Modif  →  Rebuild (si src/)  →  Injection  →  Lecture CTLD.log  →  Itération si FAIL
```

- Si `[PASS]` sur tous les steps → fin du cycle, mise à jour MP + recette.md
- Si `[FAIL]` → diagnostic, correction, réinjection sans attendre l'utilisateur
- Jamais attendre l'utilisateur pour réinjecter entre deux steps

---

## Template scenario — structure obligatoire

Tout nouveau scenario est créé depuis `live_tests/scenarios/_template_scenario.lua`.

**Points clés du template :**

| Point | Règle |
|-------|-------|
| Tag unique | `TAG = "[MON_TAG]"` — entre crochets, court |
| Banner début | `report("==== START <timestamp> \| step=N ====")` — outText + CTLD.log |
| Reset log | À step=1 : truncate CTLD.log via `closeLog` + `io.open "w"` + `reopenLogAppend` → run propre |
| Debug activation | `cfg.settings["debug"] = true` (jamais `ctld.debug = true`) |
| Cleanup garanti | pcall wrapping → `cfg.settings["debug"] = _saved_debug` toujours exécuté |
| fail() | `debug.traceback(msg, 2)` → log → `error(msg)` → capturé par pcall → cleanup → return FAIL |
| check() | `check("F-xx.1", "desc", condition, details)` — mappage direct sur cas F-xx |
| assert_eq() | `assert_eq("F-xx.2", actual, expected)` — formate expected/actual automatiquement |
| Guard INCOMPLETE | `else fail("step=N has no branch")` — détecte dérive du compteur |
| Return Witchcraft | `"[TAG] step=N SUCCESS (Xms)"` / `"FAIL: msg"` / `"ALL SUCCESS"` |
| Timer step | `os.clock()` avant pcall → elapsed en ms dans le return |
| Persistance steps | `_G["_MON_TAG_STEP"]` — persiste entre injections successives |

---

## Helpers disponibles dans le template

```lua
-- Check structuré — id mappe sur F-xx/U-xx
check("F-33.1", "group spawned", group ~= nil, tostring(group))

-- Assertions formatées automatiquement
assert_eq("F-33.2", group:getName(), "JTAC Group 2")
assert_not_nil("F-33.3", manager, "manager exists")

-- Failure avec stack trace Lua
fail("message explicite")  -- log trace + outText 60s + error() → pcall

-- Report dual (outText 30s + CTLD.log)
report("message")
pass("message")  -- préfixe [PASS] automatique
```

---

## Persistance entre injections

```lua
_G["_MON_TAG_STEP"] = value  -- écriture
local v = _G["_MON_TAG_STEP"]  -- lecture
_G["_MON_TAG_STEP"] = nil  -- reset
```

**Reset de tous les compteurs** (scenario planté) :
```bash
node bridge.js "live_tests/_reset_steps.lua"
# → "[RESET_STEPS] Cleared N step counter(s): _MON_TAG_STEP, ..."
```

---

## Troubleshooting

| Symptôme | Cause probable | Solution |
|----------|---------------|----------|
| `[SUCCESS] nil` mais rien dans CTLD.log | `debug=false` ou `ctldLogPath` absent | Vérifier les deux en tête de script |
| `[SUCCESS] nil` mais rien à l'écran | `debugScreenLog=false` | Activer `cfg.settings["debugScreenLog"]=true` ou utiliser `trigger.action.outText` direct |
| `attempt to call field 'getInstance' (a nil value)` | CTLD non encore initialisé | Attendre 3-5s après injection CTLD_Next.lua ; utiliser `wait_ctld_ready.lua` |
| `CTLDJTACManager` introuvable | Ce manager utilise `get()` et non `getInstance()` | Appeler `CTLDJTACManager.get()` |
| CTLD.log non créé | `ctldLogPath` non défini dans le .miz | Vérifier le trigger MISSION START |
| `[ERR]` côté Witchcraft | Erreur Lua non capturée avant pcall | Vérifier la syntaxe + structure pcall |
| Cleanup non exécuté | `error()` hors pcall | Toujours wrapper le step machine dans pcall |
| `step=N INCOMPLETE` | Compteur _G dérivé ou elseif manquant | Injecter `_reset_steps.lua` puis réinjecter step 1 |
| FAIL sans contexte | fail() sans détail | Lire la stack trace dans CTLD.log (debug.traceback inclus) |
