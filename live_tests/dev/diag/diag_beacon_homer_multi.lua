-- diag_beacon_homer_multi.lua
-- Test activateBeacon HOMER (type=8) avec 2 balises FM simultanées sur fréquences différentes.
-- Objectif : déterminer si DCS permet 2 beacons HOMER actifs sur 2 unités distinctes.
--
-- Test 1 (ce script) : type=8, system=4
-- Test 2 (diag_beacon_homer_multi_s7.lua) : type=8, system=7  ← si test 1 sans réception
--
-- Fréquences :
--   Balise 1 : 40.000 MHz  callsign CTD  (300m au Nord du joueur)
--   Balise 2 : 55.000 MHz  callsign CTL  (300m au Sud du joueur)
--
-- Procédure pilote :
--   1. Accorder ARC-131 sur 40.000 MHz → mode DF → vérifier aiguille ou réception Morse CTD
--   2. Accorder ARC-131 sur 55.000 MHz → mode DF → vérifier aiguille ou réception Morse CTL
--   3. Retourner résultat à l'IA pour 2e essai si nécessaire

local TAG = "[HOMER_MULTI]"
local SYSTEM = 4          -- premier essai : system=4 (TACAN_TANKER / repurposed ILS)
local FREQ1  = 40000000   -- 40.000 MHz
local FREQ2  = 55000000   -- 55.000 MHz
local CS1    = "CTD"
local CS2    = "CTL"
local BEACON_TYPE_HOMER = 8
local UNIT_TYPE = "Infantry AK"
local COUNTRY   = 2       -- USA (BLUE)
local LIFETIME  = 600     -- secondes avant cleanup auto (10 min)

-- ── Récupération position joueur ──────────────────────────────────────────────
local playerUnit = nil
do
    local units = coalition.getPlayers(coalition.side.BLUE) or {}
    if #units > 0 then playerUnit = units[1] end
end
if not playerUnit or not playerUnit:isExist() then
    return TAG .. " ABORT: aucun joueur BLUE — occuper un slot"
end

local pp = playerUnit:getPoint()
-- ── Positions : 300m Ouest et 300m Est ───────────────────────────────────────
-- Dans DCS : Est = +Z, Ouest = -Z
local pos1 = { x = pp.x, y = pp.y, z = pp.z - 300 }  -- Ouest
local pos2 = { x = pp.x, y = pp.y, z = pp.z + 300 }  -- Est

-- ── Spawn unités ─────────────────────────────────────────────────────────────
local function spawnBeaconUnit(groupName, unitName, pos)
    -- Destroy si déjà existant (relance propre)
    local existing = Group.getByName(groupName)
    if existing then existing:destroy() end

    local g = coalition.addGroup(COUNTRY, Group.Category.GROUND, {
        name    = groupName,
        task    = "Ground Nothing",
        x       = pos.x,
        y       = pos.z,   -- DCS addGroup: y = Z world
        units   = {
            {
                name    = unitName,
                type    = UNIT_TYPE,
                x       = pos.x,
                y       = pos.z,
                heading = 0,
                skill   = "Excellent",
                playerCanDrive = false,
            }
        }
    })
    return g
end

local G1 = spawnBeaconUnit("CTLD_HOMER_TEST_1", "CTLD_HOMER_TEST_1_U1", pos1)
local G2 = spawnBeaconUnit("CTLD_HOMER_TEST_2", "CTLD_HOMER_TEST_2_U1", pos2)

if not G1 or not G2 then
    return TAG .. " ABORT: échec spawn groupes"
end

-- ── Activation beacons ───────────────────────────────────────────────────────
local function activateHomer(group, freq, callsign)
    local u = group:getUnit(1)
    if not u or not u:isExist() then return false end
    u:getController():setCommand({
        id     = "ActivateBeacon",
        params = {
            type      = BEACON_TYPE_HOMER,
            system    = SYSTEM,
            AA        = false,
            frequency = freq,
            callsign  = callsign,
            bearing   = true,
        }
    })
    return true
end

local ok1 = activateHomer(G1, FREQ1, CS1)
local ok2 = activateHomer(G2, FREQ2, CS2)

-- ── Message écran ────────────────────────────────────────────────────────────
local msg = string.format(
    "%s type=8 system=%d\n" ..
    "Balise 1 (300m OUEST) : %.3f MHz  Morse=%s  %s\n" ..
    "Balise 2 (300m EST)   : %.3f MHz  Morse=%s  %s\n\n" ..
    "Procédure ARC-131 :\n" ..
    "  1. Accorder sur %.3f MHz → mode DF → aiguille vers l'ouest ?\n" ..
    "  2. Accorder sur %.3f MHz → mode DF → aiguille vers l'est ?\n" ..
    "  3. Feedback : réception 0/1/2 balises + comportement aiguille\n" ..
    "(cleanup auto dans %d min)",
    TAG, SYSTEM,
    FREQ1/1e6, CS1, ok1 and "OK" or "FAIL",
    FREQ2/1e6, CS2, ok2 and "OK" or "FAIL",
    FREQ1/1e6,
    FREQ2/1e6,
    LIFETIME/60)

trigger.action.outText(msg, 60)
ctld.utils.log("INFO", "%s system=%d freq1=%.3fMHz freq2=%.3fMHz", TAG, SYSTEM, FREQ1/1e6, FREQ2/1e6)

-- ── Cleanup auto après LIFETIME secondes ─────────────────────────────────────
timer.scheduleFunction(function()
    local g1 = Group.getByName("CTLD_HOMER_TEST_1")
    local g2 = Group.getByName("CTLD_HOMER_TEST_2")
    if g1 then g1:destroy() end
    if g2 then g2:destroy() end
    trigger.action.outText(TAG .. " cleanup — unités test détruites", 10)
    ctld.utils.log("INFO", "%s cleanup done", TAG)
end, nil, timer.getTime() + LIFETIME)

return string.format("%s OK — %.3f MHz (%s) + %.3f MHz (%s) | system=%d | cleanup T+%ds",
    TAG, FREQ1/1e6, CS1, FREQ2/1e6, CS2, SYSTEM, LIFETIME)
