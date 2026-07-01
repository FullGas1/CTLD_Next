---@diagnostic disable
-- diag_reset_trz_stock.lua — remet le stock de toutes les TRZ à leur max

local zm  = CTLDZoneManager.getInstance()
local msg = "[RESET TRZ STOCK]\n"

for _, zone in pairs(zm:getTroopZonesForCoalition(2)) do
    if zone:hasPickup() and zone.pickMaxStock and zone.pickMaxStock > 0 then
        zone.pickCurrentStock = zone.pickMaxStock
        msg = msg .. "  TRZ " .. zone.zoneName .. " → " .. zone.pickMaxStock .. "\n"
    end
end

trigger.action.outText(msg, 20)
return msg
