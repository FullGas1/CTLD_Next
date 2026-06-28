-- diag_jtac_mark_target.lua — trace drone position + distance to orbit center every 5s
local DURATION  = 120
local INTERVAL  = 5
local mgr       = CTLDJTACManager.get()

-- Find first flying JTAC with initialPosition
local jtacKey, jtacObj
for k, j in pairs(mgr.jtacs) do
    if j.isFlying and j.initialPosition then
        jtacKey = k; jtacObj = j; break
    end
end
if not jtacKey then return "NO_FLYING_JTAC_WITH_INITPOS" end

local cx        = jtacObj.initialPosition.x
local cz        = jtacObj.initialPosition.z
local rNoLase   = jtacObj.orbitParams and jtacObj.orbitParams.orbitRadiusNoLase or ctld.gs("jtacDroneRadius") or 1000
local startT    = timer.getTime()
local samples   = {}
local markBase  = 9600
local markIdx   = 0

-- Draw reference circle
trigger.action.removeMark(9599)
trigger.action.circleToAll(-1, 9599, jtacObj.initialPosition, rNoLase,
    {0.1, 1.0, 0.1, 1.0}, {0.0, 0.0, 0.0, 0.0}, 1, false,
    string.format("orbit r=%.0fm", rNoLase))

ctld.utils.log("INFO", "[mark_target] start: %s center(%.0f,%.0f) r=%.0f", jtacKey, cx, cz, rNoLase)

local function measure(_, t)
    local elapsed = math.floor(t - startT)
    local g = Group.getByName(jtacKey)
    local u = g and g:getUnits()[1]
    if not u or not u:isExist() then
        ctld.utils.log("INFO", "[mark_target] unit gone at T+%ds", elapsed)
        return nil
    end

    local pos  = u:getPoint()
    local dist = math.sqrt((pos.x-cx)^2 + (pos.z-cz)^2)
    local dev  = dist - rNoLase
    samples[#samples+1] = dist

    local mn, mx, sum = dist, dist, 0
    for _, d in ipairs(samples) do
        if d < mn then mn = d end
        if d > mx then mx = d end
        sum = sum + d
    end

    markIdx = markIdx + 1
    trigger.action.removeMark(markBase + markIdx - 1)
    trigger.action.markToAll(markBase + markIdx,
        string.format("T+%ds d=%.0f dev%+.0f", elapsed, dist, dev), pos, false, "")

    ctld.utils.log("INFO", "[mark_target] T+%ds dist=%.0fm dev=%+.0fm avg=%.0fm n=%d",
        elapsed, dist, dev, sum/#samples, #samples)

    if elapsed < DURATION then
        return t + INTERVAL
    else
        ctld.utils.log("INFO", "[mark_target][DONE] n=%d min=%.0f max=%.0f avg=%.0f target=%.0f dev=%+.0f",
            #samples, mn, mx, sum/#samples, rNoLase, sum/#samples - rNoLase)
        trigger.action.outText(string.format(
            "[mark_target] DONE %d samples\nmin=%.0fm max=%.0fm avg=%.0fm\ntarget=%.0fm dev=%+.0fm",
            #samples, mn, mx, sum/#samples, rNoLase, sum/#samples - rNoLase), 30)
        return nil
    end
end

timer.scheduleFunction(measure, nil, timer.getTime() + INTERVAL)
return string.format("monitoring %s r=%.0fm for %ds", jtacKey, rNoLase, DURATION)
