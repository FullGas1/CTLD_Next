---@diagnostic disable
-- =============================================================================
-- live_tests/scenarios/interactive/scenario_weight_aggregation.lua
-- CTLD — Validates ctld.utils.updateTransportWeight aggregates all cargo sources
--
-- Flow (single step, 4 sequential phases):
--   Phase 1 — Inject troops (320 kg)                  → weight == 320
--   Phase 2 — Inject Hummer crate (2500 kg) in CTLD   → weight == 2820
--   Phase 3 — Disembark troops                         → weight == 2500
--   Phase 4 — Unload crate                             → weight == 0
--
-- Cinématique (1 step auto) :
--   S1 [auto]  4 phases séquentielles, injection unique
--
-- Prérequis: slot BLUE UH-1H occupé.
--
-- @scenario  WGT
-- @version   3.0 — 2026-06-30
-- @coverage  F-WGT
-- =============================================================================

-- ── 1. Witchcraft guard ──────────────────────────────────────────────────────
if not ctld or not ctld.utils then
    trigger.action.outText("[WGT] ABORT: CTLD not initialized. Inject CTLD_Next.lua first.", 15)
    return Witchcraft
end

-- ── 2. Double-injection guard ────────────────────────────────────────────────
if _SCN_WGT_RUNNING then
    trigger.action.outText("[WGT] déjà actif — attendre la fin ou redémarrer DCS.", 10)
    return Witchcraft
end
_SCN_WGT_RUNNING = true
_SCN_WGT_CLEANUP = nil

-- ── 3. Global show callback ───────────────────────────────────────────────────
_SCN_WGT_INSTR = ""
_SCN_WGT_SHOW  = function()
    trigger.action.outText(_SCN_WGT_INSTR, 30)
end

do  -- isolation scope
-- ── 4. Debug ON ──────────────────────────────────────────────────────────────
local cfg                  = CTLDConfig.get()
local _savedDebug          = cfg.settings["debug"]
local _savedDebugScreenLog = cfg.settings["debugScreenLog"]
cfg.settings["debug"]          = true
cfg.settings["debugScreenLog"] = false

-- ── 5. Constants ─────────────────────────────────────────────────────────────
local TAG             = "[WGT]"
local NAME            = "Weight aggregation — 4 phases"
local MENU_NAME       = "Recette CTLD"
local MENU_PATH       = { ctld.tr("CTLD"), MENU_NAME }
local CRATE_NAME      = "SCN_WGT_HUMMER_CRATE"
local TROOP_W         = 320   -- 4 soldiers × 80 kg
local CRATE_W         = 2500  -- Hummer

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
    _SCN_WGT_INSTR = TAG .. "\n" .. msg
    log("[INSTR] " .. msg)
    trigger.action.outText(_SCN_WGT_INSTR, 360, true)
end

local function pass(id, msg) S.passed = S.passed + 1 ; log("[PASS] "..id..": "..(msg or "")) end
local function fail(id, msg) S.failed = S.failed + 1 ; table.insert(S.failReasons, id..": "..(msg or "")) ; log("[FAIL] "..id..": "..(msg or "")) end

local function check(id, desc, cond, details)
    if cond then pass(id, desc)
    else fail(id, desc .. (details and (" | " .. details) or "")) end
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
    -- Nettoyage état de test
    if S.transport then
        local tm = CTLDTroopManager.getInstance()
        local cm = CTLDCrateManager.getInstance()
        if tm then tm._inTransit[S.transport:getName()] = nil end
        if cm then cm.crates[CRATE_NAME] = nil end
        pcall(trigger.action.setUnitInternalCargo, S.transport:getName(), 0)
    end
    _SCN_WGT_INSTR = nil ; _SCN_WGT_SHOW = nil
    cfg.settings["debug"]          = _savedDebug
    cfg.settings["debugScreenLog"] = _savedDebugScreenLog
    _SCN_WGT_RUNNING = false
    _SCN_WGT_CLEANUP = nil
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
    if not ok then log("WARN cleanup: "..tostring(err)) ; _SCN_WGT_RUNNING = false end
end

-- ── 11. Step runner ───────────────────────────────────────────────────────────
local steps = {}
local advanceStep

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

-- ── 12. Weight capture helper ─────────────────────────────────────────────────
local function captureWeight(unitName)
    local captured = nil
    local _orig = trigger.action.setUnitInternalCargo
    trigger.action.setUnitInternalCargo = function(n, v)
        if n == unitName then captured = v end
        return _orig(n, v)
    end
    ctld.utils.updateTransportWeight(unitName)
    trigger.action.setUnitInternalCargo = _orig
    return captured or 0
end

-- ── 13. Steps ────────────────────────────────────────────────────────────────

-- S1 — All 4 phases (single injection, sequential)
steps[1] = function()
    instruct("Step 1/1 — F-WGT: weight aggregation 4 phases (auto)")

    local playerName = S.transport:getName()
    local pPos       = S.transport:getPoint()
    local tm         = CTLDTroopManager.getInstance()
    local cm         = CTLDCrateManager.getInstance()

    -- Cleanup stale state
    tm._inTransit[playerName] = nil
    cm.crates[CRATE_NAME]     = nil

    -- Phase 1 : troops only (_inTransit is a list of {weight=...} tables)
    tm._inTransit[playerName] = { { weight = TROOP_W } }
    local w1 = captureWeight(playerName)
    log(string.format("Phase 1 (troops only): %d kg  [expected %d]", w1, TROOP_W))
    check("F-WGT.1", "troops weight = " .. TROOP_W .. " kg", w1 == TROOP_W,
        "got=" .. w1)

    -- Phase 2 : troops + CTLD crate
    local crate = CTLDCrate:new({
        crateName   = CRATE_NAME,
        descriptor  = { weight = CRATE_W, desc = "Hummer" },
        spawnMethod = CTLDCrate.SPAWN_METHOD.MENU_CTLD,
        position    = pPos,
        coalition   = coalition.side.BLUE,
    })
    crate:load(S.transport)
    cm.crates[CRATE_NAME] = crate
    local w2 = captureWeight(playerName)
    local expected2 = TROOP_W + CRATE_W
    log(string.format("Phase 2 (troops+crate): %d kg  [expected %d]", w2, expected2))
    check("F-WGT.2", "troops+crate weight = " .. expected2 .. " kg", w2 == expected2,
        "got=" .. w2)

    -- Phase 3 : crate only (troops disembarked)
    tm._inTransit[playerName] = nil
    local w3 = captureWeight(playerName)
    log(string.format("Phase 3 (crate only):   %d kg  [expected %d]", w3, CRATE_W))
    check("F-WGT.3", "crate only weight = " .. CRATE_W .. " kg", w3 == CRATE_W,
        "got=" .. w3)

    -- Phase 4 : empty (crate unloaded)
    crate:unload(pPos)
    local w4 = captureWeight(playerName)
    log(string.format("Phase 4 (empty):          %d kg  [expected 0]", w4))
    check("F-WGT.4", "empty transport weight = 0 kg", w4 == 0,
        "got=" .. w4)

    log("═══ WEIGHT AGGREGATION 4/4 | 320→2820→2500→0 kg ═══")

    -- Cleanup state
    tm._inTransit[playerName] = nil
    cm.crates[CRATE_NAME]     = nil
    pcall(trigger.action.setUnitInternalCargo, playerName, 0)

    log("S1 done — finalisation")
    advanceStep()
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

_SCN_WGT_CLEANUP = cleanup

log("=== START: "..NAME.." | transport="..S.transport:getName().." | groupId="..tostring(S.groupId).." | "..#steps.." steps ===")
trigger.action.outText(TAG.." démarrage — "..#steps.." steps | "..S.transport:getName(), 8)
advanceStep()

end  -- do isolation scope
return Witchcraft
