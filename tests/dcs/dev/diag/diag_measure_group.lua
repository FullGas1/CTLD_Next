-- diag_measure_group.lua — measure distance of a named group to player pos
local GROUP_NAME    = "CTLD_AIR_7"
local TARGET_RADIUS = 2000
local INTERVAL      = 5
local DURATION      = 120

local playerUnit = nil
for _, p in pairs(coalition.getPlayers(coalition.side.BLUE)) do
    if p and p:isExist() then playerUnit = p; break end
end
if not playerUnit then return "NO_BLUE_PLAYER" end
local cx = playerUnit:getPoint().x
local cz = playerUnit:getPoint().z

local g = Group.getByName(GROUP_NAME)
if not g then return "GROUP_NOT_FOUND: " .. GROUP_NAME end

local startT  = timer.getTime()
local samples = {}
local markBase = 9210
local markIdx  = 0

local function measure(_, t)
    local elapsed = math.floor(t - startT)
    local grp = Group.getByName(GROUP_NAME)
    local u = grp and grp:getUnits()[1]
    if not u then return nil end

    local pos  = u:getPoint()
    local dist = math.sqrt((pos.x-cx)^2 + (pos.z-cz)^2)
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
    trigger.action.removeMark(markBase + markIdx)
    trigger.action.markToAll(markBase + markIdx,
        string.format("T+%ds d=%.0f dev%+.0f", elapsed, dist, dev), pos, false, "")

    ctld.utils.log("INFO", "[measure_grp] T+%ds dist=%.0fm dev=%+.0fm avg=%.0fm n=%d",
        elapsed, dist, dev, avg, #samples)

    if elapsed < DURATION then
        return t + INTERVAL
    else
        ctld.utils.log("INFO", "[measure_grp][DONE] n=%d min=%.0f max=%.0f avg=%.0f target=%d avg_dev=%+.0f",
            #samples, mn, mx, avg, TARGET_RADIUS, avg - TARGET_RADIUS)
        trigger.action.outText(string.format(
            "[measure_grp] DONE %d samples\nmin=%.0fm max=%.0fm avg=%.0fm\ntarget=%dm avg_dev=%+.0fm",
            #samples, mn, mx, avg, TARGET_RADIUS, avg - TARGET_RADIUS), 30)
        return nil
    end
end

timer.scheduleFunction(measure, nil, timer.getTime() + INTERVAL)
return string.format("measuring %s vs r=%dm for %ds", GROUP_NAME, TARGET_RADIUS, DURATION)
