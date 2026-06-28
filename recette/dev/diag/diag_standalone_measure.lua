-- diag_standalone_measure.lua — mesure distance CTLD_AIR_8 au centre joueur (standalone test)
local GROUP_NAME    = "CTLD_AIR_8"
local TARGET_RADIUS = 1500
local DURATION      = 120
local INTERVAL      = 5

-- Center = player position
local playerUnit = nil
for _, p in pairs(coalition.getPlayers(coalition.side.BLUE)) do
    if p and p:isExist() then playerUnit = p; break end
end
if not playerUnit then return "NO_BLUE_PLAYER" end
local cx = playerUnit:getPoint().x
local cz = playerUnit:getPoint().z

local g = Group.getByName(GROUP_NAME)
if not g then return "GROUP_NOT_FOUND: " .. GROUP_NAME end

local startT = timer.getTime()
local samples = {}
local markBase = 9700
local markIdx  = 0

trigger.action.removeMark(9699)
trigger.action.circleToAll(-1, 9699, playerUnit:getPoint(), TARGET_RADIUS,
    {1.0, 1.0, 0.0, 1.0}, {0,0,0,0}, 1, false,
    string.format("standalone r=%dm", TARGET_RADIUS))

ctld.utils.log("INFO", "[standalone_measure] start: %s center(%.0f,%.0f) r=%d", GROUP_NAME, cx, cz, TARGET_RADIUS)

local function measure(_, t)
    local elapsed = math.floor(t - startT)
    local grp = Group.getByName(GROUP_NAME)
    local u = grp and grp:getUnits()[1]
    if not u or not u:isExist() then return nil end

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

    markIdx = markIdx + 1
    trigger.action.removeMark(markBase + markIdx - 1)
    trigger.action.markToAll(markBase + markIdx,
        string.format("T+%ds d=%.0f dev%+.0f", elapsed, dist, dev), pos, false, "")

    ctld.utils.log("INFO", "[standalone_measure] T+%ds dist=%.0fm dev=%+.0fm avg=%.0fm n=%d",
        elapsed, dist, dev, sum/#samples, #samples)

    if elapsed < DURATION then
        return t + INTERVAL
    else
        ctld.utils.log("INFO", "[standalone_measure][DONE] n=%d min=%.0f max=%.0f avg=%.0f target=%d dev=%+.0f",
            #samples, mn, mx, sum/#samples, TARGET_RADIUS, sum/#samples - TARGET_RADIUS)
        trigger.action.outText(string.format(
            "[standalone] DONE %d samples\nmin=%.0fm max=%.0fm avg=%.0fm\ntarget=%dm dev=%+.0fm",
            #samples, mn, mx, sum/#samples, TARGET_RADIUS, sum/#samples - TARGET_RADIUS), 30)
        return nil
    end
end

timer.scheduleFunction(measure, nil, timer.getTime() + INTERVAL)
return string.format("measuring %s vs r=%dm for %ds", GROUP_NAME, TARGET_RADIUS, DURATION)
