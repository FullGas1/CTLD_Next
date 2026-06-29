-- diag_jtac_positions.lua — compare drone position vs initialPosition vs target last pos
local mgr = CTLDJTACManager.get()
local gname, jtac
for k, j in pairs(mgr.jtacs) do if j.isFlying then gname, jtac = k, j; break end end
if not jtac then return "NO_FLYING_JTAC" end

local g = Group.getByName(gname)
local u = g and g:getUnit(1)
local dronePos = u and u:getPoint()
local initPos  = jtac.initialPosition

local lines = { string.format("=== %s state=%s ===", gname, tostring(jtac.state)) }

if dronePos then
    lines[#lines+1] = string.format("DRONE     x=%.0f z=%.0f y=%.0f", dronePos.x, dronePos.z, dronePos.y)
    trigger.action.removeMark(9040)
    trigger.action.markToAll(9040, "DRONE NOW", dronePos, false, "")
end

if initPos then
    lines[#lines+1] = string.format("INIT_POS  x=%.0f z=%.0f y=%.0f", initPos.x, initPos.z, initPos.y)
    trigger.action.removeMark(9041)
    trigger.action.markToAll(9041, "INIT_POS (blue circle center)", initPos, false, "")
end

if dronePos and initPos then
    local dx = dronePos.x - initPos.x
    local dz = dronePos.z - initPos.z
    lines[#lines+1] = string.format("DIST drone->init: %.0fm", math.sqrt(dx*dx + dz*dz))
end

local msg = table.concat(lines, "\n")
trigger.action.outText(msg, 30)
env.info("[diag_positions] " .. msg)
return msg
