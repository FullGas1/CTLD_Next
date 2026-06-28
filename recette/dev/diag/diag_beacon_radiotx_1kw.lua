-- diag_beacon_radiotx_1kw.lua
-- Même test que diag_beacon_radiotx_fm.lua mais à 1000W (puissance actuelle CTLD production)
local TAG = "[FM_1KW]"
local SOUND = "l10n/DEFAULT/beacon.ogg"
local POWER = 1000

local playerUnit = (coalition.getPlayers(coalition.side.BLUE) or {})[1]
if not playerUnit or not playerUnit:isExist() then return TAG .. " ABORT" end
local pp = playerUnit:getPoint()

trigger.action.stopRadioTransmission("CTLD_FM_TEST_1")
trigger.action.stopRadioTransmission("CTLD_FM_TEST_2")

trigger.action.radioTransmission(SOUND, { x=pp.x, y=pp.y, z=pp.z-300 }, 1, true, 40000000, POWER, "CTLD_FM_TEST_1")
trigger.action.radioTransmission(SOUND, { x=pp.x, y=pp.y, z=pp.z+300 }, 1, true, 55000000, POWER, "CTLD_FM_TEST_2")

trigger.action.outText(TAG .. " 1000W\nOUEST 40.000 MHz | EST 55.000 MHz\nSon audible ? Aiguille ?", 30)
return TAG .. " OK 1000W"
