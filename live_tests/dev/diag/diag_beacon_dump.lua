-- diag_beacon_dump.lua — dump all active CTLD beacons: freqs, unit positions, alive status
local mgr = CTLDBeaconManager.getInstance()
local count = 0
local lines = {}

for bname, beacon in pairs(mgr._beacons) do
    count = count + 1
    local entries = {
        { label = "VHF", gname = beacon.vhfGroupName, freq = beacon.vhf },
        { label = "UHF", gname = beacon.uhfGroupName, freq = beacon.uhf },
        { label = "FM",  gname = beacon.fmGroupName,  freq = beacon.fm  },
    }
    lines[#lines+1] = string.format("=== %s (%s) ===", beacon.name, bname)
    lines[#lines+1] = string.format("  isFOB=%s battery=%s",
        tostring(beacon.isFOB),
        beacon.batteryEndTime == -1 and "infinite" or string.format("%.0fs left", beacon.batteryEndTime - timer.getTime()))

    for _, e in ipairs(entries) do
        local g = Group.getByName(e.gname)
        local u = g and g:getUnit(1)
        local pos = u and u:getPoint()
        local posStr = pos and string.format("(%.1f, %.1f, %.1f)", pos.x, pos.y, pos.z) or "UNIT NIL"
        local alive = u and u:isExist() and "ALIVE" or "DEAD/NIL"
        lines[#lines+1] = string.format("  %s: %.4f MHz | mode=%s | unit=%s | pos=%s",
            e.label,
            e.freq / 1000000,
            e.label == "FM" and "FM(1)" or "AM(0)",
            alive,
            posStr)
    end
end

if count == 0 then
    lines[#lines+1] = "No active beacons in CTLDBeaconManager"
end

local msg = table.concat(lines, "\n")
ctld.utils.log("INFO", "[beacon_dump]\n" .. msg)
trigger.action.outText(msg, 30)
return string.format("beacon_dump: %d beacon(s)", count)
