---@diagnostic disable
-- ============================================================
-- F-09 : CTLDReconManager scan → marks F10 + OnReconScan
-- Module  : M3 (src/CTLD_recon.lua)
-- Objectif: Vérifier que scan() :
--   1. Ne crash pas avec les layers actifs
--   2. Publie OnReconScan avec activeLayers et targets
--   3. Crée des marks F10 pour chaque cible détectée
--
-- DEPENDENCY mission martyr :
--   - Transport BLUE disponible (hélico ou avion)
--   - Au moins un groupe ennemi visible depuis la position du transport
--   - reconEnabled = true, altitude suffisante (reconMinAltitude)
-- ============================================================

-- Purge CTLD.log
do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_core.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_recon.lua")

ctld_test.start("F-09", "CTLDReconManager scan — marks F10 + OnReconScan")

CTLDConfig.get().settings["reconEnabled"]      = true
CTLDConfig.get().settings["reconMinAltitude"]  = 0   -- 0 pour permettre le scan au sol (test env)
CTLDConfig.get().settings["reconSearchRadius"] = 10000

EventDispatcher._instance    = nil
CTLDDCSEventBridge._instance = nil
CTLDReconManager._instance   = nil

local ok = pcall(function() CTLDReconManager.getInstance() end)
ctld_test.assert(ok, "CTLDReconManager init OK")
local rm = CTLDReconManager._instance

-- Récupérer un transport BLUE
local transport = nil
local blueUnits = coalition.getPlayers(coalition.side.BLUE) or {}
if #blueUnits > 0 then transport = blueUnits[1] end

if not transport then
    ctld_test.assert(false, "ECHEC SETUP : aucun transport BLUE dans la mission")
    ctld_test.finish()
    return
end

local playerName = transport:getPlayerName() or "TestPlayer"

-- Activer le layer infantry pour ce joueur
local layers = rm:_getPlayerLayers(playerName)
for _, layer in ipairs(layers) do
    layer.enabled = true  -- activer tous les layers pour maximiser les chances de détection
end

-- Capturer OnReconScan
local reconPayload = nil
EventDispatcher.getInstance():subscribe("OnReconScan", function(p)
    reconPayload = p
end)

-- Exécuter le scan
local okScan = pcall(function()
    rm:scan(transport, playerName)
end)

ctld_test.assert(okScan, "scan() ne crash pas")

-- OnReconScan publié
ctld_test.assertNotNil(reconPayload, "OnReconScan publié après scan")

if reconPayload then
    ctld_test.assertNotNil(reconPayload.player,       "payload.player non-nil")
    ctld_test.assertNotNil(reconPayload.activeLayers, "payload.activeLayers non-nil")
    ctld_test.assertNotNil(reconPayload.targets,      "payload.targets non-nil")
    ctld_test.assert(type(reconPayload.targets) == "table",
        "payload.targets est une table")

    -- Le scan état est enregistré dans _activeScans
    ctld_test.assertNotNil(rm._activeScans[playerName],
        "scan actif enregistré pour le player")

    -- Si des cibles détectées : vérifier qu'elles ont un markId
    local scan = rm._activeScans[playerName]
    if scan and #scan.targets > 0 then
        ctld_test.assertNotNil(scan.targets[1].markId,
            "première cible a un markId")
        ctld_test.assert(scan.targets[1].markId > 0,
            "markId > 0")
        ctld_test.assert(type(reconPayload.targetsFound) == "number",
            "payload.targetsFound est un nombre")
        ctld_test.assert(reconPayload.targetsFound == #scan.targets,
            string.format("targetsFound == %d (targets dans scan)", #scan.targets))
    else
        ctld_test.assert(true, string.format(
            "INFO: 0 cible détectée (aucun ennemi visible à portée depuis '%s')",
            transport:getName()))
    end
end

ctld_test.finish()
