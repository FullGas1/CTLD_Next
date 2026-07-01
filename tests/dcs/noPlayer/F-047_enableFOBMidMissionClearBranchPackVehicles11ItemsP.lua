---@diagnostic disable
-- F-47 : Enable FOB mid-mission + clearBranch Pack Vehicles + 11 items + pagination réelle
-- REQUIRES: F-45 executed first
trigger.action.outText("F-47: Enable FOB + clearBranch + 11 items + pagination", 10)

local players = coalition.getPlayers(coalition.side.BLUE) or {}
local unit = players[1]
if not unit then
    trigger.action.outText("F-47 SKIP: no BLUE player found", 10); return
end
local groupId = unit:getGroup():getID()
local menu    = ctld.MenuManager:getInstance():getMenuByGroupId(groupId)
if not menu then
    trigger.action.outText("F-47 SKIP: no menu found — run F-45 first", 10); return
end

timer.scheduleFunction(function()
    menu:setBranchEnabled({"CTLD Commands","FOB"}, true)
    menu:clearBranch({"CTLD Commands","Pack Vehicles"})
    for i = 1, 11 do
        menu:addCommand({"CTLD Commands","Pack Vehicles"}, "Vehicle_"..i,
            function(arg) end, { id=i })
    end
    menu:refresh()
    trigger.action.outText(
        "F-47 VISUAL CHECK:\n  FOB now visible.\n  Pack Vehicles: 9 items + Next Page (11 total).", 30)
    env.info("[F-47] Menu updated. Awaiting visual confirmation.")
end, {}, timer.getTime() + 3)
