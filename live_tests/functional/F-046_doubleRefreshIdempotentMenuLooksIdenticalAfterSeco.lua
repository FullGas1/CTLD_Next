---@diagnostic disable
-- F-46 : Double refresh() idempotent — menu looks identical after second refresh
-- REQUIRES: F-45 executed first (menu already built)
trigger.action.outText("F-46: Double refresh() idempotent", 10)

local players = coalition.getPlayers(coalition.side.BLUE) or {}
local unit = players[1]
if not unit then
    trigger.action.outText("F-46 SKIP: no BLUE player found", 10)
    env.info("[F-46] SKIP: no BLUE player")
    return
end
local groupId = unit:getGroup():getID()
local menu    = ctld.MenuManager:getInstance():getMenuByGroupId(groupId)
if not menu then
    trigger.action.outText("F-46 SKIP: no menu found — run F-45 first", 10)
    env.info("[F-46] SKIP: no menu found")
    return
end

menu:refresh()
trigger.action.outText("F-46 VISUAL CHECK:\nSecond refresh() done.\nMenu must look identical to F-45.", 20)
env.info("[F-46] Second refresh complete. Awaiting visual confirmation.")
