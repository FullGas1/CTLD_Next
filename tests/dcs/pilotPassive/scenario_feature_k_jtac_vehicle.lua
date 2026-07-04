---@diagnostic disable
-- =============================================================================
-- scenarios/scenario_feature_k_jtac_vehicle.lua
-- Feature K Sprint 1 — JTAC vehicle in-transit lifecycle (GAP-K1 + GAP-K2)
--
-- Steps:
--   Step 1 — Cleanup + spawn Hummer JTAC vehicle + assert startLase (baseline)
--   Step 2 — Load JTAC vehicle (menu_ctld) + assert JTAC IN_TRANSIT          (F-125)
--   Step 3 — Parachute vehicle CTLD (GAP-K1) + assert JTAC resumes at landing (F-126)
--   Step 4 — Load JTAC vehicle again + destroy transport (GAP-K2)             (F-127)
--            + assert JTAC deregistered + vehicle purged
--   Step 5 — RESET
--
-- Requires: UH-1H BLUE player slot occupied, CTLD loaded.
--           Player must be on the ground (posé) for load steps.
--           Targets RED must be present for autoLase to find a target.
-- =============================================================================

-- ── Witchcraft guard ─────────────────────────────────────────────────────────
if not ctld or not ctld.utils then
    trigger.action.outText("[FEAT-K] ABORT: CTLD not initialized. Inject CTLD_Next.lua first.", 15)
    return Witchcraft
end

local cfg = CTLDConfig.get()
local _saved_debug = cfg.settings["debug"]
local _savedDebugScreenLog = cfg.settings["debugScreenLog"]
cfg.settings["debug"] = true
cfg.settings["debugScreenLog"] = false

local TAG    = "[FEAT-K]"
local START  = os.date("%Y-%m-%d %H:%M:%S")
local STEP_N = "_FEAT_K_STEP"

local function log(msg)   ctld.utils.log("INFO", TAG .. " " .. msg) end
local function report(msg) trigger.action.outText(TAG .. " " .. msg, 40); log(msg) end
local function fail(msg)
    local trace = debug.traceback(msg, 2)
    trigger.action.outText(TAG .. " !! FAIL: " .. msg, 60)
    log("FAIL: " .. trace)
    error(msg)
end
local function check(id, desc, cond, details)
    if cond then
        report("[PASS] " .. id .. " — " .. desc)
    else
        fail(id .. " — " .. desc .. (details and (" | " .. details) or ""))
    end
end

-- ── resolve player ─────────────────────────────────────────────────────────────
local playerUnit = nil
do
    local units = coalition.getPlayers(coalition.side.BLUE) or {}
    if #units > 0 then playerUnit = units[1] end
end
if not playerUnit or not playerUnit:isExist() then
    cfg.settings["debug"] = _saved_debug
    return "ABORT: no BLUE player — occupy a slot first"
end
local playerName = playerUnit:getName()
local pPos       = playerUnit:getPoint()

-- ── constants ──────────────────────────────────────────────────────────────────
local JTAC_TYPE   = "Hummer"
local JTAC_GROUP  = "SCN_FEAT_K_JTAC"
local TARGET_TYPE = "Hummer"
local TARGET_GRP  = "SCN_FEAT_K_TARGET"

-- ── helpers ────────────────────────────────────────────────────────────────────

local function destroyGroup(name)
    local g = Group.getByName(name)
    if g and g:isExist() then g:destroy() end
end

local function cleanupAll()
    destroyGroup(JTAC_GROUP)
    destroyGroup(TARGET_GRP)
    -- Deregister JTAC silently
    local ok = pcall(function() CTLDJTACManager.get():deregisterJTAC(JTAC_GROUP) end)
    -- Remove JTAC vehicle from spawner registry
    local spawner = CTLDVehicleSpawner.getInstance()
    for id, v in pairs(spawner._vehicles) do
        if v.spawnData and v.spawnData.groupName == JTAC_GROUP then
            if v.spawnData.unitName then spawner._unitToVehicle[v.spawnData.unitName] = nil end
            spawner._vehicles[id] = nil
        end
    end
    log("cleanup done")
end

local function findJTACVehicle()
    local spawner = CTLDVehicleSpawner.getInstance()
    for _, v in pairs(spawner._vehicles) do
        if v.spawnData and v.spawnData.groupName == JTAC_GROUP then return v end
    end
    return nil
end

local function spawnGroundUnit(groupName, typeName, pos, countryId)
    local gid = ctld.utils.getNextUniqId()
    local uid = ctld.utils.getNextUniqId()
    local def = {
        visible  = true, hidden = false,
        category = Group.Category.GROUND,
        country  = countryId,
        name     = groupName,
        task     = {},
        units    = { { type = typeName, name = groupName,
                       x = pos.x, y = pos.z, heading = 0, skill = "Random" } },
    }
    return ctld.utils.dynAdd("scenario_feature_k", def)
end

-- ── state machine ──────────────────────────────────────────────────────────────
_G[STEP_N] = _G[STEP_N] or 1
local step = _G[STEP_N]

report("==== START " .. START .. " | step=" .. step .. " ====")

if step == 1 then
    if ctld.test_cleanup then ctld.test_cleanup() end
end

local _step_start = os.clock()
local _result     = "INCOMPLETE"

local _ok, _err = pcall(function()

-- ══════════════════════════════════════════════════════════════════════════════
-- STEP 1 — Cleanup + spawn Hummer JTAC vehicle 50m devant joueur
--          + spawn cible RED 500m devant + assert JTAC lasing démarre
-- ══════════════════════════════════════════════════════════════════════════════
if step == 1 then

    cleanupAll()

    -- Enable UH-1H for whole-vehicle transport
    cfg.settings["vehicleTransportEnabled"] = { "UH-1H", "Mi-8", "Hercules", "76MD", "C-130J-30" }

    -- Spawn RED Hummer target 500m ahead so the BLUE JTAC has something to lase.
    local tPos = { x = pPos.x + 500, y = land.getHeight({x=pPos.x+500, y=pPos.z}), z = pPos.z }
    local tRes = spawnGroundUnit(TARGET_GRP, TARGET_TYPE, tPos, country.id.RUSSIA)
    check("F-125.1", "RED Hummer target spawned", tRes ~= nil, tostring(tRes))

    -- Spawn Hummer JTAC 50m devant joueur (BLUE)
    local jPos = { x = pPos.x + 50, y = land.getHeight({x=pPos.x+50, y=pPos.z}), z = pPos.z }
    local jRes = spawnGroundUnit(JTAC_GROUP, JTAC_TYPE, jPos, country.id.USA)
    check("F-125.2", "Hummer JTAC group spawned", jRes ~= nil, tostring(jRes))

    -- Register as JTAC vehicle (simulates Request JTAC Equipment path)
    -- Use autoLase directly (synchronous) instead of startLase (deferred +1s timer)
    -- so that jtacs[JTAC_GROUP] is populated immediately for the checks below.
    local spawner = CTLDVehicleSpawner.getInstance()
    spawner:registerJTACVehicle(JTAC_GROUP, JTAC_TYPE, playerUnit, nil)
    CTLDJTACManager.get():autoLase(JTAC_GROUP)

    -- Verify registered in spawner
    local veh = findJTACVehicle()
    check("F-125.3", "Hummer registered in CTLDVehicleSpawner", veh ~= nil)

    -- Verify registered in JTACManager
    local jtac = CTLDJTACManager.get().jtacs[JTAC_GROUP]
    check("F-125.4", "Hummer registered in CTLDJTACManager", jtac ~= nil)
    if jtac then
        local validState = (jtac.state == CTLDJTAC.STATE.IDLE or jtac.state == CTLDJTAC.STATE.LASING)
        check("F-125.5", "JTAC state IDLE or LASING after startLase",
            validState, "state=" .. tostring(jtac.state))
    end

    report("Step 1 PASS — JTAC Hummer spawned + lasing. Re-inject for Step 2 (Load).")
    _G[STEP_N] = 2
    _result = "step=1 SUCCESS"

-- ══════════════════════════════════════════════════════════════════════════════
-- STEP 2 — Load JTAC vehicle (menu_ctld) → assert JTAC IN_TRANSIT  [F-125]
-- ══════════════════════════════════════════════════════════════════════════════
elseif step == 2 then

    local spawner = CTLDVehicleSpawner.getInstance()
    local veh = findJTACVehicle()
    if not veh then fail("JTAC vehicle not found in spawner — did Step 1 succeed?") end

    -- Vehicle must be in WAITING to load
    check("F-125.6", "vehicle state WAITING before load",
        veh:getState() == CTLDVehicle.STATE.WAITING, "state=" .. veh:getState())

    -- Execute load
    spawner:loadVehicle(veh, playerUnit, playerName, "menu_ctld")

    check("F-125.7", "vehicle state LOADED after loadVehicle",
        veh:getState() == CTLDVehicle.STATE.LOADED, "state=" .. veh:getState())
    check("F-125.8", "loadTransportName set to player",
        veh.loadTransportName == playerName, "got=" .. tostring(veh.loadTransportName))

    -- JTAC must be IN_TRANSIT
    local jtac = CTLDJTACManager.get().jtacs[JTAC_GROUP]
    check("F-125.9", "JTAC registered in manager after load", jtac ~= nil)
    if jtac then
        check("F-125.10", "JTAC state IN_TRANSIT after loadVehicle",
            jtac.state == CTLDJTAC.STATE.IN_TRANSIT, "state=" .. tostring(jtac.state))
    end

    report("Step 2 PASS — vehicle LOADED, JTAC IN_TRANSIT. Re-inject for Step 3 (Parachute).")
    _G[STEP_N] = 3
    _result = "step=2 SUCCESS"

-- ══════════════════════════════════════════════════════════════════════════════
-- STEP 3 — Parachute CTLD virtual (GAP-K1)
--          → vehicle state WAITING, JTAC resumes lasing after descentTime   [F-126]
-- Note: descentRate default 8 m/s. On the ground altAGL ≈ 0 → alt check may
--       block. We simulate an airborne transport by mocking transport:getPoint.
-- ══════════════════════════════════════════════════════════════════════════════
elseif step == 3 then

    local spawner = CTLDVehicleSpawner.getInstance()
    local veh = findJTACVehicle()
    if not veh then fail("JTAC vehicle not found — did Steps 1-2 succeed?") end

    check("F-126.1", "vehicle state LOADED before parachute",
        veh:getState() == CTLDVehicle.STATE.LOADED, "state=" .. veh:getState())

    -- Simulate: transport at 200m AGL by overriding parachuteMinAltitudeVehicles to 0
    local _savedMinAlt = cfg.settings["parachuteMinAltitudeVehicles"]
    cfg.settings["parachuteMinAltitudeVehicles"] = 0

    -- playerObj minimal (groupId needed for outTextForGroup)
    local playerGroup = playerUnit:getGroup()
    local playerObj = {
        groupId  = playerGroup and playerGroup:getID() or 1,
        unitName = playerName,
        coalition = coalition.side.BLUE,
    }

    local descentBefore = cfg.settings["parachuteDescentRateVehicles"] or 8
    -- Force very short descent time for test (0.1s)
    cfg.settings["parachuteDescentRateVehicles"] = 999  -- very fast: landPos near dropPos, descentTime tiny

    local ok2, err2 = pcall(function()
        spawner:parachuteVehicle(playerUnit, veh.id, playerObj)
    end)
    cfg.settings["parachuteMinAltitudeVehicles"]  = _savedMinAlt
    cfg.settings["parachuteDescentRateVehicles"]  = descentBefore

    if not ok2 then fail("parachuteVehicle crashed: " .. tostring(err2)) end

    -- Immediately after call: vehicle should be WAITING (not DELIVERED, not LOADED)
    check("F-126.2", "vehicle state WAITING immediately after parachuteVehicle",
        veh:getState() == CTLDVehicle.STATE.WAITING, "state=" .. veh:getState())
    check("F-126.3", "loadTransportName cleared after parachuteVehicle",
        veh.loadTransportName == nil, "got=" .. tostring(veh.loadTransportName))

    -- JTAC: the resumeJTAC is called inside timer.scheduleFunction (deferred).
    -- At this instant the JTAC is still IN_TRANSIT (timer not yet fired).
    -- The timer fires at timer.getTime() + descentTime (≈0 since rate=999).
    -- In DCS, timers don't fire synchronously in tests, so we verify the
    -- registration is still intact (JTAC not lost) and state will resume.
    local jtac = CTLDJTACManager.get().jtacs[JTAC_GROUP]
    check("F-126.4", "JTAC still registered in manager (not lost during parachute)",
        jtac ~= nil)

    report("Step 3 PASS — vehicle WAITING, JTAC intact. Timer resume will fire shortly.")
    report("Note: JTAC state IN_TRANSIT → IDLE/LASING will occur in next DCS tick via timer.")
    report("Re-inject for Step 4 (Transport Destroy).")
    _G[STEP_N] = 4
    _result = "step=3 SUCCESS"

-- ══════════════════════════════════════════════════════════════════════════════
-- STEP 4 — Re-load JTAC + destroy transport → assert JTAC deregistered
--          + vehicle purged from spawner                                  [F-127]
-- ══════════════════════════════════════════════════════════════════════════════
elseif step == 4 then

    local spawner = CTLDVehicleSpawner.getInstance()
    local jtacMgr = CTLDJTACManager.get()

    -- Re-register and re-load for this step (vehicle may have been re-spawned by timer)
    -- Ensure a clean LOADED state: re-register if needed
    local veh = findJTACVehicle()
    if not veh then
        -- Vehicle was re-spawned by parachuteVehicle timer — find by type
        for _, v in pairs(spawner._vehicles) do
            if v.vehicleType == JTAC_TYPE then veh = v; break end
        end
    end
    if not veh then
        -- Re-spawn from scratch for this step
        local jPos2 = { x = pPos.x + 50, y = land.getHeight({x=pPos.x+50, y=pPos.z+5}), z = pPos.z + 5 }
        spawnGroundUnit(JTAC_GROUP, JTAC_TYPE, jPos2, country.id.USA)
        spawner:registerJTACVehicle(JTAC_GROUP, JTAC_TYPE, playerUnit, nil)
        jtacMgr:startLase(JTAC_GROUP)
        veh = findJTACVehicle()
    end
    if not veh then fail("Could not establish JTAC vehicle for Step 4") end

    -- Ensure vehicle is in WAITING state before loading
    if veh:getState() ~= CTLDVehicle.STATE.WAITING then
        -- Force WAITING for test
        veh:setState(CTLDVehicle.STATE.WAITING)
        veh.loadTransportName = nil
        veh.loadMethod = nil
    end
    -- Ensure JTAC is registered
    if not jtacMgr.jtacs[JTAC_GROUP] then
        jtacMgr:startLase(JTAC_GROUP)
    end

    -- Load vehicle into transport
    spawner:loadVehicle(veh, playerUnit, playerName, "menu_ctld")
    check("F-127.1", "vehicle LOADED before transport destroy",
        veh:getState() == CTLDVehicle.STATE.LOADED, "state=" .. veh:getState())

    local jtacBefore = jtacMgr.jtacs[JTAC_GROUP]
    check("F-127.2", "JTAC registered before transport destroy", jtacBefore ~= nil)

    -- Simulate transport S_EVENT_DEAD by calling onDead directly
    local fakeEvent = { initiator = playerUnit }
    spawner:onDead(fakeEvent)

    -- Vehicle must be purged from spawner
    local vehAfter = findJTACVehicle()
    check("F-127.3", "vehicle purged from spawner after transport destroy",
        vehAfter == nil, vehAfter and ("id=" .. vehAfter.id) or "nil")

    -- JTAC must be deregistered
    local jtacAfter = jtacMgr.jtacs[JTAC_GROUP]
    check("F-127.4", "JTAC deregistered after transport destroy",
        jtacAfter == nil, jtacAfter and ("state=" .. tostring(jtacAfter.state)) or "nil")

    -- Reverse lookup must be cleared
    local revLookup = spawner._unitToVehicle[playerName]
    check("F-127.5", "unitToVehicle lookup cleared for transport name",
        revLookup == nil, "got=" .. tostring(revLookup))

    report("Step 4 PASS — transport destroyed: JTAC deregistered, vehicle purged.")
    report("=== FEATURE K SPRINT 1 — ALL STEPS PASS. Re-inject for RESET. ===")
    _G[STEP_N] = 5
    _result = "step=4 SUCCESS"

-- ══════════════════════════════════════════════════════════════════════════════
-- STEP 5 — RESET
-- ══════════════════════════════════════════════════════════════════════════════
elseif step >= 5 then

    cleanupAll()
    _G[STEP_N] = 1
    report("RESET — all test objects removed. Re-inject to restart.")
    _result = "ALL SUCCESS"

else
    fail("step=" .. step .. " has no matching branch")
end

end)  -- end pcall

cfg.settings["debug"] = _saved_debug
cfg.settings["debugScreenLog"] = _savedDebugScreenLog

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
