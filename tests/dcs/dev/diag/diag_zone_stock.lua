---@diagnostic disable
-- diag_zone_stock.lua : état des zones TRZ chargées et stock
do local f = io.open(((ctld and ctld.path or "") .. "CTLD.log"),"w") if f then f:close() end end

local function log(msg)
    env.info("[STOCK] " .. tostring(msg))
    local f = io.open(((ctld and ctld.path or "") .. "CTLD.log"),"a")
    if f then f:write("[STOCK] " .. tostring(msg) .. "\n") f:close() end
end

log("=== ZONE STOCK DIAGNOSTIC ===")

local zm = CTLDZoneManager and CTLDZoneManager._instance
if not zm then log("CTLDZoneManager nil — CTLD not init"); return end

-- Toutes les TRZ
local n = 0
for k, zone in pairs(zm._troopZones or {}) do
    n = n + 1
    log(string.format("TRZ '%s' dcsName=%s coal=%s pickMaxStock=%s pickCurrentStock=%s hasPickup=%s hasExtract=%s",
        tostring(k),
        tostring(zone.dcsName),
        tostring(zone.coalition),
        tostring(zone.pickMaxStock),
        tostring(zone.pickCurrentStock),
        tostring(zone:hasPickup()),
        tostring(zone:hasExtract())))
end
log("total TRZ: " .. n)

-- Templates disponibles (pour voir template.total)
local tm = CTLDTroopManager and CTLDTroopManager._instance
if tm then
    log("--- templates ---")
    for i, t in ipairs(tm._templates or {}) do
        log(string.format("  tmpl[%d] name='%s' total=%s side=%s disabled=%s",
            i, tostring(t.name), tostring(t.total), tostring(t.side), tostring(t.disabled)))
    end
end

log("=== END ===")
