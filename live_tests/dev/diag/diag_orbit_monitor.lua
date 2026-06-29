-- diag_orbit_monitor.lua
-- Redraw initial orbit circle + show drone live position + state
if mIdx == nil then mIdx = 9500 end
local function gidx() mIdx = mIdx + 1; return mIdx end

local mgr = CTLDJTACManager.get()
local gname, jtac
for k, j in pairs(mgr.jtacs) do
    if j.isFlying then gname, jtac = k, j; break end
end
if not jtac then return "NO_FLYING_JTAC" end

local r = jtac.orbitParams and jtac.orbitParams.orbitRadiusNoLase or ctld.gs("jtacDroneRadius") or 1000

-- Draw initial orbit circle (always new ID — never reuse)
if jtac.initialPosition then
    local cPos = { x = jtac.initialPosition.x, y = 3000, z = jtac.initialPosition.z or jtac.initialPosition.y }
    trigger.action.circleToAll(-1, gidx(), cPos, r,
        {0.2, 0.5, 1.0, 1.0}, {0.2, 0.5, 1.0, 0.05}, 1, false,
        string.format("INIT ORBIT r=%dm", r))
end

-- Draw drone live position
local g = Group.getByName(gname)
local u = g and g:getUnits()[1]
if u and u:isExist() then
    local upos = u:getPoint()
    trigger.action.markToAll(gidx(), string.format("[%s] %s tgt=%s", gname,
        tostring(jtac.state), jtac.currentTarget and jtac.currentTarget.unitName or "none"),
        upos, false, "")

    -- Distance from orbit center
    local ip = jtac.initialPosition
    if ip then
        local cz = ip.z or ip.y
        local dx = upos.x - ip.x
        local dz = upos.z - cz
        local dist = math.sqrt(dx*dx + dz*dz)
        trigger.action.outText(string.format(
            "[monitor] %s | state=%s | onTargetOrbit=%s\ndist from center=%.0fm (target r=%dm)",
            gname, tostring(jtac.state), tostring(jtac.onTargetOrbit), dist, r), 20)
        ctld.utils.log("INFO", "[monitor] %s state=%s onTargetOrbit=%s dist=%.0fm",
            gname, tostring(jtac.state), tostring(jtac.onTargetOrbit), dist)
    end
end
return "monitor drawn"
