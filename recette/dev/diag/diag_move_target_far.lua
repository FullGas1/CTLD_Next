-- diag_move_target_far.lua
-- Teleport current JTAC target 60km north so drone loses target and returns to initial orbit.
local OFFSET_X = 60000  -- 60km north

local jtac
for _, j in pairs(CTLDJTACManager.get().jtacs) do
    if j.isFlying then jtac = j; break end
end
if not jtac then return "NO_FLYING_JTAC" end

-- Find any enemy ground unit visible (current target or nearest red)
local targetName = jtac.currentTarget and jtac.currentTarget.unitName

-- If no current target, find nearest red unit
if not targetName then
    for _, grp in pairs(coalition.getGroups(coalition.side.RED)) do
        local u = grp:getUnit(1)
        if u and u:isExist() then targetName = u:getName(); break end
    end
end
if not targetName then return "NO_TARGET_FOUND" end

local tu = Unit.getByName(targetName)
if not (tu and tu:isExist()) then return "TARGET_NOT_EXIST: " .. targetName end

local tg = tu:getGroup()
local tPos = tu:getPoint()
local tCountry = tu:getCountry()
local tType = tu:getTypeName()
local tGroupName = tg and tg:getName() or targetName

-- Destroy and respawn 30km away
if tg then tg:destroy() else tu:destroy() end

local newX = tPos.x + OFFSET_X
local unitDef = {
    id = ctld.utils.getNextUniqId(),
    name = targetName,
    type = tType,
    x    = newX,
    y    = tPos.z,
    heading = 0,
    skill   = "Average",
    playerCanDrive = false,
}
local groupDef = {
    id       = ctld.utils.getNextUniqId(),
    name     = tGroupName,
    task     = "Ground Nothing",
    start_time = 0,
    units    = { unitDef },
    route    = { points = {{ x=newX, y=tPos.z, type="Turning Point", action="Off Road", speed=0, alt=tPos.y }} },
}
coalition.addGroup(tCountry, Group.Category.GROUND, groupDef)

trigger.action.outText(string.format(
    "[move_target] %s moved 60km north (%.0f,%.0f) → (%.0f,%.0f)\nDrone should return to initial orbit",
    targetName, tPos.x, tPos.z, newX, tPos.z), 15)

return string.format("MOVED: %s to x=%.0f", targetName, newX)
