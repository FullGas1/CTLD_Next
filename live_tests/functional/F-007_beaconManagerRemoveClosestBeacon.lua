---@diagnostic disable
-- ============================================================
-- F-07 : CTLDBeaconManager removeClosestBeacon
-- Module  : M2 (src/CTLD_beacon.lua)
-- Objectif: Vérifier que removeClosestBeacon :
--   1. Identifie le beacon le plus proche (< 500 m)
--   2. Le supprime de _beacons
--   3. Publie OnBeaconRemoved avec reason="manual"
--
-- DEPENDENCY : Un transport BLUE doit être disponible dans la mission.
-- ============================================================

-- Purge CTLD.log
do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_core.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_beacon.lua")

ctld_test.start("F-07", "CTLDBeaconManager removeClosestBeacon — suppression + OnBeaconRemoved")

CTLDConfig.get().settings["enabledRadioBeaconDrop"] = true
CTLDConfig.get().settings["deployedBeaconBattery"]  = 30

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

-- Capturer OnBeaconDropped puis OnBeaconRemoved
local removedPayload = nil
EventDispatcher.getInstance():subscribe("OnBeaconRemoved", function(p)
    removedPayload = p
end)

-- Dropper un beacon d'abord
local beacon = nil
local okDrop = pcall(function()
    beacon = bm:dropBeacon(transport, "TestPlayer", false)
end)
ctld_test.assert(okDrop, "dropBeacon ne crash pas")

if not beacon then
    ctld_test.assert(false, "ECHEC : dropBeacon nil — impossible de tester removeClosest")
    ctld_test.finish()
    return
end

local beaconCountBefore = 0
for _ in pairs(bm._beacons) do beaconCountBefore = beaconCountBefore + 1 end
ctld_test.assert(beaconCountBefore >= 1, "au moins 1 beacon présent avant remove")

-- Supprimer le beacon le plus proche
local okRemove = pcall(function()
    bm:removeClosestBeacon(transport, "TestPlayer")
end)
ctld_test.assert(okRemove, "removeClosestBeacon ne crash pas")

-- Vérifier la suppression
local beaconCountAfter = 0
for _ in pairs(bm._beacons) do beaconCountAfter = beaconCountAfter + 1 end
ctld_test.assertEqual(beaconCountAfter, beaconCountBefore - 1,
    "nombre de beacons diminué de 1")

-- Event OnBeaconRemoved publié
ctld_test.assertNotNil(removedPayload, "OnBeaconRemoved publié")
if removedPayload then
    ctld_test.assertEqual(removedPayload.reason, "manual", "payload.reason == 'manual'")
    ctld_test.assertEqual(removedPayload.player, "TestPlayer", "payload.player correct")
    ctld_test.assertNotNil(removedPayload.beacon, "payload.beacon non-nil")
    ctld_test.assertNotNil(removedPayload.frequenciesFreed, "payload.frequenciesFreed non-nil")
end

ctld_test.finish()
