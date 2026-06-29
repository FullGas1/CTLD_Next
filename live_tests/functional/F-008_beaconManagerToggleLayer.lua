---@diagnostic disable
-- ============================================================
-- F-08 : CTLDBeaconManager toggleLayer
-- Module  : M2 (src/CTLD_beacon.lua)
-- Objectif: Vérifier que toggleLayer :
--   1. Passe l'état enabled : false → true puis true → false
--   2. Publie OnBeaconLayerToggled avec les bons champs
--      (previousState, newState, action)
--
-- DEPENDENCY : transport BLUE dans la mission, beaconLayerEnabled=true
-- ============================================================

-- Purge CTLD.log
do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_core.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_beacon.lua")

ctld_test.start("F-08", "CTLDBeaconManager toggleLayer — ON/OFF + OnBeaconLayerToggled")

CTLDConfig.get().settings["enabledRadioBeaconDrop"] = true
CTLDConfig.get().settings["beaconLayerEnabled"]     = true
CTLDConfig.get().settings["beaconAutoRefreshLayer"] = false  -- éviter les draws auto

EventDispatcher._instance    = nil
CTLDDCSEventBridge._instance = nil
CTLDBeaconManager._instance  = nil

local ok = pcall(function() CTLDBeaconManager.getInstance() end)
ctld_test.assert(ok, "CTLDBeaconManager init OK")
local bm = CTLDBeaconManager._instance

-- Récupérer un transport
local transport = nil
local blueUnits = coalition.getPlayers(coalition.side.BLUE) or {}
if #blueUnits > 0 then transport = blueUnits[1] end

if not transport then
    ctld_test.assert(false, "ECHEC SETUP : aucun transport BLUE dans la mission")
    ctld_test.finish()
    return
end

local playerName = transport:getPlayerName() or "TestPlayer"

-- Capturer les events
local payloads = {}
EventDispatcher.getInstance():subscribe("OnBeaconLayerToggled", function(p)
    payloads[#payloads + 1] = p
end)

-- Premier toggle : OFF → ON
local okToggle1 = pcall(function()
    bm:toggleLayer(playerName, transport)
end)
ctld_test.assert(okToggle1, "premier toggleLayer ne crash pas")

ctld_test.assert(#payloads >= 1, "OnBeaconLayerToggled publié (1er toggle)")
if #payloads >= 1 then
    local p1 = payloads[1]
    ctld_test.assertEqual(p1.previousState, false, "1er toggle: previousState == false")
    ctld_test.assertEqual(p1.newState,      true,  "1er toggle: newState == true")
    ctld_test.assertEqual(p1.action,        "enabled", "1er toggle: action == 'enabled'")
    ctld_test.assertEqual(p1.player,        playerName, "payload.player correct")
end

-- Vérifier l'état interne
ctld_test.assert(bm._layerState[playerName] ~= nil, "layerState créé pour le player")
if bm._layerState[playerName] then
    ctld_test.assert(bm._layerState[playerName].enabled == true,
        "layerState.enabled == true après 1er toggle")
end

-- Second toggle : ON → OFF
local okToggle2 = pcall(function()
    bm:toggleLayer(playerName, transport)
end)
ctld_test.assert(okToggle2, "second toggleLayer ne crash pas")

ctld_test.assert(#payloads >= 2, "OnBeaconLayerToggled publié (2ème toggle)")
if #payloads >= 2 then
    local p2 = payloads[2]
    ctld_test.assertEqual(p2.previousState, true,   "2ème toggle: previousState == true")
    ctld_test.assertEqual(p2.newState,      false,  "2ème toggle: newState == false")
    ctld_test.assertEqual(p2.action,        "disabled", "2ème toggle: action == 'disabled'")
end

ctld_test.finish()
