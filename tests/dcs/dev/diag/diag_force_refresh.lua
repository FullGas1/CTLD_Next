---@diagnostic disable
do local f = io.open(((ctld and ctld.path or "") .. "CTLD.log"),"w") if f then f:close() end end

local function log(msg)
    env.info("[REFRESH] " .. tostring(msg))
    local f = io.open(((ctld and ctld.path or "") .. "CTLD.log"),"a")
    if f then f:write("[REFRESH] " .. tostring(msg) .. "\n") f:close() end
end

local pm = CTLDPlayerManager._instance
if not pm then log("not init"); return end

for unitName, player in pairs(pm._players or {}) do
    log("forcing refreshMenuSection for " .. unitName)
    CTLDTroopManager.getInstance():refreshMenuSection(player)
    log("done — inAir=" .. tostring(CTLDTroopManager.getInstance():_isInAir(Unit.getByName(unitName))))
    log("hasTroops=" .. tostring(CTLDTroopManager.getInstance():hasTroops(unitName)))
end
