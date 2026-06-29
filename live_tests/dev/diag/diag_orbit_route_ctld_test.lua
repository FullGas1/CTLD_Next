-- diag_orbit_route_ctld_test.lua
-- Validate that CTLDJTACManager:_setOrbitRoute assigns a working circular route
-- to the drone (via normal CTLD flow — NOT a manual route override).
--
-- Prereq:
--   1. Deploy a JTAC drone via F10 menu (JTAC Commands → Deploy Air JTAC)
--   2. Ensure enableAutoOrbitingFlyingJtacOnTarget = true in config
--   3. Run this script; it samples orbit radius every 5s for 60s and reports avg.

-- ── mark index (monotonic, never reuse) ──────────────────────────────────────
if mIdx == nil then mIdx = 9500 end
local function gidx() mIdx = mIdx + 1; return mIdx end

-- ── 1. Find flying JTAC ───────────────────────────────────────────────────────
local jtacGroupName = nil
local jtacRecord    = nil
for k, j in pairs(CTLDJTACManager.get().jtacs) do
    if j.isFlying and j.state ~= CTLDJTAC.STATE.DEAD then
        jtacGroupName = k
        jtacRecord    = j
        break
    end
end
if not jtacGroupName then return "NO_FLYING_JTAC — deploy a drone first via F10" end

local dcsGroup = Group.getByName(jtacGroupName)
if not dcsGroup then return "GROUP_NOT_FOUND: " .. jtacGroupName end

local dcsUnit = dcsGroup:getUnits()[1]
if not dcsUnit or not dcsUnit:isExist() then return "DRONE_UNIT_NOT_FOUND" end

-- ── 2. Draw orbit center (initialPosition of JTAC) ───────────────────────────
local center = jtacRecord.initialPosition
local cx = center.x
local cz = center.y or center.z   -- initialPosition may be vec2 (x,y) or vec3 (x,y,z)
if center.z then cz = center.z end -- prefer vec3.z if present
-- Correct: initialPosition is stored as vec2 {x, y} where y = DCS z-axis
-- Use center as stored by CTLDJTACManager
local cx2, cz2 = center.x, (center.y ~= nil and center.z == nil) and center.y or (center.z or center.y)

local r = jtacRecord.orbitParams and jtacRecord.orbitParams.orbitRadiusNoLase
       or ctld.gs("jtacDroneRadius") or 1000

local centerPos3 = { x = center.x, y = dcsUnit:getPoint().y, z = cz2 }
trigger.action.circleToAll(
    -1, gidx(), centerPos3, r,
    { 0.2, 0.8, 0.2, 1.0 },
    { 0.2, 0.8, 0.2, 0.05 },
    1, false,
    string.format("ORBIT center r=%dm", r))

trigger.action.outText(string.format(
    "[orbit-test] Drone: %s | center(%.0f,%.0f) | r=%dm | state=%s | onTarget=%s",
    jtacGroupName, center.x, cz2, r,
    tostring(jtacRecord.state), tostring(jtacRecord.onTargetOrbit)), 15)

ctld.utils.log("INFO", "[orbit-test] START group=%s center(%.0f,%.0f) r=%dm",
    jtacGroupName, center.x, cz2, r)

-- ── 3. Sample orbit radius every 5s ─────────────────────────────────────────
local samples    = {}
local MAX_SAMPLE = 12   -- 12 × 5s = 60s
local sampleIdx  = 0

local function sample(_, t)
    sampleIdx = sampleIdx + 1
    local g = Group.getByName(jtacGroupName)
    if not g then return nil end
    local u = g:getUnits()[1]
    if not u or not u:isExist() then return nil end

    local upos = u:getPoint()
    local dx   = upos.x - center.x
    local dz   = upos.z - cz2
    local dist = math.sqrt(dx*dx + dz*dz)
    samples[sampleIdx] = dist

    -- Draw drone position mark
    trigger.action.markToAll(gidx(), string.format("#%d %.0fm", sampleIdx, dist), upos, false, "")

    ctld.utils.log("INFO", "[orbit-test] sample#%d dist=%.0fm", sampleIdx, dist)
    trigger.action.outText(string.format("[orbit-test] #%d dist=%.0fm (target %dm)", sampleIdx, dist, r), 5)

    if sampleIdx >= MAX_SAMPLE then
        -- Compute avg and deviation
        local sum = 0
        for _, v in ipairs(samples) do sum = sum + v end
        local avg = sum / #samples
        local dev = avg - r
        local msg = string.format(
            "[orbit-test] DONE | avg=%.0fm target=%dm dev=%+.0fm (%.1f%%)\n%s",
            avg, r, dev, (dev / r) * 100,
            (math.abs(dev / r) < 0.15) and "PASS — orbit radius OK" or "WARN — deviation > 15%")
        trigger.action.outText(msg, 30)
        ctld.utils.log("INFO", msg)
        return nil
    end
    return t + 5
end

timer.scheduleFunction(sample, nil, timer.getTime() + 5)
return string.format("OK | monitoring %s | %d samples × 5s | target r=%dm", jtacGroupName, MAX_SAMPLE, r)
