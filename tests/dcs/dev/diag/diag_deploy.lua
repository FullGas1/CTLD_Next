---@diagnostic disable
-- diag_deploy.lua : trace l'état de deploy pour le joueur courant
do local f = io.open(((ctld and ctld.path or "") .. "CTLD.log"),"w") if f then f:close() end end

local function log(msg)
    env.info("[DEPLOY] " .. tostring(msg))
    local f = io.open(((ctld and ctld.path or "") .. "CTLD.log"),"a")
    if f then f:write("[DEPLOY] " .. tostring(msg) .. "\n") f:close() end
end

local pm = CTLDPlayerManager and CTLDPlayerManager._instance
if not pm then log("CTLD not init"); return end

local tm = CTLDTroopManager._instance
local zm = CTLDZoneManager._instance

for unitName, player in pairs(pm._players or {}) do
    local unit = Unit.getByName(unitName)
    if not unit then log(unitName .. " : unit not found") break end

    local pt = unit:getPoint()
    log(string.format("unit=%s pos=%.0f/%.0f/%.0f", unitName, pt.x, pt.y, pt.z))

    -- Troops onboard ?
    local group = tm and tm._inTransit and tm._inTransit[unitName]
    log("troops onboard: " .. tostring(group ~= nil) .. (group and (" tmpl=" .. tostring(group.templateName) .. " total=" .. tostring(group.unitTotal)) or ""))

    -- In air ?
    local inAir = tm and tm:_isInAir(unit)
    log("inAir: " .. tostring(inAir))

    -- Zones check
    local exzZone = zm and zm:isUnitInZone(unitName, "extract")
    local pkzZone = zm and zm:isUnitInZone(unitName, "pickup")
    log("extract zone: " .. (exzZone and ("'" .. exzZone.zoneName .. "' flag=" .. tostring(exzZone.objectiveFlag)) or "nil"))
    log("pickup zone : " .. (pkzZone and ("'" .. pkzZone.zoneName .. "' stock=" .. tostring(pkzZone.pickCurrentStock)) or "nil"))

    -- What would deploy() do ?
    if group and not inAir then
        if exzZone then
            log("ACTION: → silent extract (flag increment), NO DCS group spawn")
        elseif pkzZone then
            log("ACTION: → returnToBase (stock restore)")
        else
            log("ACTION: → combat deploy (DCS group spawn)")
        end
    end
end

log("=== END ===")
