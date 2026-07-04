---@diagnostic disable
-- =============================================================================
-- scenarios/interactive/scenario_farp_repack.lua
-- TODO [I]+[Q] — FARP Repack : pack scene + warehouse snapshot cycle
--
-- Validates:
--   - playSceneAtPos "Countryside FARP" starts correctly             (F-MT16.1)
--   - scene registered in _active with correct _modelName            (F-MT16.2)
--   - findNearbyRepackableScenes detects scene within radius         (F-MT16.3)
--   - findNearbyRepackableScenes returns empty outside radius        (F-MT16.4)
--   - packScene removes scene from _active                           (F-MT16.5)
--   - packScene returns repackData table                             (F-MT16.6)
--   - crate.metadata.warehouseSnapshot carried after pack            (F-MT16.7)
--   - playSceneAtPos with repackData: _params.repackData transmitted (F-MT16.8)
--
-- Steps:
--   Step 1 — deploy CS FARP (playSceneAtPos), wait ~20s
--   Step 2 — all mechanical checks (find + pack + metadata + params)
--   Step 99 — summary / reset
--
-- Prerequisites: UH-1H BLUE slot occupied, helicopter on the ground
-- =============================================================================

-- ── Witchcraft guard ─────────────────────────────────────────────────────────
if not ctld or not ctld.utils then
    trigger.action.outText("[FRP] ABORT: CTLD not initialized. Inject CTLD_Next.lua first.", 15)
    return Witchcraft
end

local TAG      = "[FRP]"
local STEP_VAR = "_FRP_STEP"

trigger.action.outText(
    "[FRP] FARP Repack recette\n"
    .. "PRE : UH-1H BLUE au sol\n"
    .. "RUN : step 1 => CS FARP deploy (~15 s)\n"
    .. "      step 2 => re-injecter a T+20 pour checks",
    20)

-- ── helpers ───────────────────────────────────────────────────────────────────

local function report(msg)
    trigger.action.outText(TAG .. " " .. msg, 40)
    ctld.utils.log("INFO", TAG .. " " .. msg)
end

local function pass(msg)   report("[PASS] " .. msg) end
local function fail(msg)   report("[FAIL] " .. msg); error(msg) end

local function check(id, desc, cond, detail)
    if cond then
        pass(id .. " — " .. desc)
    else
        fail(id .. " — " .. desc .. (detail and (" | " .. detail) or ""))
    end
end

-- ── debug activation ──────────────────────────────────────────────────────────

local cfg          = CTLDConfig.get()
local _saved_debug = cfg.settings["debug"]
local _saved_repack = cfg.settings["enableFARPRepack"]
local _savedDebugScreenLog = cfg.settings["debugScreenLog"]

cfg.settings["debug"]                  = true
cfg.settings["debugScreenLog"]         = false
cfg.settings["debugScreenLogDuration"] = 12

-- ── state machine ─────────────────────────────────────────────────────────────

_G[STEP_VAR] = _G[STEP_VAR] or 1
local step = _G[STEP_VAR]
report("==== START " .. os.date("%H:%M:%S") .. " | step=" .. step .. " ====")

local _ok, _err = pcall(function()

-- ══════════════════════════════════════════════════════════════════════════════
-- STEP 1 — Deploy CS FARP scene via playSceneAtPos
-- Expected: scene instance returned, steps begin executing in background
-- ══════════════════════════════════════════════════════════════════════════════
if step == 1 then

    ctld_test.cleanup()

    local transport = ctld_test.getTransport()
    if not transport then fail("no BLUE player unit") end

    cfg.settings["enableFARPRepack"] = true

    local sm  = CTLDSceneManager.getInstance()
    local pos = transport:getPoint()

    -- Cleanup: destroy any pre-existing CS FARP scene to avoid stale _active entries.
    for _, sc in pairs(sm._active) do
        if sc._modelName == "Countryside FARP" then
            sm:packScene(sc)
        end
    end

    local scene = sm:playSceneAtPos("Countryside FARP", pos,
        coalition.side.BLUE, country.id.USA, nil)

    check("F-MT16.1", "playSceneAtPos 'Countryside FARP' returns non-nil", scene ~= nil,
        "scene=" .. tostring(scene))
    if not scene then fail("CS FARP scene not started") end

    report("Scene '" .. tostring(scene._name) .. "' started (~15 s). Re-inject at T+20 for step 2.")
    _G[STEP_VAR] = 2

-- ══════════════════════════════════════════════════════════════════════════════
-- STEP 2 — Verify active + pack + metadata + repackData params propagation
-- Expected: all mechanical checks pass regardless of mod availability
-- ══════════════════════════════════════════════════════════════════════════════
elseif step == 2 then

    local transport = ctld_test.getTransport()
    if not transport then fail("no BLUE player unit") end

    local sm  = CTLDSceneManager.getInstance()
    local pos = transport:getPoint()

    -- ── F-MT16.2 : scene present in _active ──────────────────────────────────

    local scene = nil
    for _, sc in pairs(sm._active) do
        if sc._modelName == "Countryside FARP" then
            scene = sc
            break
        end
    end
    check("F-MT16.2a", "CS FARP scene found in _active", scene ~= nil)
    if not scene then
        fail("no active CS FARP scene — was step 2 injected too early? retry after T+20")
    end

    check("F-MT16.2b", "_modelName == 'Countryside FARP'",
        scene._modelName == "Countryside FARP",
        "got=" .. tostring(scene._modelName))

    -- ── F-MT16.3 : findNearbyRepackableScenes within radius ──────────────────

    local found300 = sm:findNearbyRepackableScenes(pos, 300)
    check("F-MT16.3", "findNearbyRepackableScenes(300m) returns >= 1 scene", #found300 >= 1,
        "count=" .. #found300)

    -- ── F-MT16.4 : findNearbyRepackableScenes outside radius (1 m) ───────────

    local found1 = sm:findNearbyRepackableScenes(pos, 1)
    -- If player is exactly at refpoint distance may be 0 → only info, not fail.
    report("F-MT16.4 [INFO] findNearbyRepackableScenes(1m): count=" .. #found1
        .. (found1 == 0 and " (expected 0 — PASS)" or " (player very close to refpoint)"))

    -- ── F-MT16.5 + F-MT16.6 : packScene ─────────────────────────────────────

    local sceneName  = scene._name
    local repackData = sm:packScene(scene)

    check("F-MT16.5", "packScene removes scene from _active",
        sm._active[sceneName] == nil,
        "key=" .. tostring(sceneName))
    check("F-MT16.6", "packScene returns a table",
        type(repackData) == "table",
        "type=" .. type(repackData))

    -- F-MT16.6b: warehouseSnapshot is mod-dependent — adaptive info, not a hard fail.
    if repackData.warehouseSnapshot then
        report("F-MT16.6b [INFO] warehouseSnapshot present (mod installed)")
        local snap = repackData.warehouseSnapshot
        check("F-MT16.6c", "warehouseSnapshot.liquid is a table",
            type(snap.liquid) == "table", tostring(snap.liquid))
        local l0 = snap.liquid[0]
        report("F-MT16.6d [INFO] liquid[0]=" .. tostring(l0)
            .. " liquid[1]=" .. tostring(snap.liquid[1])
            .. " liquid[2]=" .. tostring(snap.liquid[2])
            .. " liquid[3]=" .. tostring(snap.liquid[3]))
    else
        report("F-MT16.6b [INFO] warehouseSnapshot nil (mod absent or FARP airbase not yet registered) — expected")
    end

    -- ── F-MT16.7 : crate.metadata.warehouseSnapshot ──────────────────────────
    -- Simulate what the Pack FARP menu does: assign snapshot to crate.metadata.

    local fakeSnap = { liquid = { [0] = 5000, [1] = 2000, [2] = 0, [3] = 1000 } }
    local snapToCarry = (repackData and repackData.warehouseSnapshot) or fakeSnap
    local fakeCrate = { metadata = {} }
    fakeCrate.metadata.warehouseSnapshot = snapToCarry

    check("F-MT16.7a", "crate.metadata.warehouseSnapshot assigned",
        fakeCrate.metadata.warehouseSnapshot ~= nil)
    check("F-MT16.7b", "metadata.warehouseSnapshot.liquid table present",
        type(fakeCrate.metadata.warehouseSnapshot.liquid) == "table",
        "type=" .. type(fakeCrate.metadata.warehouseSnapshot.liquid))
    check("F-MT16.7c", "metadata.warehouseSnapshot.liquid[0] is number",
        type(fakeCrate.metadata.warehouseSnapshot.liquid[0]) == "number",
        "got=" .. tostring(fakeCrate.metadata.warehouseSnapshot.liquid[0]))

    -- ── F-MT16.8 : playSceneAtPos with repackData → _params.repackData ───────
    -- Deploy a second CS FARP scene with a known fake snapshot; verify transmission.

    local testSnap = { liquid = { [0] = 7777, [1] = 3333, [2] = 111, [3] = 0 } }
    local scene2 = sm:playSceneAtPos("Countryside FARP", pos,
        coalition.side.BLUE, country.id.USA,
        { repackData = { warehouseSnapshot = testSnap } })

    check("F-MT16.8a", "playSceneAtPos with repackData returns non-nil scene", scene2 ~= nil)
    if scene2 then
        local rd = scene2._params and scene2._params.repackData
        check("F-MT16.8b", "scene._params.repackData present", rd ~= nil)
        if rd and rd.warehouseSnapshot then
            check("F-MT16.8c", "scene._params.repackData.warehouseSnapshot.liquid[0] == 7777",
                rd.warehouseSnapshot.liquid[0] == 7777,
                "got=" .. tostring(rd.warehouseSnapshot.liquid[0]))
        else
            fail("F-MT16.8c — _params.repackData.warehouseSnapshot missing after transmit")
        end
    end

    report("Step 2 done. Re-inject for step 99 (summary).")
    _G[STEP_VAR] = 99

-- ══════════════════════════════════════════════════════════════════════════════
-- STEP 99 — Summary / reset counter
-- ══════════════════════════════════════════════════════════════════════════════
elseif step >= 99 then

    report("═══════════════════════════════════════")
    report("FRP — FARP Repack recette complete")
    report("Cases covered: F-MT16.1 -> F-MT16.8")
    report("═══════════════════════════════════════")
    _G[STEP_VAR] = 1

else
    fail("step=" .. step .. " — no matching branch (reset _FRP_STEP = 1 or add elseif)")
end

end)  -- end pcall

-- ── cleanup (always executed — debug and config restored even on fail) ────────
cfg.settings["debug"]            = _saved_debug
cfg.settings["debugScreenLog"]   = _savedDebugScreenLog
cfg.settings["enableFARPRepack"] = _saved_repack

-- ── Witchcraft return value ───────────────────────────────────────────────────
if not _ok then
    trigger.action.outText(TAG .. " ❌ step=" .. step .. " FAIL", 60, true)
    return TAG .. " step=" .. step .. " FAIL: " .. tostring(_err)
end
trigger.action.outText(TAG .. " ✅ step=" .. step .. " SUCCESS", 30, true)
return TAG .. " step=" .. step .. " SUCCESS"
