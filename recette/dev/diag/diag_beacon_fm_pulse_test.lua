-- diag_beacon_fm_pulse_test.lua
-- Test solution B : FM pulsée (transmit 7s / stop 1s / repeat)
-- Injecte une boucle timer indépendante du CTLDBeaconManager.
-- Arrêt : recharger la mission ou injecter diag_beacon_fm_pulse_stop.lua

local FREQ   = 33200000   -- 33.2 MHz en Hz
local POWER  = 100        -- watts (test à faible puissance)
local TX_KEY = "CTLD_FM_PULSE_TEST"
local SOUND  = "l10n/DEFAULT/beacon.ogg"
local TX_DUR = 7          -- secondes d'émission
local STOP_DUR = 1        -- secondes de silence

-- Récupère la position de l'unité FM du beacon actif
local mgr  = CTLDBeaconManager.getInstance()
local fmPos = nil
for _, b in pairs(mgr._beacons) do
    local g = Group.getByName(b.fmGroupName)
    local u = g and g:getUnit(1)
    if u and u:isExist() then
        fmPos = u:getPoint()
        FREQ  = b.fm    -- utilise la fréquence réelle du beacon
        break
    end
end

if not fmPos then
    -- Fallback : position fixe si pas de beacon actif
    fmPos = { x = -356664.6, y = 9.3, z = 617543.6 }
    trigger.action.outText("[FM_PULSE] Aucun beacon actif — position fixe utilisée", 5)
end

trigger.action.outText(string.format(
    "[FM_PULSE] Démarrage boucle FM %.4f MHz %dW\ntransmit=%ds / pause=%ds",
    FREQ/1000000, POWER, TX_DUR, STOP_DUR), 10)
ctld.utils.log("INFO", "[FM_PULSE] start %.4f MHz %dW pos=(%.1f,%.1f,%.1f)",
    FREQ/1000000, POWER, fmPos.x, fmPos.y, fmPos.z)

-- Boucle : transmit → schedule stop → schedule restart
local function startTx()
    trigger.action.stopRadioTransmission(TX_KEY)
    trigger.action.radioTransmission(SOUND, fmPos, 1, false, FREQ, POWER, TX_KEY)
    ctld.utils.log("INFO", "[FM_PULSE] TX ON  %.4f MHz", FREQ/1000000)
end

local function stopTx()
    trigger.action.stopRadioTransmission(TX_KEY)
    ctld.utils.log("INFO", "[FM_PULSE] TX OFF %.4f MHz", FREQ/1000000)
end

-- Démarre le cycle
local function cycle(_, t)
    startTx()
    -- Arrêt après TX_DUR secondes
    timer.scheduleFunction(function(_, t2)
        stopTx()
        -- Redémarre après STOP_DUR secondes
        timer.scheduleFunction(cycle, nil, t2 + STOP_DUR)
    end, nil, t + TX_DUR)
end

cycle(nil, timer.getTime())
return string.format("FM pulse started: %.4f MHz %dW cycle=%ds+%ds", FREQ/1000000, POWER, TX_DUR, STOP_DUR)
