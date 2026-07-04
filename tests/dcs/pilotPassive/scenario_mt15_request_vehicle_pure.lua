---@diagnostic disable
-- =============================================================================
-- MT-15 : Request Vehicle pur — full spawn / load / unload cycle
-- =============================================================================
-- Tests the "Request Vehicle" F10 path (spawnAsVehicle=true branch) end-to-end:
--   spawnVehicleForTransport → loadVehicle → unloadVehicle
-- No crate is spawned or unpacked — this is the pure whole-vehicle transport flow.
--
-- Steps:
--   Step 1 — Cleanup + configure capabilitiesByType (UH-1H canTransportWholeVehicle=true,
--             loadableVehiclesBLUE={"M1043 HMMWV Armament"})
--   Step 2 — spawnVehicleForTransport → assert CTLDVehicle in WAITING + DCS unit alive
--   Step 3 — findLoadableVehicles → assert HMMWV found; loadVehicle → assert LOADED
--   Step 4 — findLoadedVehicles → assert HMMWV found; unloadVehicle → assert WAITING,
--             DCS unit re-spawned on map
--   Step 5 — Final report + config restore
--
-- Prerequisites:
--   - UH-1H BLUE slot "Batumi_UH-1H_0-1" occupied AND on the ground
--   - CTLD_Next.lua injected (wait ≥3 s before injecting this script)
--   - ctldLogPath set in .miz MISSION START trigger (private, not committed)
--   - Witchcraft bridge running
-- =============================================================================

-- ── DEBUG ACTIVATION ──────────────────────────────────────────────────────────

-- ── Witchcraft guard ────────────────────────────────────────────────
if not ctld or not ctld.utils then
    trigger.action.outText("[MT-15] ABORT: CTLD not initialized. Inject CTLD_Next.lua first.", 15)
    return Witchcraft
end
local cfg = CTLDConfig.get()
local _saved_debug = cfg.settings["debug"]
local _savedDebugScreenLog = cfg.settings["debugScreenLog"]
cfg.settings["debug"] = true
cfg.settings["debugScreenLog"] = false

-- ── METADATA ──────────────────────────────────────────────────────────────────
local TAG    = "[MT-15]"
local START  = os.date("%Y-%m-%d %H:%M:%S")
local STEP_N = "_MT15_STEP"

-- ── HELPERS ───────────────────────────────────────────────────────────────────
local function log(msg)
    ctld.utils.log("INFO", TAG .. " " .. msg)
end
local function report(msg)
    trigger.action.outText(TAG .. " " .. msg, 30)
    log(msg)
end
local function pass(msg)
    report("[PASS] " .. msg)
end
local function fail(msg)
    local trace = debug.traceback(msg, 2)
    trigger.action.outText(TAG .. " !! FAIL: " .. msg, 60)
    log("FAIL: " .. trace)
    error(msg)
end
local function check(id, desc, cond, details)
    if cond then
        pass(id .. " — " .. desc)
    else
        fail(id .. " — " .. desc .. (details and (" | " .. details) or ""))
    end
end
local function assert_eq(id, actual, expected)
    check(id, "eq", actual == expected,
        "expected=" .. tostring(expected) .. " actual=" .. tostring(actual))
end
local function assert_not_nil(id, val, desc)
    check(id, desc or "not nil", val ~= nil, "got nil")
end

-- ── CONSTANTS ─────────────────────────────────────────────────────────────────
local HMMWV_TYPE   = "M1043 HMMWV Armament"
local PLAYER_SLOT  = "Batumi_UH-1H_0-1"

-- ── CONFIG SAVED / RESTORED ───────────────────────────────────────────────────
-- Saved at step 1, restored at step 5.
-- Keys stored in global so they persist across injections.
local _CFG_SAVED_KEY = "_MT15_saved_caps"

-- ── STATE MACHINE ─────────────────────────────────────────────────────────────
_G[STEP_N] = _G[STEP_N] or 1
local step = _G[STEP_N]

report(string.format("==== START %s | step=%d ====", START, step))

-- P1 — Truncate CTLD.log at step 1 for a clean run
if step == 1 then
    pcall(function()
        ctld.utils.closeLog()
        local f = io.open((cfg.settings["ctldLogPath"] or "") .. "CTLD.log", "w")
        if f then
            f:write("[" .. START .. "] === MT-15 LOG RESET ===\n")
            f:close()
        end
        ctld.utils.reopenLogAppend()
    end)
end

local _step_start = os.clock()
local _result     = "INCOMPLETE"

local _ok, _err = pcall(function()

-- ══════════════════════════════════════════════════════════════════════════════
-- STEP 1 — Cleanup + configure capabilitiesByType
-- Expected: all prior MT-15 vehicles destroyed; UH-1H configured for whole-vehicle transport
-- ══════════════════════════════════════════════════════════════════════════════
if step == 1 then

    -- Destroy any leftover MT-15 HMMWV groups from previous runs
    local vs = CTLDVehicleSpawner.getInstance()
    for id, veh in pairs(vs._vehicles) do
        if veh.vehicleType == HMMWV_TYPE then
            if veh.unit and veh.unit:isExist() then
                local g = veh.unit:getGroup()
                if g then pcall(function() g:destroy() end) end
            end
            if veh.spawnData then
                vs._unitToVehicle[veh.spawnData.unitName] = nil
            end
            vs._vehicles[id] = nil
        end
    end

    -- Save current capabilitiesByType for restoration at step 5
    _G[_CFG_SAVED_KEY] = cfg.settings["capabilitiesByType"]

    -- Configure UH-1H for whole-vehicle transport with HMMWV allowed
    local caps = {}
    for k, v in pairs(_G[_CFG_SAVED_KEY] or {}) do caps[k] = v end
    caps["UH-1H"] = {
        cratesEnabled             = true,
        canTransportWholeVehicle  = true,
        maxWholeVehiclesOnboard   = 1,
        loadableVehiclesBLUE      = { HMMWV_TYPE },
        loadableVehiclesRED       = {},
    }
    cfg.settings["capabilitiesByType"]               = caps
    cfg.settings["maximumDistancePackableUnitsSearch"] = 300

    pass("Step 1 — Cleanup OK, UH-1H configured (canTransportWholeVehicle=true, HMMWV loadable). Re-inject for Step 2.")
    _G[STEP_N] = 2
    _result = "step=1 SUCCESS"

-- ══════════════════════════════════════════════════════════════════════════════
-- STEP 2 — spawnVehicleForTransport
-- Expected: CTLDVehicle created in WAITING state, DCS unit alive on map
-- ══════════════════════════════════════════════════════════════════════════════
elseif step == 2 then

    -- Resolve player transport
    local playerUnit = Unit.getByName(PLAYER_SLOT)
    if not playerUnit or not playerUnit:isExist() then
        fail("Unit '" .. PLAYER_SLOT .. "' not found — occupy the UH-1H slot first")
    end

    local vs      = CTLDVehicleSpawner.getInstance()
    local vehicle = vs:spawnVehicleForTransport(HMMWV_TYPE, playerUnit, nil)

    assert_not_nil("MT-15.2.1", vehicle, "CTLDVehicle returned by spawnVehicleForTransport")
    if not vehicle then fail("spawnVehicleForTransport returned nil") end

    assert_eq("MT-15.2.2", vehicle:getState(), CTLDVehicle.STATE.WAITING)

    -- DCS unit must be alive on map
    local dcsUnit = vehicle.unit
    check("MT-15.2.3", "DCS unit exists and isExist",
        dcsUnit ~= nil and dcsUnit:isExist(), tostring(dcsUnit))

    -- vehicleType recorded correctly
    assert_eq("MT-15.2.4", vehicle.vehicleType, HMMWV_TYPE)

    -- Persist vehicle id for next steps
    _G["_MT15_VEH_ID"] = vehicle.id

    pass("Step 2 — HMMWV spawned id=" .. vehicle.id .. " WAITING. Re-inject for Step 3 (Load).")
    _G[STEP_N] = 3
    _result = "step=2 SUCCESS"

-- ══════════════════════════════════════════════════════════════════════════════
-- STEP 3 — findLoadableVehicles → loadVehicle
-- Expected: HMMWV found in range; after loadVehicle → state=LOADED, DCS unit gone
-- ══════════════════════════════════════════════════════════════════════════════
elseif step == 3 then

    local playerUnit = Unit.getByName(PLAYER_SLOT)
    if not playerUnit or not playerUnit:isExist() then
        fail("Unit '" .. PLAYER_SLOT .. "' not found")
    end

    local vs       = CTLDVehicleSpawner.getInstance()
    local loadable = vs:findLoadableVehicles(playerUnit)

    check("MT-15.3.1", "findLoadableVehicles returns ≥1 vehicle", #loadable >= 1,
        "got " .. tostring(#loadable))

    -- Locate our specific HMMWV in the list
    local vehId = _G["_MT15_VEH_ID"]
    local targetVeh = nil
    for _, v in ipairs(loadable) do
        if v.id == vehId then targetVeh = v; break end
    end
    assert_not_nil("MT-15.3.2", targetVeh, "our HMMWV (id=" .. tostring(vehId) .. ") in loadable list")
    if not targetVeh then fail("HMMWV not found in loadable list") end

    -- Load the vehicle
    vs:loadVehicle(targetVeh, playerUnit, playerUnit:getName(), "menu_ctld")

    assert_eq("MT-15.3.3", targetVeh:getState(), CTLDVehicle.STATE.LOADED)

    -- DCS unit must be gone from map (destroyed on load)
    local dcsUnit = targetVeh.unit
    check("MT-15.3.4", "DCS unit no longer exists after load",
        dcsUnit == nil or not dcsUnit:isExist(), "unit still exists")

    -- Vehicle must be linked to this transport
    assert_eq("MT-15.3.5", targetVeh.loadTransportName, playerUnit:getName())

    pass("Step 3 — HMMWV loaded (LOADED state, DCS unit gone). Re-inject for Step 4 (Unload).")
    _G[STEP_N] = 4
    _result = "step=3 SUCCESS"

-- ══════════════════════════════════════════════════════════════════════════════
-- STEP 4 — findLoadedVehicles → unloadVehicle
-- Expected: HMMWV found as loaded; after unloadVehicle → state=WAITING, DCS unit back
-- ══════════════════════════════════════════════════════════════════════════════
elseif step == 4 then

    local playerUnit = Unit.getByName(PLAYER_SLOT)
    if not playerUnit or not playerUnit:isExist() then
        fail("Unit '" .. PLAYER_SLOT .. "' not found")
    end

    local vs     = CTLDVehicleSpawner.getInstance()
    local loaded = vs:findLoadedVehicles(playerUnit)

    check("MT-15.4.1", "findLoadedVehicles returns ≥1 vehicle", #loaded >= 1,
        "got " .. tostring(#loaded))

    local vehId = _G["_MT15_VEH_ID"]
    local targetVeh = nil
    for _, v in ipairs(loaded) do
        if v.id == vehId then targetVeh = v; break end
    end
    assert_not_nil("MT-15.4.2", targetVeh, "our HMMWV (id=" .. tostring(vehId) .. ") in loaded list")
    if not targetVeh then fail("HMMWV not found in loaded list") end

    -- Unload the vehicle
    vs:unloadVehicle(targetVeh, playerUnit, playerUnit:getName(), "menu_ctld", false)

    assert_eq("MT-15.4.3", targetVeh:getState(), CTLDVehicle.STATE.WAITING)

    -- DCS unit must be back on map
    local dcsUnit = targetVeh.unit
    check("MT-15.4.4", "DCS unit re-spawned after unload",
        dcsUnit ~= nil and dcsUnit:isExist(), tostring(dcsUnit))

    pass("Step 4 — HMMWV unloaded (WAITING state, DCS unit back). Re-inject for Step 5 (Report).")
    _G[STEP_N] = 5
    _result = "step=4 SUCCESS"

-- ══════════════════════════════════════════════════════════════════════════════
-- STEP 5 — Final report + config restore
-- ══════════════════════════════════════════════════════════════════════════════
elseif step == 5 then

    -- Restore capabilitiesByType to saved value
    if _G[_CFG_SAVED_KEY] ~= nil then
        cfg.settings["capabilitiesByType"] = _G[_CFG_SAVED_KEY]
        _G[_CFG_SAVED_KEY] = nil
    end
    _G["_MT15_VEH_ID"] = nil

    report("═══════════════════════════════════════")
    report("MT-15 — All steps PASS")
    report("  MT-15.2.1/2/3/4 : spawnVehicleForTransport OK")
    report("  MT-15.3.1/2/3/4/5 : findLoadableVehicles + loadVehicle OK")
    report("  MT-15.4.1/2/3/4   : findLoadedVehicles + unloadVehicle OK")
    report("═══════════════════════════════════════")

    _G[STEP_N] = 1  -- reset for next run
    _result = "ALL SUCCESS"

else
    fail("step=" .. step .. " has no matching branch — reset with _G['" .. STEP_N .. "']=1")
end

end)  -- end pcall

-- ── CLEANUP (always executed) ─────────────────────────────────────────────────
cfg.settings["debug"] = _saved_debug
cfg.settings["debugScreenLog"] = _savedDebugScreenLog

-- ── WITCHCRAFT RETURN VALUE ───────────────────────────────────────────────────
local _ms = math.floor((os.clock() - _step_start) * 1000)
if not _ok then
    trigger.action.outText(TAG .. " ❌ step=" .. step .. " FAIL", 60, true)
    return TAG .. " step=" .. step .. " FAIL: " .. tostring(_err)
end
if _result == "ALL SUCCESS" then
    trigger.action.outText(TAG .. " ✅ ALL SUCCESS (" .. _ms .. "ms)", 30, true)
    return TAG .. " " .. _result .. " (" .. _ms .. "ms)"
end
return TAG .. " " .. _result:gsub("SUCCESS", "SUCCESS (" .. _ms .. "ms)")
