-- Quick probe: stinger and infantry types for BLUE guards
local results = {}
local probePos = { x = -284900, z = 687500 }
local idx = 100

local gCandidates = {
    "Soldier stinger",
    "Stinger manpad",
    "FIM-92 Stinger manpad",
    "Soldier M4",
    "Infantry",
}
for _, tn in ipairs(gCandidates) do
    idx = idx + 1
    local gd = {
        task  = "Ground Nothing",
        name  = "PROBE2_G" .. idx,
        units = {{ type = tn, name = "PROBE2_G" .. idx .. "_u1",
                   x = probePos.x + idx * 3, y = probePos.z + idx * 3,
                   heading = 0, skill = "Average" }}
    }
    local ok, grp = pcall(coalition.addGroup, country.id.USA, Group.Category.GROUND, gd)
    if ok and grp then
        local us = grp:getUnits()
        if #us > 0 then
            local ok2, actual = pcall(function() return us[1]:getTypeName() end)
            local valid = ok2 and (actual == tn)
            results[#results + 1] = string.format("'%s' -> %s (actual='%s')",
                tn, valid and "OK" or "SUBSTITUTED", tostring(actual))
        end
        pcall(function() grp:destroy() end)
    else
        results[#results + 1] = string.format("'%s' -> ADD FAILED", tn)
    end
end
return table.concat(results, " | ")
