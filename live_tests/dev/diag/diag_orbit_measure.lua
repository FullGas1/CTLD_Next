-- diag_orbit_measure.lua
-- Sample drone distance to orbit center every 5s for 90s.
-- Prints min/max/avg distance and deviation from TARGET_RADIUS.

local TARGET_RADIUS = 1500   -- must match diag_orbit_radius_test.lua
local INTERVAL      = 5      -- seconds between samples
local DURATION      = 90     -- total monitoring time

-- Capture orbit center = player position at start
local playerUnit = nil
for _, p in pairs(coalition.getPlayers(coalition.side.BLUE)) do
    if p and p:isExist() then playerUnit = p; break end
end
if not playerUnit then return "NO_BLUE_PLAYER" end
local cx = playerUnit:getPoint().x
local cz = playerUnit:getPoint().z   -- DCS z = horizontal south-north

-- Mark center
trigger.action.removeMark(9060)
trigger.action.markToAll(9060, "ORBIT CENTER", playerUnit:getPoint(), false, "")

-- Find JTAC group
local jtacGroupName = nil
for k, j in pairs(CTLDJTACManager.get().jtacs) do
    if j.isFlying then jtacGroupName = k; break end
end
if not jtacGroupName then return "NO_FLYING_JTAC" end

local samples   = {}
local startT    = timer.getTime()
local markBase  = 9061
local markIdx   = 0

local function sample(_, t)
    local elapsed = math.floor(t - startT)
    local g = Group.getByName(jtacGroupName)
    local u = g and g:getUnits()[1]
    if not u then return nil end

    local pos  = u:getPoint()
    local dx   = pos.x - cx
    local dz   = pos.z - cz
    local dist = math.sqrt(dx*dx + dz*dz)
    local dev  = dist - TARGET_RADIUS

    samples[#samples+1] = dist

    -- Running stats
    local mn, mx, sum = dist, dist, 0
    for _, d in ipairs(samples) do
        if d < mn then mn = d end
        if d > mx then mx = d end
        sum = sum + d
    end
    local avg = sum / #samples

    -- Drop a mark at drone pos
    markIdx = markIdx + 1
    trigger.action.removeMark(markBase + markIdx)
    trigger.action.markToAll(markBase + markIdx,
        string.format("T+%ds d=%.0fm dev%+.0fm", elapsed, dist, dev),
        pos, false, "")

    local msg = string.format(
        "[measure] T+%ds | dist=%.0fm | dev=%+.0fm | min=%.0f max=%.0f avg=%.0f | target=%dm | n=%d",
        elapsed, dist, dev, mn, mx, avg, TARGET_RADIUS, #samples)
    trigger.action.outText(msg, INTERVAL + 1)
    ctld.utils.log("INFO", msg)

    if elapsed < DURATION then
        return t + INTERVAL
    else
        local final = string.format(
            "[measure] DONE %d samples | min=%.0fm max=%.0fm avg=%.0fm | target=%dm | avg_dev=%+.0fm",
            #samples, mn, mx, avg, TARGET_RADIUS, avg - TARGET_RADIUS)
        trigger.action.outText(final, 30)
        ctld.utils.log("INFO", final)
        return nil
    end
end

timer.scheduleFunction(sample, nil, timer.getTime() + INTERVAL)
return string.format("measuring %s vs r=%dm for %ds", jtacGroupName, TARGET_RADIUS, DURATION)
