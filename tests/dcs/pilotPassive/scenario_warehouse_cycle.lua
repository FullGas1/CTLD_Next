---@diagnostic disable
-- =============================================================================
-- scenarios/interactive/scenario_warehouse_cycle.lua
-- TODO [I]+[Q] — Full FARP warehouse snapshot cycle (7 injections)
--
-- Validates the complete repack + warehouse snapshot chain:
--   - Metal FARP crate spawned near player
--   - Player loads/flies/lands/unpacks FARP via F10
--   - Script sets known fuel levels in the FARP warehouse
--   - Player packs FARP via F10 "Pack FARP" menu
--   - Script verifies metadata.warehouseSnapshot == set values
--   - Player flies to new location and unpacks FARP
--   - Script verifies warehouse restored to same values
--
-- Injection map:
--   Injection 1  — spawn Metal FARP crate + instructions: load/fly/land
--   Injection 2  — check crate exists, instructions: unload + unpack FARP
--   Injection 3  — check FARP active, SET fuel 5k/10k/15k/20k, instructions: pack + load
--   Injection 4  — verify warehouseSnapshot in crate metadata, instructions: fly + land
--   Injection 5  — verify ground + new position, instructions: unload + unpack FARP
--   Injection 6  — verify new FARP scene active
--   Injection 7  — verify warehouse restored == 5k/10k/15k/20k
--
-- Prerequisites:
--   • UH-1H BLUE slot occupied, helicopter on the ground
--   • Mod Farp_FG_Petit_Helipad installed (required for warehouse steps 3+7)
--   • enableFARPRepack must be true (set automatically by step 1)
-- =============================================================================

-- ── Witchcraft guard ────────────────────────────────────────────────
if not ctld or not ctld.utils then
    trigger.action.outText("[WRHSE] ABORT: CTLD not initialized. Inject CTLD_Next.lua first.", 15)
    return Witchcraft
end
local TAG      = "[WRHSE]"
local STEP_VAR = "_WRHSE_STEP"
local POS_VAR  = "_WRHSE_PACK_POS"  -- stored pack position for relocation check

-- Fuel values to set and verify (DCS warehouse units — litres or kg depending on DCS version)
local FUEL_SET  = { [0] = 5000, [1] = 10000, [2] = 15000, [3] = 20000 }
local FUEL_NAME = { [0] = "JetFuel(0)", [1] = "AvGas(1)", [2] = "MW50(2)", [3] = "Diesel(3)" }

-- ── persistent header (shown at every injection) ──────────────────────────────

trigger.action.outText(
    "[WRHSE] FARP Warehouse Cycle — " .. ((_G[STEP_VAR] or 1) == 1 and "START" or "step=" .. tostring(_G[STEP_VAR])) .. "\n"
    .. "PRE: UH-1H BLUE au sol | mod Farp_FG_Petit_Helipad installe\n"
    .. "FUEL TARGET: Jet=5000 / AvGas=10000 / MW50=15000 / Diesel=20000",
    20)

-- ── helpers ───────────────────────────────────────────────────────────────────

local function report(msg)
    trigger.action.outText(TAG .. " " .. msg, 50)
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

-- Find the first active FARP scene that supports onRepack (any model), or nil.
local function findFarpScene()
    local sm = CTLDSceneManager.getInstance()
    for _, sc in pairs(sm._active) do
        local model = sm:getModel(sc._modelName)
        if model and model.onRepack then return sc end
    end
    return nil
end

-- Find the first FARP crate carrying a warehouseSnapshot, or nil.
local function findPackedCrate()
    local cm = CTLDCrateManager.getInstance()
    for _, crate in pairs(cm.crates) do
        if crate.metadata and crate.metadata.warehouseSnapshot then
            return crate
        end
    end
    return nil
end

-- ── debug activation ──────────────────────────────────────────────────────────

local cfg            = CTLDConfig.get()
local _saved_debug         = cfg.settings["debug"]
local _savedDebugScreenLog = cfg.settings["debugScreenLog"]
-- enableFARPRepack is intentionally NOT saved/restored — it must persist between injections.

cfg.settings["debug"]                  = true
cfg.settings["debugScreenLog"]         = true
cfg.settings["debugScreenLogDuration"] = 15

-- ── state machine ─────────────────────────────────────────────────────────────

_G[STEP_VAR] = _G[STEP_VAR] or 1
local step = _G[STEP_VAR]
report("==== START " .. os.date("%H:%M:%S") .. " | step=" .. step .. " ====")

local _ok, _err = pcall(function()

-- ══════════════════════════════════════════════════════════════════════════════
-- INJECTION 1 — Setup: enable FARP repack, clean leftover scenes, give instructions
-- The player uses the normal F10 menu to request and load a Metal FARP crate.
-- ══════════════════════════════════════════════════════════════════════════════
if step == 1 then

    ctld_test.cleanup()
    cfg.settings["enableFARPRepack"] = true

    -- Destroy any pre-existing Metal FARP scenes so we start clean.
    local sm = CTLDSceneManager.getInstance()
    for _, sc in pairs(sm._active) do
        if sc._modelName == "Metal FARP" then sm:packScene(sc) end
    end

    -- Verify Metal FARP is available in the menu (descriptor exists).
    local mgr_c = CTLDCrateManager.getInstance()
    local desc  = mgr_c:findDescriptorByUnitType("Metal FARP")
    check("W.1.1", "Metal FARP descriptor available", desc ~= nil)

    -- Override cratesRequired to 1 for this test run (restored at step 3 after unpack).
    if desc then
        _G["_WRHSE_SAVED_REQUIRED"] = desc.cratesRequired
        desc.cratesRequired = 1
        report("W.1.x [INFO] cratesRequired: " .. tostring(_G["_WRHSE_SAVED_REQUIRED"]) .. " -> 1")
    end

    -- Store current player position for relocation check later.
    local transport = ctld_test.getTransport()
    if transport then
        local p = transport:getPoint()
        _G[POS_VAR] = { x = p.x, z = p.z }
    end

    report(
        ">>> STEP 1 — enableFARPRepack actif.\n"
        .. "Actions joueur :\n"
        .. "  1. F10 > Request Equipment > [zone] > Metal FARP (demander 1 crate)\n"
        .. "  2. F10 > Crate Commands > Load Crate > Metal FARP\n"
        .. "  3. Decoller\n"
        .. "  4. Se poser\n"
        .. "  5. Reinjecter")
    _G[STEP_VAR] = 2

-- ══════════════════════════════════════════════════════════════════════════════
-- INJECTION 2 — Verify crate is loaded (or on ground), instruct unload+unpack
-- Player has: loaded crate, taken off, landed
-- ══════════════════════════════════════════════════════════════════════════════
elseif step == 2 then

    local mgr_c    = CTLDCrateManager.getInstance()
    local found    = false
    local stateStr = "?"
    for _, crate in pairs(mgr_c.crates) do
        if crate.descriptor then
            found    = true
            stateStr = tostring(crate.state) .. " unit=" .. tostring(crate.descriptor.unit)
            break
        end
    end
    check("W.2.1", "FARP crate present in manager", found,
        "Did you load the crate before re-injecting?")
    report("W.2.1 [INFO] crate.state = " .. stateStr)

    report(
        ">>> STEP 2 — Unload and deploy FARP.\n"
        .. "Player actions to complete before re-injecting:\n"
        .. "  1. F10 > Crate Commands > Unload Crate\n"
        .. "  2. F10 > Crate Commands > Unpack Crate > Metal FARP\n"
        .. "  3. Wait ~15 s for the FARP scene to finish deploying\n"
        .. "  4. Re-inject this script (step 3 will run)")
    _G[STEP_VAR] = 3

-- ══════════════════════════════════════════════════════════════════════════════
-- INJECTION 3 — Verify FARP active, SET known fuel levels
-- Player has: unloaded crate, unpacked FARP (waited ~15 s)
-- ══════════════════════════════════════════════════════════════════════════════
elseif step == 3 then

    -- Restore cratesRequired to its original value now that the unpack is confirmed.
    local mgr_c_r = CTLDCrateManager.getInstance()
    local sm_r    = CTLDSceneManager.getInstance()
    local sc_r    = findFarpScene()
    local desc_r  = sc_r and mgr_c_r:findDescriptorByUnitType(sc_r._modelName)
    if desc_r and _G["_WRHSE_SAVED_REQUIRED"] then
        desc_r.cratesRequired = _G["_WRHSE_SAVED_REQUIRED"]
        report("W.3.x [INFO] cratesRequired restored to " .. _G["_WRHSE_SAVED_REQUIRED"])
    end

    local farpScene = findFarpScene()
    check("W.3.1", "FARP scene active in CTLDSceneManager", farpScene ~= nil,
        "Did you unpack the FARP and wait for it to finish (~15 s)?")
    if not farpScene then fail("FARP scene not found") end

    local farpName = farpScene._params and farpScene._params.farpName
    check("W.3.2", "farpName set in scene._params", farpName ~= nil)
    if not farpName then fail("farpName nil — scene did not register an airbase") end

    local ab = Airbase.getByName(farpName)
    check("W.3.3", "Airbase '" .. farpName .. "' found", ab ~= nil)
    if not ab then fail("Airbase.getByName returned nil") end

    local w = ab:getWarehouse()
    check("W.3.4", "warehouse accessible (mod helipad required for " .. farpScene._modelName .. ")",
        w ~= nil, "getWarehouse() returned nil — this scene type has no accessible warehouse")
    if not w then
        fail("warehouse nil — use Metal FARP (mod Farp_FG_Petit_Helipad) for the warehouse cycle test")
    end

    -- Set known fuel levels.
    for fuelType = 0, 3 do
        w:setLiquidAmount(fuelType, FUEL_SET[fuelType])
    end
    -- Readback via getLiquid (only available on mod-based warehouses).
    for fuelType = 0, 3 do
        local ok_rb, readback = pcall(function() return w:getLiquidAmount(fuelType) end)
        if ok_rb then
            local match = math.abs(readback - FUEL_SET[fuelType]) < 1
            check("W.3." .. (fuelType + 5),
                FUEL_NAME[fuelType] .. " set=" .. FUEL_SET[fuelType] .. " readback OK",
                match, "readback=" .. tostring(readback))
        else
            report("W.3." .. (fuelType + 5) .. " [INFO] getLiquidAmount not available on this warehouse type — set only")
        end
    end

    report(
        ">>> STEP 3 DONE — Fuel levels set and confirmed.\n"
        .. "Player actions to complete before re-injecting:\n"
        .. "  1. F10 > Crate Commands > Pack FARP > Pack Metal FARP\n"
        .. "  2. F10 > Crate Commands > Load Crate (the crate that just appeared)\n"
        .. "  3. Re-inject this script (step 4 will run)")
    _G[STEP_VAR] = 4

-- ══════════════════════════════════════════════════════════════════════════════
-- INJECTION 4 — Verify warehouseSnapshot carried in crate metadata
-- Player has: packed FARP, loaded the spawned crate
-- ══════════════════════════════════════════════════════════════════════════════
elseif step == 4 then

    local packed_crate = findPackedCrate()
    check("W.4.1", "FARP crate with warehouseSnapshot found in manager",
        packed_crate ~= nil,
        "Did you Pack FARP then Load the crate?")
    if not packed_crate then fail("No packed crate with snapshot found") end

    local snap = packed_crate.metadata.warehouseSnapshot
    check("W.4.2", "warehouseSnapshot.liquid is a table", type(snap.liquid) == "table",
        "type=" .. type(snap.liquid))

    if snap.liquid then
        for fuelType = 0, 3 do
            local expected = FUEL_SET[fuelType]
            local actual   = snap.liquid[fuelType]
            check("W.4." .. (fuelType + 3),
                FUEL_NAME[fuelType] .. " snapshot == " .. expected,
                type(actual) == "number" and math.abs(actual - expected) < 1,
                "expected=" .. expected .. " actual=" .. tostring(actual))
        end
    end

    -- Update pack position from current transport location (in case player moved during step 2→3).
    local transport = ctld_test.getTransport()
    if transport then
        local p      = transport:getPoint()
        _G[POS_VAR] = { x = p.x, z = p.z }
        report("W.4.8 [INFO] Pack position recorded: x=" .. math.floor(p.x) .. " z=" .. math.floor(p.z))
    end

    report(
        ">>> STEP 4 DONE — Snapshot verified in crate metadata.\n"
        .. "Player actions to complete before re-injecting:\n"
        .. "  1. Take off\n"
        .. "  2. Fly to a DIFFERENT location (at least 400 m away)\n"
        .. "  3. Land\n"
        .. "  4. Re-inject this script (step 5 will run)")
    _G[STEP_VAR] = 5

-- ══════════════════════════════════════════════════════════════════════════════
-- INJECTION 5 — Verify relocation, instruct unload+unpack at new location
-- Player has: taken off, flown > 400 m away, landed
-- ══════════════════════════════════════════════════════════════════════════════
elseif step == 5 then

    local transport = ctld_test.getTransport()
    if not transport then fail("no BLUE player unit") end

    check("W.5.1", "Transport on the ground", not ctld.utils.inAir(transport),
        "inAir=" .. tostring(ctld.utils.inAir(transport)))

    local pp = _G[POS_VAR]
    if pp then
        local p    = transport:getPoint()
        local dx   = p.x - pp.x
        local dz   = p.z - pp.z
        local dist = math.sqrt(dx * dx + dz * dz)
        report("W.5.2 [INFO] Distance from pack location: " .. math.floor(dist) .. " m")
        if dist < 100 then
            fail("Transport still near pack location (" .. math.floor(dist) .. " m) — please fly > 400 m away")
        else
            pass("W.5.2 — Relocated: " .. math.floor(dist) .. " m ✓")
        end
    else
        report("W.5.2 [INFO] Pack position not recorded — relocation check skipped")
    end

    report(
        ">>> STEP 5 — Unload and deploy FARP at new location.\n"
        .. "Player actions to complete before re-injecting:\n"
        .. "  1. F10 > Crate Commands > Unload Crate\n"
        .. "  2. F10 > Crate Commands > Unpack Crate > Metal FARP\n"
        .. "  3. Wait ~15 s for the FARP scene to finish deploying\n"
        .. "  4. Re-inject this script (step 6 will run)")
    _G[STEP_VAR] = 6

-- ══════════════════════════════════════════════════════════════════════════════
-- INJECTION 6 — Verify new FARP scene active at new location
-- Player has: unloaded crate, unpacked FARP (waited ~15 s)
-- ══════════════════════════════════════════════════════════════════════════════
elseif step == 6 then

    local farpScene2 = findFarpScene()
    check("W.6.1", "New FARP scene active in CTLDSceneManager", farpScene2 ~= nil,
        "Did you unpack the FARP and wait for it to finish (~15 s)?")
    if not farpScene2 then fail("No active FARP scene found") end

    local farpName2 = farpScene2._params and farpScene2._params.farpName
    check("W.6.2", "farpName set in new scene._params", farpName2 ~= nil,
        "Mod required — without it warehouse check in step 7 will fail")
    report("W.6.2 [INFO] FARP airbase name: " .. tostring(farpName2))

    report(
        ">>> STEP 6 DONE — New FARP deployed at second location.\n"
        .. "Re-inject for final fuel level verification (step 7).")
    _G[STEP_VAR] = 7

-- ══════════════════════════════════════════════════════════════════════════════
-- INJECTION 7 — Verify warehouse fuel levels restored from snapshot
-- Expected: getLiquid(0..3) == 5000 / 10000 / 15000 / 20000
-- ══════════════════════════════════════════════════════════════════════════════
elseif step == 7 then

    local farpScene2 = findFarpScene()
    check("W.7.1", "FARP scene still active", farpScene2 ~= nil)
    if not farpScene2 then fail("Scene disappeared between step 6 and 7") end

    local farpName2 = farpScene2._params and farpScene2._params.farpName
    check("W.7.2", "farpName available from scene._params", farpName2 ~= nil,
        "Mod Farp_FG_Petit_Helipad required")
    if not farpName2 then fail("farpName nil — mod absent or step 1 of scene failed") end

    local ab = Airbase.getByName(farpName2)
    check("W.7.3", "Airbase '" .. farpName2 .. "' accessible", ab ~= nil)
    if not ab then fail("Airbase.getByName returned nil") end

    local w      = ab:getWarehouse()
    local passed = 0
    for fuelType = 0, 3 do
        local expected = FUEL_SET[fuelType]
        local actual   = w:getLiquidAmount(fuelType)
        local ok       = type(actual) == "number" and math.abs(actual - expected) < 1
        check("W.7." .. (fuelType + 4),
            FUEL_NAME[fuelType] .. " restored: expected=" .. expected .. " actual=" .. tostring(actual),
            ok,
            "delta=" .. tostring(actual and math.abs(actual - expected) or "nil"))
        if ok then passed = passed + 1 end
    end

    report("═══════════════════════════════════════")
    report("WAREHOUSE CYCLE — All steps complete")
    report("Fuel types verified: " .. passed .. "/4 PASS")
    report("Full repack/redeploy warehouse cycle validated")
    report("═══════════════════════════════════════")
    _G[STEP_VAR] = 1  -- reset for next run

else
    fail("step=" .. step .. " — no matching branch (reset _WRHSE_STEP = 1 or add elseif)")
end

end)  -- end pcall

-- ── cleanup (always executed — debug + config restored even on fail) ──────────
cfg.settings["debug"]            = _saved_debug
cfg.settings["debugScreenLog"]   = _savedDebugScreenLog

-- ── Witchcraft return value ───────────────────────────────────────────────────
if not _ok then
    trigger.action.outText(TAG .. " ❌ step=" .. step .. " FAIL", 60, true)
    return TAG .. " step=" .. step .. " FAIL: " .. tostring(_err)
end
trigger.action.outText(TAG .. " ✅ step=" .. step .. " SUCCESS", 30, true)
return TAG .. " step=" .. step .. " SUCCESS"
