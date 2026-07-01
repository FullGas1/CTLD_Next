-- patch_menu_remove.lua
-- Patch in-mission: replaces refreshMenuForGroup to only remove CTLD items,
-- preserving standard DCS menu entries (Ground Crew, ATC, etc.)
ctld.MenuManager.refreshMenuForGroup = function(self, groupId)
    if not self.menus[groupId] then
        ctld.logWarning("ctld.MenuManager:refreshMenuForGroup: no menu for group %s", tostring(groupId))
        return { success = false, message = "Menu not found for group " .. tostring(groupId), refreshedCount = 0 }
    end
    local menu = self.menus[groupId]

    for _, item in ipairs(menu.children) do
        missionCommands.removeItemForGroup(groupId, { item.name })
    end

    local count = 0
    for _, item in ipairs(ctld.MenuManager:_sortByOrder(menu.children)) do
        count = count + ctld.MenuManager:_rebuildMenuNode(groupId, {}, item)
    end

    ctld.logInfo("ctld.MenuManager:refreshMenuForGroup: rebuilt %d items for group %d", count, groupId)
    return { success = true, message = "Menu refreshed: " .. count .. " items", refreshedCount = count }
end

-- Force immediate rebuild for all tracked players
local mgr = CTLDPlayerManager.getInstance()
for _, playerObj in pairs(mgr._players or {}) do
    ctld.MenuManager:getInstance():refreshMenuForGroup(playerObj.groupId)
end

trigger.action.outText("Menu patch applied — check F10 now", 15)
ctld.utils.log("INFO", "[patch_menu_remove] applied")
return "patch OK"
