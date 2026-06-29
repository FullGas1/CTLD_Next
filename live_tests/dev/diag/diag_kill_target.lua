-- diag_kill_target.lua — destroy current JTAC target; drone should return to BLUE orbit
local jtac
for _, j in pairs(CTLDJTACManager.get().jtacs) do
    if j.isFlying and j.currentTarget then jtac = j; break end
end
if not jtac then return "NO_ACTIVE_TARGET" end

local targetName = jtac.currentTarget.unitName
local tu = Unit.getByName(targetName)
if not (tu and tu:isExist()) then return "TARGET_NOT_FOUND: " .. targetName end

local tg = tu:getGroup()
if tg then tg:destroy() else tu:destroy() end

trigger.action.outText("[diag] Target " .. targetName .. " destroyed — drone should return to BLUE circle", 15)
return "DESTROYED: " .. targetName
