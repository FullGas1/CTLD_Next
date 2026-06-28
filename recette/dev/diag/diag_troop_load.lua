---@diagnostic disable
-- Test chargement CTLD_troop.lua en isolation
do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

local function log(msg)
    env.info("[CTLD-TROOP] " .. tostring(msg))
    local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","a")
    if f then f:write("[TROOP] " .. tostring(msg) .. "\n") f:close() end
end

log("CTLDTroopManager before dofile: " .. type(CTLDTroopManager))

local ok, err = pcall(dofile, "C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_troop.lua")
if ok then
    log("CTLD_troop.lua loaded OK")
    log("CTLDTroopManager after dofile: " .. type(CTLDTroopManager))
else
    log("CTLD_troop.lua FAILED: " .. tostring(err))
end
