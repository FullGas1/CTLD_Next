-- diag_check_drone_ret.lua — returns group check result as a string
local result = {}
local names = { "CTLD_MQ9_BLUE_TEST", "CTLD_RQ1A_RED_TEST" }
for _, gname in ipairs(names) do
    local g = Group.getByName(gname)
    if g then
        local cat = g:getCategory()
        local u1  = g:getUnit(1)
        local alt = u1 and u1:getPoint().y or -1
        table.insert(result, string.format("%s cat=%d alt=%.0f", gname, cat, alt))
    else
        table.insert(result, gname .. " NOT_FOUND")
    end
end
return table.concat(result, " | ")
