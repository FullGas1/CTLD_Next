---@diagnostic disable
-- Diagnostic : état CTLD au runtime
do local f = io.open(((ctld and ctld.path or "") .. "CTLD.log"),"w") if f then f:close() end end

local function log(msg)
    env.info("[CTLD-DIAG] " .. tostring(msg))
    local f = io.open(((ctld and ctld.path or "") .. "CTLD.log"),"a")
    if f then f:write("[DIAG] " .. tostring(msg) .. "\n") f:close() end
end

log("=== CTLD RUNTIME DIAGNOSTIC ===")

-- 1. Singletons instanciés ?
log("EventDispatcher._instance : " .. tostring(EventDispatcher and EventDispatcher._instance))
log("CTLDDCSEventBridge._instance : " .. tostring(CTLDDCSEventBridge and CTLDDCSEventBridge._instance))
log("CTLDPlayerManager._instance : " .. tostring(CTLDPlayerManager and CTLDPlayerManager._instance))
log("CTLDZoneManager._instance : " .. tostring(CTLDZoneManager and CTLDZoneManager._instance))
log("CTLDTroopManager._instance : " .. tostring(CTLDTroopManager and CTLDTroopManager._instance))

-- 2. Joueurs trackés
local pm = CTLDPlayerManager and CTLDPlayerManager._instance
if pm then
    local count = 0
    for k, v in pairs(pm._players or {}) do
        count = count + 1
        log("  player: " .. tostring(k) .. "  type=" .. tostring(v.typeName)
            .. "  isTransport=" .. tostring(v.isTransport))
    end
    log("total players tracked: " .. count)
    log("menuSections registered: " .. tostring(#(pm._menuSections or {})))
    for i, s in ipairs(pm._menuSections or {}) do
        log("  section[" .. i .. "] key=" .. tostring(s.key)
            .. "  configKey=" .. tostring(s.configKey))
    end
else
    log("CTLDPlayerManager._instance = nil — CTLD NOT INITIALISED")
end

-- 3. Zones TRZ chargées
local zm = CTLDZoneManager and CTLDZoneManager._instance
if zm then
    local n = 0
    for k, v in pairs(zm._troopZones or {}) do
        n = n + 1
        log("  TRZ '" .. tostring(k) .. "'  dcsName=" .. tostring(v.dcsName)
            .. "  stock=" .. tostring(v.pickMaxStock)
            .. "  flag=" .. tostring(v.objectiveFlag))
    end
    log("total TRZ zones: " .. n)
else
    log("CTLDZoneManager._instance = nil")
end

log("=== END DIAGNOSTIC ===")
