-- diag_beacon_homer_s7.lua
-- Test system=7 (BROADCAST_STATION) sur les unités déjà spawnées par diag_beacon_homer_multi.lua
-- Si les unités ne sont plus là, elles sont re-spawnées.

local TAG = "[HOMER_S7]"
local FREQ1 = 40000000   -- 40.000 MHz  OUEST
local FREQ2 = 55000000   -- 55.000 MHz  EST
local COUNTRY = 2

local function ensureUnit(groupName, unitName, posX, posZ)
    local g = Group.getByName(groupName)
    if g and g:getUnit(1) and g:getUnit(1):isExist() then
        return g:getUnit(1)
    end
    -- Respawn si absent
    local ng = coalition.addGroup(COUNTRY, Group.Category.GROUND, {
        name  = groupName,
        task  = "Ground Nothing",
        x     = posX, y = posZ,
        units = {{
            name    = unitName,
            type    = "Infantry AK",
            x       = posX, y = posZ,
            heading = 0, skill = "Excellent",
        }}
    })
    return ng and ng:getUnit(1)
end

local playerUnit = (coalition.getPlayers(coalition.side.BLUE) or {})[1]
if not playerUnit or not playerUnit:isExist() then
    return TAG .. " ABORT: pas de joueur BLUE"
end
local pp = playerUnit:getPoint()

local u1 = ensureUnit("CTLD_HOMER_TEST_1", "CTLD_HOMER_TEST_1_U1", pp.x, pp.z - 300)
local u2 = ensureUnit("CTLD_HOMER_TEST_2", "CTLD_HOMER_TEST_2_U1", pp.x, pp.z + 300)

local function activate(u, freq, cs, sysVal)
    if not u or not u:isExist() then return "UNIT MISSING" end
    u:getController():setCommand({
        id = "ActivateBeacon",
        params = {
            type      = 8,
            system    = sysVal,
            AA        = false,
            frequency = freq,
            callsign  = cs,
            bearing   = true,
        }
    })
    return "OK"
end

local r1 = activate(u1, FREQ1, "CTD", 7)
local r2 = activate(u2, FREQ2, "CTL", 7)

local msg = string.format(
    "%s type=8 system=7 (BROADCAST_STATION)\n" ..
    "Balise OUEST 300m : 40.000 MHz  CTD  %s\n" ..
    "Balise EST  300m  : 55.000 MHz  CTL  %s\n\n" ..
    "Tester ARC-131 : 40.000 MHz mode DF → aiguille O ?\n" ..
    "              puis 55.000 MHz mode DF → aiguille E ?",
    TAG, r1, r2)

trigger.action.outText(msg, 40)
ctld.utils.log("INFO", "%s system=7 r1=%s r2=%s", TAG, r1, r2)
return string.format("%s system=7 | OUEST=%s | EST=%s", TAG, r1, r2)
