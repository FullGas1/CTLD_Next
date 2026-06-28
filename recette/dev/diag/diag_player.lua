---@diagnostic disable
-- Test : charge zone.lua puis player.lua dans le contexte DCS existant
do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

local BASE = "C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/"
local function log(msg)
    env.info("[P] " .. tostring(msg))
    local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","a")
    if f then f:write("[P] " .. tostring(msg) .. "\n") f:close() end
end

-- État avant
log("Before player.lua: CTLDPlayerManager=" .. type(CTLDPlayerManager))
log("CTLDTroopManager=" .. type(CTLDTroopManager))

-- Charger player.lua seul (dans le contexte où les autres fichiers sont déjà chargés)
local ok, err = pcall(dofile, BASE .. "CTLD_player.lua")
if ok then
    log("CTLD_player.lua OK")
    log("CTLDPlayerManager=" .. type(CTLDPlayerManager))
    log("CTLDPlayer=" .. type(CTLDPlayer))
else
    log("CTLD_player.lua FAIL: " .. tostring(err))
end
