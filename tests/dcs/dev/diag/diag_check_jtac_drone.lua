-- diag_check_jtac_drone.lua — find CTLD_JTAC_DRONE_ groups and return status
local found = {}
for _, g in ipairs(coalition.getGroups(coalition.side.BLUE)) do
    local n = g:getName()
    if string.sub(n, 1, 16) == "CTLD_JTAC_DRONE_" then
        local u1  = g:getUnit(1)
        local alt = u1 and u1:getPoint().y or -1
        local cat = g:getCategory()
        table.insert(found, string.format("%s cat=%d alt=%.0f", n, cat, alt))
    end
end
for _, g in ipairs(coalition.getGroups(coalition.side.RED)) do
    local n = g:getName()
    if string.sub(n, 1, 16) == "CTLD_JTAC_DRONE_" then
        table.insert(found, n .. " [RED]")
    end
end
if #found == 0 then return "NO_DRONE_GROUPS_FOUND" end
return table.concat(found, " | ")
