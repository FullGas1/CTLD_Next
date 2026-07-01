---@diagnostic disable
-- =============================================================================
-- live_tests/scenarios/interactive/scenario_troop_menu_sol_vol_visual.lua
-- CTLD — Troop Commands menu : vérification sol / vol / sol (visual)
--
-- Mini-application de recette interactive : injection unique, avance
-- automatiquement (waitFor décollage/atterrissage) ou via menu F10
-- "Recette CTLD" (vérifications visuelles et auto).
--
-- Prérequis :
--   - Slot UH-1H BLUE occupé, hélico au sol dans/près d'une TRZ (Troop Zone)
--   - troopsEnabled=true, canParachuteDrop=true pour le type UH-1H
--   - Au moins un template de troupes configuré
--
-- Cinématique (5 steps, injection unique) :
--   S1 [F10]  Vérifier menu sol + embarquer des troupes
--   S2 [auto] Décoller → détecté via inAir()
--   S3 [auto] Vérifier menu vol (Parachute Troops VISIBLE)
--   S4 [auto] Atterrir → détecté via not inAir()
--   S5 [auto] Vérifier menu sol restauré (Disembark VISIBLE, Parachute ABSENT)
--
-- @scenario  TMFV
-- @version   1.0 — 2026-06-30
-- @coverage  F-183 (sol), F-184 (vol), F-185 (restauration sol)
-- =============================================================================

-- ── 1. Witchcraft guard ──────────────────────────────────────────────────────
if not ctld or not ctld.utils then
    trigger.action.outText("[TMFV] ABORT: CTLD not initialized. Inject CTLD_Next.lua first.", 15)
    return Witchcraft
end

-- ── 2. Double-injection guard ────────────────────────────────────────────────
if _SCN_TMFV_RUNNING then
    trigger.action.outText("[TMFV] déjà actif — attendre la fin ou redémarrer DCS.", 10)
    return Witchcraft
end
_SCN_TMFV_RUNNING = true
_SCN_TMFV_CLEANUP = nil

-- ── 3. Global show callback ──────────────────────────────────────────────────
_SCN_TMFV_INSTR = ""
_SCN_TMFV_SHOW  = function()
    trigger.action.outText(_SCN_TMFV_INSTR, 30)
end

do  -- isolation scope
-- ── 4. Debug ON ──────────────────────────────────────────────────────────────
local cfg                  = CTLDConfig.get()
local _savedDebug          = cfg.settings["debug"]
local _savedDebugScreenLog = cfg.settings["debugScreenLog"]
cfg.settings["debug"]          = true
cfg.settings["debugScreenLog"] = false

-- ── 5. Constants ─────────────────────────────────────────────────────────────
local TAG             = "[TMFV]"
local NAME            = "Troop Commands menu — sol/vol/sol"
local HUMAN_TIMEOUT_S = 300
local MENU_NAME       = "Recette CTLD"
local MENU_PATH       = { ctld.tr("CTLD"), MENU_NAME }
local TROOP_SUB       = ctld.tr("Troop Commands")

-- ── 6. State ─────────────────────────────────────────────────────────────────
local S = {
    step        = 0,
    passed      = 0,
    failed      = 0,
    failReasons = {},
    groupId     = nil,
    timerHandle = nil,
    timerGen    = 0,
    transport   = nil,
}

-- ── 7. Helpers ───────────────────────────────────────────────────────────────
local function log(msg) ctld.utils.log("INFO", "%s %s", TAG, msg) end

local function instruct(msg)
    _SCN_TMFV_INSTR = TAG .. "\n" .. msg
    log("[INSTR] " .. msg)
    trigger.action.outText(_SCN_TMFV_INSTR, 360, true)
end

local function pass(id, msg) S.passed = S.passed + 1 ; log("[PASS] "..id..": "..(msg or "")) end
local function fail(id, msg) S.failed = S.failed + 1 ; table.insert(S.failReasons, id..": "..(msg or "")) ; log("[FAIL] "..id..": "..(msg or "")) end

-- Capture l'état du menu Troop Commands dans CTLD.log.
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

        local root   = ctld.tr("CTLD")
        local prefix = root .. "." .. TROOP_SUB .. "."

        local seen  = {}
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
            log("[SNAPSHOT] Troop Commands : aucun item trouvé (prefix="..prefix..")")
        else
            log("[SNAPSHOT] Troop Commands :\n"..table.concat(items, "\n"))
        end
    end)
    if not ok then log("[SNAPSHOT] ERREUR: "..tostring(err)) end
end

-- ── 8. Cleanup ───────────────────────────────────────────────────────────────
local function cleanup()
    if S.timerHandle then timer.removeFunction(S.timerHandle) ; S.timerHandle = nil end
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
    _SCN_TMFV_INSTR = nil ; _SCN_TMFV_SHOW = nil
    cfg.settings["debug"]          = _savedDebug
    cfg.settings["debugScreenLog"] = _savedDebugScreenLog
    _SCN_TMFV_RUNNING = false
    _SCN_TMFV_CLEANUP = nil
    log("cleanup done")
end

-- ── 9. Timer helpers ─────────────────────────────────────────────────────────
local function cancelTimer()
    S.timerGen = S.timerGen + 1
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
        if S.timerGen ~= myGen then return nil end
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

local function waitThen(delayS, callback)
    cancelTimer()
    local myGen = S.timerGen
    S.timerHandle = timer.scheduleFunction(function()
        if S.timerGen ~= myGen then return nil end
        S.timerHandle = nil
        callback()
    end, nil, timer.getTime() + delayS)
end

-- Auto-verify Troop Commands menu state.
-- expected = list of {name=string, state="VISIBLE"|"MASQUE"|"ABSENT"}
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

    local root   = ctld.tr("CTLD")
    local prefix = root .. "." .. TROOP_SUB .. "."

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

    local issues = {}
    for _, exp in ipairs(expected) do
        local got = actual[exp.name] or "ABSENT"
        if got ~= exp.state then
            table.insert(issues, string.format("  %-26s : got %-7s expected %s", exp.name, got, exp.state))
        end
    end
    return #issues == 0, issues
end

-- ── 10. Finalization ─────────────────────────────────────────────────────────
local function finalizeScenario()
    cancelTimer()
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
    if not ok then log("WARN cleanup: "..tostring(err)) ; _SCN_TMFV_RUNNING = false end
end

-- ── 11. Step humain (MenuManager) ────────────────────────────────────────────
local advanceStep

local function setHumanStep(stepId, title, options)
    cancelTimer()
    local myGen = S.timerGen

    local mm   = ctld.MenuManager:getInstance()
    local menu = mm and mm:getMenuByGroupId(S.groupId)
    if not menu then
        log("[ERR] setHumanStep: no CTLD menu for groupId="..tostring(S.groupId))
        fail(stepId, "no CTLD menu") ; finalizeScenario() ; return
    end

    pcall(function() menu:clearBranch(MENU_PATH) end)
    pcall(function() menu:setBranchEnabled(MENU_PATH, true) end)
    menu:addCommand(MENU_PATH, "↩ Step "..S.step..": "..title, _SCN_TMFV_SHOW)

    local function onResponse(opt_fn)
        if S.timerGen ~= myGen then return end
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
    if not steps[S.step] then finalizeScenario() ; return end
    local ok, err = pcall(steps[S.step])
    if not ok then
        fail("S"..S.step, "pcall: "..tostring(err))
        trigger.action.outText(TAG.." ⚠️ S"..S.step.." ERREUR: "..tostring(err), 15, false)
        advanceStep()
    end
end

-- ── 13. Steps ────────────────────────────────────────────────────────────────

-- S1 — Vérification menu sol + embarquer des troupes [F10]
steps[1] = function()
    if not (ctld.gs("enableTroops") ~= false) then
        instruct("Step 1/5 — ABORT PRÉREQUIS\nenableTroops=false dans la config.")
        fail("F-183", "enableTroops=false — test impossible") ; finalizeScenario() ; return
    end
    instruct(
        "Step 1/5 — MENU SOL TROUPES (F-183)\n"..
        "Prérequis : hélico AU SOL dans ou près d'une zone de troupes (TRZ)\n"..
        "\nA) Vérifier F10 → CTLD → Troop Commands :\n"..
        "  ✅ VISIBLE  : Embark / Extract Troops\n"..
        "  ✅ VISIBLE  : Check Cargo\n"..
        "  ❌ ABSENT   : Parachute Troops (sol uniquement)\n"..
        "  ❌ ABSENT   : Disembark Troops (aucune troupe à bord)\n"..
        "\nB) Embarquer des troupes :\n"..
        "  F10 → CTLD → Troop Commands → Embark / Extract Troops → [zone] → Load [modèle]\n"..
        "  → Confirmation d'embarquement affichée\n"..
        "\nRépondre OUI/NON après A+B."
    )
    setHumanStep("F-183", "Menu sol troupes correct + troupes embarquées ?", {
        { label = "OUI — menu OK et troupes embarquées",  fn = function() pass("F-183", "menu sol troupes OK") ; advanceStep() end },
        { label = "NON — menu incorrect",                 fn = function() fail("F-183", "menu sol troupes KO") ; advanceStep() end },
        { label = "SKIP — ne peut vérifier",              fn = function() log("[SKIP] S1")                      ; advanceStep() end },
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
-- F-184: Parachute Troops doit être VISIBLE en vol si troupes à bord + canParachuteDrop.
-- Disembark Troops doit être ABSENT (sol uniquement).
steps[3] = function()
    instruct(
        "Step 3/5 — VÉRIFICATION AUTO MENU VOL (F-184)\n"..
        "Vérification automatique du menu en cours (2s)…"
    )
    local EXPECTED_VOL = {
        { name = "Parachute Troops",         state = "VISIBLE" },
        { name = "Disembark Troops",          state = "ABSENT"  },
        { name = "Embark / Extract Troops",   state = "ABSENT"  },
        { name = "Check Cargo",               state = "ABSENT"  },
    }
    waitThen(2, function()
        -- Force refresh troop menu section for current flight state
        local tm = CTLDTroopManager.getInstance()
        local pm = CTLDPlayerManager.getInstance()
        local playerObj
        if pm and pm._players then for _, p in pairs(pm._players) do playerObj = p ; break end end
        local inAirNow = S.transport and S.transport:isExist() and S.transport:inAir() or false
        log("[AUTO-CHECK] S3 inAir="..tostring(inAirNow))
        if playerObj then tm:refreshMenuSection(playerObj) end

        local ok, issues = checkMenuExpected(EXPECTED_VOL)
        logMenuSnapshot()
        if ok then
            pass("F-184", "menu vol troupes auto-vérifié OK")
            local msg = TAG.." ✅ F-184 menu vol troupes OK (auto-vérifié)\nParachute Troops VISIBLE en vol."
            log("[AUTO-CHECK] F-184 PASS")
            trigger.action.outText(msg, 15, true)
        else
            fail("F-184", "menu vol troupes KO: "..table.concat(issues, " | "))
            local msg = TAG.." ❌ F-184 menu vol troupes KO (auto-vérifié)\n"..table.concat(issues, "\n")
            log("[AUTO-CHECK] F-184 FAIL: "..table.concat(issues, " | "))
            trigger.action.outText(msg, 20, true)
        end
        advanceStep()
    end)
end

-- S4 — Atterrir [auto]
steps[4] = function()
    instruct(
        "Step 4/5 — ATTERRIR (auto)\n"..
        "Atterrir SANS larguer les troupes.\n"..
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
-- F-185: Parachute Troops → ABSENT (sol). Disembark Troops → VISIBLE (troupes toujours à bord).
steps[5] = function()
    instruct(
        "Step 5/5 — VÉRIFICATION AUTO SOL RESTAURÉ (F-185)\n"..
        "Vérification automatique du menu en cours (2s)…"
    )
    local EXPECTED_SOL_KEY = {
        { name = "Parachute Troops",   state = "ABSENT"  },
        { name = "Disembark Troops",   state = "VISIBLE" },
    }
    waitThen(2, function()
        local tm = CTLDTroopManager.getInstance()
        local pm = CTLDPlayerManager.getInstance()
        local playerObj
        if pm and pm._players then for _, p in pairs(pm._players) do playerObj = p ; break end end
        local inAirNow = S.transport and S.transport:isExist() and S.transport:inAir() or false
        log("[AUTO-CHECK] S5 inAir="..tostring(inAirNow))
        if playerObj then tm:refreshMenuSection(playerObj) end

        local ok, issues = checkMenuExpected(EXPECTED_SOL_KEY)
        logMenuSnapshot()
        if ok then
            pass("F-185", "sol restauré troupes auto-vérifié OK")
            local msg = TAG.." ✅ F-185 sol restauré troupes OK (auto-vérifié)\nParachute Troops ABSENT, Disembark VISIBLE."
            log("[AUTO-CHECK] F-185 PASS")
            trigger.action.outText(msg, 15, true)
        else
            fail("F-185", "sol restauré troupes KO: "..table.concat(issues, " | "))
            local msg = TAG.." ❌ F-185 sol restauré troupes KO (auto-vérifié)\n"..table.concat(issues, "\n")
            log("[AUTO-CHECK] F-185 FAIL: "..table.concat(issues, " | "))
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
    cleanup() ; return Witchcraft
end

local pm_start = CTLDPlayerManager.getInstance()
local playerObjStart
if pm_start and pm_start._players then
    for _, p in pairs(pm_start._players) do
        if p.unitName == S.transport:getName() then playerObjStart = p ; break end
    end
    if not playerObjStart then
        for _, p in pairs(pm_start._players) do playerObjStart = p ; break end
    end
end
if not playerObjStart then
    trigger.action.outText(TAG.." ABORT : no CTLD playerObj for transport.", 20)
    cleanup() ; return Witchcraft
end

S.groupId = playerObjStart.groupId

local mm_init   = ctld.MenuManager:getInstance()
local menu_init = mm_init and mm_init:getMenuByGroupId(S.groupId)
if not menu_init then
    trigger.action.outText(TAG.." ABORT : no CTLD MenuManager menu for player group.", 20)
    cleanup() ; return Witchcraft
end
menu_init:addSubMenu({ ctld.tr("CTLD") }, MENU_NAME, { order = 0, enabled = true })
-- Force order=0 + enabled=true même si nœud existe déjà (addSubMenu idempotent met à jour depuis CTLD_menu.lua fix)
local _rNode = menu_init:_getNode(MENU_PATH)
if _rNode then _rNode.order = 0 ; _rNode.enabled = true end
menu_init:refresh()

_SCN_TMFV_CLEANUP = cleanup

log("=== START: "..NAME.." | transport="..S.transport:getName().." | groupId="..tostring(S.groupId).." | 5 steps ===")
trigger.action.outText(TAG.." démarrage — 5 steps | "..S.transport:getName(), 8)
advanceStep()

end  -- do isolation scope
return Witchcraft
