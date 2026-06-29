-- diag_orbit_radius_test.lua
-- Minimal standalone test: draw a circle of TARGET_RADIUS at player position,
-- then assign an Anchored Orbit task to any flying JTAC drone so it orbits on that circle.
-- Goal: validate that width=diameter produces the expected orbit radius.

local TARGET_RADIUS = 1500   -- meters — change this to test different radii
local SPEED_KMH     = 150
local ALTI_AGL      = 2000   -- meters AGL

-- ── 1. Find the BLUE player (orbit center) ────────────────────────────────────
local playerUnit = nil
for _, p in pairs(coalition.getPlayers(coalition.side.BLUE)) do
    if p and p:isExist() then playerUnit = p; break end
end
if not playerUnit then return "NO_BLUE_PLAYER" end

local center = playerUnit:getPoint()

-- ── 2. Draw the reference circle ─────────────────────────────────────────────
trigger.action.removeMark(9050)
trigger.action.circleToAll(
    -1, 9050, center, TARGET_RADIUS,
    {0.2, 0.8, 0.2, 1.0},   -- green outline
    {0.2, 0.8, 0.2, 0.05},  -- green fill (faint)
    1, false,
    string.format("ORBIT TARGET r=%dm", TARGET_RADIUS)
)

-- ── 3. Find a flying JTAC drone ───────────────────────────────────────────────
local jtacGroupName = nil
for k, j in pairs(CTLDJTACManager.get().jtacs) do
    if j.isFlying then jtacGroupName = k; break end
end
if not jtacGroupName then return "NO_FLYING_JTAC — deploy a drone first" end

local dcsGroup = Group.getByName(jtacGroupName)
if not dcsGroup then return "GROUP_NOT_FOUND: " .. jtacGroupName end

-- ── 4. Build Anchored Orbit task ─────────────────────────────────────────────
local orbitPoint = { x = center.x, y = center.z }   -- vec2 for task
local terrainH   = land.getHeight(orbitPoint)

dcsGroup:getController():setTask({
    id     = "Orbit",
    params = {
        pattern   = "Anchored",
        point     = orbitPoint,
        altitude  = terrainH + ALTI_AGL,
        speed     = SPEED_KMH / 3.6,
        width     = TARGET_RADIUS * 2,
        hotLegDir = 0,
        clockWise = true,
    },
})

trigger.action.outText(string.format(
    "[orbit_test] Group=%s\nCenter: x=%.0f z=%.0f\nRadius=%dm | width=%dm\nAltitude=%.0f ASL | Speed=%.0f m/s\nOrbit task SET — watch the drone!",
    jtacGroupName, center.x, center.z,
    TARGET_RADIUS, TARGET_RADIUS * 2,
    terrainH + ALTI_AGL, SPEED_KMH / 3.6), 30)

return string.format("OK | %s | center(%.0f,%.0f) r=%dm", jtacGroupName, center.x, center.z, TARGET_RADIUS)
