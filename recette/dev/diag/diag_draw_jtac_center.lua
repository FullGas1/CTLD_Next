-- Draw circle + marks at JTAC initialPosition, nothing else
local jtacGroupName, jtacObj
for k, j in pairs(CTLDJTACManager.get().jtacs) do
    if j.isFlying then jtacGroupName = k; jtacObj = j; break end
end
if not jtacObj then return "NO_FLYING_JTAC" end
if not jtacObj.initialPosition then return "NO_INIT_POS" end

local ip = jtacObj.initialPosition  -- Vec3
local r  = 2000
local n  = 8

trigger.action.removeMark(9300)
trigger.action.circleToAll(-1, 9300, ip, r,
    {0.1, 1.0, 0.1, 1.0}, {0.1, 1.0, 0.1, 0.1}, 1, false,
    string.format("INIT_POS r=%dm", r))
trigger.action.removeMark(9301)
trigger.action.markToAll(9301, "CENTER", ip, false, "")

for i = 1, n do
    local angle = 2 * math.pi * (i-1) / n
    local wx = ip.x + r * math.cos(angle)
    local wz = ip.z + r * math.sin(angle)
    local wpos = { x=wx, y=ip.y, z=wz }
    trigger.action.removeMark(9301 + i)
    trigger.action.markToAll(9301 + i, string.format("W%d", i), wpos, false, "")
end

trigger.action.outText(string.format("DRAWN at x=%.0f z=%.0f r=%dm", ip.x, ip.z, r), 20)
return string.format("OK center(%.0f,%.0f)", ip.x, ip.z)
