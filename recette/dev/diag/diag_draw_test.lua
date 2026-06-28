-- Minimal draw test: circle + mark at player position
local p = nil
for _, u in pairs(coalition.getPlayers(coalition.side.BLUE)) do
    if u and u:isExist() then p = u; break end
end
if not p then return "NO_PLAYER" end
local pos = p:getPoint()

trigger.action.removeMark(9100)
trigger.action.removeMark(9101)

trigger.action.markToAll(9100, string.format("PLAYER x=%.0f z=%.0f", pos.x, pos.z), pos, false, "")
trigger.action.circleToAll(-1, 9101, pos, 1000, {1,0,0,1}, {1,0,0,0.1}, 1, false, "TEST r=1000m")

trigger.action.outText(string.format("DRAWN at x=%.0f z=%.0f", pos.x, pos.z), 30)
return string.format("OK x=%.0f z=%.0f", pos.x, pos.z)
