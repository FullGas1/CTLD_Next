---@diagnostic disable
-- ============================================================
-- F-06 : CTLDBeaconManager dropBeacon
-- Module  : M2 (src/CTLD_beacon.lua)
-- Objectif: Vérifier que dropBeacon :
--   1. Spawne 3 unités DCS (VHF, UHF, FM)
--   2. Assigne des fréquences non-nil aux trois bandes
--   3. Publie OnBeaconDropped avec les champs attendus
--
-- DEPENDENCY mission martyr :
--   - Un hélicoptère ou avion joueur BLUE actif (transport)
--   - enabledRadioBeaconDrop doit être true dans la config
-- ============================================================

-- Purge CTLD.log
do local f = io.open("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/CTLD.log","w") if f then f:close() end end

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/recette/setup.lua")

dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_core.lua")
dofile("C:/Users/Moi/Documents/GitHub/DCS-CTLD_FG/src/CTLD_beacon.lua")

ctld_test.start("F-06", "CTLDBeaconManager dropBeacon — unit spawné + freq + OnBeaconDropped")

-- Forcer enabledRadioBeaconDrop = true pour ce test
CTLDConfig.get().settings["enabledRadioBeaconDrop"] = true
CTLDConfig.get().settings["deployedBeaconBattery"]  = 30

EventDispatcher._instance       = nil
CTLDDCSEventBridge._instance    = nil
CTLDBeaconManager._instance     = nil

-- Initialiser le BeaconManager
local ok, err = pcall(function() CTLDBeaconManager.getInstance() end)
ctld_test.assert(ok, string.format("CTLDBeaconManager.getInstance() ne crash pas [%s]", tostring(err)))

local bm = CTLDBeaconManager._instance

-- Capturer l'event OnBeaconDropped
local beaconDroppedPayload = nil
EventDispatcher.getInstance():subscribe("OnBeaconDropped", function(p)
    beaconDroppedPayload = p
end)

-- Récupérer un transport réel depuis la mission
-- DEPENDENCY : remplacer "your_transport_unit" par le nom exact dans la mission martyr
local transportName = "your_transport_unit"
local transport = Unit.getByName(transportName)

if not transport or not transport:isExist() then
    -- Fallback : chercher n'importe quelle unité BLUE
    local blueUnits = coalition.getPlayers(coalition.side.BLUE) or {}
    if #blueUnits > 0 then
        transport = blueUnits[1]
        transportName = transport:getName()
    end
end

if not transport then
    ctld_test.assert(false, "ECHEC SETUP : aucun transport BLUE disponible dans la mission")
    ctld_test.finish()
    return
end

ctld_test.assertNotNil(transport, string.format("transport '%s' trouvé", transportName))

-- Appeler dropBeacon
local beacon, dropErr = nil, nil
local okDrop = pcall(function()
    beacon = bm:dropBeacon(transport, "TestPlayer", false)
end)

ctld_test.assert(okDrop, "dropBeacon ne crash pas")

if beacon then
    -- Fréquences assignées
    ctld_test.assertNotNil(beacon.vhf, "beacon.vhf non-nil")
    ctld_test.assertNotNil(beacon.uhf, "beacon.uhf non-nil")
    ctld_test.assertNotNil(beacon.fm,  "beacon.fm non-nil")

    ctld_test.assert(beacon.vhf > 0, "beacon.vhf > 0")
    ctld_test.assert(beacon.uhf > 0, "beacon.uhf > 0")
    ctld_test.assert(beacon.fm  > 0, "beacon.fm > 0")

    -- Batterie non-infinie (isFOB = false)
    ctld_test.assert(beacon.batteryEndTime ~= -1, "batteryEndTime != -1 (beacon temporaire)")
    ctld_test.assert(beacon:isBatteryAlive(), "beacon vivant juste après drop")

    -- freqText non vide
    local txt = beacon:freqText()
    ctld_test.assertNotNil(txt, "freqText() non-nil")
    ctld_test.assert(#txt > 0, "freqText() non vide")

    -- Unités DCS spawned (3 groupes)
    local alive = beacon:countAliveUnits()
    ctld_test.assertEqual(alive, 3, "3 unités DCS vivantes après drop")
else
    ctld_test.assert(false, "ECHEC : dropBeacon a retourné nil")
end

-- Event OnBeaconDropped publié
ctld_test.assertNotNil(beaconDroppedPayload, "OnBeaconDropped publié")
if beaconDroppedPayload then
    ctld_test.assertEqual(beaconDroppedPayload.player, "TestPlayer",
        "payload.player == 'TestPlayer'")
    ctld_test.assertNotNil(beaconDroppedPayload.beacon,
        "payload.beacon non-nil")
    ctld_test.assertNotNil(beaconDroppedPayload.beacon.frequencies,
        "payload.beacon.frequencies non-nil")
end

ctld_test.finish()
