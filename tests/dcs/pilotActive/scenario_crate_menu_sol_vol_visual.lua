---@diagnostic disable
-- =============================================================================
-- live_tests/scenarios/interactive/scenario_crate_menu_sol_vol_visual.lua
-- CTLD — Crate Commands menu : vérification sol / vol / sol (visual)
--
-- Mini-application de recette interactive : injection unique, avance
-- automatiquement (waitFor décollage/atterrissage) ou via menu F10
-- "Recette CTLD" (vérifications visuelles).
--
-- Prérequis :
--   - Slot UH-1H BLUE occupé, hélico au sol près d'une zone logistique
--   - enableCrates=true, enablePackingVehicles=true dans la config
--   - canParachuteDrop=true, canSlingload=true pour le type UH-1H
--
-- Cinématique (5 steps, injection unique) :
--   S1 [F10]  Vérifier menu sol          → OUI / NON / SKIP
--   S2 [auto] Charger crate + décoller   → détecté via inAir()
--   S3 [auto] Vérifier menu vol          → auto-vérifié
--   S4 [auto] Atterrir                   → détecté via not inAir()
--   S5 [auto] Vérifier menu sol restauré → auto-vérifié
--
-- @scenario  CMFV
-- @version   2.1 — 2026-06-30
-- @coverage  F-168 (sol), F-169 (vol), F-170 (restauration sol)
-- =============================================================================

-- ── 1. Witchcraft guard ──────────────────────────────────────────────────────
if not ctld or not ctld.utils then
    trigger.action.outText("[CMFV-VIS] ABORT: CTLD not initialized. Inject CTLD_Next.lua first.", 15)
    return Witchcraft
end

-- ── 2. Double-injection guard ────────────────────────────────────────────────
if _SCN_CMFV_RUNNING then
    trigger.action.outText("[CMFV-VIS] déjà actif — attendre la fin ou redémarrer DCS.", 10)
    return Witchcraft
end
_SCN_CMFV_RUNNING = true
_SCN_CMFV_CLEANUP = nil   -- exposé pour reset externe (reset script)

-- ── 3. Global show callback (closure Lua compatible MenuManager) ─────────────
_SCN_CMFV_INSTR = ""
_SCN_CMFV_SHOW  = function()
    trigger.action.outText(_SCN_CMFV_INSTR, 30)
end

do  -- isolation scope
-- ── 4. Debug ON ──────────────────────────────────────────────────────────────
local cfg                  = CTLDConfig.get()
local _savedDebug          = cfg.settings["debug"]
local _savedDebugScreenLog = cfg.settings["debugScreenLog"]
cfg.settings["debug"]          = true
cfg.settings["debugScreenLog"] = false   -- traces internes via log() uniquement, pas écran

-- ── 5. Constants ─────────────────────────────────────────────────────────────
local TAG             = "[CMFV-VIS]"
local NAME            = "Crate Commands menu — sol/vol/sol"
local HUMAN_TIMEOUT_S = 300
local MENU_NAME       = "Recette CTLD"
local MENU_PATH       = { ctld.tr("CTLD"), MENU_NAME }   -- inside CTLD (order=999 → last)
local RESP_FLAG       = "CMFV_RESP"

-- ── 6. State ─────────────────────────────────────────────────────────────────
local S = {
    step        = 0,
    passed      = 0,
    failed      = 0,
    failReasons = {},
    groupId     = nil,   -- player groupId for MenuManager lookups
    timerHandle = nil,
    timerGen    = 0,     -- generation counter : invalide les timers d'une précédente waitFor
    transport   = nil,
}

-- ── 7. Helpers ───────────────────────────────────────────────────────────────
local function log(msg) ctld.utils.log("INFO", "%s %s", TAG, msg) end

local function instruct(msg)
    _SCN_CMFV_INSTR = TAG .. "\n" .. msg
    log("[INSTR] " .. msg)
    trigger.action.outText(_SCN_CMFV_INSTR, 360, true)
end

local function pass(id, msg) S.passed = S.passed + 1 ; log("[PASS] "..id..": "..(msg or "")) end
local function fail(id, msg) S.failed = S.failed + 1 ; table.insert(S.failReasons, id..": "..(msg or "")) ; log("[FAIL] "..id..": "..(msg or "")) end

-- Capture l'état réel du menu Crate Commands dans CTLD.log.
local function logMenuSnapshot()
    local ok, err = pcall(function()
        local pm = CTLDPlayerManager.getInstance()
        local playerObj
        if pm and pm._players then
            for _, p in pairs(pm._players) do playerObj = p ; break end
        end
        if not playerObj then log("[SNAPSHOT] no playerObj") ; return end

        local mm   = ctld.MenuManager:getInstance()
        local menu = mm:getMenuByGroupId(playerObj.groupId)
        if not menu or not menu._lookup then log("[SNAPSHOT] no menu._lookup") ; return end

        local root      = ctld.tr("CTLD")
        local cratesSub = ctld.tr("Crate Commands")
        local prefix    = root .. "." .. cratesSub .. "."

        local seen = {}
        local items = {}
        for path, node in pairs(menu._lookup) do
            if path:find(prefix, 1, true) == 1 then
                local name = path:sub(#prefix + 1)
                if name ~= "" and not name:find(".", 1, true) then
                    if not seen[name] then
                        seen[name] = true
                        local enabled = node.enabled ~= false and "VISIBLE" or "MASQUE "
                        table.insert(items, "  "..enabled.." : "..name)
                    end
                else
                    local parent = name:match("^([^%.]+)")
                    if parent and not seen[parent] then
                        seen[parent] = true
                        local parentNode = menu._lookup[prefix .. parent]
                        local enabled = (parentNode and parentNode.enabled ~= false) and "VISIBLE" or "MASQUE "
                        table.insert(items, "  "..enabled.." : "..parent)
                    end
                end
            end
        end
        table.sort(items)
        if #items == 0 then
            log("[SNAPSHOT] Crate Commands : aucun item trouvé dans _lookup (prefix="..prefix..")")
        else
            log("[SNAPSHOT] Crate Commands au moment de la réponse :\n"..table.concat(items, "\n"))
        end
    end)
    if not ok then log("[SNAPSHOT] ERREUR: "..tostring(err)) end
end

-- ── 8. Cleanup ───────────────────────────────────────────────────────────────
local function cleanup()
    if S.timerHandle then timer.removeFunction(S.timerHandle) ; S.timerHandle = nil end
    -- Masquer le menu scénario via MenuManager (clearBranch + setBranchEnabled + refresh)
    if S.groupId then
        local mm = ctld.MenuManager:getInstance()
        local menu = mm and mm:getMenuByGroupId(S.groupId)
        if menu then
            pcall(function()
                menu:clearBranch(MENU_PATH)
                menu:setBranchEnabled(MENU_PATH, false)
                menu:refresh()
            end)
        end
    end
    trigger.action.setUserFlag(RESP_FLAG, 0)
    _SCN_CMFV_INSTR = nil ; _SCN_CMFV_SHOW = nil
    cfg.settings["debug"]          = _savedDebug
    cfg.settings["debugScreenLog"] = _savedDebugScreenLog
    _SCN_CMFV_RUNNING = false
    _SCN_CMFV_CLEANUP = nil
    log("cleanup done")
end

-- ── 9. Timer helpers ─────────────────────────────────────────────────────────
local function cancelTimer()
    S.timerGen = S.timerGen + 1   -- invalide tout poll existant même si removeFunction échoue
    if S.timerHandle then
        pcall(timer.removeFunction, S.timerHandle)
        S.timerHandle = nil
    end
end

local function waitFor(checkFn, intervalS, timeoutS, onSuccess, onFail)
    cancelTimer()
    local myGen = S.timerGen
    local elapsed = 0
    local function poll()
        if S.timerGen ~= myGen then return nil end  -- invalidé : arrêt silencieux
        elapsed = elapsed + intervalS
        if checkFn() then
            S.timerHandle = nil ; onSuccess()
        elseif elapsed >= timeoutS then
            S.timerHandle = nil ; log("[TIMEOUT] "..timeoutS.."s") ; onFail()
        else
            return timer.getTime() + intervalS
        end
    end
    S.timerHandle = timer.scheduleFunction(poll, nil, timer.getTime() + intervalS)
end

-- Execute callback once after delayS seconds (one-shot timer, honours timerGen).
local function waitThen(delayS, callback)
    cancelTimer()
    local myGen = S.timerGen
    S.timerHandle = timer.scheduleFunction(function()
        if S.timerGen ~= myGen then return nil end
        S.timerHandle = nil
        callback()
    end, nil, timer.getTime() + delayS)
end

-- Auto-verify Crate Commands menu state.
-- expected = list of {name=string, state="VISIBLE"|"MASQUE"|"ABSENT"}
-- Returns: ok (bool), issues (list of strings)
local function checkMenuExpected(expected)
    local pm = CTLDPlayerManager.getInstance()
    local playerObj
    if pm and pm._players then
        for _, p in pairs(pm._players) do playerObj = p ; break end
    end
    if not playerObj then return false, {"no playerObj"} end

    local mm   = ctld.MenuManager:getInstance()
    local menu = mm:getMenuByGroupId(playerObj.groupId)
    if not menu or not menu._lookup then return false, {"no menu._lookup"} end

    local root      = ctld.tr("CTLD")
    local cratesSub = ctld.tr("Crate Commands")
    local prefix    = root .. "." .. cratesSub .. "."

    -- Build actual state map: itemName → "VISIBLE" | "MASQUE"
    local actual = {}
    local seen   = {}
    for path, node in pairs(menu._lookup) do
        if path:find(prefix, 1, true) == 1 then
            local rel  = path:sub(#prefix + 1)
            local name = rel:find(".", 1, true) and rel:match("^([^%.]+)") or rel
            if name and name ~= "" and not seen[name] then
                seen[name] = true
                local parentNode = menu._lookup[prefix .. name]
                actual[name] = (parentNode and parentNode.enabled ~= false) and "VISIBLE" or "MASQUE"
            end
        end
    end
    -- anything not in actual → "ABSENT"

    local issues = {}
    for _, exp in ipairs(expected) do
        local got = actual[exp.name] or "ABSENT"
        if got ~= exp.state then
            table.insert(issues, string.format("  %-22s : got %-7s expected %s", exp.name, got, exp.state))
        end
    end
    return #issues == 0, issues
end

-- ── 10. Finalization ─────────────────────────────────────────────────────────
local function finalizeScenario()
    cancelTimer()
    -- Masquer le menu scénario via MenuManager
    if S.groupId then
        local mm = ctld.MenuManager:getInstance()
        local menu = mm and mm:getMenuByGroupId(S.groupId)
        if menu then
            pcall(function()
                menu:clearBranch(MENU_PATH)
                menu:setBranchEnabled(MENU_PATH, false)
                menu:refresh()
            end)
        end
    end
    local total = S.passed + S.failed
    local summary
    if S.failed == 0 then
        summary = TAG.." ✅ [OK] "..NAME.." — "..S.passed.."/"..total.." PASS"
    else
        summary = TAG.." ❌ [KO] "..NAME.." — "..S.failed.." FAIL: "..
            table.concat(S.failReasons, " | ")
    end
    log(summary)
    trigger.action.outText(summary, 360, true)
    local ok, err = pcall(cleanup)
    if not ok then log("WARN cleanup: "..tostring(err)) ; _SCN_CMFV_RUNNING = false end
end

-- ── 11. Step humain (MenuManager) ────────────────────────────────────────────
-- Le sous-menu "Recette CTLD" est créé UNE SEULE FOIS dans Start (order=999).
-- Seules les commandes enfants sont effacées/recréées entre les steps (clearBranch).
local advanceStep

local function setHumanStep(stepId, title, options)
    cancelTimer()
    local myGen = S.timerGen  -- capture après cancelTimer (gen actuel)

    local mm   = ctld.MenuManager:getInstance()
    local menu = mm and mm:getMenuByGroupId(S.groupId)
    if not menu then
        log("[ERR] setHumanStep: no CTLD menu for groupId="..tostring(S.groupId))
        fail(stepId, "no CTLD menu")
        finalizeScenario()
        return
    end

    -- Effacer les commandes du step précédent et reconstruire (assurer visibilité du nœud)
    pcall(function() menu:clearBranch(MENU_PATH) end)
    pcall(function() menu:setBranchEnabled(MENU_PATH, true) end)
    menu:addCommand(MENU_PATH, "↩ Step "..S.step..": "..title, _SCN_CMFV_SHOW)

    local function onResponse(opt_fn)
        if S.timerGen ~= myGen then return end  -- doublon ou post-timeout : ignorer
        cancelTimer()
        pcall(function() menu:clearBranch(MENU_PATH) ; menu:refresh() end)
        logMenuSnapshot()
        opt_fn()
    end

    for _, opt in ipairs(options) do
        local fn = opt.fn
        menu:addCommand(MENU_PATH, opt.label, function() onResponse(fn) end)
    end
    menu:refresh()

    -- Timer de timeout (géré manuellement pour contrôler timerGen précisément)
    S.timerHandle = timer.scheduleFunction(function()
        if S.timerGen ~= myGen then return nil end
        S.timerHandle = nil
        log("[TIMEOUT] step "..S.step.." ("..stepId..") — ABORT")
        pcall(function() menu:clearBranch(MENU_PATH) ; menu:refresh() end)
        fail(stepId, "timeout "..HUMAN_TIMEOUT_S.."s sans réponse")
        finalizeScenario()
    end, nil, timer.getTime() + HUMAN_TIMEOUT_S)
end

-- ── 12. Step runner ──────────────────────────────────────────────────────────
local steps = {}

advanceStep = function()
    S.step = S.step + 1
    if not steps[S.step] then
        finalizeScenario()
        return
    end
    local ok, err = pcall(steps[S.step])
    if not ok then
        local msg = "S"..S.step.." ERREUR: "..tostring(err)
        fail("S"..S.step, "pcall: "..tostring(err))
        trigger.action.outText(TAG.." ⚠️ "..msg, 15, false)
        advanceStep()
    end
end

-- ── 13. Steps ────────────────────────────────────────────────────────────────

-- S1 — Vérification menu sol + chargement crate [F10]
steps[1] = function()
    if cfg.settings["enablePackingVehicles"] ~= true then
        instruct(
            "Step 1/5 — ABORT PRÉREQUIS\n"..
            "enablePackingVehicles=false dans la config.\n"..
            "Ce test requiert enablePackingVehicles=true.\n"..
            "Modifier la config et redémarrer."
        )
        fail("F-168", "enablePackingVehicles=false — test impossible")
        finalizeScenario()
        return
    end
    instruct(
        "Step 1/5 — MENU SOL + CHARGER UNE CRATE (F-168)\n"..
        "Prérequis : hélico au sol à portée d'une zone logistique\n"..
        "\nA) Demander un équipement :\n"..
        "  F10 → CTLD → Request Equipment → [zone] → [catégorie] → [item]\n"..
        "  → un véhicule/équipement apparaît au sol\n"..
        "\nB) Packer le véhicule en crate :\n"..
        "  F10 → CTLD → Crate Commands → Pack Equipt → [nom du véhicule]\n"..
        "  → le véhicule est remplacé par une crate au sol\n"..
        "\nC) Vérifier F10 → CTLD → Crate Commands :\n"..
        "  ✅ VISIBLE  : Load Crate\n"..
        "  ✅ VISIBLE  : Drop Crate(s)\n"..
        "  ✅ VISIBLE  : Unpack Crate\n"..
        "  ✅ VISIBLE  : List Nearby Crates\n"..
        "  ✅ VISIBLE  : Pack Equipt\n"..
        "  ❌ MASQUÉ   : Parachute Crates\n"..
        "  ❌ MASQUÉ   : Release Slingload\n"..
        "  ❌ MASQUÉ   : Cut Slingload\n"..
        "\nD) Charger la crate : F10 → CTLD → Crate Commands → Load Crate\n"..
        "\nRépondre OUI/NON après A+B+C+D."
    )
    setHumanStep("F-168", "Menu sol correct + crate chargée ?", {
        { label = "OUI — menu OK et crate chargée",  fn = function() pass("F-168", "menu sol OK") ; advanceStep() end },
        { label = "NON — menu incorrect",            fn = function() fail("F-168", "menu sol KO") ; advanceStep() end },
        { label = "SKIP — ne peut vérifier",         fn = function() log("[SKIP] S1")             ; advanceStep() end },
    })
end

-- S2 — Décoller [auto]
steps[2] = function()
    instruct(
        "Step 2/5 — DÉCOLLER (auto)\n"..
        "Décoller — le scénario avancera automatiquement\n"..
        "dès la détection du décollage."
    )
    waitFor(
        function() return S.transport:isExist() and S.transport:inAir() end,
        3, 300,
        function() pass("S2", "décollage détecté") ; advanceStep() end,
        function() fail("S2", "timeout décollage") ; advanceStep() end
    )
end

-- S3 — Vérification menu vol [AUTO]
-- F-169: onTakeoff already calls refreshCrateFlightSection(playerObj, true) via _isFlying flag.
-- waitThen(2) ensures DCS event processing is complete before the check.
steps[3] = function()
    instruct(
        "Step 3/5 — VÉRIFICATION AUTO MENU VOL (F-169)\n"..
        "Vérification automatique du menu en cours (2s)…"
    )
    local EXPECTED_VOL = {
        { name = "Parachute Crates",  state = "VISIBLE" },
        { name = "Load Crate",        state = "MASQUE"  },
        { name = "Drop Crate(s)",     state = "MASQUE"  },
        { name = "Unpack Crate",      state = "MASQUE"  },
        { name = "List Nearby Crates",state = "MASQUE"  },
        { name = "Pack Equipt",       state = "ABSENT"  },
        { name = "Release Slingload", state = "MASQUE"  },
        { name = "Cut Slingload",     state = "MASQUE"  },
    }
    waitThen(2, function()
        local cm = CTLDCrateManager.getInstance()
        local pm = CTLDPlayerManager.getInstance()
        local playerObj
        if pm and pm._players then for _, p in pairs(pm._players) do playerObj = p ; break end end
        local inAirNow = S.transport and S.transport:isExist() and S.transport:inAir() or false
        log("[AUTO-CHECK] S3 inAir="..tostring(inAirNow))
        if playerObj then cm:refreshCrateFlightSection(playerObj, inAirNow) end

        local ok, issues = checkMenuExpected(EXPECTED_VOL)
        logMenuSnapshot()
        if ok then
            pass("F-169", "menu vol auto-vérifié OK")
            local msg = TAG.." ✅ F-169 menu vol OK (auto-vérifié)\nParachute Crates VISIBLE, Pack Equipt ABSENT."
            log("[AUTO-CHECK] F-169 PASS")
            trigger.action.outText(msg, 15, true)
        else
            fail("F-169", "menu vol KO: "..table.concat(issues, " | "))
            local msg = TAG.." ❌ F-169 menu vol KO (auto-vérifié)\n"..table.concat(issues, "\n")
            log("[AUTO-CHECK] F-169 FAIL: "..table.concat(issues, " | "))
            trigger.action.outText(msg, 20, true)
        end
        advanceStep()
    end)
end

-- S4 — Atterrir sans parachuter [auto]
steps[4] = function()
    instruct(
        "Step 4/5 — ATTERRIR (auto)\n"..
        "Atterrir SANS utiliser Parachute Crates.\n"..
        "Le scénario avancera automatiquement à la détection de l'atterrissage."
    )
    waitFor(
        function() return S.transport:isExist() and not S.transport:inAir() end,
        3, 300,
        function() pass("S4", "atterrissage détecté") ; advanceStep() end,
        function() fail("S4", "timeout atterrissage") ; advanceStep() end
    )
end

-- S5 — Vérification menu sol restauré [AUTO]
-- Key checks: Parachute Crates → MASQUE (was VISIBLE in flight).
--             Drop Crate(s)    → VISIBLE (crate still aboard).
steps[5] = function()
    instruct(
        "Step 5/5 — VÉRIFICATION AUTO SOL RESTAURÉ (F-170)\n"..
        "Vérification automatique du menu en cours (2s)…"
    )
    local EXPECTED_SOL_KEY = {
        { name = "Parachute Crates", state = "MASQUE"  },
        { name = "Drop Crate(s)",    state = "VISIBLE" },
    }
    waitThen(2, function()
        local cm = CTLDCrateManager.getInstance()
        local pm = CTLDPlayerManager.getInstance()
        local playerObj
        if pm and pm._players then for _, p in pairs(pm._players) do playerObj = p ; break end end
        local inAirNow = S.transport and S.transport:isExist() and S.transport:inAir() or false
        log("[AUTO-CHECK] S5 inAir="..tostring(inAirNow))
        if playerObj then cm:refreshCrateFlightSection(playerObj, inAirNow) end

        local ok, issues = checkMenuExpected(EXPECTED_SOL_KEY)
        logMenuSnapshot()
        if ok then
            pass("F-170", "sol restauré auto-vérifié OK")
            local msg = TAG.." ✅ F-170 sol restauré OK (auto-vérifié)\nParachute Crates MASQUÉ, Drop Crate(s) VISIBLE."
            log("[AUTO-CHECK] F-170 PASS")
            trigger.action.outText(msg, 15, true)
        else
            fail("F-170", "sol restauré KO: "..table.concat(issues, " | "))
            local msg = TAG.." ❌ F-170 sol restauré KO (auto-vérifié)\n"..table.concat(issues, "\n")
            log("[AUTO-CHECK] F-170 FAIL: "..table.concat(issues, " | "))
            trigger.action.outText(msg, 20, true)
        end
        advanceStep()
    end)
end

-- ── 14. Start ────────────────────────────────────────────────────────────────
S.transport = (function()
    local ok, pm = pcall(CTLDPlayerManager.getInstance)
    if ok and pm and pm._players then
        for unitName in pairs(pm._players) do
            local u = Unit.getByName(unitName)
            if u and u:isExist() then return u end
        end
    end
    for _, grp in ipairs(coalition.getGroups(coalition.side.BLUE) or {}) do
        for _, unit in ipairs(grp:getUnits() or {}) do
            if unit and unit:isExist() and unit:getPlayerName() then return unit end
        end
    end
    return nil
end)()

if not S.transport then
    trigger.action.outText(TAG.." ABORT : aucun joueur BLUE. Occuper un slot avant injection.", 20)
    cleanup()
    return Witchcraft
end

-- Récupérer le groupId du joueur via CTLDPlayerManager
local pm_start = CTLDPlayerManager.getInstance()
local playerObjStart
if pm_start and pm_start._players then
    for _, p in pairs(pm_start._players) do
        if p.unitName == S.transport:getName() then
            playerObjStart = p ; break
        end
    end
    if not playerObjStart then
        -- Fallback: premier joueur disponible
        for _, p in pairs(pm_start._players) do playerObjStart = p ; break end
    end
end
if not playerObjStart then
    trigger.action.outText(TAG.." ABORT : no CTLD playerObj for transport.", 20)
    cleanup() ; return Witchcraft
end

S.groupId = playerObjStart.groupId

-- Créer le sous-menu "Recette CTLD" sous "CTLD" via MenuManager (order=999 → dernier)
-- Le nesting garantit que "Recette CTLD" est reconstruit avec l'arbre CTLD à chaque
-- refresh → reste après "CTLD" dans la liste F10, jamais devant.
local mm_init   = ctld.MenuManager:getInstance()
local menu_init = mm_init and mm_init:getMenuByGroupId(S.groupId)
if not menu_init then
    trigger.action.outText(TAG.." ABORT : no CTLD MenuManager menu for player group.", 20)
    cleanup() ; return Witchcraft
end
menu_init:addSubMenu({ ctld.tr("CTLD") }, MENU_NAME, { order = 0 })
-- addSubMenu est idempotent : si le nœud existait déjà (cleanup précédent), il ne met pas à jour
-- order ni enabled. Forcer les deux via _getNode.
local _rNode = menu_init:_getNode(MENU_PATH)
if _rNode then _rNode.order = 0 ; _rNode.enabled = true end
menu_init:refresh()

_SCN_CMFV_CLEANUP = cleanup   -- exposé pour reset externe

log("=== START: "..NAME.." | transport="..S.transport:getName().." | groupId="..tostring(S.groupId).." | 5 steps ===")
trigger.action.outText(TAG.." démarrage — 5 steps | "..S.transport:getName(), 8)
advanceStep()

end  -- do isolation scope
return Witchcraft
