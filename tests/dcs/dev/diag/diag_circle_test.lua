-- diag_circle_test.lua
-- Standalone test: draws two circles at the player's position to verify circleToAll params.
-- circleToAll(coalition, id, vec3 center, radius, color, fillColor, lineType, readOnly, message)
--   color tables MUST be positional {r, g, b, a} — named keys are silently ignored by DCS

trigger.action.removeMark(9001)
trigger.action.removeMark(9002)

local playerUnit = nil
for _, p in pairs(coalition.getPlayers(coalition.side.BLUE)) do
    if p and p:isExist() then playerUnit = p; break end
end
if not playerUnit then return "NO_BLUE_PLAYER" end

-- getPoint() returns Vec3 {x, y, z} directly
local c1 = playerUnit:getPoint()
local c2 = { x = c1.x + 2000, y = c1.y, z = c1.z + 2000 }

-- BLUE circle
trigger.action.circleToAll(-1, 9001, c1, 2500,
    {0.2, 0.5, 1.0, 1.0}, {0.2, 0.5, 1.0, 0.05}, 1, false, "INITIAL ORBIT")

-- RED circle
trigger.action.circleToAll(-1, 9002, c2, 2500,
    {1.0, 0.1, 0.1, 1.0}, {1.0, 0.1, 0.1, 0.05}, 1, false, "TARGET ORBIT")

return string.format("OK | %s | c1=(%.0f,%.0f) c2=(%.0f,%.0f)",
    playerUnit:getName(), c1.x, c1.z, c2.x, c2.z)
