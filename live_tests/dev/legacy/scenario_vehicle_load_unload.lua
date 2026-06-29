---@diagnostic disable
-- =============================================================================
-- scenarios/scenario_vehicle_load_unload.lua
-- Interactive test — GAP-1 : Load / Unload whole vehicle via F10 menu
--
-- Steps (one injection per step):
--   Step 1 — cleanup + config + Request Equipment (spawn HMMWV crate near player)
--   Step 2 — Unpack crate (spawn HMMWV vehicle) + assert registered in spawner
--   Step 3 — Simulate Load menu (findLoadableVehicles + loadVehicle)
--   Step 4 — Simulate Unload menu (findLoadedVehicles + unloadVehicle) + final report
--   Step 5 — RESET
--
-- Requires: UH-1H BLUE player slot occupied, CTLD loaded.
-- =============================================================================

-- ── DEBUG ACTIVATION ──────────────────────────────────────────────────────────
local cfg = CTLDConfig.get()
local _saved_debug = cfg.settings["debug"]
cfg.settings["debug"] = true

-- ── METADATA ──────────────────────────────────────────────────────────────────
local TAG     = "[VEH-LOAD]"
local START   = os.date("%Y-%m-%d %H:%M:%S")
local STEP_N  = "_VEH_LOAD_STEP"

-- ── HELPERS ───────────────────────────────────────────────────────────────────
local function log(msg)
    ctld.utils.log("INFO", TAG .. " " .. msg)
end
local function report(msg)
    trigger.action.outText(TAG .. " " .. msg, 50)
    log(msg)
end
local function pass(msg)
    report("[PASS] " .. msg)
end
local function fail(msg)
    trigger.action.outText(TAG .. " !! FAIL: " .. msg, 60)
    log("FAIL: " .. msg)
    error(msg)
end
local function check(id, desc, condition, details)
    if condition then
        pass(id .. " — " .. desc)
    else
        fail(id .. " — " .. desc .. (details and (" | " .. details) or ""))
    end
end
local function assert_eq(id, actual, expected)
    check(id, "eq", actual == expected,
        "expected=" .. tostring(expected) .. " actual=" .. tostring(actual))
end

-- ── CONSTANTS ─────────────────────────────────────────────────────────────────
local HMMWV_TYPE  = "M1043 HMMWV Armament"
local CRATE_GROUP = "SCN_VEH_CRATE_HMMWV"
local VEH_GROUP   = "SCN_VEH_HMMWV"

-- ── RESOLVE PLAYER ────────────────────────────────────────────────────────────
local playerUnit = nil
do
    local units = coalition.getPlayers(coalition.side.BLUE) or {}
    if #units > 0 then playerUnit = units[1] end
end
if not playerUnit or not playerUnit:isExist() then
    cfg.settings["debug"] = _saved_debug
    return TAG .. " ABORT: no BLUE player — occupy a slot first"
end
local playerName = playerUnit:getName()
local pPos       = playerUnit:getPoint()

-- ── INTERNAL HELPERS ──────────────────────────────────────────────────────────
local function destroyGroup(name)
    local g = Group.getByName(name)
    if g and g:isExist() then g:destroy() end
end

local function cleanupAll()
    destroyGroup(CRATE_GROUP)
    destroyGroup(VEH_GROUP)
    local grps = coalition.getGroups(coalition.side.BLUE, Group.Category.GROUND) or {}
    for _, g in ipairs(grps) do
        if g and g:isExist() then g:destroy() end
    end
    local spawner = CTLDVehicleSpawner.getInstance()
    for id, v in pairs(spawner._vehicles) do
        if v.vehicleType == HMMWV_TYPE then
            if v.spawnData then
                spawner._unitToVehicle[v.spawnData.unitName] = nil
            end
            spawner._vehicles[id] = nil
        end
    end
    log("cleanup done")
end

local function findRegisteredHmmwv()
    local spawner = CTLDVehicleSpawner.getInstance()
    for _, v in pairs(spawner._vehicles) do
        if v.vehicleType == HMMWV_TYPE then return v end
    end
    return nil
end

-- ── STATE MACHINE ─────────────────────────────────────────────────────────────
_G[STEP_N] = _G[STEP_N] or 1
local step = _G[STEP_N]

report("==== START " .. START .. " | step=" .. step .. " ====")

local _result = "INCOMPLETE"
local _ok, _err = pcall(function()

-- ══════════════════════════════════════════════════════════════════════════════
-- STEP 1 — Cleanup + config + spawn HMMWV crate near player
-- ══════════════════════════════════════════════════════════════════════════════
if step == 1 then

    cleanupAll()

    local cfgS = CTLDConfig.get().settings
    cfgS["vehicleTransportEnabled"] = { "UH-1H", "Mi-8", "Hercules", "76MD", "C-130J-30" }
    report("Config: UH-1H added to vehicleTransportEnabled.")

    local cratePos = { x = pPos.x + 30, y = land.getHeight({x=pPos.x+30, y=pPos.z}), z = pPos.z }
    local mgr = CTLDCrateManager.getInstance()
    local desc = mgr:findDescriptorByUnitType(HMMWV_TYPE)
    if not desc then
        fail("No descriptor found for " .. HMMWV_TYPE .. " — check spawnableCrates config")
    end

    mgr:spawnCrate(desc, cratePos, coalition.side.BLUE, playerName, "request_equipment")

    pass("Step 1 — HMMWV crate spawned 30m ahead. Re-inject for Step 2 (Unpack).")
    _G[STEP_N] = 2
    _result = "step=1 SUCCESS"

-- ══════════════════════════════════════════════════════════════════════════════
-- STEP 2 — Unpack crate → HMMWV vehicle spawned + registered in CTLDVehicleSpawner
-- ══════════════════════════════════════════════════════════════════════════════
elseif step == 2 then

    local mgr     = CTLDCrateManager.getInstance()
    local spawner = CTLDVehicleSpawner.getInstance()

    local nearby = mgr:getCratesInRange(pPos, 200)
    local targetCrate = nil
    for _, c in ipairs(nearby) do
        if c.descriptor and c.descriptor.unit == HMMWV_TYPE and c:isOnGround() then
            targetCrate = c; break
        end
    end
    if not targetCrate then
        fail("No HMMWV crate found within 200m — did Step 1 succeed?")
    end

    local beforeCount = 0
    for _ in pairs(spawner._vehicles) do beforeCount = beforeCount + 1 end

    local spawnPos  = { x = pPos.x + 50, y = land.getHeight({x=pPos.x+50, y=pPos.z+10}), z = pPos.z + 10 }
    local crateDesc = targetCrate.descriptor
    mgr:unpackCrate(targetCrate.crateName, playerUnit)
    mgr:_spawnUnpacked(crateDesc, spawnPos, coalition.side.BLUE, country.id.USA)

    local afterCount = 0
    for _ in pairs(spawner._vehicles) do afterCount = afterCount + 1 end

    check("F-GAP1.2", "HMMWV registered in spawner", afterCount > beforeCount,
        "before=" .. beforeCount .. " after=" .. afterCount)

    local v = findRegisteredHmmwv()
    check("F-GAP1.2b", "HMMWV found in spawner._vehicles", v ~= nil, "got nil")

    pass(string.format("Step 2 — HMMWV unpacked (id=%s, state=%s). Re-inject for Step 3 (Load).",
        v and v.id or "?", v and v:getState() or "?"))
    _G[STEP_N] = 3
    _result = "step=2 SUCCESS"

-- ══════════════════════════════════════════════════════════════════════════════
-- STEP 3 — Simulate Load menu : findLoadableVehicles → loadVehicle
-- ══════════════════════════════════════════════════════════════════════════════
elseif step == 3 then

    local spawner = CTLDVehicleSpawner.getInstance()

    local loadable = spawner:findLoadableVehicles(playerUnit)
    check("F-GAP1.3", "findLoadableVehicles non-empty", #loadable > 0,
        "count=" .. #loadable)

    local veh = nil
    for _, v in ipairs(loadable) do
        if v.vehicleType == HMMWV_TYPE then veh = v; break end
    end
    if not veh then
        fail("HMMWV not in loadable list — found " .. #loadable .. " other vehicle(s)")
    end

    report(string.format("findLoadableVehicles: %d vehicle(s), HMMWV id=%s", #loadable, veh.id))

    spawner:loadVehicle(veh, playerUnit, playerName, "menu_ctld")

    assert_eq("F-GAP1.3b", veh:getState(), CTLDVehicle.STATE.LOADED)

    pass(string.format("Step 3 — HMMWV id=%s loaded into %s. Re-inject for Step 4 (Unload).",
        veh.id, playerName))
    _G[STEP_N] = 4
    _result = "step=3 SUCCESS"

-- ══════════════════════════════════════════════════════════════════════════════
-- STEP 4 — Simulate Unload menu : findLoadedVehicles → unloadVehicle
-- ══════════════════════════════════════════════════════════════════════════════
elseif step == 4 then

    local spawner = CTLDVehicleSpawner.getInstance()

    local onboard = spawner:findLoadedVehicles(playerUnit)
    check("F-GAP1.4", "findLoadedVehicles non-empty", #onboard > 0,
        "count=" .. #onboard)

    local veh = nil
    for _, v in ipairs(onboard) do
        if v.vehicleType == HMMWV_TYPE then veh = v; break end
    end
    if not veh then
        fail("HMMWV not in onboard list — found " .. #onboard .. " other vehicle(s)")
    end

    report(string.format("findLoadedVehicles: %d onboard, HMMWV id=%s", #onboard, veh.id))

    spawner:unloadVehicle(veh, playerUnit, playerName, "menu_ctld")

    assert_eq("F-GAP1.4b", veh:getState(), CTLDVehicle.STATE.WAITING)

    local stillOnboard = spawner:findLoadedVehicles(playerUnit)
    local stillFound = false
    for _, v in ipairs(stillOnboard) do
        if v.id == veh.id then stillFound = true end
    end
    check("F-GAP1.4c", "HMMWV not in onboard list after unload", not stillFound)

    pass(string.format("Step 4 — HMMWV id=%s unloaded (state=WAITING, no longer in onboard list).", veh.id))
    report("=== SCENARIO COMPLETE — all 4 steps PASS. Re-inject for RESET. ===")
    _G[STEP_N] = 5
    _result = "step=4 SUCCESS"

-- ══════════════════════════════════════════════════════════════════════════════
-- STEP 5 — RESET
-- ══════════════════════════════════════════════════════════════════════════════
elseif step >= 5 then

    cleanupAll()
    _G[STEP_N] = 1
    report("RESET — all test objects removed. Re-inject to start from Step 1.")
    _result = "RESET"

else
    fail("step=" .. step .. " has no matching branch")
end

end)  -- end pcall

-- ── CLEANUP (debug always restored) ───────────────────────────────────────────
cfg.settings["debug"] = _saved_debug

if not _ok then
    return TAG .. " step=" .. step .. " FAIL: " .. tostring(_err)
end
return TAG .. " " .. _result
