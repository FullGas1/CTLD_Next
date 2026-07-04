---@diagnostic disable
-- =============================================================================
-- scenario_feature_i_goto_wpz.lua
-- Feature I — Post-spawn task: "gotoNearestWPZ"
--
-- Verifies that a spawned troop group is ordered to march to the nearest WPZ
-- when its template has specificParams = { task = "gotoNearestWPZ" }.
--
-- Protocol:
--   Step 1 — Inject mock WPZ zone, spawn BLUE ground group, call _assignPostSpawnTask
--   Step 2 — (inject 3s later) Verify CTLD.log contains assignment confirmation
--   Step 3 — Cleanup
--
-- Pre-requisites:
--   - BLUE player slot occupied (any aircraft)
--   - CTLD fully initialised (inject CTLD_Next.lua + 5s wait before this scenario)
--   - recette/enable_debug.lua injected before this scenario
-- =============================================================================

-- ── Witchcraft guard ─────────────────────────────────────────────────────────
if not ctld or not ctld.utils then
    trigger.action.outText("[FI-WPZ] ABORT: CTLD not initialized. Inject CTLD_Next.lua first.", 15)
    return Witchcraft
end

local cfg = CTLDConfig.get()
local _saved_debug = cfg.settings["debug"]
local _savedDebugScreenLog = cfg.settings["debugScreenLog"]
cfg.settings["debug"] = true
cfg.settings["debugScreenLog"] = false

local TAG    = "[FI-WPZ]"
local START  = os.date("%Y-%m-%d %H:%M:%S")
local STEP_N = "_FI_WPZ_STEP"

local GRP_NAME    = "FI_WPZ_TestGroup"
local ZONE_NAME   = "FI_WPZ_MockZone"
local WPZ_OFFSET  = 600   -- WPZ injected 600 m north of player

local function log(msg)
    ctld.utils.log("INFO", TAG .. " " .. msg)
end
local function report(msg)
    trigger.action.outText(TAG .. " " .. msg, 30)
    log(msg)
end
local function pass(msg)  report("[PASS] " .. msg) end
local function fail(msg)
    local trace = debug.traceback(msg, 2)
    trigger.action.outText(TAG .. " !! FAIL: " .. msg, 60)
    log("FAIL: " .. trace)
    error(msg)
end
local function check(id, desc, cond, details)
    if cond then pass(id .. " — " .. desc)
    else fail(id .. " — " .. desc .. (details and (" | " .. details) or "")) end
end

-- ── CLEANUP ───────────────────────────────────────────────────────────────────
local function cleanup()
    -- Remove mock WPZ from zone manager
    local zm = CTLDZoneManager.getInstance()
    if zm and zm._troopZones then
        zm._troopZones[ZONE_NAME] = nil
    end
    -- Destroy test group
    local grp = Group.getByName(GRP_NAME)
    if grp and grp:isExist() then grp:destroy() end
    log("cleanup done")
end

-- ── PLAYER RESOLUTION ─────────────────────────────────────────────────────────
local playerUnit = nil
for attempt = 1, 5 do
    local units = coalition.getPlayers(coalition.side.BLUE) or {}
    if #units > 0 and units[1]:isExist() then
        playerUnit = units[1]; break
    end
    local t = os.clock() + 0.5; while os.clock() < t do end
end
if not playerUnit or not playerUnit:isExist() then
    cfg.settings["debug"] = _saved_debug
    return TAG .. " ABORT: no BLUE player"
end

-- ── STATE MACHINE ─────────────────────────────────────────────────────────────
_G[STEP_N] = _G[STEP_N] or 1
local step = _G[STEP_N]
report("==== START " .. START .. " | step=" .. step .. " ====")

if step == 1 then pcall(function()
    ctld.utils.closeLog()
    local f = io.open((cfg.settings["ctldLogPath"] or "") .. "CTLD.log", "w")
    if f then f:write("[" .. START .. "] === LOG RESET ===\n"); f:close() end
    ctld.utils.reopenLogAppend()
end) end

local _step_start = os.clock()
local _result = "INCOMPLETE"
local _ok, _err = pcall(function()

-- ══════════════════════════════════════════════════════════════════════════════
-- STEP 1 — Setup: inject WPZ, spawn group, call _assignPostSpawnTask
-- ══════════════════════════════════════════════════════════════════════════════
if step == 1 then
    cleanup()

    local pPos = playerUnit:getPoint()
    -- Offset spawn 50 m south of player to avoid airbase concrete/runway (no-walk zones)
    local spawnPt  = { x = pPos.x, y = 0, z = pPos.z - 50 }
    spawnPt.y = land.getHeight({ x = spawnPt.x, y = spawnPt.z })
    -- WPZ 600 m north of spawn
    local wpzCenter = { x = pPos.x + WPZ_OFFSET, y = 0, z = pPos.z - 50 }
    wpzCenter.y = land.getHeight({ x = wpzCenter.x, y = wpzCenter.z })

    -- Inject a mock WPZ CTLDTroopZone into the zone manager
    local zm = CTLDZoneManager.getInstance()
    check("FI-WPZ.1.1", "CTLDZoneManager available", zm ~= nil)

    local mockZone = CTLDTroopZone:new({
        dcsName    = ZONE_NAME,
        zoneName   = ZONE_NAME,
        coalition  = coalition.side.BLUE,
        center     = wpzCenter,
        radius     = 300,
        isWaypoint = true,
        active     = true,
    })
    zm._troopZones[ZONE_NAME] = mockZone
    log("Mock WPZ injected at (" .. wpzCenter.x .. ", " .. wpzCenter.z .. ")")

    -- Verify getNearestWaypointZone finds our mock zone
    local found = zm:getNearestWaypointZone(spawnPt, coalition.side.BLUE)
    check("FI-WPZ.1.2", "getNearestWaypointZone returns mock WPZ",
        found ~= nil and found.zoneName == ZONE_NAME,
        "got " .. tostring(found and found.zoneName))

    -- Spawn a real DCS BLUE ground group at player position
    local country = playerUnit:getCountry()
    local grpData = {
        name  = GRP_NAME,
        task  = "Ground Nothing",
        units = {
            { name = GRP_NAME .. "_u1", type = "Soldier M4",
              x = spawnPt.x, y = spawnPt.z, heading = 0, skill = "High",
              playerCanDrive = false, unitId = math.random(90000, 99999) },
        },
    }
    local spawnedGrp = coalition.addGroup(country, Group.Category.GROUND, grpData)
    check("FI-WPZ.1.3", "test group spawned", spawnedGrp ~= nil)

    -- Store WPZ center + initial distance for step 2 verification
    _G["_FI_WPZ_DEST"]      = wpzCenter
    _G["_FI_WPZ_DIST_ORIG"] = ctld.utils.getDistance("FI-WPZ.1", spawnPt, wpzCenter)

    -- Draw WPZ circle on F10 map (all coalitions) so the zone is visible
    local drawPts = {}
    local steps   = 32
    local r       = 300
    for i = 0, steps - 1 do
        local a = i * (2 * math.pi / steps)
        drawPts[#drawPts + 1] = { x = wpzCenter.x + r * math.cos(a), y = wpzCenter.y,
                                   z = wpzCenter.z + r * math.sin(a) }
    end
    -- Close the circle
    drawPts[#drawPts + 1] = drawPts[1]
    for i = 1, #drawPts - 1 do
        trigger.action.lineToAll(-1, 99900 + i, drawPts[i], drawPts[i+1],
            { 0, 0.8, 0, 0.9 }, 2)
    end
    -- Zone label
    trigger.action.textToAll(-1, 99999, wpzCenter, { 0, 0.9, 0, 1 }, { 0, 0, 0, 0 },
        14, true, "WPZ Target")
    log("WPZ zone drawn on F10 map (green circle r=300m)")

    -- Schedule zone-entry detection: poll every 1s, message when unit enters 300m radius
    local _dest    = wpzCenter
    local _entered = false
    timer.scheduleFunction(function(arg)
        if _entered then return end
        local grp2 = Group.getByName(arg.grpName)
        if not grp2 or not grp2:isExist() then return end
        local u = grp2:getUnit(1)
        if not (u and u:isExist()) then return end
        local dist = ctld.utils.getDistance("FI-WPZ.enter", u:getPoint(), arg.dest)
        if dist < 300 then
            _entered = true
            trigger.action.outText("[FI-WPZ] Troops entered WPZ zone (dist=" ..
                string.format("%.0f", dist) .. "m)", 20)
            ctld.utils.log("INFO", "[FI-WPZ] Troops entered WPZ zone dist=%.0f", dist)
        else
            -- Continue polling every 2s (return next fire time)
            return timer.getTime() + 2
        end
    end, { grpName = GRP_NAME, dest = _dest }, timer.getTime() + 3)

    -- Call _assignPostSpawnTask (scheduled +2s)
    CTLDTroopManager.getInstance():_assignPostSpawnTask(
        GRP_NAME, spawnPt, coalition.side.BLUE, { task = "gotoNearestWPZ" })
    log("_assignPostSpawnTask called — task will execute in 2s")

    pass("Step 1 OK — re-inject in 6s+ for Step 2 (wait for unit to start moving)")
    _G[STEP_N] = 2
    _result = "step=1 SUCCESS"

-- ══════════════════════════════════════════════════════════════════════════════
-- STEP 2 — Verify CTLD.log + group alive
-- ══════════════════════════════════════════════════════════════════════════════
elseif step == 2 then
    -- Primary: group still exists
    local grp = Group.getByName(GRP_NAME)
    check("FI-WPZ.2.1", "test group still alive after task assignment",
        grp ~= nil and grp:isExist())

    -- Secondary: unit is moving (velocity > 0 → route task was applied by controller)
    local unit1  = grp and grp:getUnit(1)
    local vel    = unit1 and unit1:getVelocity()
    local speed  = vel and math.sqrt((vel.x or 0)^2 + (vel.z or 0)^2) or 0
    log("unit velocity: " .. string.format("%.3f", speed) .. " m/s")
    check("FI-WPZ.2.2", "unit is moving toward WPZ (speed > 0.1 m/s)",
        speed > 0.1, "speed=" .. string.format("%.3f", speed) .. " m/s")

    -- Tertiary: current position is closer to WPZ than spawn was
    local uPt   = unit1 and unit1:getPoint()
    local dest  = _G["_FI_WPZ_DEST"]
    if uPt and dest then
        local distNow = ctld.utils.getDistance("FI-WPZ.2.3", uPt, dest)
        local distOrig = _G["_FI_WPZ_DIST_ORIG"] or math.huge
        log("distOrig=" .. string.format("%.1f", distOrig) ..
            " distNow=" .. string.format("%.1f", distNow))
        check("FI-WPZ.2.3", "unit closer to WPZ than at spawn", distNow < distOrig,
            "orig=" .. string.format("%.1f", distOrig) ..
            " now=" .. string.format("%.1f", distNow))
    end

    pass("Step 2 OK — gotoNearestWPZ task confirmed. Re-inject for cleanup.")
    _G[STEP_N] = 99
    _result = "step=2 SUCCESS"

-- ══════════════════════════════════════════════════════════════════════════════
-- STEP FINAL — Cleanup + Summary
-- ══════════════════════════════════════════════════════════════════════════════
elseif step >= 99 then
    cleanup()
    report("═══════════════════════════════════")
    report("FI-WPZ — ALL STEPS COMPLETE")
    report("═══════════════════════════════════")
    _G[STEP_N] = 1
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
