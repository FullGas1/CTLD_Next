-- Probe White_Flag static with various country IDs
local results = {}
local probePos = { x = -284900, z = 687500 }
local idx = 300

-- Try a range of country IDs
local countries = {
    { id=2,  name="USA" },
    { id=0,  name="USSR" },
    { id=1,  name="Russia" },
    { id=4,  name="Germany" },
    { id=5,  name="UK" },
    { id=13, name="France" },
    { id=29, name="USAF Aggressors" },
    { id=80, name="Combined Joint Task Forces Blue" },
    { id=81, name="Combined Joint Task Forces Red" },
}
for _, c in ipairs(countries) do
    idx = idx + 1
    local sd = {
        name          = "PROBE_FLAG_" .. idx,
        type          = "White_Flag",
        shape_name    = "H-Flag_W",
        category      = "Fortifications",
        x             = probePos.x + idx * 4,
        y             = probePos.z + idx * 4,
        heading       = 0,
        start_time    = 0,
        dead          = false,
        transportable = { randomTransportable = false },
    }
    local ok, obj = pcall(coalition.addStaticObject, c.id, sd)
    local valid = ok and (obj ~= nil)
    if valid then
        -- Check actual type
        local ok2, tn = pcall(function() return obj:getTypeName() end)
        results[#results + 1] = string.format("%s(%d) -> OK type='%s'", c.name, c.id, tostring(tn))
        pcall(function() obj:destroy() end)
    else
        results[#results + 1] = string.format("%s(%d) -> FAIL", c.name, c.id)
    end
end
return table.concat(results, " | ")
