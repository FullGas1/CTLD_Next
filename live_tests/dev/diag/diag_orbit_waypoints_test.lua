-- diag_orbit_waypoints_test.lua
-- Build a circular route (N waypoints) at TARGET_RADIUS and assign it to the JTAC drone.
-- A repeating timer re-issues the route before the drone reaches the last waypoint.

local TARGET_RADIUS = 1500 -- meters
local NUM_PTS       = 16   -- waypoints on the circle
local SPEED_KMH     = 150
local ALTI_AGL      = 2000 -- meters AGL
local REFRESH_EVERY = 200  -- seconds — re-issue route before one full loop (~226s)

-- ── helpers ──────────────────────────────────────────────────────────────────
local function makeCircleRoute(cx, cz, radius, n, altASL, speedMs)
    local pts = {}
    for i = 1, n do
        local angle = 2 * math.pi * (i - 1) / n
        pts[i] = {
            x            = cx + radius * math.cos(angle),
            y            = cz + radius * math.sin(angle),
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
    end
    return pts
end

-- Rotate table so index nearestIdx comes first, for shortest initial fly-to
local function rotateRoute(pts, nearestIdx)
    local n = #pts
    local result = {}
    for i = 1, n do
        result[i] = pts[((nearestIdx + i - 2) % n) + 1]
    end
    return result
end

local function setCircleRoute(dcsGroup, cx, cz, radius, n, altASL, speedMs)
    local pts = makeCircleRoute(cx, cz, radius, n, altASL, speedMs)

    -- Find waypoint nearest to drone's current position to minimise initial transit
    local u = dcsGroup:getUnits()[1]
    local nearestIdx = 1
    if u then
        local upos = u:getPoint()
        local minD = math.huge
        for i, pt in ipairs(pts) do
            local dx = pt.x - upos.x
            local dz = pt.y - upos.z
            local d  = dx * dx + dz * dz
            if d < minD then
                minD = d; nearestIdx = i
            end
        end
    end
    pts = rotateRoute(pts, nearestIdx)

    dcsGroup:getController():setTask({
        id     = "Mission",
        params = { route = { points = pts } },
    })
end
trigger.action.outText("TEST FG", 10)
-- ── 1. Find BLUE player → orbit center ───────────────────────────────────────
local playerUnit = nil
for _, p in pairs(coalition.getPlayers(coalition.side.BLUE)) do
    if p and p:isExist() then
        playerUnit = p; break
    end
end
if not playerUnit then return "NO_BLUE_PLAYER" end

local pPos     = playerUnit:getPoint()
local cx, cz   = pPos.x, pPos.z
local terrainH = land.getHeight({ x = cx, y = cz })
local altASL   = terrainH + ALTI_AGL
local speedMs  = SPEED_KMH / 3.6

-- ── 2. Draw reference circle ──────────────────────────────────────────────────
trigger.action.removeMark(9070)
trigger.action.circleToAll(
    -1, 9070, pPos, TARGET_RADIUS,
    { 0.2, 0.8, 0.2, 1.0 },
    { 0.2, 0.8, 0.2, 0.05 },
    1, false,
    string.format("ORBIT r=%dm", TARGET_RADIUS))

-- Draw waypoint marks
for i = 1, NUM_PTS do
    local angle = 2 * math.pi * (i - 1) / NUM_PTS
    local wx = cx + TARGET_RADIUS * math.cos(angle)
    local wz = cz + TARGET_RADIUS * math.sin(angle)
    local wPos = { x = wx, y = altASL, z = wz }
    trigger.action.removeMark(9070 + i)
    trigger.action.markToAll(9070 + i, tostring(i), wPos, false, "")
end

-- ── 3. Find flying JTAC ───────────────────────────────────────────────────────
local jtacGroupName = nil
for k, j in pairs(CTLDJTACManager.get().jtacs) do
    if j.isFlying then
        jtacGroupName = k; break
    end
end
if not jtacGroupName then return "NO_FLYING_JTAC — deploy a drone first" end

local dcsGroup = Group.getByName(jtacGroupName)
if not dcsGroup then return "GROUP_NOT_FOUND: " .. jtacGroupName end

-- ── 4. Set initial route ──────────────────────────────────────────────────────
setCircleRoute(dcsGroup, cx, cz, TARGET_RADIUS, NUM_PTS, altASL, speedMs)

trigger.action.outText(string.format(
    "[waypoints] %s | r=%dm | %d pts | alt=%.0f ASL | spd=%.0f m/s\nRoute SET — refresh every %ds",
    jtacGroupName, TARGET_RADIUS, NUM_PTS, altASL, speedMs, REFRESH_EVERY), 15)

ctld.utils.log("INFO", "[waypoints] route set | group=%s r=%d pts=%d altASL=%.0f spd=%.1f",
    jtacGroupName, TARGET_RADIUS, NUM_PTS, altASL, speedMs)

-- ── 5. Refresh loop ───────────────────────────────────────────────────────────
local refreshCount = 0
local MAX_REFRESH  = 10 -- stop after 10 refreshes (~33 min)

local function refresh(_, t)
    refreshCount = refreshCount + 1
    if refreshCount > MAX_REFRESH then return nil end

    local g = Group.getByName(jtacGroupName)
    if not g then return nil end

    setCircleRoute(g, cx, cz, TARGET_RADIUS, NUM_PTS, altASL, speedMs)
    ctld.utils.log("INFO", "[waypoints] route refresh #%d", refreshCount)
    return t + REFRESH_EVERY
end

timer.scheduleFunction(refresh, nil, timer.getTime() + REFRESH_EVERY)

return string.format("OK | %s | center(%.0f,%.0f) r=%dm %d pts", jtacGroupName, cx, cz, TARGET_RADIUS, NUM_PTS)
