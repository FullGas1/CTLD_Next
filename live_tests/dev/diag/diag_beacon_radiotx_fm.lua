-- diag_beacon_radiotx_fm.lua
-- Test radioTransmission mode=1 (FM) avec puissance max sur unités déjà présentes.
-- Objectif : vérifier si radioTransmission FM produit un signal reçu par ARC-131 (audio ou DF).
-- Sons requis dans la mission : beacon.ogg + beaconsilent.ogg (Mission → Sounds → Add)

local TAG = "[FM_RADIOTX]"
local SOUND = "l10n/DEFAULT/beacon.ogg"
local POWER = 100000   -- watts (max pour test)

local playerUnit = (coalition.getPlayers(coalition.side.BLUE) or {})[1]
if not playerUnit or not playerUnit:isExist() then
    return TAG .. " ABORT: pas de joueur BLUE"
end
local pp = playerUnit:getPoint()

-- Positions Ouest/Est
local pos1 = { x = pp.x, y = pp.y, z = pp.z - 300 }
local pos2 = { x = pp.x, y = pp.y, z = pp.z + 300 }

-- Stoppe les transmissions précédentes (activateBeacon)
trigger.action.stopRadioTransmission("CTLD_FM_TEST_1")
trigger.action.stopRadioTransmission("CTLD_FM_TEST_2")

-- Lance radioTransmission FM sur les 2 positions
trigger.action.radioTransmission(SOUND, pos1, 1, true, 40000000, POWER, "CTLD_FM_TEST_1")
trigger.action.radioTransmission(SOUND, pos2, 1, true, 55000000, POWER, "CTLD_FM_TEST_2")

local msg = string.format(
    "%s radioTransmission mode=1 (FM) power=%dW\n" ..
    "TX1 OUEST 300m : 40.000 MHz (loop)\n" ..
    "TX2 EST  300m  : 55.000 MHz (loop)\n\n" ..
    "Tester ARC-131 :\n" ..
    "  40.000 MHz → son beacon audible ? aiguille ?\n" ..
    "  55.000 MHz → son beacon audible ? aiguille ?\n\n" ..
    "PRÉREQUIS : beacon.ogg ajouté dans Mission → Sounds",
    TAG, POWER)

trigger.action.outText(msg, 40)
ctld.utils.log("INFO", "%s TX1=40MHz TX2=55MHz power=%dW", TAG, POWER)
return string.format("%s OK power=%dW TX1+TX2 started", TAG, POWER)
