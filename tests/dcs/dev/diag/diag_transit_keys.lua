---@diagnostic disable
-- diag_transit_keys.lua — dump complet _inTransit avec templateKey

local SLOT = "Batumi_CH-47F_310-1"
local pm   = CTLDPlayerManager.getInstance()
-- auto-detect slot
local found = nil
for k in pairs(pm._players) do
    if k:find("CH%-47") then found = k; break end
end
SLOT = found or SLOT

local tm   = CTLDTroopManager.getInstance()
local list = tm._inTransit[SLOT]

local msg = "[DIAG TRANSIT KEYS] slot=" .. SLOT .. "\n"
if not list then
    msg = msg .. "_inTransit: nil\n"
else
    msg = msg .. "_inTransit: " .. #list .. " group(s)\n"
    for i, g in ipairs(list) do
        msg = msg .. string.format("  [%d] name=%s key=%s total=%s\n",
            i, tostring(g.templateName), tostring(g.templateKey), tostring(g.unitTotal))
    end
end

trigger.action.outText(msg, 30)
return msg
