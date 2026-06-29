---@diagnostic disable
-- diag_refresh_menu.lua — force rebuild menu pour tous les joueurs

local pm = CTLDPlayerManager.getInstance()
local tm = CTLDTroopManager.getInstance()
local count = 0
for _, pObj in pairs(pm._players) do
    tm:refreshMenuSection(pObj)
    count = count + 1
end
trigger.action.outText("[REFRESH MENU] " .. count .. " player(s)", 10)
return "[REFRESH MENU] " .. count
