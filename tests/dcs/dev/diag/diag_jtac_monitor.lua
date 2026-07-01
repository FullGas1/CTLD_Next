-- diag_jtac_monitor.lua — log JTAC state + drone position every 30s for 4 minutes
-- Run after diag_jtac_deploy_test.lua to observe orbit behavior continuously.

local DURATION = 240  -- seconds
local INTERVAL = 30

local startT = timer.getTime()
local tick = 0

local function monitor(_, t)
    tick = tick + 1
    local elapsed = math.floor(t - startT)

    local mgr = CTLDJTACManager.get()
    local gname, jtac
    for k, j in pairs(mgr.jtacs) do if j.isFlying then gname, jtac = k, j; break end end

    if not jtac then
        trigger.action.outText(string.format("[monitor] T+%ds: NO FLYING JTAC", elapsed), 8)
        return nil
    end

    local g = Group.getByName(gname)
    local u = g and g:getUnit(1)
    local dronePos = u and u:getPoint()
    local initPos  = jtac.initialPosition

    local distToInit = "?"
    if dronePos and initPos then
        local dx = dronePos.x - initPos.x
        local dz = dronePos.z - initPos.z
        distToInit = string.format("%.0fm", math.sqrt(dx*dx + dz*dz))
    end

    trigger.action.outText(string.format(
        "[monitor] T+%ds | state=%s | target=%s\ndist to BLUE center: %s",
        elapsed, tostring(jtac.state),
        jtac.currentTarget and jtac.currentTarget.unitName or "none",
        distToInit), INTERVAL - 2)

    -- Pin at drone position
    trigger.action.removeMark(9030 + tick)
    if dronePos then
        trigger.action.markToAll(9030 + tick,
            string.format("T+%ds %s", elapsed, tostring(jtac.state)), dronePos, false, "")
    end

    if elapsed < DURATION then
        return t + INTERVAL
    end
end

timer.scheduleFunction(monitor, nil, timer.getTime() + INTERVAL)
return "monitoring started — 30s intervals for 4 min"
