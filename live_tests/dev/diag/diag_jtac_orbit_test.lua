-- diag_jtac_orbit_test.lua
-- Blue circle  = initial orbit (drone position as center)
-- Red circle   = target orbit (target unit as center)
-- Green circle = drone position check at T+25s
-- Destroys target at T+10s.

local ORBIT_RADIUS = 2500  -- meters

-- color tables MUST be positional {r, g, b, a} — named keys {r=,g=,b=,a=} are ignored by DCS
local function drawCircle(id, center, radius, r, g, b, label)
    trigger.action.circleToAll(-1, id, center, radius,
        { r, g, b, 1.0 },
        { r, g, b, 0.05 },
        2, false, label)
end

local mgr = CTLDJTACManager.get()

local gname, jtac
for k, j in pairs(mgr.jtacs) do
    if j.isFlying and j.currentTarget and j.state ~= CTLDJTAC.STATE.DEAD then
        gname, jtac = k, j
        break
    end
end
if not gname then return "NO_ACTIVE_FLYING_JTAC" end

local targetUnitName = jtac.currentTarget.unitName
local targetUnit = Unit.getByName(targetUnitName)
if not targetUnit then return "TARGET_NOT_FOUND" end

local g = Group.getByName(gname)
local droneUnit = g and g:getUnit(1)
if not droneUnit then return "DRONE_NOT_FOUND" end

-- getPoint() returns Vec3 {x, y, z} directly — no conversion needed
local initCenter = droneUnit:getPoint()
local tgtCenter  = targetUnit:getPoint()

-- Blue = initial orbit (drone position)
drawCircle(701001, initCenter, ORBIT_RADIUS, 0.2, 0.5, 1.0, "INITIAL ORBIT")

-- Red = target orbit
drawCircle(702001, tgtCenter, ORBIT_RADIUS, 1.0, 0.1, 0.1, "TARGET ORBIT - " .. targetUnitName)

trigger.action.outText(string.format(
    "[CTLD] Blue=initial orbit  Red=target orbit  R=%dm\nTarget destroyed in 60s",
    ORBIT_RADIUS), 15)

-- Destroy target at T+60s
timer.scheduleFunction(function()
    local tu = Unit.getByName(targetUnitName)
    if tu and tu:isExist() then
        tu:destroy()
        trigger.action.outText("[CTLD] Target destroyed — drone check in 30s", 8)
    end
end, nil, timer.getTime() + 60)

-- Green circle at T+90s
timer.scheduleFunction(function()
    local g2 = Group.getByName(gname)
    local u2 = g2 and g2:getUnit(1)
    if not u2 then
        trigger.action.outText("[CTLD] Drone gone after destroy", 10)
        return
    end
    local j2 = CTLDJTACManager.get().jtacs[gname]
    local state = j2 and tostring(j2.state) or "?"
    drawCircle(703001, u2:getPoint(), ORBIT_RADIUS, 0.1, 0.9, 0.2,
        "DRONE +25s state=" .. state)
    trigger.action.outText(string.format(
        "[CTLD] T+25s drone state: %s  target: %s",
        state, j2 and j2.currentTarget and j2.currentTarget.unitName or "none"), 15)
end, nil, timer.getTime() + 90)

return string.format("OK | %s -> %s | R=%dm", gname, targetUnitName, ORBIT_RADIUS)
