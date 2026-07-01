-- diag_probe_typenames.lua
-- Probes "Invisible FARP" static and igla soldier type names in DCS.
local results = {}
local probePos = { x = -284900, z = 687500 }
local idx = 0

-- 1. Static candidates for Invisible FARP
local sCandidate = { "Invisible FARP", "InvisibleFARP", "Invisible_FARP", "SINGLE_HELIPAD_INVISIBLE" }
for _, tn in ipairs(sCandidate) do
    idx = idx + 1
    local sd = {
        name          = "PROBE_S" .. idx,
        type          = tn,
        category      = "Heliports",
        x             = probePos.x + idx * 8,
        y             = probePos.z + idx * 8,
        heading       = 0,
        start_time    = 0,
        dead          = false,
        transportable = { randomTransportable = false },
    }
    local ok, obj = pcall(coalition.addStaticObject, country.id.USA, sd)
    local valid    = ok and (obj ~= nil)
    results[#results + 1] = string.format("STATIC '%s' -> %s", tn, valid and "OK" or "NOT FOUND")
    if ok and obj then pcall(function() obj:destroy() end) end
end

-- 2. Ground candidates for igla MANPAD soldier
local gCandidates = {
    "Soldier igla",
    "Infantry_Igla",
    "SA-18 Igla manpad",
    "SA-18 Igla-S manpad",
}
for _, tn in ipairs(gCandidates) do
    idx = idx + 1
    local gd = {
        task  = "Ground Nothing",
        name  = "PROBE_G" .. idx,
        units = {{ type = tn, name = "PROBE_G" .. idx .. "_u1",
                   x = probePos.x + idx * 3, y = probePos.z + idx * 3,
                   heading = 0, skill = "Average" }}
    }
    local ok, grp = pcall(coalition.addGroup, country.id.USA, Group.Category.GROUND, gd)
    if ok and grp then
        local us = grp:getUnits()
        if #us > 0 then
            local ok2, actual = pcall(function() return us[1]:getTypeName() end)
            local valid = ok2 and (actual == tn)
            results[#results + 1] = string.format("GROUND '%s' -> %s (actual='%s')",
                tn, valid and "OK" or "SUBSTITUTED", tostring(actual))
        end
        pcall(function() grp:destroy() end)
    else
        results[#results + 1] = string.format("GROUND '%s' -> ADD FAILED", tn)
    end
end

return table.concat(results, " | ")
