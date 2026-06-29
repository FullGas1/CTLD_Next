---@diagnostic disable
-- diag_list_players.lua
-- Liste tous les slots dans CTLDPlayerManager

local pm = CTLDPlayerManager.getInstance()
local msg = "[DIAG PLAYERS]\n"
local count = 0
for k, v in pairs(pm._players) do
    count = count + 1
    msg = msg .. "  slot: [" .. tostring(k) .. "]\n"
end
msg = msg .. "Total: " .. count .. "\n"
trigger.action.outText(msg, 30)
return msg
