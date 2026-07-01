---@diagnostic disable
-- diag_trz_stock.lua — dump stock TRZ

local zm  = CTLDZoneManager.getInstance()
local msg = "[DIAG TRZ STOCK]\n"

-- coalition 2 = BLUE
for _, zone in pairs(zm:getTroopZonesForCoalition(2)) do
    if zone:hasPickup() then
        msg = msg .. string.format("  TRZ %s: currentStock=%s maxStock=%s\n",
            tostring(zone.zoneName),
            tostring(zone.pickCurrentStock),
            tostring(zone.pickMaxStock))
    end
end

trigger.action.outText(msg, 30)
return msg
