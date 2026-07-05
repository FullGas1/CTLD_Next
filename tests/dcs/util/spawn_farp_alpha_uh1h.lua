---@diagnostic disable
-- spawn_farp_alpha_uh1h.lua
-- Spawne la scène FARP Alpha devant l'UH-1H pour vérification visuelle du layout.

local pm = CTLDPlayerManager.getInstance()
local playerObj
for _, p in pairs(pm._players) do
    if p.typeName == "UH-1H" then playerObj = p; break end
end
if not playerObj then
    -- fallback : premier joueur disponible
    for _, p in pairs(pm._players) do playerObj = p; break end
end
if not playerObj then
    trigger.action.outText("[FA-SPAWN] Aucun joueur trouvé.", 10)
    return Witchcraft
end

local unit = Unit.getByName(playerObj.unitName)
if not (unit and unit:isExist()) then
    trigger.action.outText("[FA-SPAWN] Unité introuvable: " .. tostring(playerObj.unitName), 10)
    return Witchcraft
end

trigger.action.outText("[FA-SPAWN] Déploiement FARP Alpha depuis " .. unit:getName() .. " ...", 8)
CTLDSceneManager.getInstance():playScene(unit, "FARP Alpha", nil, function()
    trigger.action.outText("[FA-SPAWN] FARP Alpha déployé — vérification visuelle OK ?", 20)
end)

return Witchcraft
