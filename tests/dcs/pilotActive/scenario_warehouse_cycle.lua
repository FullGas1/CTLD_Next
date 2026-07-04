---@diagnostic disable
-- =============================================================================
-- live_tests/scenarios/interactive/scenario_warehouse_cycle.lua
-- CTLD — Full FARP warehouse snapshot cycle
--
-- Valide le cycle complet repack + warehouse snapshot chain :
--   - Metal FARP crate spawné via menu F10
--   - Joueur charge/vole/atterrit/unpack FARP via F10
--   - Script fixe des niveaux de fuel connus dans la warehouse
--   - Joueur pack FARP via F10 "Pack FARP"
--   - Script vérifie metadata.warehouseSnapshot == valeurs fixées
--   - Joueur vole vers nouvelle position et unpack le FARP
--   - Script vérifie que la warehouse est restaurée aux mêmes valeurs
--
-- Cinématique (7 steps, injection unique) :
--   S1 [auto]   Setup + instructions : demander crate + charger + décoller + atterrir
--   S2 [human]  Confirmer : crate chargée à bord + au sol ?
--   S3 [human]  Confirmer : FARP déployé (~15s attente) ?
--   S4 [auto]   Vérifier scène active + SET fuel 5k/10k/15k/20k + instructions pack
--   S5 [human]  Confirmer : FARP packé + crate rechargée ?
--   S6 [auto]   Vérifier snapshot + instructions : voler + atterrir nouvelle position
--   S7 [human]  Confirmer : FARP redéployé à nouvelle position (~15s attente) ?
--   S8 [auto]   Vérifier warehouse restaurée == valeurs fixées
--
-- Prérequis :
--   - UH-1H BLUE slot occupé, hélico au sol
--   - Mod Farp_FG_Petit_Helipad installé (requis pour les vérifications warehouse)
--   - enableFARPRepack=true (activé automatiquement par S1)
--   - Inject CTLD_Next.lua first, wait 3–5 s for init.
--
-- @scenario  WRHSE
-- @version   3.0 — 2026-06-30
-- @coverage  W.1–W.7
-- =============================================================================

-- ── 1. Witchcraft guard ──────────────────────────────────────────────────────
if not ctld or not ctld.utils then
    trigger.action.outText("[WRHSE] ABORT: CTLD not initialized. Inject CTLD_Next.lua first.", 15)
    return Witchcraft
end

-- ── 2. Double-injection guard ────────────────────────────────────────────────
if _SCN_WRHSE_RUNNING then
    trigger.action.outText("[WRHSE] déjà actif — attendre la fin ou redémarrer DCS.", 10)
    return Witchcraft
end
_SCN_WRHSE_RUNNING = true
_SCN_WRHSE_CLEANUP = nil

-- ── 3. Global show callback (closure Lua compatible MenuManager) ─────────────
_SCN_WRHSE_INSTR = ""
_SCN_WRHSE_SHOW  = function()
    trigger.action.outText(_SCN_WRHSE_INSTR, 30)
end

do  -- isolation scope
-- ── 4. Debug ON ──────────────────────────────────────────────────────────────
local cfg                  = CTLDConfig.get()
local _savedDebug          = cfg.settings["debug"]
local _savedDebugScreenLog = cfg.settings["debugScreenLog"]
-- enableFARPRepack est intentionnellement NON restauré — doit persister pendant le test.
cfg.settings["debug"]          = true
cfg.settings["debugScreenLog"] = false

-- ── 5. Constants ─────────────────────────────────────────────────────────────
local TAG             = "[WRHSE]"
local NAME            = "FARP Warehouse Cycle"
local HUMAN_TIMEOUT_S = 600
local MENU_NAME       = "Recette CTLD"
local MENU_PATH       = { ctld.tr("CTLD"), MENU_NAME }

-- Fuel values to set and verify
local FUEL_SET  = { [0] = 5000, [1] = 10000, [2] = 15000, [3] = 20000 }
local FUEL_NAME = { [0] = "JetFuel(0)", [1] = "AvGas(1)", [2] = "MW50(2)", [3] = "Diesel(3)" }

-- ── 6. State ─────────────────────────────────────────────────────────────────
local S = {
    step          = 0,
    passed        = 0,
    failed        = 0,
    failReasons   = {},
    groupId       = nil,
    timerHandle   = nil,
    timerGen      = 0,
    transport     = nil,
    packPos       = nil,   -- position enregistrée au moment du pack (vérif relocation)
    savedRequired = nil,   -- cratesRequired original (restauré après unpack)
}

-- ── 7. Helpers ───────────────────────────────────────────────────────────────
local function log(msg) ctld.utils.log("INFO", "%s %s", TAG, msg) end

local function instruct(msg)
    _SCN_WRHSE_INSTR = TAG .. "\n" .. msg
    log("[INSTR] " .. msg)
    trigger.action.outText(_SCN_WRHSE_INSTR, 360, true)
end

local function pass(id, msg) S.passed = S.passed + 1 ; log("[PASS] "..id..": "..(msg or "")) end
local function fail(id, msg) S.failed = S.failed + 1 ; table.insert(S.failReasons, id..": "..(msg or "")) ; log("[FAIL] "..id..": "..(msg or "")) end
local function check(id, desc, cond, detail)
    if cond then pass(id, desc)
    else fail(id, desc .. (detail and (" | " .. detail) or "")) end
end

-- Trouver la première scène FARP active supportant onRepack, ou nil.
local function findFarpScene()
    local sm = CTLDSceneManager.getInstance()
    for _, sc in pairs(sm._active) do
        local model = sm:getModel(sc._modelName)
        if model and model.onRepack then return sc end
    end
    return nil
end

-- Trouver la première crate FARP portant un warehouseSnapshot, ou nil.
local function findPackedCrate()
    local cm = CTLDCrateManager.getInstance()
    for _, crate in pairs(cm.crates) do
        if crate.metadata and crate.metadata.warehouseSnapshot then
            return crate
        end
    end
    return nil
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
    _SCN_WRHSE_INSTR = nil ; _SCN_WRHSE_SHOW = nil
    cfg.settings["debug"]          = _savedDebug
    cfg.settings["debugScreenLog"] = _savedDebugScreenLog
    _SCN_WRHSE_RUNNING = false
    _SCN_WRHSE_CLEANUP = nil
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
    if not ok then log("WARN cleanup: "..tostring(err)) ; _SCN_WRHSE_RUNNING = false end
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
        fail(stepId, "no CTLD menu")
        finalizeScenario()
        return
    end

    pcall(function() menu:clearBranch(MENU_PATH) end)
    pcall(function() menu:setBranchEnabled(MENU_PATH, true) end)
    menu:addCommand(MENU_PATH, "↩ Step "..S.step..": "..title, _SCN_WRHSE_SHOW)

    local function onResponse(opt_fn)
        if S.timerGen ~= myGen then return end
        cancelTimer()
        pcall(function() menu:clearBranch(MENU_PATH) ; menu:refresh() end)
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
    if not steps[S.step] then
        finalizeScenario()
        return
    end
    local ok, err = pcall(steps[S.step])
    if not ok then
        fail("S"..S.step, "pcall: "..tostring(err))
        trigger.action.outText(TAG.." ⚠️ S"..S.step.." ERREUR: "..tostring(err), 15, false)
        advanceStep()
    end
end

-- ── 13. Steps ────────────────────────────────────────────────────────────────

-- S1 — Setup + instructions (auto)
steps[1] = function()
    ctld_test.cleanup()
    cfg.settings["enableFARPRepack"] = true

    -- Détruire toute scène Metal FARP existante
    local sm = CTLDSceneManager.getInstance()
    for _, sc in pairs(sm._active) do
        if sc._modelName == "Metal FARP" then sm:packScene(sc) end
    end

    -- Vérifier descriptor Metal FARP
    local mgr_c = CTLDCrateManager.getInstance()
    local desc  = mgr_c:findDescriptorByUnitType("Metal FARP")
    check("W.1.1", "Metal FARP descriptor available", desc ~= nil)

    -- Forcer cratesRequired=1 pour ce test (restauré après unpack au step 4)
    if desc then
        S.savedRequired     = desc.cratesRequired
        desc.cratesRequired = 1
        log("W.1.x [INFO] cratesRequired: "..tostring(S.savedRequired).." -> 1")
    end

    -- Enregistrer la position actuelle du joueur
    if S.transport then
        local p = S.transport:getPoint()
        S.packPos = { x = p.x, z = p.z }
    end

    instruct(
        "Step 1/"..#steps.." — SETUP ACTIF (enableFARPRepack=true)\n"..
        "FUEL TARGET : Jet=5000 / AvGas=10000 / MW50=15000 / Diesel=20000\n"..
        "\nActions à effectuer :\n"..
        "  1. F10 → Request Equipment → [zone] → Metal FARP (demander 1 crate)\n"..
        "  2. F10 → Crate Commands → Load Crate → Metal FARP\n"..
        "  3. Décoller\n"..
        "  4. Se poser\n"..
        "\nConfirmer OUI quand fait."
    )
    setHumanStep("W.S1", "Crate chargée, décollé et posé ?", {
        { label = "OUI — crate chargée, décollé, posé", fn = function() pass("W.S1", "actions S1 confirmées") ; advanceStep() end },
        { label = "SKIP — passer cette étape",          fn = function() log("[SKIP] S1") ; advanceStep() end },
    })
end

-- S2 — Vérifier crate chargée + instructions unload+unpack [human]
steps[2] = function()
    local mgr_c    = CTLDCrateManager.getInstance()
    local found    = false
    local stateStr = "?"
    for _, crate in pairs(mgr_c.crates) do
        if crate.descriptor then
            found    = true
            stateStr = tostring(crate.state).." unit="..tostring(crate.descriptor.unit)
            break
        end
    end
    check("W.2.1", "FARP crate présente dans le manager", found, "Avez-vous chargé la crate avant la confirmation ?")
    log("W.2.1 [INFO] crate.state = "..stateStr)

    instruct(
        "Step 2/"..#steps.." — UNLOAD + UNPACK FARP\n"..
        "\nActions à effectuer :\n"..
        "  1. F10 → Crate Commands → Unload Crate\n"..
        "  2. F10 → Crate Commands → Unpack Crate → Metal FARP\n"..
        "  3. Attendre ~15s pour que la scène FARP se déploie\n"..
        "\nConfirmer OUI quand le FARP est déployé."
    )
    setHumanStep("W.S2", "FARP déployé (~15s) ?", {
        { label = "OUI — FARP déployé",   fn = function() pass("W.S2", "FARP déploiement confirmé") ; advanceStep() end },
        { label = "SKIP — passer",        fn = function() log("[SKIP] S2") ; advanceStep() end },
    })
end

-- S3 — Vérifier scène active + SET fuel + instructions pack [auto then human]
steps[3] = function()
    instruct(
        "Step 3/"..#steps.." — VÉRIFICATION SCÈNE + SET FUEL (auto)\n"..
        "Vérification auto de la scène FARP active et fixation des niveaux fuel…"
    )
    waitThen(2, function()
        -- Restaurer cratesRequired maintenant que le FARP est déployé
        local mgr_c_r = CTLDCrateManager.getInstance()
        local sc_r    = findFarpScene()
        local desc_r  = sc_r and mgr_c_r:findDescriptorByUnitType(sc_r._modelName)
        if desc_r and S.savedRequired then
            desc_r.cratesRequired = S.savedRequired
            log("W.3.x [INFO] cratesRequired restauré à "..S.savedRequired)
        end

        local farpScene = findFarpScene()
        check("W.3.1", "scène FARP active dans CTLDSceneManager", farpScene ~= nil,
            "Avez-vous unpack le FARP et attendu ~15s ?")
        if not farpScene then fail("W.3.1b", "scène FARP introuvable") ; advanceStep() ; return end

        local farpName = farpScene._params and farpScene._params.farpName
        check("W.3.2", "farpName défini dans scene._params", farpName ~= nil)
        if not farpName then fail("W.3.2b", "farpName nil — scène sans airbase") ; advanceStep() ; return end

        local ab = Airbase.getByName(farpName)
        check("W.3.3", "Airbase '"..farpName.."' trouvé", ab ~= nil)
        if not ab then fail("W.3.3b", "Airbase.getByName returned nil") ; advanceStep() ; return end

        local w = ab:getWarehouse()
        check("W.3.4", "warehouse accessible (mod Farp_FG_Petit_Helipad requis)", w ~= nil,
            "getWarehouse() returned nil — cette scène n'a pas de warehouse accessible")
        if not w then fail("W.3.4b", "warehouse nil") ; advanceStep() ; return end

        -- Fixer les niveaux fuel connus
        for fuelType = 0, 3 do
            w:setLiquidAmount(fuelType, FUEL_SET[fuelType])
        end
        for fuelType = 0, 3 do
            local ok_rb, readback = pcall(function() return w:getLiquidAmount(fuelType) end)
            if ok_rb then
                local match = math.abs(readback - FUEL_SET[fuelType]) < 1
                check("W.3."..(fuelType + 5),
                    FUEL_NAME[fuelType].." set="..FUEL_SET[fuelType].." readback OK",
                    match, "readback="..tostring(readback))
            else
                log("W.3."..(fuelType + 5).." [INFO] getLiquidAmount non disponible — set only")
            end
        end

        instruct(
            "Step 3/"..#steps.." — FUEL FIXÉ ✅\n"..
            "Jet=5000 / AvGas=10000 / MW50=15000 / Diesel=20000\n"..
            "\nActions à effectuer :\n"..
            "  1. F10 → Crate Commands → Pack FARP → Pack Metal FARP\n"..
            "  2. F10 → Crate Commands → Load Crate (la crate qui vient d'apparaître)\n"..
            "\nConfirmer OUI quand la crate est chargée."
        )
        setHumanStep("W.S3", "FARP packé + crate chargée ?", {
            { label = "OUI — FARP packé, crate chargée", fn = function() pass("W.S3", "pack+charge confirmé") ; advanceStep() end },
            { label = "SKIP — passer",                   fn = function() log("[SKIP] S3") ; advanceStep() end },
        })
    end)
end

-- S4 — Vérifier warehouseSnapshot dans la crate + instructions vol [auto then human]
steps[4] = function()
    instruct(
        "Step 4/"..#steps.." — VÉRIFICATION SNAPSHOT (auto)\n"..
        "Vérification auto du warehouseSnapshot dans la crate…"
    )
    waitThen(1, function()
        local packed_crate = findPackedCrate()
        check("W.4.1", "crate FARP avec warehouseSnapshot trouvée", packed_crate ~= nil,
            "Avez-vous Pack FARP puis Load la crate ?")
        if not packed_crate then fail("W.4.1b", "No packed crate with snapshot found") ; advanceStep() ; return end

        local snap = packed_crate.metadata.warehouseSnapshot
        check("W.4.2", "warehouseSnapshot.liquid est une table", type(snap.liquid) == "table",
            "type="..type(snap.liquid))

        if snap.liquid then
            for fuelType = 0, 3 do
                local expected = FUEL_SET[fuelType]
                local actual   = snap.liquid[fuelType]
                check("W.4."..(fuelType + 3),
                    FUEL_NAME[fuelType].." snapshot == "..expected,
                    type(actual) == "number" and math.abs(actual - expected) < 1,
                    "expected="..expected.." actual="..tostring(actual))
            end
        end

        -- Enregistrer la position de pack actuelle
        if S.transport then
            local p = S.transport:getPoint()
            S.packPos = { x = p.x, z = p.z }
            log("W.4.8 [INFO] Pack position: x="..math.floor(p.x).." z="..math.floor(p.z))
        end

        instruct(
            "Step 4/"..#steps.." — SNAPSHOT VÉRIFIÉ ✅\n"..
            "\nActions à effectuer :\n"..
            "  1. Décoller\n"..
            "  2. Voler vers une AUTRE position (au moins 400m)\n"..
            "  3. Atterrir\n"..
            "\nConfirmer OUI quand posé à la nouvelle position."
        )
        setHumanStep("W.S4", "Posé à nouvelle position (>400m) ?", {
            { label = "OUI — posé à nouvelle position", fn = function() pass("W.S4", "relocation confirmée") ; advanceStep() end },
            { label = "SKIP — passer",                  fn = function() log("[SKIP] S4") ; advanceStep() end },
        })
    end)
end

-- S5 — Vérifier relocation + instructions unload+unpack [auto then human]
steps[5] = function()
    instruct(
        "Step 5/"..#steps.." — VÉRIFICATION RELOCATION (auto)\n"..
        "Vérification auto de la relocation…"
    )
    waitThen(1, function()
        if not S.transport then fail("W.5.0", "no BLUE player unit") ; advanceStep() ; return end

        check("W.5.1", "transport au sol", not ctld.utils.inAir(S.transport),
            "inAir="..tostring(ctld.utils.inAir(S.transport)))

        if S.packPos then
            local p    = S.transport:getPoint()
            local dx   = p.x - S.packPos.x
            local dz   = p.z - S.packPos.z
            local dist = math.sqrt(dx * dx + dz * dz)
            log("W.5.2 [INFO] Distance depuis position pack: "..math.floor(dist).." m")
            if dist < 100 then
                fail("W.5.2", "transport encore près de la position pack ("..math.floor(dist).." m) — voler > 400m")
            else
                pass("W.5.2", "Relocalisé: "..math.floor(dist).." m")
            end
        else
            log("W.5.2 [INFO] Position pack non enregistrée — vérif relocation ignorée")
        end

        instruct(
            "Step 5/"..#steps.." — RELOCATION ✅\n"..
            "\nActions à effectuer :\n"..
            "  1. F10 → Crate Commands → Unload Crate\n"..
            "  2. F10 → Crate Commands → Unpack Crate → Metal FARP\n"..
            "  3. Attendre ~15s pour que la scène FARP se déploie\n"..
            "\nConfirmer OUI quand le FARP est déployé à la nouvelle position."
        )
        setHumanStep("W.S5", "FARP redéployé nouvelle position (~15s) ?", {
            { label = "OUI — FARP redéployé",  fn = function() pass("W.S5", "redéploiement confirmé") ; advanceStep() end },
            { label = "SKIP — passer",         fn = function() log("[SKIP] S5") ; advanceStep() end },
        })
    end)
end

-- S6 — Vérifier nouvelle scène FARP active [auto]
steps[6] = function()
    instruct(
        "Step 6/"..#steps.." — VÉRIFICATION NOUVELLE SCÈNE FARP (auto)\n"..
        "Vérification auto de la scène FARP à la nouvelle position…"
    )
    waitThen(2, function()
        local farpScene2 = findFarpScene()
        check("W.6.1", "nouvelle scène FARP active dans CTLDSceneManager", farpScene2 ~= nil,
            "Avez-vous unpack le FARP et attendu ~15s ?")
        if not farpScene2 then fail("W.6.1b", "No active FARP scene found") ; advanceStep() ; return end

        local farpName2 = farpScene2._params and farpScene2._params.farpName
        check("W.6.2", "farpName défini dans nouvelle scene._params", farpName2 ~= nil,
            "Mod requis — sans lui la vérif warehouse en S7 échouera")
        log("W.6.2 [INFO] FARP airbase name: "..tostring(farpName2))

        advanceStep()
    end)
end

-- S7 — Vérifier warehouse fuel restaurée [auto]
steps[7] = function()
    instruct(
        "Step 7/"..#steps.." — VÉRIFICATION WAREHOUSE RESTAURÉE (auto)\n"..
        "Vérification finale : fuel restauré depuis le snapshot.\n"..
        "Attendu : Jet=5000 / AvGas=10000 / MW50=15000 / Diesel=20000"
    )
    waitThen(2, function()
        local farpScene2 = findFarpScene()
        check("W.7.1", "scène FARP toujours active", farpScene2 ~= nil)
        if not farpScene2 then fail("W.7.1b", "scène disparue entre S6 et S7") ; advanceStep() ; return end

        local farpName2 = farpScene2._params and farpScene2._params.farpName
        check("W.7.2", "farpName disponible depuis scene._params", farpName2 ~= nil,
            "Mod Farp_FG_Petit_Helipad requis")
        if not farpName2 then fail("W.7.2b", "farpName nil — mod absent") ; advanceStep() ; return end

        local ab = Airbase.getByName(farpName2)
        check("W.7.3", "Airbase '"..farpName2.."' accessible", ab ~= nil)
        if not ab then fail("W.7.3b", "Airbase.getByName returned nil") ; advanceStep() ; return end

        local w      = ab:getWarehouse()
        local passed = 0
        for fuelType = 0, 3 do
            local expected = FUEL_SET[fuelType]
            local actual   = w:getLiquidAmount(fuelType)
            local ok       = type(actual) == "number" and math.abs(actual - expected) < 1
            check("W.7."..(fuelType + 4),
                FUEL_NAME[fuelType].." restauré: expected="..expected.." actual="..tostring(actual),
                ok,
                "delta="..tostring(actual and math.abs(actual - expected) or "nil"))
            if ok then passed = passed + 1 end
        end

        log("Fuel types vérifiés: "..passed.."/4 PASS")
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
        for _, p in pairs(pm_start._players) do playerObjStart = p ; break end
    end
end
if not playerObjStart then
    trigger.action.outText(TAG.." ABORT : no CTLD playerObj for transport.", 20)
    cleanup() ; return Witchcraft
end

S.groupId = playerObjStart.groupId

-- Créer le sous-menu "Recette CTLD" sous "CTLD" via MenuManager
local mm_init   = ctld.MenuManager:getInstance()
local menu_init = mm_init and mm_init:getMenuByGroupId(S.groupId)
if not menu_init then
    trigger.action.outText(TAG.." ABORT : no CTLD MenuManager menu for player group.", 20)
    cleanup() ; return Witchcraft
end
menu_init:addSubMenu({ ctld.tr("CTLD") }, MENU_NAME, { order = 0 })
local _rNode = menu_init:_getNode(MENU_PATH)
if _rNode then _rNode.order = 0 ; _rNode.enabled = true end
menu_init:refresh()

_SCN_WRHSE_CLEANUP = cleanup

log("=== START: "..NAME.." | transport="..S.transport:getName().." | groupId="..tostring(S.groupId).." | "..#steps.." steps ===")
trigger.action.outText(TAG.." démarrage — "..#steps.." steps | "..S.transport:getName(), 8)
advanceStep()

end  -- do isolation scope
return Witchcraft
