---@diagnostic disable
-- =============================================================================
-- live_tests/scenarios/_template_interactive.lua
-- CTLD Interactive Scenario Template
--
-- Mini-application de recette interactive : injection unique, avance
-- automatiquement (waitFor / waitThen) ou via menu F10 "Recette CTLD"
-- (vérifications visuelles humaines).
--
-- Prérequis :
--   - Inject CTLD_Next.lua first, wait 3–5 s for init.
--   - Slot BLUE occupé (hélico ou avion selon le scénario).
--   - Config CTLD appropriée au scénario (activer les features testées).
--
-- Cinématique (3 steps d'exemple) :
--   S1 [F10]   Vérification manuelle initiale  → OUI / NON / SKIP
--   S2 [auto]  Condition DCS détectée (waitFor) → auto
--   S3 [auto]  Vérification différée (waitThen) → auto
--
-- @scenario  SCN-XXX
-- @version   3.0 — 2026-06-30
-- @coverage  F-XXX, F-YYY
-- =============================================================================

-- ── 1. Witchcraft guard ──────────────────────────────────────────────────────
if not ctld or not ctld.utils then
    trigger.action.outText("[SCN-XXX] ABORT: CTLD not initialized. Inject CTLD_Next.lua first.", 15)
    return Witchcraft
end

-- ── 2. Double-injection guard ────────────────────────────────────────────────
if _SCN_XXX_RUNNING then
    trigger.action.outText("[SCN-XXX] déjà actif — attendre la fin ou redémarrer DCS.", 10)
    return Witchcraft
end
_SCN_XXX_RUNNING = true
_SCN_XXX_CLEANUP = nil   -- exposé pour reset externe (reset script)

-- ── 3. Global show callback (closure Lua compatible MenuManager) ─────────────
_SCN_XXX_INSTR = ""
_SCN_XXX_SHOW  = function()
    trigger.action.outText(_SCN_XXX_INSTR, 30)
end

do  -- isolation scope
-- ── 4. Debug ON ──────────────────────────────────────────────────────────────
local cfg                  = CTLDConfig.get()
local _savedDebug          = cfg.settings["debug"]
local _savedDebugScreenLog = cfg.settings["debugScreenLog"]
cfg.settings["debug"]          = true
cfg.settings["debugScreenLog"] = false   -- traces internes via log() uniquement, pas écran

-- ── 5. Constants ─────────────────────────────────────────────────────────────
local TAG             = "[SCN-XXX]"
local NAME            = "Description du scénario"
local HUMAN_TIMEOUT_S = 300
local MENU_NAME       = "Recette CTLD"
local MENU_PATH       = { ctld.tr("CTLD"), MENU_NAME }   -- nested sous CTLD (order=0 → premier)

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
    _SCN_XXX_INSTR = TAG .. "\n" .. msg
    log("[INSTR] " .. msg)
    trigger.action.outText(_SCN_XXX_INSTR, 360, true)
end

local function pass(id, msg) S.passed = S.passed + 1 ; log("[PASS] "..id..": "..(msg or "")) end
local function fail(id, msg) S.failed = S.failed + 1 ; table.insert(S.failReasons, id..": "..(msg or "")) ; log("[FAIL] "..id..": "..(msg or "")) end

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
    _SCN_XXX_INSTR = nil ; _SCN_XXX_SHOW = nil
    cfg.settings["debug"]          = _savedDebug
    cfg.settings["debugScreenLog"] = _savedDebugScreenLog
    _SCN_XXX_RUNNING = false
    _SCN_XXX_CLEANUP = nil
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
    if not ok then log("WARN cleanup: "..tostring(err)) ; _SCN_XXX_RUNNING = false end
end

-- ── 11. Step humain (MenuManager) ────────────────────────────────────────────
-- Le sous-menu "Recette CTLD" est créé UNE SEULE FOIS dans Start (order=0).
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
    menu:addCommand(MENU_PATH, "↩ Step "..S.step..": "..title, _SCN_XXX_SHOW)

    local function onResponse(opt_fn)
        if S.timerGen ~= myGen then return end  -- doublon ou post-timeout : ignorer
        cancelTimer()
        pcall(function() menu:clearBranch(MENU_PATH) ; menu:refresh() end)
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

-- S1 — Vérification manuelle initiale [F10 humain]
steps[1] = function()
    instruct(
        "Step 1/3 — VÉRIFICATION INITIALE (F-XXX)\n"..
        "Décrire ici ce que le testeur doit observer ou faire.\n"..
        "\nExemple :\n"..
        "  F10 → CTLD → [sous-menu] → [action]\n"..
        "  ✅ attendu : [item VISIBLE]\n"..
        "  ❌ attendu : [item MASQUÉ]\n"..
        "\nRépondre OUI/NON/SKIP via F10 → CTLD → Recette CTLD."
    )
    setHumanStep("F-XXX", "Résultat correct ?", {
        { label = "OUI — résultat attendu",    fn = function() pass("F-XXX", "vérif initiale OK") ; advanceStep() end },
        { label = "NON — résultat incorrect",  fn = function() fail("F-XXX", "vérif initiale KO") ; advanceStep() end },
        { label = "SKIP — ne peut vérifier",   fn = function() log("[SKIP] S1")                   ; advanceStep() end },
    })
end

-- S2 — Condition DCS auto-détectée [POLLED via waitFor]
steps[2] = function()
    instruct(
        "Step 2/3 — ACTION AUTO-DÉTECTÉE (S2)\n"..
        "Effectuer l'action DCS (ex : décoller, approcher zone...).\n"..
        "Le scénario avancera automatiquement à la détection."
    )
    waitFor(
        function()
            -- Remplacer par la condition DCS réelle (ex: S.transport:inAir())
            return S.transport and S.transport:isExist() and S.transport:inAir()
        end,
        3, 300,
        function() pass("S2", "condition détectée") ; advanceStep() end,
        function() fail("S2", "timeout condition")  ; advanceStep() end
    )
end

-- S3 — Vérification différée auto [waitThen]
steps[3] = function()
    instruct(
        "Step 3/3 — VÉRIFICATION AUTO DIFFÉRÉE (F-YYY)\n"..
        "Vérification automatique en cours (2s)…"
    )
    waitThen(2, function()
        -- Remplacer par les assertions automatiques réelles.
        local ok = true   -- exemple : résultat du check
        if ok then
            pass("F-YYY", "vérif auto OK")
            log("[AUTO-CHECK] F-YYY PASS")
        else
            fail("F-YYY", "vérif auto KO")
            log("[AUTO-CHECK] F-YYY FAIL")
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

-- Créer le sous-menu "Recette CTLD" sous "CTLD" via MenuManager (order=0)
-- Le nesting garantit que le sous-menu reste dans l'arbre CTLD à chaque refresh.
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

_SCN_XXX_CLEANUP = cleanup   -- exposé pour reset externe

log("=== START: "..NAME.." | transport="..S.transport:getName().." | groupId="..tostring(S.groupId).." | "..#steps.." steps ===")
trigger.action.outText(TAG.." démarrage — "..#steps.." steps | "..S.transport:getName(), 8)
advanceStep()

end  -- do isolation scope
return Witchcraft
