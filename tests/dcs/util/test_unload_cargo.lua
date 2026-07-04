-- =============================================================================
-- test_unload_cargo.lua — Test: Unit:UnloadCargo() avant destroy
-- =============================================================================
-- Objectif : vérifier que appeler UnloadCargo() avant dcsStatic:destroy()
-- libère proprement le slot DCS cargo (pas de ghost dans l'UI).
--
-- Prérequis : une crate CTLD chargée via DCS native UI (loadedByDCSNative=true)
-- =============================================================================

local ok, cm = pcall(CTLDCrateManager.getInstance)
if not ok or not cm then
    trigger.action.outText("[TEST] CTLDCrateManager introuvable", 8)
    return "error: no manager"
end

-- Cherche une crate chargée avec dcsStatic encore vivant
local target = nil
for _, crate in pairs(cm.crates or {}) do
    if crate:isLoaded() and crate.dcsStatic and crate.dcsStatic:isExist() then
        target = crate
        break
    end
end

if not target then
    trigger.action.outText("[TEST] Aucune crate chargée avec dcsStatic vivant trouvée", 8)
    return "no target"
end

local transport = target.loadedBy
local staticRef = target.dcsStatic
local crateName = target.crateName

trigger.action.outText(string.format(
    "[TEST] Cible: %s | transport: %s | native: %s",
    crateName,
    transport and transport:getName() or "nil",
    tostring(target.loadedByDCSNative)), 8)

env.info(string.format("[TEST] Avant UnloadCargo — crate=%s native=%s static_exists=%s",
    crateName, tostring(target.loadedByDCSNative), tostring(staticRef:isExist())))

-- 1. Appel UnloadCargo avant destroy
if transport and transport:isExist() then
    local ok2, err = pcall(function()
        transport:UnloadCargo(staticRef)
    end)
    if ok2 then
        env.info("[TEST] UnloadCargo() OK")
        trigger.action.outText("[TEST] UnloadCargo() appelé — OK", 5)
    else
        env.info("[TEST] UnloadCargo() ERREUR: " .. tostring(err))
        trigger.action.outText("[TEST] UnloadCargo() ERREUR: " .. tostring(err), 8)
    end
else
    trigger.action.outText("[TEST] Transport introuvable — UnloadCargo ignoré", 8)
end

-- 2. Destroy le static
local ok3, err3 = pcall(function() staticRef:destroy() end)
if ok3 then
    env.info("[TEST] dcsStatic:destroy() OK")
    trigger.action.outText("[TEST] dcsStatic:destroy() OK", 5)
else
    env.info("[TEST] dcsStatic:destroy() ERREUR: " .. tostring(err3))
    trigger.action.outText("[TEST] ERREUR destroy: " .. tostring(err3), 8)
end

trigger.action.outText("[TEST] Vérifie maintenant l'UI DynamicCargo — ghost présent ?", 10)
return "test done — check UI"
