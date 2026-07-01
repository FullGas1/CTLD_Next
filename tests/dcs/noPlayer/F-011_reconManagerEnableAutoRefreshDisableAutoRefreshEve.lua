---@diagnostic disable
-- ============================================================
-- F-11 : CTLDReconManager enableAutoRefresh / disableAutoRefresh + events
-- Module  : M3 (src/CTLD_recon.lua)
-- Objectif: Vérifier que :
--   - enableAutoRefresh publie OnReconAutoRefreshEnabled (previousState=false, newState=true)
--   - disableAutoRefresh publie OnReconAutoRefreshDisabled (previousState=true, newState=false)
--   - Le timer est créé puis annulé
--
-- On injecte un scan fictif pour s'affranchir de _scanLOS.
-- ============================================================

-- Purge CTLD.log
do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_core.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_recon.lua")

ctld_test.start("F-11", "CTLDReconManager enableAutoRefresh / disableAutoRefresh + events")

CTLDConfig.get().settings["reconEnabled"]       = true
CTLDConfig.get().settings["reconRefreshInterval"] = 10

EventDispatcher._instance    = nil
CTLDDCSEventBridge._instance = nil
CTLDReconManager._instance   = nil

local ok = pcall(function() CTLDReconManager.getInstance() end)
ctld_test.assert(ok, "CTLDReconManager init OK")
local rm = CTLDReconManager._instance

-- Récupérer transport BLUE
local transport = nil
local blueUnits = coalition.getPlayers(coalition.side.BLUE) or {}
if #blueUnits > 0 then transport = blueUnits[1] end

if not transport then
    ctld_test.assert(false, "ECHEC SETUP : aucun transport BLUE")
    ctld_test.finish()
    return
end

local playerName = transport:getPlayerName() or "TestPlayer"

-- Capturer les events
local enabledPayload  = nil
local disabledPayload = nil
EventDispatcher.getInstance():subscribe("OnReconAutoRefreshEnabled", function(p)
    enabledPayload = p
end)
EventDispatcher.getInstance():subscribe("OnReconAutoRefreshDisabled", function(p)
    disabledPayload = p
end)

-- Test enable sans scan préalable → doit retourner sans crash et sans event
local okNoScan = pcall(function()
    rm:enableAutoRefresh(transport, playerName)
end)
ctld_test.assert(okNoScan, "enableAutoRefresh sans scan ne crash pas")
ctld_test.assertNil(enabledPayload, "pas d'event si pas de scan actif")

-- Injecter un scan fictif
rm._activeScans[playerName] = {
    playerUnit   = transport,
    coalition    = 2,
    autoRefresh  = false,
    refreshTimer = nil,
    targets      = {},
    layers       = {},
}

-- enableAutoRefresh
local okEnable = pcall(function()
    rm:enableAutoRefresh(transport, playerName)
end)
ctld_test.assert(okEnable, "enableAutoRefresh avec scan ne crash pas")

ctld_test.assertNotNil(enabledPayload, "OnReconAutoRefreshEnabled publié")
if enabledPayload then
    ctld_test.assertEqual(enabledPayload.previousState, false, "previousState == false")
    ctld_test.assertEqual(enabledPayload.newState,      true,  "newState == true")
    ctld_test.assertEqual(enabledPayload.player,        playerName, "player correct")
    ctld_test.assert(enabledPayload.refreshInterval > 0, "refreshInterval > 0")
end

-- Timer programmé
local scan = rm._activeScans[playerName]
ctld_test.assert(scan ~= nil, "scan toujours présent après enable")
if scan then
    ctld_test.assert(scan.autoRefresh == true, "scan.autoRefresh == true")
    ctld_test.assertNotNil(scan.refreshTimer, "refreshTimer créé")
end

-- enableAutoRefresh une seconde fois → no-op (déjà activé)
local prevEnabledPayload = enabledPayload
local okEnableAgain = pcall(function()
    rm:enableAutoRefresh(transport, playerName)
end)
ctld_test.assert(okEnableAgain, "second enableAutoRefresh ne crash pas")
ctld_test.assert(enabledPayload == prevEnabledPayload,
    "pas de nouvel event si déjà activé")

-- disableAutoRefresh
local okDisable = pcall(function()
    rm:disableAutoRefresh(transport, playerName)
end)
ctld_test.assert(okDisable, "disableAutoRefresh ne crash pas")

ctld_test.assertNotNil(disabledPayload, "OnReconAutoRefreshDisabled publié")
if disabledPayload then
    ctld_test.assertEqual(disabledPayload.previousState, true,  "previousState == true")
    ctld_test.assertEqual(disabledPayload.newState,      false, "newState == false")
end

if scan then
    ctld_test.assert(scan.autoRefresh == false, "scan.autoRefresh == false après disable")
    ctld_test.assertNil(scan.refreshTimer, "refreshTimer annulé après disable")
end

ctld_test.finish()
