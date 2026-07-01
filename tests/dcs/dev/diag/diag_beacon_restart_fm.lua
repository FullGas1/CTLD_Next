-- diag_beacon_restart_fm.lua — force restart FM transmission on all active beacons
local mgr = CTLDBeaconManager.getInstance()
local sound = "l10n/DEFAULT/" .. (ctld.gs("radioSound") or "beacon.ogg")
local count = 0

for _, beacon in pairs(mgr._beacons) do
    local g = Group.getByName(beacon.fmGroupName)
    local u = g and g:getUnit(1)
    if u and u:isExist() then
        local pos = u:getPoint()
        trigger.action.stopRadioTransmission(beacon.fmGroupName)
        trigger.action.radioTransmission(sound, pos, 1, true, beacon.fm, 1000, beacon.fmGroupName)
        count = count + 1
        local msg = string.format("[beacon_restart_fm] FM restarted: %.4f MHz | pos=(%.1f,%.1f,%.1f)",
            beacon.fm / 1000000, pos.x, pos.y, pos.z)
        ctld.utils.log("INFO", msg)
        trigger.action.outText(msg, 15)
    else
        ctld.utils.log("WARN", "[beacon_restart_fm] FM unit not alive for %s", beacon.fmGroupName)
    end
end
return string.format("restarted %d FM transmission(s)", count)
