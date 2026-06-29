-- diag_raw_route_test.lua
-- Fully standalone test: no CTLD manager, no orbit loop.
-- 1. Finds any flying group (CTLD JTAC drone) by name pattern
-- 2. Draws a green circle + a numbered mark at each waypoint
-- 3. Assigns a Mission route (circle) directly on the DCS group
-- 4. Schedules distance samples to CTLD.log every 5s for 90s
--
-- Variables to tune:
local TARGET_RADIUS = 2000   -- meters — must match orbitRadiusNoLase in config
local NUM_PTS       = 8      -- fewer pts = larger segments = easier turns for fixed-wing
local SPEED_KMH     = 150
local ALTI_AGL      = 2000   -- meters AGL

-- ── 1. Disable orbit loop so manager doesn't override the test route ──────────
CTLDConfig.get().settings["enableAutoOrbitingFlyingJtacOnTarget"] = false

-- ── 2. Find flying JTAC and use its initialPosition as orbit center ───────────
local jtacGroupName = nil
local jtacObj       = nil
for k, j in pairs(CTLDJTACManager.get().jtacs) do
    if j.isFlying then jtacGroupName = k; jtacObj = j; break end
end
if not jtacGroupName then return "NO_FLYING_JTAC" end

-- Use initialPosition if captured, else fall back to player position
local refPos
if jtacObj and jtacObj.initialPosition then
    refPos = jtacObj.initialPosition
else
    for _, p in pairs(coalition.getPlayers(coalition.side.BLUE)) do
        if p and p:isExist() then refPos = p:getPoint(); break end
    end
end
if not refPos then return "NO_REF_POS" end

local cx, cz   = refPos.x, refPos.z
local terrainH = land.getHeight({ x = cx, y = cz })
local altASL   = terrainH + ALTI_AGL
local speedMs  = SPEED_KMH / 3.6

local dcsGroup = Group.getByName(jtacGroupName)
if not dcsGroup then return "GROUP_NOT_FOUND" end

-- ── 3. Compute waypoints ──────────────────────────────────────────────────────
local u = dcsGroup:getUnits()[1]
local nearestIdx = 1
if u then
    local upos = u:getPoint()
    local minD = math.huge
    for i = 1, NUM_PTS do
        local angle = 2 * math.pi * (i - 1) / NUM_PTS
        local wx = cx + TARGET_RADIUS * math.cos(angle)
        local wz = cz + TARGET_RADIUS * math.sin(angle)
        local dx = wx - upos.x
        local dz = wz - upos.z
        local d  = dx*dx + dz*dz
        if d < minD then minD = d; nearestIdx = i end
    end
end

-- Build N waypoints on circle + WP N+1 with SwitchWaypoint back to 1 (loop)
local pts = {}
for i = 1, NUM_PTS do
    local idx   = ((nearestIdx + i - 2) % NUM_PTS) + 1
    local angle = 2 * math.pi * (idx - 1) / NUM_PTS
    local wx    = cx + TARGET_RADIUS * math.cos(angle)
    local wz    = cz + TARGET_RADIUS * math.sin(angle)
    pts[i] = {
        x            = wx,
        y            = wz,
        alt          = altASL,
        alt_type     = "BARO",
        speed        = speedMs,
        speed_locked = true,
        type         = "Turning Point",
        action       = "Turning Point",
        ETA          = 0,
        ETA_locked   = false,
        task         = { id = "ComboTask", params = { tasks = {} } },
    }

    -- Mark each WP on F10 map
    local markPos = { x = wx, y = altASL, z = wz }
    trigger.action.removeMark(9200 + i)
    trigger.action.markToAll(9200 + i,
        string.format("WP%d", idx), markPos, false, "")
end

-- Last waypoint: SwitchWaypoint back to 1
local loopIdx = NUM_PTS + 1
local angle0  = 2 * math.pi * (nearestIdx - 1) / NUM_PTS  -- same position as WP1
pts[loopIdx] = {
    x            = cx + TARGET_RADIUS * math.cos(angle0),
    y            = cz + TARGET_RADIUS * math.sin(angle0),
    alt          = altASL,
    alt_type     = "BARO",
    speed        = speedMs,
    speed_locked = true,
    type         = "Turning Point",
    action       = "Turning Point",
    ETA          = 0,
    ETA_locked   = false,
    task         = {
        id     = "ComboTask",
        params = {
            tasks = {
                [1] = {
                    enabled = true,
                    auto    = false,
                    id      = "WrappedAction",
                    number  = 1,
                    params  = {
                        action = {
                            id     = "SwitchWaypoint",
                            params = {
                                goToWaypointIndex   = 1,
                                fromWaypointIndex   = loopIdx,
                            },
                        },
                    },
                },
            },
        },
    },
}

-- ── 4. Draw reference circle ──────────────────────────────────────────────────
trigger.action.removeMark(9199)
trigger.action.circleToAll(-1, 9199, refPos, TARGET_RADIUS,
    {0.2, 0.9, 0.2, 1.0}, {0.2, 0.9, 0.2, 0.05}, 1, false,
    string.format("ROUTE r=%dm %dpts loop", TARGET_RADIUS, NUM_PTS))

-- ── 5. Remove drone from CTLD manager so orbit loop never touches it ─────────
CTLDJTACManager.get().jtacs[jtacGroupName] = nil  -- remove from manager entirely
ctld.utils.log("INFO", "[raw_route] removed %s from manager to prevent orbit loop override", jtacGroupName)

dcsGroup:getController():setTask({
    id     = "Mission",
    params = { route = { points = pts } },
})

ctld.utils.log("INFO", "[raw_route] group=%s center x=%.0f y=%.0f r=%d pts=%d altASL=%.0f spd=%.1f start_wp=%d",
    jtacGroupName, cx, cz, TARGET_RADIUS, NUM_PTS, altASL, speedMs, nearestIdx)
-- Log each WP coord vs circle formula
for i, pt in ipairs(pts) do
    if i <= NUM_PTS then  -- skip loop WP
        ctld.utils.log("INFO", "[raw_route] WP%d -> route(x=%.0f y=%.0f) circle(x=%.0f y=%.0f) match=%s",
            i, pt.x, pt.y,
            cx + TARGET_RADIUS * math.cos(2*math.pi*(i-1)/NUM_PTS),
            cz + TARGET_RADIUS * math.sin(2*math.pi*(i-1)/NUM_PTS),
            tostring(math.abs(pt.x - (cx + TARGET_RADIUS * math.cos(2*math.pi*(i-1)/NUM_PTS))) < 1))
    end
end

trigger.action.outText(string.format(
    "[raw_route] %s | r=%dm | %dpts | altASL=%.0f | spd=%.0f m/s\nstart_wp=%d | route SET",
    jtacGroupName, TARGET_RADIUS, NUM_PTS, altASL, speedMs, nearestIdx), 15)

-- ── 6. Measure distance every 5s for 120s ─────────────────────────────────────
local DURATION   = 120
local INTERVAL   = 5
local startT     = timer.getTime()
local samples    = {}
local markBase   = 9090
local markIdx    = 0

local function measure(_, t)
    local elapsed = math.floor(t - startT)
    local g = Group.getByName(jtacGroupName)
    local un = g and g:getUnits()[1]
    if not un then return nil end

    local pos  = un:getPoint()
    local dx   = pos.x - cx
    local dz   = pos.z - cz
    local dist = math.sqrt(dx*dx + dz*dz)
    local dev  = dist - TARGET_RADIUS
    samples[#samples+1] = dist

    local mn, mx, sum = dist, dist, 0
    for _, d in ipairs(samples) do
        if d < mn then mn = d end
        if d > mx then mx = d end
        sum = sum + d
    end
    local avg = sum / #samples

    markIdx = markIdx + 1
    local mpos = { x = pos.x, y = pos.y, z = pos.z }
    trigger.action.removeMark(markBase + markIdx)
    trigger.action.markToAll(markBase + markIdx,
        string.format("T+%ds d=%.0f dev%+.0f", elapsed, dist, dev), mpos, false, "")

    ctld.utils.log("INFO", "[raw_route][measure] T+%ds dist=%.0fm dev=%+.0fm avg=%.0fm n=%d",
        elapsed, dist, dev, avg, #samples)

    if elapsed < DURATION then
        return t + INTERVAL
    else
        ctld.utils.log("INFO", "[raw_route][DONE] n=%d min=%.0f max=%.0f avg=%.0f target=%d avg_dev=%+.0f",
            #samples, mn, mx, avg, TARGET_RADIUS, avg - TARGET_RADIUS)
        trigger.action.outText(string.format(
            "[raw_route] DONE %d samples\nmin=%.0fm max=%.0fm avg=%.0fm\ntarget=%dm avg_dev=%+.0fm",
            #samples, mn, mx, avg, TARGET_RADIUS, avg - TARGET_RADIUS), 30)
        return nil
    end
end

timer.scheduleFunction(measure, nil, timer.getTime() + INTERVAL)

return string.format("OK | %s | r=%dm | %dpts | start_wp=%d", jtacGroupName, TARGET_RADIUS, NUM_PTS, nearestIdx)
