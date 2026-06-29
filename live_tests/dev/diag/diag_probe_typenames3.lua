local results = {}
local probePos = { x = -284900, z = 687500 }
local idx = 200
for _, tn in ipairs({"Infantry AK", "Soldier AK", "Infantry AK ver 3"}) do
    idx = idx + 1
    local gd = { task="Ground Nothing", name="PROBE3_G"..idx,
        units={{ type=tn, name="PROBE3_G"..idx.."_u1",
            x=probePos.x+idx*3, y=probePos.z+idx*3, heading=0, skill="Average" }} }
    local ok, grp = pcall(coalition.addGroup, country.id.USSR, Group.Category.GROUND, gd)
    if ok and grp then
        local us = grp:getUnits()
        if #us > 0 then
            local ok2, actual = pcall(function() return us[1]:getTypeName() end)
            results[#results+1] = string.format("'%s' -> %s (actual='%s')", tn, (ok2 and actual==tn) and "OK" or "SUBST", tostring(actual))
        end
        pcall(function() grp:destroy() end)
    else
        results[#results+1] = string.format("'%s' -> FAIL", tn)
    end
end
return table.concat(results, " | ")
