---@diagnostic disable
-- diag_env.lua : vérifie si CTLD est chargé dans l'environnement DCS
do local f = io.open(((ctld and ctld.path or "") .. "CTLD.log"),"w") if f then f:close() end end

local function log(msg)
    env.info("[CTLD-ENV] " .. tostring(msg))
    local f = io.open(((ctld and ctld.path or "") .. "CTLD.log"),"a")
    if f then f:write("[ENV] " .. tostring(msg) .. "\n") f:close() end
end

log("=== CTLD ENVIRONMENT CHECK ===")
log("ctld global          : " .. type(ctld))
log("CTLDPlayerManager    : " .. type(CTLDPlayerManager))
log("CTLDZoneManager      : " .. type(CTLDZoneManager))
log("CTLDConfig           : " .. type(CTLDConfig))
log("EventDispatcher      : " .. type(EventDispatcher))
log("class (lib)          : " .. type(class))

-- Est-ce que ctld.initialize existe ?
if type(ctld) == "table" then
    log("ctld.initialize      : " .. type(ctld.initialize))
    log("ctld.gs              : " .. type(ctld.gs))
end

-- Quelle est la mission en cours ?
log("timer.getAbsTime()   : " .. tostring(timer.getAbsTime()))
log("=== END ENV CHECK ===")
