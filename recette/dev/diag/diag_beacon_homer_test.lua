-- diag_beacon_homer_test.lua
-- Test activateBeacon type HOMER (8) sur l'unité FM du beacon CTLD actif.
-- BEACON_TYPE_HOMER = 8 → FM homing, reçu par ARC-131 UH-1H en mode DF.
-- Ref: https://wiki.hoggitworld.com/view/DCS_command_activateBeacon

local mgr = CTLDBeaconManager.getInstance()
local fmUnit, fmFreq

for _, b in pairs(mgr._beacons) do
    local g = Group.getByName(b.fmGroupName)
    local u = g and g:getUnit(1)
    if u and u:isExist() then
        fmUnit = u
        fmFreq = b.fm
        break
    end
end

if not fmUnit then
    return "NO FM UNIT FOUND"
end

local freq = fmFreq  -- ex: 33200000 Hz

-- activateBeacon via setCommand sur le controller de l'unité
-- Paramètres HOMER : type=8, system=4 (ILS Glideslope repurposed for homer), AA=false
-- callsign = "CTD" (3 chars Morse), bearing = true
local cmd = {
    id = "ActivateBeacon",
    params = {
        type      = 8,        -- BEACON_TYPE_HOMER
        system    = 4,        -- essai : 4 = ILS/homer compatible
        AA        = false,
        frequency = freq,
        callsign  = "CTD",
        bearing   = true,
    }
}

fmUnit:getController():setCommand(cmd)

local msg = string.format(
    "[HOMER_TEST] activateBeacon HOMER type=8 system=4\nfreq=%.4f MHz | unit=%s | pos=(%.1f,%.1f,%.1f)\nAccorde ARC-131 sur %.2f MHz mode DF",
    freq/1000000, fmUnit:getName(),
    fmUnit:getPoint().x, fmUnit:getPoint().y, fmUnit:getPoint().z,
    freq/1000000)

ctld.utils.log("INFO", msg)
trigger.action.outText(msg, 30)
return string.format("HOMER beacon activated on %.4f MHz", freq/1000000)
